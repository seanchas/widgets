global = module?.exports ? ( exports ? this )

scope = global.mx.widgets.tiny

$ = jQuery

cache = kizzy('mx.widgets.tiny.usdrub_closed')

f = (x) -> if 0 < x < 10 then "0" + x else x
d = (d) -> "#{f d.getDate()}.#{f( d.getMonth() + 1 )}.#{d.getFullYear()}"

widget = (element) ->
    element = $(element); return unless _.size(element) == 1

    cache_key = mx.utils.sha1( "usd_rub" + mx.locale() )

    containers =
        date:       $('.date',          element)
        usd:        $('.usd',           element)
        usd_value:  $('.usd .value',    element)
        usd_change: $('.usd .change',   element)

    render = (data) ->
        return unless data?

        date = mx.utils.parse_date(data['USDTOM_UTS_TRADEDATE'])

        containers['date'].html(d date)

        value       = data["USDTOM_UTS_CLOSEPRICE"]
        change      = data["USDTOM_UTS_CLOSEPRICETOPREVPRCN"]

        containers.usd.toggleClass('gt', change >  0)
        containers.usd.toggleClass('le', change <  0)
        containers.usd.toggleClass('eq', change == 0)

        containers.usd_value.html(
            mx.utils.render(value, { type: 'number', precision: 4 })
        )

        containers.usd_change.html(
            mx.utils.render(change, { type: 'number', precision: 4, is_signed: 1 })
        )


    render(cache.get(cache_key))

    mx.iss.currency_rates().then (data) ->
        render(data)
        cache.set(cache_key, data)


_.extend scope,
    usdrub_closed: widget
