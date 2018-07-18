require 'bundler'
Bundler.require :default

configure do
  DB = Sequel.connect ENV['DATABASE_URL']
end

helpers do
  def user_by_name(name)
    DB[:users].where(name: name).first
  end

  def thing_by_name(user_id, name)
    DB[:things].where(user_id: user_id, name: name).first
  end

  def things_of_user(user_id)
    DB[:things].where(user_id: user_id)
  end

  def points_of_thing(thing_id, opts = {})
    limit = opts[:no_limit] ? nil : (opts[:limit] || 500)
    range = opts[:no_range] ? nil : (opts[:range] || '12 hour')

    q = DB[:points].where(thing_id: thing_id).order_by(:created)

    q = q.limit(limit) if limit
    q = q.where { created > now() - Sequel.lit('interval') range } if range

    q
  end

  def data_of_thing(thing_id)
    points_of_thing(thing_id)
      .select(:value, :created)
      .map { |p| { date: p[:created].iso8601, value: p[:value] } }
  end

  def pretty_name(name)
    name.gsub('-', ' ').capitalize
  end
end

get '/' do
  @users = DB[:users]
  if @users.count == 1
    redirect "/@#{@users.first[:name]}", 307
  else
    haml :index
  end
end

get '/@:user', provides: 'html' do
  @user = user_by_name(params['user'])
  halt 404 if @user.nil?

  @title = "#{pretty_name @user[:name]}’s things"
  @things = things_of_user(@user[:id])
  haml :user
end

get '/@:user', provides: 'json' do
  content_type :json
  @user = user_by_name(params['user'])
  halt 404 if @user.nil?

  JSON.generate(
    things: things_of_user(@user[:id])
      .select(:name)
      .map { |t| t[:name] }
  )
end

get '/@:user/:thing', provides: 'html' do
  @user = user_by_name(params['user'])
  halt 404 if @user.nil?

  @thing = thing_by_name(@user[:id], params['thing'])
  halt 404 if @thing.nil?

  @title = "#{pretty_name @user[:name]}’s thing: #{pretty_name @thing[:name]}"
  haml :thing
end

get '/@:user/:thing', provides: 'json' do
  content_type :json
  @user = user_by_name(params['user'])
  halt 404 if @user.nil?

  @thing = thing_by_name(@user[:id], params['thing'])
  halt 404 if @thing.nil?

  JSON.generate(points: data_of_thing(@thing[:id]))
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

  @user = user_by_name(params['user'])
  halt 404, 'no' if @user.nil?
  halt 403, 'nope' if @user[:key] != key
  halt 403, 'nuh-uh' unless TOTP.valid?(@user[:secret], code.to_i)

  @thing = thing_by_name(@user[:id], params['thing'])
  if @thing.nil?
    id = DB[:things].insert(user_id: @user[:id], name: params['thing'])
    @thing = DB[:things].where(id: id).first
    halt 500, 'uh-oh' if @thing.nil?
  end

  pid = DB[:points].insert(thing_id: @thing[:id], value: value)
  halt 500, 'oh-no' if pid.nil?

  halt 200, 'ok'
end
