require 'bundler'
Bundler.require :default

configure do
  DB = Sequel.connect ENV['DATABASE_URL']
end

get '/' do
  redirect '/@felix', 307
end

get '/@:user', provides: 'html' do
  @user = DB[:users].where(name: params['user']).first
  halt 404 if @user.nil?

  @things = DB[:things].where(user_id: @user[:id])

  haml :user
end

get '/@:user', provides: 'json' do
  content_type :json
  @user = DB[:users].where(name: params['user']).first
  halt 404 if @user.nil?

  JSON.generate(
    things: DB[:things]
      .select(:name)
      .where(user_id: @user[:id])
      .map { |t| t[:name] }
  )
end

get '/@:user/:thing', provides: 'html' do
  @user = DB[:users].where(name: params['user']).first
  halt 404 if @user.nil?

  @thing = DB[:things].where(user_id: @user[:id], name: params['thing']).first
  halt 404 if @thing.nil?

  @points = DB[:points].where(thing_id: @thing[:id]).order_by(:created)

  haml :thing
end

get '/@:user/:thing', provides: 'json' do
  content_type :json
  @user = DB[:users].where(name: params['user']).first
  halt 404 if @user.nil?

  @thing = DB[:things].where(user_id: @user[:id], name: params['thing']).first
  halt 404 if @thing.nil?

  JSON.generate(
    points: DB[:points]
      .select(:value, :created)
      .where(thing_id: @thing[:id])
      .order_by(:created)
      .map { |p| { date: p[:created].iso8601, value: p[:value] } }
  )
end

post '/@:user/:thing' do
  content_type :text

  bod = request.body.read.to_s.strip
  value = bod.to_i
  halt 400, "#{bod} #{value} what?" unless value.to_s == bod

  halt 400, 'stop' if request.env['HTTP_AUTHORIZATION'].nil?
  auth = request.env['HTTP_AUTHORIZATION'].strip
  halt 400, 'bad' unless auth.start_with? /^Bearer\s+/
  auth = auth.split.last
  halt 400, 'still bad' if auth.nil?
  key, code = auth.split('.')
  halt 400, 'also bad' if key.nil? || code.nil? || key.length != 64 || code.length < 5

  @user = DB[:users].where(name: params['user']).first
  halt 404, 'no' if @user.nil?
  halt 403, 'nope' if @user[:key] != key
  halt 403, 'nuh-uh' unless TOTP.valid?(@user[:secret], code.to_i)

  @thing = DB[:things].where(user_id: @user[:id], name: params['thing']).first
  if @thing.nil?
    id = DB[:things].insert(user_id: @user[:id], name: params['thing'])
    @thing = DB[:things].where(id: id).first
    halt 500, 'uh-oh' if @thing.nil?
  end

  pid = DB[:points].insert(thing_id: @thing[:id], value: value)
  halt 500, 'oh-no' if pid.nil?

  halt 200, 'ok'
end
