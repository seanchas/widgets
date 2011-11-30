##= require emile

global = module?.exports ? ( exports ? this )

global.mx           ||= {}
global.mx.widgets   ||= {}

scope = global.mx.widgets

$ = jQuery


load = (queries) ->
    deferred = new $.Deferred
    
    records = []
    
    complete = _.after _.size(queries), ->
        deferred.resolve(records)

    for key, params of queries
        [engine, market] = key.split(":")
        mx.iss.records(engine, market, params).then (json) ->
            records.push(json...)
            complete()
    
    deferred.promise()
    

widget = (element, instruments, options = {}) ->
    element = $(element); return if _.size(element) == 0
    element.html($("<div>").addClass("mx-widget-ticker")); element = $('.mx-widget-ticker', element)
    

    queries = _.reduce instruments, (memo, instrument) ->
        [engine, market, board, param] = instrument.split(":")
        (memo[[engine, market].join(":")] ||= []).push([board, param].join(":"))
        memo
    , {}
    
    sort = _.map instruments, (instrument) ->
        [engine, market, board, param] = instrument.split(":")
        [board, param].join(":")
    
    speed = + options.speed || 25

    cancelled = false
    
    containers = []
    
    element.toggleClass('toggleable', options.toggleable == true)

    if (options.toggleable == true)
        element.on 'click', (e) ->
            for el in $('ul', element) when $(el).data('animating')?
                el = $(el)
                if cancelled
                    el.removeData('animating')
                    animate(el)
                else
                    $(el).data('animating').cancel()

            cancelled = !cancelled
            
            

    render_name = (record) ->
        value = record['SHORTNAME']
        $("<span>")
            .addClass("name")
            .html(value)
    
    render_last = (record) ->
        value = + (record['LAST'] || record['LASTVALUE'] || 0).toFixed(2)
        $("<span>")
            .addClass("last")
            .html(mx.utils.render(value, { type: 'number', decimals: 2 }))
    
    render_change = (record) ->
        value = + (record['LASTCHANGEPRCNT'] || record['LASTCHANGEPRC'] || 0).toFixed(2)
        $("<span>")
            .addClass("change")
            .toggleClass('trend_up', value > 0)
            .toggleClass('trend_down', value < 0)
            .html(mx.utils.render(value, { type: 'number', decimals: 2, is_signed: 1, has_percent: 1 }))
    
    render_record = (record) ->
        $("<li>")
            .append(render_name(record))
            .append(render_last(record))
            .append(render_change(record))
    
    animate = (container) ->
        container ?= _.first containers
        
        return if container.data('animating')?
        
        duration = (container.position().left + container.outerWidth()) / speed
        
        container.data 'animating', emile container[0], "left: -#{container.outerWidth()}px;", { duration: duration * 1000, easing: _.bind easing, container }, ->
            cleanup container
        
    render = (records) ->
        container = $("<ul>")
            .addClass("tickers")
        
        for record in records
            container.append render_record record
        
        element.append container
        
        container.width _.reduce $("li", container), (sum, el) ->
            sum + $(el).outerWidth()
        , 0
        
        container.css('left', element.outerWidth())
        
        containers.push container
        
        animate()
    
    easing = (position) ->
        
        unless this.data('refresh-sent')
            last = this.children('li').last()
            if element.offset().left + element.innerWidth() >= last.offset().left
                refresh()
                this.data('refresh-sent', true)
        
        unless this.data('animate-sent')
            if this.position().left + this.outerWidth() < element.innerWidth()
                containers.shift()
                animate()
                this.data('animate-sent', true)
        
        position

    cleanup = (container) ->
        container.remove()
    
    refresh = ->
        load(queries).then (records) ->
            render _.sortBy records, (instrument) ->
                _.indexOf sort, [instrument['BOARDID'], instrument['SECID']].join(":")
    
    refresh()


_.extend scope,
    ticker: widget
