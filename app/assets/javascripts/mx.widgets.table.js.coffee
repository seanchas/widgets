##= require jquery
##= require underscore
##= require backbone
##= require mx.utils
##= require mx.iss
##= require mx.widgets.chart
##= require kizzy

global = module?.exports ? ( exports ? this )

global.mx           ||= {}
global.mx.widgets   ||= {}

scope = global.mx.widgets


$ = jQuery

cache = kizzy('widgets.table')

read_cache = (element, key) ->
    element.html cache.get key

write_cache = (element, key) ->
    cache.set key, element.html()

remove_cache = (key) ->
    cache.remove key


filter_name = 'widget'


escape_selector = (string) ->
    string.replace /([\W])/g, "\\$1"


default_delay       = 60 * 1000
min_delay           =  5 * 1000
chart_refresh_delay =  5 * 1000

calculate_delay = (delay) ->
    delay = + delay
    delay = default_delay if _.isNaN delay
    delay = _.max [delay, min_delay] unless delay == 0


filters_data_source = (params) ->
    deferred = new $.Deferred
    
    result      = {}
    
    complete = _.after _.size(params), ->
        deferred.resolve result

    _.each params, (param) ->
        [engine, market] = param.split(':')
        mx.iss.filters(engine, market).done (json) ->
            result[param] = json
            complete()

    deferred
    
columns_data_source = (params) ->
    deferred = new $.Deferred

    result = {}

    complete = _.after _.size(params), ->
        deferred.resolve result

    _.each params, (param) ->
        [engine, market] = param.split(':')
        mx.iss.columns(engine, market).done (json) ->
            result[param] = json
            complete()

    deferred


records_data_source = (params, options) ->
    deferred = new $.Deferred
    

    result = {}
    
    complete = _.after _.size(params), ->
        deferred.resolve result
    
    _.each params, (params, keys) ->
        mx.iss.records(keys.split(":")..., params, _.extend(options, { force: true })).done (json) ->
            result[keys] = json
            complete()
    
    deferred

# entry point

