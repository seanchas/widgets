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
    en:
        current_value: 'Current Value'
        previous_date: 'Previous Close'
        valtoday:      'Volume (RUB)'
        valtoday_usd:  'Volume (USD)'
        numtrades:     'Trades'


widget = (element, engine, markets, options = {}) ->
    element = $(element); return unless _.size(element)

    markets ||= []
    markets   = markets.split(",").map( (w) -> w.trim() ) if _.isString(markets)

    params = {}

    params.is_tonight_session = if options.is_tonight_session then true else false
    params.locale             = if mx.locale() is 'en' then 'en' else 'ru'
    params.force              = true

    refresh_timeout  = if _.isNumber(options.refresh_timeout) then options.refresh_timeout else  60 * 1000
    refresh_callback = if options.afterRefresh and _.isFunction(options.afterRefresh) then options.afterRefresh else undefined
    show_prev_date    = if options.show_prev_date is false then false else true
    usd              = if options.usd then true else false

    cache_key = mx.utils.sha1(JSON.stringify({ engine: engine, markets: markets, options: params }))

    table      = $("<table>").addClass('mx-widget-market-turnovers').html("<thead></thead><tbody></tbody>")
    table_head = $('thead', table)
    table_body = $('tbody', table)

    create_table_head = _.once () ->
        first_row  = $("<tr>").append($("<th>"))
            .append($("<th colspan=\"2\">").html( localization[params.locale].current_value ).addClass('current'))
            .append($("<th colspan=\"2\">").html( localization[params.locale].previous_date ).addClass('previous'))

        valtoday_title = localization[params.locale][ if usd then "valtoday_usd" else "valtoday" ]

        second_row = $("<tr>").append($("<td>").addClass('string'))
            .append($("<td>").html( valtoday_title ).addClass('number'))
            .append($("<td>").html( localization[params.locale].numtrades ).addClass('number'))

        if show_prev_date
            second_row
                .append($("<td>").html( valtoday_title ).addClass('number'))
                .append($("<td>").html( localization[params.locale].numtrades ).addClass('number'))
            table_head.append(first_row)

        table_head.append(second_row)


    create_table_body = (data) ->
        table_body.empty()
        for market in data.turnovers

            prevdate = _.find(data.turnoversprevdate, ((m) -> m['NAME'] is market['NAME']))
            valtoday = market[   if usd then 'VALTODAY_USD' else 'VALTODAY' ]
            valprev  = prevdate[ if usd then 'VALTODAY_USD' else 'VALTODAY' ]
            valtoday = if valtoday then valtoday * 1000000 else null
            valprev  = if valprev  then valprev  * 1000000 else null

            row = $("<tr>")
                .append($("<td>").html( market['TITLE'] || '&mdash;' ).addClass('string'))
                .append($("<td>").html( mx.widgets.utils.render_value(valtoday, { type: 'number', precision: '0' }) || '&mdash;' ).addClass('number'))
                .append($("<td>").html( mx.widgets.utils.render_value((market['NUMTRADES'] || null), { type: 'number', precision: '0' }) || '&mdash;' ).addClass('number'))
            row
                .append($("<td>").html( mx.widgets.utils.render_value(valprev, { type: 'number', precision: '0' }) || '&mdash;' ).addClass('number'))
                .append($("<td>").html( mx.widgets.utils.render_value((prevdate['NUMTRADES'] || null), { type: 'number', precision: '0' }) || '&mdash;' ).addClass('number')) if show_prev_date

            table_body.append(row)


    render = (data) ->
        return unless data

        create_table_head()
        create_table_body(data)
        element.html(table)

    render(cache.get(cache_key))

    refresh = () ->
        $.when(mx.iss.market_turnovers(engine, params)).then (data) ->

            turnovers         = data.turnovers
            turnoversprevdate = data.turnoversprevdate

            if _.size(markets) > 0
                data.turnovers         = _.filter(data.turnovers,         ((t) -> _.any(markets, (m) -> t['NAME'] is m )))
                data.turnoversprevdate = _.filter(data.turnoversprevdate, ((t) -> _.any(markets, (m) -> t['NAME'] is m )))

            render(data)
            refresh_callback new Date _.max(mx.utils.parse_date time for time in _.pluck(data.turnovers, 'UPDATETIME')) if refresh_callback

            cache.set(cache_key, data)
            _.delay refresh, refresh_timeout

    refresh()



_.extend scope,
    market_turnovers: widget