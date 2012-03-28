global = module?.exports ? ( exports ? this )

scope = global.mx.widgets.tiny

$ = jQuery

f = (x) -> if 0 < x < 10 then "0" + x else x
d = (d) -> "#{f d.getDate()}.#{f( d.getMonth() + 1 )}.#{d.getFullYear()} #{f d.getHours()}:#{f d.getMinutes()}"


cache = kizzy('mx.widgets.turnovers')

render = (element, data) ->
    return unless data?

    containers =
        date:      $(".date",       element)
        rub:       $(".rub",        element)
        rub_value: $(".rub .value", element)
        rub_base:  $(".rub .base",  element)
        usd:       $(".usd",        element)
        usd_value: $(".usd .value", element)
        usd_base:  $(".usd .base",  element)

    date = mx.utils.parse_date data["UPDATETIME"]

    containers['date'].html d(date)

    for type in ["rub", "usd"]
        value    = ( if type == "usd" then data["VALTODAY_USD"] else data["VALTODAY"] ) * 1000000
        if value == 0 then value = "-"; base = "" else
            str  = mx.utils.number_with_power(value, { precision: 4, shift: 1 }).match /([\d ,.]+)(.+)?/
            base  = str[2]
            value = str[1]
        containers["#{type}_value"].html(value)
        containers["#{type}_base"].html(base)

widget = (element, options = {}) ->

    element = $(element); return unless _.size(element) == 1

    cache_key = mx.utils.sha1(JSON.stringify( { is_tonight_session: !!(options.is_tonight_session || false) } ) + mx.locale())

    engine           = options.engine             || "currency"
    refresh_timeout  = options.refresh_timeout    || 10 * 1000

    render element, (_.find cache.get(cache_key)?.turnovers || [], (obj) -> obj["NAME"] == engine)

    refresh = ->
        mx.iss.turnovers(options).then (data) ->
            render element, (_.find data?.turnovers || [], (obj) -> obj["NAME"] == engine)
            cache.set cache_key, data
            _.delay refresh, refresh_timeout

    refresh()

_.extend scope,
    turnovers: widget




