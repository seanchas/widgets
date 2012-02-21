global = module?.exports ? ( exports ? this )

scope = global.mx.widgets.tiny

$ = jQuery

f = (x) -> if 0 < x < 10 then "0" + x else x
d = (d) -> "#{f d.getDate()}.#{f( d.getMonth() + 1 )}.#{d.getFullYear()} #{f d.getHours()}:#{f d.getMinutes()}"


render = (element, data) ->
    return unless data?

    containers =
        date:      $(".date",       element)
        rub:       $(".rub",        element)
        rub_value: $(".rub .value", element)
        rub_order: $(".rub .order", element)
        usd:       $(".usd",        element)
        usd_value: $(".usd .value", element)
        usd_order: $(".usd .order", element)

    date = mx.utils.parse_date data["UPDATETIME"]

    containers['date'].html d(date)

    for type in ["rub", "usd"]
        value    = ( if type == "usd" then data["VALTODAY_USD"] else data["VALTODAY"] ) * 1000000
        if value == 0 then value = "-" else
            value    = mx.utils.number_with_power value, { precision: 4, shift: 1 }
        containers["#{type}_value"].html(value)

widget = (element, options = {}) ->

    element = $(element); return unless _.size(element) == 1

    engine           = options.engine          || "currency"
    refresh_timeout  = options.refresh_timeout || 10 * 1000

    refresh = ->
        mx.iss.turnovers(options).then (data) ->
            render element, (_.find data, (obj) -> obj["NAME"] == engine)
            _.delay refresh, refresh_timeout

    refresh()

_.extend scope,
    turnovers: widget




