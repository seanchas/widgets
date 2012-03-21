global = module?.exports ? ( exports ? this )

global.mx           ||= {}
global.mx.widgets   ||= {}

scope = global.mx.widgets

$ = jQuery

localization =
  title:
    ru: "Объемы торгов"
    en: "Trading volumes"
  currency:
    ru:
      usd: "USD"
      rub: "РУБ"
    en:
      usd: "USD"
      rub: "RUB"

cache = kizzy('mx.widgets.turnovers')

create_table = ->
    $('<table>')
        .addClass('mx-widget-turnovers')
        .html('<thead></thead><tbody></tbody>')

create_table_head = (options = {}) ->
    currency = if options.usd == true then localization.currency[mx.locale()]?["usd"] else localization.currency[mx.locale()]?["rub"]
    
    $('<tr>')
        .append($('<td>').html(localization.title[ mx.locale() ]))
        .append($('<td>').addClass('number').html(mx.widgets.utils.render_value(new Date, { type: 'date' }) + " [#{currency}]"))

create_row = (record, index, options = {}) ->
    value = record["VALTODAY#{ if options.usd == true then '_USD' else ''}"]
    value = mx.widgets.utils.render_value((if value then value * 1000000 else null), { type: 'number', precision: '0' })

    $('<tr>')
        .toggleClass('even',    (index + 1) %  2 == 0)
        .toggleClass('odd',     (index + 1) %  2 == 1)
        .append(
            $('<td>')
                .addClass('title')
                .html(record['TITLE'])
        )
        .append(
            $('<td>')
                .addClass('number')
                .html(value || '&mdash;')
        )

render = (engines, element, turnovers, options = {}) ->

    return unless turnovers?

    if engines.length > 0 then turnovers = _.filter turnovers, (obj) -> _.include(engines, obj["NAME"])

    table = create_table()

    table_head = $('thead', table)
    table_body = $('tbody', table)

    table_head.html create_table_head options

    for record, index in turnovers
        table_body.append create_row record, index, options

    element.html table


widget = (element, options = {}) ->
    element = $(element); return if element.length == 0

    cache_key = mx.utils.sha1(JSON.stringify(_.rest(arguments).join("/")) + mx.locale())

    engines          = options.engines || []
    engines          = engines.split(",").map( (w) -> w.trim() ) if _.isString(engines)

    refresh_timeout  = options.refresh_timeout || 60 * 1000

    refresh_callback = if options.afterRefresh and _.isFunction(options.afterRefresh) then options.afterRefresh else undefined

    iss_callback = if options.issCallback and _.isFunction(options.issCallback) then options.issCallback else undefined

    render engines, element, cache.get(cache_key), options

    refresh = ->
        mx.iss.turnovers(options).then (turnovers) ->
            render engines, element, turnovers, options
            refresh_callback new Date _.max(mx.utils.parse_date time for time in _.pluck(turnovers, 'UPDATETIME')) if refresh_callback
            iss_callback turnovers if iss_callback

            cache.set(cache_key, turnovers)

            _.delay refresh, refresh_timeout

    refresh()

_.extend scope,
    turnovers: widget
