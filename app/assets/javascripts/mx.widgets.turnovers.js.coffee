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
  sector_prefix:
    ru: "в т.ч."
    en: "inc."

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
        .toggleClass('alt',     options.is_sector?)
        .append(
            $('<td>')
                .addClass('title')
                .html([ (if options.is_sector? then localization.sector_prefix[ mx.locale() ] else ""), record['TITLE'] ].join " ")
        )
        .append(
            $('<td>')
                .addClass('number')
                .html(value || '&mdash;')
        )

render = (engines, element, data, options = {}) ->

    return unless data?

    turnovers =        data.turnovers
    turnoverssectors = data.turnoverssectors

    return unless turnovers?

    if engines.length > 0 then turnovers = _.filter turnovers, (obj) -> _.include(engines, obj["NAME"])

    table = create_table()

    table_head = $('thead', table)
    table_body = $('tbody', table)

    table_head.html create_table_head options

    for record, index in turnovers
        table_body.append create_row record, index, options

        if options.show_sectors
            sectors = _.filter turnoverssectors, (obj) -> obj["NAME"] == record["NAME"]
            table_body.append create_row sector, k, _.extend _.clone(options), { is_sector: true } for sector, k in sectors if sectors.length > 0

    element.html table


widget = (element, options = {}) ->
    element = $(element); return if element.length == 0

    cache_key = mx.utils.sha1(JSON.stringify( { is_tonight_session: !!(options.is_tonight_session || false) } ) + mx.locale())

    options.show_sectors = if options.show_sectors == undefined then true
    options.show_sectors = !!options.show_sectors

    options.force    = true

    engines          = options.engines || []
    engines          = engines.split(",").map( (w) -> w.trim() ) if _.isString(engines)

    refresh_timeout  = options.refresh_timeout || 60 * 1000

    refresh_callback = if options.afterRefresh and _.isFunction(options.afterRefresh) then options.afterRefresh else undefined

    iss_callback = if options.issCallback and _.isFunction(options.issCallback) then options.issCallback else undefined

    render engines, element, cache.get(cache_key), options

    deferred = () -> $.when(mx.iss.turnovers(options), mx.iss.turnoverssectors(options))

    refresh = ->
        deferred().then (turnovers, turnoverssectors) ->

            data = { turnovers: turnovers, turnoverssectors: turnoverssectors }

            render engines, element, data, options
            refresh_callback new Date _.max(mx.utils.parse_date time for time in _.pluck(turnovers, 'UPDATETIME')) if refresh_callback
            iss_callback data if iss_callback

            cache.set(cache_key, data)
            _.delay refresh, refresh_timeout

    refresh()

_.extend scope,
    turnovers: widget