widget = (element, engine, market, params, options = {}) ->
    
    element = $ element; return if _.size(element) == 0


    cache_key = mx.utils.sha1(JSON.stringify(_.rest(arguments).join("/")))
    cacheable = options.cache == true
    
    read_cache(element, cache_key) if cacheable


    delay   = calculate_delay(options.refresh_timeout)
    timeout = null

    if _.isArray(engine)
        params  = engine
        engine  = null
        market  = null
    
    order = []
    
    has_chart   = options.chart? and options.chart != false
    chart_width = 0
    
    params = _.reduce params, (memo, param) ->
        parts = param.split(":")
        parts.unshift engine, market if _.size(parts) < 3
        order.push parts.join(':')
        (memo[_.first(parts, 2).join(":")] ?= []).push(_.rest(parts, 2).join(":"))
        memo
    , {}
    
    fds = filters_data_source(_.keys params)
    cds = columns_data_source(_.keys params)
    
    options.params_name ||= 'securities'

    make_record_order_key = (record) ->
        switch options.params_name
            when 'securities'
                [record['ENGINE'], record['MARKET'], record['BOARDID'], record['SECID']].join(':')
            when 'sectypes'
                [record['ENGINE'], record['MARKET'], record['SECTYPE']].join(':')
    
    
    charts_times = {}
    records_urls = {}
    
    make_url = (row) ->
        key = row.data('key')
        
        records_urls[key] ?= if options.url and _.isFunction(options.url) then options.url(key.split(":")...) else "##{key}"

    refresh_chart = (chart_row) ->
        key     = chart_row.data('key')
        
        return if charts_times[key]? and charts_times[key] + chart_refresh_delay > + new Date
        
        parts   = chart_row.data('key').split(":")
        cell    = $("td", chart_row)
        
        url     = mx.widgets.chart_url(cell, parts[0], parts[1], parts[3], _.extend({ width: chart_width }, options.chart_option))
        
        cell.addClass('loading') unless _.size($("img", cell)) > 0
        
        write_cache(element, cache_key) if cacheable

        image   = $("<img>").attr('src', url)
        
        image.on 'load', ->
            cell.removeClass('loading')
            cell.html(image)
            cell.css('height', cell.height())
            charts_times[key] = + new Date
            write_cache(element, cache_key) if cacheable
        
        image.on 'error', ->
            chart_row.prev("tr.row").removeClass("current")
            chart_row.data('defunct', true).hide()
            cell.removeClass('loading')
            cell.empty()
            write_cache(element, cache_key) if cacheable

        
    
    activate_row = (row) ->
        chart_row   = row.next("tr.chart")
        
        $("tr.row", element).not(row).removeClass("current")
        $("tr.chart", element).not(chart_row).hide()

        chart_row.toggle()

        row.toggleClass("current", chart_row.is(":visible"))
        
        if chart_row.is(":visible")
            refresh_chart chart_row
    
    observe = _.once ->
        element.on 'click', 'tr.row', (event) ->
            activate_row $(event.currentTarget)
        
        element.on 'click', 'a', (event) ->
            row = $(event.currentTarget).closest("tr.row")
            return event.preventDefault() if !row.hasClass("current") and row.next("tr.chart").data('defunct') != true
            event.stopPropagation()
        
    
    $.when(fds, cds).then (filters, columns) ->
        
        if _.isNumber(options.chart)
            current_row_key = order[options.chart] || _.first(order)
        
        render = (data) ->
            return if _.size(data) == 0
            
            old_table = $('table', element)
            
            table = $("<table>")
                .addClass("mx-widget-table")
                .toggleClass("chart", has_chart)
                .html("<thead></thead><tbody></tbody>")
            
            table_head = $('thead', table)
            table_body = $('tbody', table)
            
            current_row_key = $("tr.row.current", old_table).data('key') || current_row_key
            
            records_size = _.size(data)
            
            for record, record_index in data
                [engine, market] = [record['ENGINE'], record['MARKET']]
                
                _filters    = filters["#{engine}:#{market}"][filter_name]
                _columns    = columns["#{engine}:#{market}"]
                
                record = mx.utils.process_record record, _columns
                
                record_key = [record['ENGINE'], record['MARKET'], record['BOARDID'], record['SECID']].join(":")
                
                row = $("<tr>")
                    .addClass("row")
                    .toggleClass('first',   record_index       == 0)
                    .toggleClass('last',    (record_index + 1) == records_size)
                    .toggleClass('even',    (record_index + 1) %  2 == 0)
                    .toggleClass('odd',     (record_index + 1) %  2 == 1)
                    .attr
                        'data-key': record_key
                        
                for field, index in _filters
                    
                    column  = _columns[field.id]
                    
                    trend   = record.trends[column.name]
                    
                    value = record[column.name]
                    
                    if value == 0
                        if column.trend_by == field.id
                            value = undefined if _.all((record[c.name] for id, c of _columns when c.trend_by == field.id), (v) -> v == 0)
                        else
                            value = undefined if trend == 0
                        
                    
                    cell = $("<td>")
                        .attr
                            'data-name':    column.name
                            'title':        column.title
                        .addClass(column.type)
                        .html($("<span>").html(mx.utils.render(value, _.extend({}, column, { precision: record.precisions[column.name]} )) || '&mdash;'))
                    
                    if column.trend_by == field.id
                        cell.toggleClass('trend_up',    trend  > 0)
                        cell.toggleClass('trend_down',  trend  < 0)
                        cell.toggleClass('trend_none',  trend == 0)
                    
                    row.append cell
                    
                    $("span", cell).wrap($("<a>").attr('href', make_url(row))) if index == 0
                
                table_body.append row
                
                if has_chart
                    chart_row = $("<tr>")
                        .addClass("chart")
                        .attr
                            'data-key': record_key
                        .html($("<td>").attr({ 'colspan': _.size(row.children()) }).html("&nbsp;"))
                    row.after chart_row

                    if _.size(old_chart_row = $("tr.chart[data-key=#{escape_selector record_key}]")) > 0
                        if url = $("img", old_chart_row).attr('src')
                            $("td", chart_row).css('height', $("td", old_chart_row).height()).html($("<img>").attr('src', url))
                        chart_row.data('defunct', old_chart_row.data('defunct'))
            
            element.children().remove()
            element.html table

            chart_width = $("tr.chart td", table).width()
            $("tr.chart", table).hide()
            
            activate_row $("tr.row[data-key=#{escape_selector current_row_key}]") if current_row_key
            current_row_key = undefined
            
            if has_chart
                observe()
            
            write_cache(element, cache_key) if cacheable
                
        
        refresh = ->
            rds = records_data_source(params, options).then (data) ->
                data = _.reduce data, (memo, records, key) ->
                    [engine, market] = key.split(":")
                    for record in records
                        record['ENGINE'] = engine
                        record['MARKET'] = market
                        memo.push record
                    memo
                , []
                
                data = _.sortBy data, (record) ->
                    _.indexOf order, make_record_order_key(record)
                
                render data if _.size(data) > 0
            
            timeout = _.delay refresh, delay if delay > 0
                
                
        
        refresh()
        
        
    {}


_.extend scope,
    table: widget
