'use strict'

function rem2px (rem) {
  return rem * parseFloat(getComputedStyle(document.documentElement).fontSize)
}

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

window.addEventListener('load', () =>
  Array.from(document.getElementsByClassName('thing')).forEach(thing => {
    const dataScript = thing.querySelector('script.data')
    const initial = JSON.parse(dataScript.innerHTML)
    const target = thing.querySelector('.graph')
    dataScript.remove()
    makeGraph(target, thing.dataset.title, initial)
  })
)
