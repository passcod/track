'use strict'

function makeGraph (target, title, data) {
  for (const dat of data) if (!(dat.date instanceof Date)) dat.date = new Date(dat.date)

  const breakpoint = getComputedStyle(document.documentElement).getPropertyValue('--breakpoint-now')
  let width = parseFloat(breakpoint)
  if (target.parentElement.querySelector('.open-thing')) width *= (1 - 2/12)
  else width *= (1 - 1/12)
  width = width || 600

  MG.data_graphic({
    title,
    data,
    target,
    width,
    height: 200,
    x_accessor: 'date',
    y_accessor: 'value'
  })
}

const allData = new Map
function refreshAllUsing (dataFn) {
  Array.from(document.getElementsByClassName('thing')).forEach(async thing => {
    const target = thing.querySelector('.graph')
    makeGraph(target, thing.dataset.title, (await dataFn(thing)) || allData.get(thing) || [])
  })
}

window.addEventListener('load', () => refreshAllUsing(thing => {
  const dataScript = thing.querySelector('script.data')
  const initial = JSON.parse(dataScript.innerHTML)
  dataScript.remove()
  allData.set(thing, initial)
  return initial
}))

window.addEventListener('resize', () => {
  if (allData.size < 1) return;
  refreshAllUsing(() => 0)
})

setInterval(() => refreshAllUsing(async thing => {
  const topic = thing.dataset.name
  const user = thing.dataset.user
  const url = `/@${user}/${topic}`
  const json = await fetch(url, { headers: { Accept: 'application/json' } })
  const data = (await json.json()).points
  allData.set(thing, data)
  return data
}), 60000)
