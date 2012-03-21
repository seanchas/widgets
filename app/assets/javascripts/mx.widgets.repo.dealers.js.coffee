global = module?.exports ? ( exports ? this )

global.mx           ||= {}
global.mx.widgets   ||= {}

scope = global.mx.widgets

$ = jQuery

cache = kizzy('mx.widgets.repo_dealers')

columns = [
    { title: { ru: "Срок РЕПО", en: "REPO term" },              column: "TITLE",       type: "string"   },
    { title: { ru: "Ставка, % годовых", en: "Rate, PCPA" },     column: "WARATE",      type: "number", is_signed: 0, has_percent: 0, precision: 2   },
    { title: { ru: "Изменение", en: "Change" },                 column: "TRENDWARATE", type: "number", is_signed: 1, has_percent: 1, precision: 2   },
    { title: { ru: "Объем, млн. руб.", en: "Volume, mln RUB" }, column: "TOTALVALUE",  type: "number", is_signed: 0, has_percent: 0, precision: 2   },
    { title: { ru: "Сделок, шт.", en: "Trades, pcs" },          column: "NUMTRADES",   type: "number", is_signed: 0, has_percent: 0, precision: 0   },
    { title: { ru: "Дата", en: "Date" },                        column: "TRADEDATE",   type: "date"     }]

create_table = ->
    $('<table>')
    .addClass('mx-widget-repo-dealers')
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
                if _.include(["WARATE", "TRENDWARATE"], column)
                    td.toggleClass('gt', value >  0)
                    td.toggleClass('le', value <  0)
                    td.toggleClass('eq', value == 0)
                value = mx.utils.render(value, { type: 'number', precision: col.precision, is_signed: col.is_signed, has_percent: col.has_percent })
            when "date"
                date  = mx.utils.parse_date(value)
                value = mx.widgets.utils.render_value(date, { type: 'date' })

        td.html(if value then value else "-")
        tr.append td

    if (index + 1) %  2 == 0 then tr.toggleClass('even') else tr.toggleClass('odd')



widget = (element) ->
    element = $(element); return unless _.size(element) == 1

    cache_key = mx.utils.sha1( "repo_dealers" + mx.locale() )

    render = (data) ->
        return unless data?

        table = create_table()
        thead = $("thead", table).html(create_table_head)
        tbody = $("tbody", table)

        for row, index in data then tbody.append create_table_row(row, index)

        element.html(table)

    render(cache.get(cache_key))

    mx.iss.repo_dealers().then (data) ->
        render(data)
        cache.set(cache_key, data)


_.extend scope,
    repo_dealers: widget