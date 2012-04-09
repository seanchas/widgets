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

#### localization ####

localization = {
  remove_compare: {
    ru: 'Убрать сравнение'
    en: 'Remove compare'
  }
}




#### cache functionality ####

# set cache namespace
cache = kizzy('widgets.table')

# read widget representation from cache and insert it to page element
read_cache = (element, key) ->
    element.html cache.get key

# write whole widget html elements in cache store
write_cache = (element, key) ->
    cache.set key, element.html()

# clear cache by current cache key
remove_cache = (key) ->
    cache.remove key




# default filter name
filter_name = 'widget'


escape_selector = (string) ->
    string.replace /([\W])/g, "\\$1"


# default values for calculating delay between refreshing
default_delay       = 60 * 1000    # default delay between data refreshing
min_delay           =  5 * 1000    # min delay between data refreshing
chart_refresh_delay =  5 * 1000    # min delay between chart refreshing

# function that calculates delay timeout between refreshing data,
# uses user delay based on option 'refresh_timeout' or uses default timeout delay if option does not exists
calculate_delay = (delay) ->
    delay = + delay
    delay = default_delay if _.isNaN delay
    delay = _.max [delay, min_delay] unless delay == 0




# deffered objects for filters, columns and records
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




#### widget entry point ####

widget = (element, engine, market, params, options = {}) ->
    
    # element on page in which table will be rendered
    element = $ element; return if _.size(element) == 0

    # cache that stores whole table elements
    cache_key = mx.utils.sha1(JSON.stringify(_.rest(arguments).join("/")) + mx.locale())
    cacheable = options.cache == true
    
    # render table from cache if cache is turned on
    read_cache(element, cache_key) if cacheable

    # calculate delay timeout between refreshing data, uses user delay base on options.refresh_timeout or default timeout
    delay   = calculate_delay(options.refresh_timeout)
    timeout = null

    if _.isArray(engine)
        params  = engine
        engine  = null
        market  = null
    
    order = []
    
    # flag for rendering chart (true - render; false - don't render)
    has_chart   = options.chart? and options.chart != false
    # chart width
    chart_width = 0

    # flag: is widget rows draggable?
    is_draggable  = options.dragndrop != false
    # flag: is widget rows droppable?
    is_droppable  = has_chart and options.dragndrop != false
    
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
    
    
    # hash of refreshing times of charts in widget
    charts_times = {}
    # hash of urls for secutities
    records_urls = {}
    
    # make url for row - if options.url is function then call this function like function([ engine, market, board, security])
    make_url = (row) ->
        key = row.data('key')
        records_urls[key] ?= if options.url and _.isFunction(options.url) then options.url(key.split(":")...) else "##{key}"

    # refreshing chart
    refresh_chart = (chart_row, refresh_options = {}) ->

        row         = chart_row.prev("tr.row")
        key         = row.data('key')
        compare_key = row.data('compare-key')
        chart_key   = if compare_key then "#{key}:#{compare_key}" else key

        return if charts_times[chart_key]? and charts_times[chart_key] + chart_refresh_delay > + new Date and options.force != true
        
        parts   = key.split(":")
        cell    = $("td", chart_row)
        
        if compare_key
            compare_parts = compare_key.split(":")
            compare_parts.splice(2, 1)
            url = mx.widgets.chart_url(cell, parts[0], parts[1], parts[3], _.extend({ width: chart_width, compare: compare_parts.join(":") }, options.chart_option))
        else
            url = mx.widgets.chart_url(cell, parts[0], parts[1], parts[3], _.extend({ width: chart_width }, options.chart_option))

        cell.html("").css('height', 0) if refresh_options.force
        cell.addClass('loading') unless _.size($("img", cell)) > 0
        
        write_cache(element, cache_key) if cacheable

        image   = $("<img>").attr('src', url)
        
        image.on 'load', ->
            cell.removeClass('loading')
            cell.html(image)
            cell.css('height', cell.height())
            charts_times[chart_key] = + new Date
            update_compare_toolbox(chart_row)
            write_cache(element, cache_key) if cacheable

        image.on 'error', ->
            row.removeClass("current")
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




    #### drag and drop ####

    make_row_draggable = (row) ->
        row.draggable({
            cursorAt: { left: 5, top: 5 },
            start: (event, ui) ->
                $("table.mx-widget-table[data-dragging]").attr("data-dragging", true)
            stop:  (event, ui) ->
                $("table.mx-widget-table[data-dragging]").attr("data-dragging", false)
                $("div.security-drag-helper").remove()
            helper:   (event) ->
                el      = $(event.currentTarget)
                title   = el.data('title')
                $('<div>')
                    .addClass('security-drag-helper')
                    .html(title);
        })

    make_row_droppable = (row) ->
        row.droppable({
            hoverClass: 'droppable',
            over: (event, ui) ->
                $(this).next("tr.chart").addClass("droppable")
            out:  (event, ui) ->
                $(this).next("tr.chart").removeClass("droppable")
            accept: (draggable) ->
                $(this).data('key') != draggable.data('key')
            drop: (event, ui) ->
                $(this).data 'compare-key',   ui.draggable.data('key')
                $(this).data 'compare-title', ui.draggable.data('title')
                refresh_chart $(this).next("tr.chart").removeClass("droppable"), { force: true }
                activate_row row
        })

    make_chart_row_droppable = (chart_row) ->
        chart_row.droppable({
            hoverClass: 'droppable',
            over:   (event, ui) ->
                $(this).prev("tr.row").addClass("droppable")
            out:    (event, ui) ->
                $(this).prev("tr.row").removeClass("droppable")
            accept: (draggable) ->
                row = $(this).prev('tr.row')
                row.data('key') != draggable.data('key') and draggable.hasClass('row')
            drop: (event, ui) ->
                row = $(this).prev("tr.row")
                row.removeClass("droppable")
                row.data 'compare-key',   ui.draggable.data('key')
                row.data 'compare-title', ui.draggable.data('title')
                refresh_chart $(this), { force: true }
        })

    update_compare_toolbox = (chart_row) ->
        row            = chart_row.prev("tr.row")
        return unless    row.data("compare-key")
        $("td div.toolbox", chart_row).length || $("td", chart_row).append($("<div>").addClass("toolbox"))
        container      = $("div.toolbox", chart_row)
        desc           = row.data("compare-key").split(":")
        container.html   row.data("compare-title")
        container.append $("<span>").addClass("description").html(desc[3])
        container.append $("<a hred=\"#\">").addClass("remove_comparable").html(localization.remove_compare[mx.locale()])

    remove_compare = (chart_row) ->
        row     = chart_row.prev("tr.row")
        $("div.toolbox", chart_row).remove()
        row.removeData "compare-key"
        row.removeData "compare-title"
        refresh_chart chart_row, { force: true }


    #### add event listeners if widget with chart ####
    
    observe = _.once ->
        element.on 'click', 'tr.row', (event) ->
            activate_row $(event.currentTarget)

        element.on 'click', 'div.toolbox a', (event) ->
            remove_compare $(event.currentTarget).closest("tr.chart")
        
        element.on 'click', 'a', (event) ->
            row = $(event.currentTarget).closest("tr.row")
            return event.preventDefault() if !row.hasClass("current") and row.next("tr.chart").data('defunct') != true
            event.stopPropagation()
        
    
    $.when(fds, cds).then (filters, columns) ->
        
        # get key for current row
        if _.isNumber(options.chart)
            current_row_key = order[options.chart] || _.first(order)


        # render table
        render = (data) ->
            # do not render if there is no data
            return if _.size(data) == 0

            # get element table rendered before
            old_table = $('table', element)

            # do not render if drag and drop is happening
            return if old_table.attr("data-dragging") == "true"

            # create new table and add classes
            table = $("<table>")
                .addClass("mx-widget-table")
                .toggleClass("chart", has_chart)
                .html("<thead></thead><tbody></tbody>")

            table.attr("data-dragging", false) if is_droppable
            
            # get tbody and thead elements of new table
            table_head = $('thead', table)
            table_body = $('tbody', table)
            
            # get key of active row in previously rendered table
            current_row_key = $("tr.row.current", old_table).data('key') || current_row_key
            
            records_size = _.size(data)
            
            for record, record_index in data
                [engine, market] = [record['ENGINE'], record['MARKET']]
                
                _filters    = filters["#{engine}:#{market}"][options.filter_name || filter_name]
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


                if old_table
                    old_row = $("tr.row:eq(#{record_index})", old_table)
                    row.data "compare-key",   old_row.data("compare-key")
                    row.data "compare-title", old_row.data("compare-title")

                for field, index in _filters
                    
                    column  = _columns[field.id]
                    trend   = record.trends[column.name]
                    value   = record[column.name]

                    row.data("title", record[column.name])  if index == 0
                    
                    if value == 0 or value == null
                        if column.trend_by == field.id
                            value = undefined if _.all((record[c.name] for id, c of _columns when c.trend_by == field.id), (v) -> v == 0 or v == null)
                        else
                            value = undefined if trend == 0 or trend == null
                    
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
                    
                    $("span", cell).wrap($("<a>").attr('href', make_url(row))) if index == 0 and options.url != false

                table_body.append row
                
                if has_chart
                    chart_row = $("<tr>")
                        .addClass("chart")
                        .html($("<td>").attr({ 'colspan': _.size(row.children()) }).html("&nbsp;"))
                    row.after chart_row

                    if _.size(old_chart_row = $("tr.row[data-key=#{escape_selector record_key}] + tr.chart", old_table)) > 0
                        if url = $("img", old_chart_row).attr('src')
                            $("td", chart_row).css('height', $("td", old_chart_row).height()).html($("<img>").attr('src', url)).append($("div.toolbox", old_chart_row))
                        chart_row.data('defunct', old_chart_row.data('defunct'))

                    make_chart_row_droppable chart_row if is_droppable



                make_row_draggable(row) if is_draggable
                make_row_droppable(row) if is_droppable

            
            element.children().remove()
            element.html table

            chart_width = $("tr.chart td", table).width()
            $("tr.chart", table).hide()
            
            activate_row $("tr.row[data-key=#{escape_selector current_row_key}]") if current_row_key
            current_row_key = undefined
            
            if has_chart
                observe()
            
            write_cache(element, cache_key) if cacheable
                
        
        # function 'refresh' call self in delay times, gets new data and makes call to rerender table

        refresh = ->
            rds = records_data_source(params, options).then (data) ->
                console.log "element: #{element.attr 'id'}, delay: #{delay}"
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
    table_dragndrop: widget
