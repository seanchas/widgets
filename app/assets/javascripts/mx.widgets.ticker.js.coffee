global = module?.exports ? ( exports ? this )

global.mx           ||= {}
global.mx.widgets   ||= {}

scope = global.mx.widgets

$ = jQuery


escape_selector = (string) ->
    string.replace /([\W])/g, "\\$1"


widget = (element, params, options = {}) ->
    element = $(element); return if _.size(element) == 0
    element.html($("<div>").addClass("mx-widget-ticker"))
    element = $(".mx-widget-ticker", element)

    element.toggleClass('toggleable', options.toggleable == true)

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
    
    insert_after_last_tick = (view) ->
        tick = $(".tick:last", element)
        left = if _.size(tick) > 0 then tick.position().left + tick.outerWidth() else 0
        view.css({ left: left })
        element.append view
    
    animate = (view) ->
        view.stop()
        
        length = view.position().left + view.outerWidth()
        
        view.animate { left: - view.outerWidth() }, length / 30 * 1000, 'linear', () ->
            insert_after_last_tick view
            animate view
    
    toggle_animation = ->
        $(".tick", element).each (index, tick) ->
            tick = $(tick)
            if tick.is(":animated") then tick.stop() else animate tick
    
    element.on 'click', toggle_animation if options.toggleable == true


    $.when(fetch_filters(), fetch_columns()).then (filters, columns) ->
        
        for id, filter of filters
            filter = _.reduce filter.widget, (memo, field) ->
                memo[field.alias] = field
                memo
            , {}
            filters[id] = filter
        
        render = (records) ->
            return if _.size(records) == 0
            
            for record in records
                
                key = "#{record['ENGINE']}:#{record['MARKET']}"
                
                _filters = filters[key]
                _columns = columns[key]
                
                record = mx.utils.process_record record, _columns
                
                tick = $(".tick:last", element)
                
                record_key = "#{record['BOARDID']}:#{record['SECID']}"
                
                view = $("ul[data-key=#{escape_selector record_key}]", element)

                if _.size(view) == 0
                     view = $("<ul>").addClass('tick').attr({ 'data-key': record_key })
                     insert_after_last_tick view


                for name in ['SHORTNAME', 'LAST', 'CHANGE']
                    field = $("li.#{name.toLowerCase()}", view)

                    if _.size(field) == 0
                        field = $("<li>").addClass(name.toLowerCase())
                        view.append field

                    field.html(mx.utils.render record[_filters[name].name], _columns[_filters[name].id])
                
                if trend = record.trends[_filters['CHANGE'].name]
                    cell = $("li.change", view)
                    cell.toggleClass('trend_up',    trend > 0)
                    cell.toggleClass('trend_down',  trend < 0)
                
                animate view
                
                

        refresh = ->
            fetch().then (records) ->
                render records
                _.delay refresh, 60 * 1000

        refresh()



_.extend scope,
    ticker: widget
