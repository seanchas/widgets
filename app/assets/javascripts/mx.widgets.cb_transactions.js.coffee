global = module?.exports ? ( exports ? this )

global.mx           ||= {}
global.mx.widgets   ||= {}

scope = global.mx.widgets

$ = jQuery

cache = kizzy('mx.widgets.cb_transactions')

columns = [
  { title: { ru: "", en: "" },                                  column: "TITLE",          type: "string"   },
  { title: { ru: "Депозиты", en: "Deposits" },                  column: "WADEPSRATE",     type: "number", is_signed: 0, has_percent: 0, precision: 0  },
  { title: { ru: "Прямое РЕПО", en: "Direct REPO" },            column: "WAREPORATE",     type: "number", is_signed: 0, has_percent: 0, precision: 0  },
  { title: { ru: "Фикс. прямого РЕПО", en: "Direct REPO fix" }, column: "WAREPORATEFIXN", type: "number", is_signed: 0, has_percent: 0, precision: 0  },
  { title: { ru: "Дата", en: "Date" },                          column: "TRADEDATE",      type: "date"     }]

sort_order = [ 0, 1, 4, 3, 5, 2 ]

create_table = ->
  $('<table>')
  .addClass('mx-widget-cb-transactions')
  .html('<thead></thead><tbody></tbody>')

create_table_head = ->
  tr    = $("<tr>")
  for col in columns then tr.append $("<td>").addClass(col.type).html(col.title[ mx.locale() ])
  return tr

create_table_row = (row, index) ->
  tr = $("<tr>")

  for col in columns
    type   = col.type
    column = col.column
    value  = row[column]
    td     = $("<td>").addClass(type)

    switch type
      when "number"
        value = mx.utils.render(value, { type: 'number', precision: col.precision, is_signed: col.is_signed, has_percent: col.has_percent })
      when "date"
        date  = mx.utils.parse_date(value)
        value = mx.widgets.utils.render_value(date, { type: 'date' })

    td.html(if value then value else "-")
    tr.append td

  if (index + 1) %  2 == 0 then tr.toggleClass('even') else tr.toggleClass('odd')



widget = (element) ->
  element = $(element); return unless _.size(element) == 1

  cache_key = mx.utils.sha1(JSON.stringify(_.rest(arguments).join("/")))

  render = (data) ->
    return unless data?

    table = create_table()
    thead = $("thead", table).html(create_table_head)
    tbody = $("tbody", table)

    for order_index, index in sort_order then tbody.append create_table_row(data[order_index], index)

    element.html(table)

  render(cache.get(cache_key))

  mx.iss.cb_transactions().then (data) ->
    render(data)
    cache.set(cache_key, data)


_.extend scope,
  cb_transactions: widget