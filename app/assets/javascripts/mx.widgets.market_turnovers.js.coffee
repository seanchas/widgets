global = module?.exports ? ( exports ? this )

global.mx           ||= {}
global.mx.widgets   ||= {}

scope = global.mx.widgets

$ = jQuery

cache = kizzy('mx.widgets.market_turnovers')

localization =
    ru:
        current_value: 'Текущее значение'
        previous_date: 'Предыдущее закрытие'
        valtoday:      'Объем торгов (РУБ)'
        valtoday_usd:  'Объем торгов (USD)'
        numtrades:     'Число сделок'



widget = (element, engine, markets, options = {}) ->
    element = $(element); return unless _.size(element)

    markets        ||= []
    markets          = markets.split(",").map( (w) -> w.trim() ) if _.isString(markets)

    refresh_timeout  = options.refresh_timeout || 1 * 1000

    cache_key = mx.utils.sha1(JSON.stringify({ engine: engine, markets: markets, options: options, locale: mx.locale() }))

    table = $("<table>").addClass('mx-widget-table').html("<thead></thead><tbody></tbody>")
    table_head = $('thead', table)
    table_body = $('tbody', table)

    create_table_head = _.once () ->
        first_row  = $("<tr>").append($("<th>"))
            .append($("<th colspan=\"2\">").html(localization[mx.locale()].current_value))
            .append($("<th colspan=\"2\">").html(localization[mx.locale()].previous_date))

        valtoday_title = localization[mx.locale()][ if options.usd then "valtoday_usd" else "valtoday" ]

        second_row = $("<tr>").append($("<th>"))
            .append($("<th>").html(valtoday_title))
            .append($("<th>").html(localization[mx.locale()].numtrades))
            .append($("<th>").html(valtoday_title))
            .append($("<th>").html(localization[mx.locale()].numtrades))

        table_head.append(first_row).append(second_row)


    create_table_body = (data) ->
        table_body.empty()
        for market in data.turnovers
            row = $("<tr>")
                .append($("<td>").html(market['TITLE'] || '-'))
                .append($("<td>").html(market[ if options.usd then 'VALTODAY_USD' else 'VALTODAY' ] || '-'))
                .append($("<td>").html(market['NUMTRADES'] || '-'))
            prevdate = _.find(data.turnoversprevdate, ((m) -> m['NAME'] is market['NAME']))
            row
                .append($("<td>").html(prevdate[ if options.usd then 'VALTODAY_USD' else 'VALTODAY' ] || '-'))
                .append($("<td>").html(prevdate['NUMTRADES'] || '-'))
            table_body.append(row)


    render = (data) ->
        return unless data
        create_table_head()
        create_table_body(data)
        element.html(table)

    render(cache.get(cache_key))

    refresh = () ->
        $.when(mx.iss.market_turnovers(engine, options)).then (data) ->
            console.log(new Date)

            turnovers         = data.turnovers
            turnoversprevdate = data.turnoversprevdate

            if _.size(markets) > 0
                data.turnovers         = _.filter(data.turnovers,         ((t) -> _.any(markets, (m) -> t['NAME'] is m )))
                data.turnoversprevdate = _.filter(data.turnoversprevdate, ((t) -> _.any(markets, (m) -> t['NAME'] is m )))

            render data
            cache.set(cache_key, data)

            _.delay refresh, refresh_timeout

    refresh()



_.extend scope,
    market_turnovers: widget