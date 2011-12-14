global = module?.exports ? ( exports ? this )

global.mx           ||= {}
global.mx.widgets   ||= {}

scope = global.mx.widgets

$ = jQuery


escape_selector = (string) ->
    string.replace /([\W])/g, "\\$1"


widget = (element, params, options = {}) ->
    element = $(element); return if _.size(element) == 0
    element.html($("<div>").addClass("mx-widget-ticker loading"))
    element = $(".mx-widget-ticker", element)
    
    speed       = options.speed ? 25
    toggleable  = options.toggleable == true
    animated    = true

    _.times 2, (index) -> element.append $("<ul>").css({ left: element.width() * index })
        
    element.toggleClass('toggleable', toggleable)

    queries = _.reduce params, (memo, param) ->
        parts = param.split(":")
        (memo[_.first(parts, 2).join(":")] ?= []).push _.last(parts, 2).join(":")
        memo
    , {}
    

    fetch = ->
        deferred = new $.Deferred
        
        records = []
        
        complete = _.after _.size(queries), ->
            deferred.resolve _.sortBy records, (record) ->
                _.indexOf params, [record['ENGINE'], record['MARKET'], record['BOARDID'], record['SECID']].join(":")
            
        _.each queries, (params, key) ->
            [engine, market] = key.split(":")
            mx.iss.records(engine, market, params, { force: true }).then (json) ->
                for record in json
                    record['ENGINE'] = engine
                    record['MARKET'] = market
                records.push json...
                complete()
        
        deferred.promise()
    

    fetch_filters = ->
        deferred = new $.Deferred
        
        filters = {}
        
        complete = _.after _.size(queries), ->
            deferred.resolve filters
        
        _.each queries, (params, key) ->
            mx.iss.filters(key.split(":")...).then (json) ->
                filters[key] = json
                complete()
        
        deferred.promise()
    

    fetch_columns = ->
        deferred = new $.Deferred

        columns = {}

        complete = _.after _.size(queries), ->
            deferred.resolve columns

        _.each queries, (params, key) ->
            mx.iss.columns(key.split(":")...).then (json) ->
                columns[key] = json
                complete()

        deferred.promise()
    
    insert_after_last_tick = (screen, tick) ->
        last_tick = $(".tick:last", element)
        left = if _.size(last_tick) > 0 then last_tick.position().left + last_tick.outerWidth() else 0
        tick.css({ left: left })
        screen.append tick
    
    animate = ->
        return unless animated
        
        screens = $("ul", element)

        screens.stop()

        [first, last] = [$(_.first screens), $(_.last screens)]
        
        return if first.outerWidth() <= element.width()
        
        first_length = first.position().left + first.outerWidth()
        
        last.css({ left: first_length })
        
        last_length = last.position().left + last.outerWidth()
        
        first.animate({ left: - first.outerWidth() }, { easing: 'linear', duration: first_length / speed * 1000, complete: reanimate })
        last.animate({ left: - last.outerWidth() }, { easing: 'linear', duration: last_length / speed * 1000 })        
    
    
    reanimate = ->
        screens = $("ul", element)

        screens.stop()
        
        [first, last] = [$(_.first screens), $(_.last screens)]
        
        last.after first
        
        animate()
    

    toggle_animation = ->
        screens = $("ul", element)
        animated = not screens.is(":animated")
        if screens.is(":animated") then screens.stop() else animate()


    $.when(fetch_filters(), fetch_columns()).then (filters, columns) ->
        
        element.on "click", toggle_animation
        
        for id, filter of filters
            filter = _.reduce filter.widget, (memo, field) ->
                memo[field.alias] = field
                memo
            , {}
            filters[id] = filter
        
        render = (records) ->
            return if _.size(records) == 0
            
            screens = $("ul", element)
            
            for record in records
                
                key = "#{record['ENGINE']}:#{record['MARKET']}"
                
                _filters = filters[key]
                _columns = columns[key]
                
                record = mx.utils.process_record record, _columns
                
                tick = $(".tick:last", element)
                
                record_key = "#{record['BOARDID']}:#{record['SECID']}"
                
                views = $("li[data-key=#{escape_selector record_key}]", element)

                if _.size(views) == 0
                     for screen in screens
                         $(screen).append $("<li>").addClass('tick').attr({ 'data-key': record_key })


                views = $("li[data-key=#{escape_selector record_key}]", element)

                for name in ['SHORTNAME', 'LAST', 'CHANGE']
                    fields = $("span.#{name.toLowerCase()}", views)

                    if _.size(fields) == 0
                        for view in views
                            $(view).append $("<span>").addClass(name.toLowerCase())
                    
                    fields = $("span.#{name.toLowerCase()}", views)
                    
                    fields.html(mx.utils.render record[_filters[name].name], _columns[_filters[name].id])
                
                if trend = record.trends[_filters['CHANGE'].name]
                    cell = $("span.change", views)
                    cell.toggleClass('trend_up',    trend > 0)
                    cell.toggleClass('trend_down',  trend < 0)
                
            animate()
                
                

        refresh = ->
            fetch().then (records) ->
                element.removeClass("loading")
                
                render records
                
                _.delay refresh, 10 * 1000

        refresh()



_.extend scope,
    ticker: widget
