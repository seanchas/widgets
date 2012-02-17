global = module?.exports ? ( exports ? this )

scope = global.mx.widgets.tiny

$ = jQuery

cache = kizzy('mx.widgets.tiny.currency_rates')


months = [
    'января'
    'февраля'
    'марта'
    'апреля'
    'мая'
    'июня'
    'июля'
    'августа'
    'сентября'
    'октября'
    'ноября'
    'декабря'
]


widget = (element) ->
    element = $(element); return unless _.size(element) == 1
    
    cache_key = mx.utils.sha1(JSON.stringify(_.rest(arguments).join("/")))
    
    containers =
        date:       $('.date',          element)
        usd:        $('.usd',           element)
        usd_value:  $('.usd .value',    element)
        usd_change: $('.usd .change',   element)
        eur:        $('.eur',           element)
        eur_value:  $('.eur .value',    element)
        eur_change: $('.eur .change',   element)
    
    render = (data) ->
        return unless data?
        
        date = mx.utils.parse_date(data['CBRF_EUR_TRADEDATE'])
        
        containers['date'].html(date.getDate() + ' ' + months[date.getMonth()])
        
        for type in ['eur', 'usd']
            container   = containers[type]
            value       = data["cbrf_#{type}_last".toUpperCase()]
            change      = data["cbrf_#{type}_lastchangeprcnt".toUpperCase()]
            
            container.toggleClass('gt', change >  0)            
            container.toggleClass('le', change <  0)            
            container.toggleClass('eq', change == 0)            
            
            containers["#{type}_value"].html(
                mx.utils.render(value, { type: 'number', precision: 4 })
            )

            containers["#{type}_change"].html(
                mx.utils.render(change, { type: 'number', precision: 4, is_signed: 1, has_percent: 1 })
            )
        
    
    render(cache.get(cache_key))

    mx.iss.currency_rates().then (data) ->
        render(data)
        cache.set(cache_key, data)


_.extend scope,
    currency_rates: widget
