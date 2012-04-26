##= require jquery
##= require underscore
##= require underscore.string
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

_.mixin _.str.exports()

localization =
    toolbox:
        remove:
            ru: 'Удалить'
            en: 'Remove'


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
dropover_delay      =  1 * 1000

default_toolbox_position =
    top:   10
    right: 10


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


    cache_key = mx.utils.sha1(JSON.stringify(_.rest(arguments).join("/")) + mx.locale())
    cacheable = options.cache == true

    has_chart    = options.chart? and options.chart != false
    chart_width  = 0
    chart_height = 0

    options.chart_option = options.chart_options || {}


    add_spinner    = (wrapper) ->
        return if _.size($("div.spinner_wrapper", wrapper)) > 0
        wrapper.css("position", "relative")
        container = $("<div>").addClass("spinner_wrapper")
        container.append $("<div>").addClass("spinner_background")
        container.append $("<div>").addClass("spinner")
        wrapper.append   container
        wrapper.addClass "loading"


    remove_spinner = (wrapper) ->
        spinner = $("div.spinner_wrapper", wrapper)
        return unless _.size(spinner) > 0
        wrapper.removeClass("loading")
        spinner.remove()


    read_cache(element, cache_key) if cacheable

    if cacheable and has_chart
        $("div.toolbox", element).each ->
            toolbox  = $(this)
            wrapper  = toolbox.parent()
            toolbox.css
                top:  default_toolbox_position.top
                left: (if default_toolbox_position.right then (wrapper.width() - toolbox.outerWidth() - default_toolbox_position.right) else default_toolbox_position.left)


        $("tr.chart img", element).each ->
            old_image    = $(this)
            wrapper      = old_image.parent()
            chart_width  = chart_width  || wrapper.width()
            chart_height = chart_height || wrapper.height()
            image        = $("<img>").attr("src", old_image.attr("src"))

            old_image.remove()
            add_spinner(wrapper)

            image.on "load", ->
                wrapper.prepend(image)
                remove_spinner(wrapper)


    delay   = calculate_delay(options.refresh_timeout)
    timeout = null

    if _.isArray(engine)
        params  = engine
        engine  = null
        market  = null
    
    order = []

    is_draggable  = options.dragndrop != false
    is_droppable  = has_chart and options.dragndrop != false
    dropover_time = new Date - dropover_delay
    
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


    make_rows_draggable = (rows) ->
        table = $("table", element)
        rows.addClass("draggable-row")
        rows.draggable({
            start:  ->
                table.data("drag-lock", true)
            stop:   ->
                table.data("drag-lock", false)
            cursor: "move"
            cursorAt:
                top:  5
                left: 5
            helper: ->
                $("<div>").addClass("security-drag-helper").html($("td:first", $(this)).html())
            appendTo: "body"
        })


    make_charts_draggable = (chart_rows) ->
        table = $("table", element)
        chart_rows.addClass("draggable-row")
        chart_rows.draggable({
            start:  ->
                table.data("drag-lock", true)
            stop:   ->
                table.data("drag-lock", false)
            cursor: "move"
            cursorAt:
                top:  5
                left: 5
            helper: ->
                $("<div>").addClass("security-drag-helper").html( $(this).prev("tr.row").find("td:first").html() )
            appendTo: "body"
        })


    make_rows_droppable = (rows) ->
        table = $("table", element)
        rows.droppable({
            accept: (draggable) ->
                is_accept_draggable $(this), draggable
            over: ->
                table.data("drop-lock", true)
                $(this).addClass("drophover").next("tr.chart").addClass("drophover")
            out:  ->
                table.data("drop-lock", false).data("dropover-time", + new Date)
                $(this).removeClass("drophover").next("tr.chart").removeClass("drophover")
            deactivate: ->
                table.data("drop-lock", false).data("dropover-time", + new Date)
            drop: (event, ui) ->
                target = $(this)
                source = ui.draggable
                source = source.prev("tr.row") if source.hasClass("chart")
                target.removeClass("drophover").next("tr.chart").removeClass("drophover")
                target.attr
                    "data-compare-key":   source.attr "data-key"
                    "data-compare-title": source.attr "data-title"

                if target.hasClass("current") then refresh_chart(target.next("tr.chart"), { force: true }) else activate_row(target, { force: true })
        })


    make_charts_droppable = (chart_rows) ->
        table = $("table", element)
        chart_rows.droppable({
            accept: (draggable) ->
                is_accept_draggable $(this).prev("tr.row"), draggable
            over: ->
                table.data("drop-lock", true)
                $(this).addClass("drophover").prev("tr.row").addClass("drophover")
            out:  ->
                table.data("drop-lock", false).data("dropover-time", + new Date)
                $(this).removeClass("drophover").prev("tr.row").removeClass("drophover")
            deacticate: ->
                table.data("drop-lock", false).data("dropover-time", + new Date)
            drop: (event, ui) ->
                target = $(this).prev("tr.row")
                source = ui.draggable
                source = source.prev("tr.row") if source.hasClass("chart")
                target.removeClass("drophover").next("tr.chart").removeClass("drophover")
                target.attr
                    "data-compare-key":   source.attr "data-key"
                    "data-compare-title": source.attr "data-title"

                if target.hasClass("current") then refresh_chart($(this), { force: true }) else activate_row(target, { force: true })
        })


    is_accept_draggable = (target, source) ->
        !(source.attr("data-key") == target.attr("data-key") or source.attr("data-key") == target.attr("data-compare-key")) and source.hasClass("draggable-row") and !target.data("chart-is-loading")


    add_compare_toolbox = (chart_row) ->
        return if _.size( $("div.toolbox", chart_row) ) > 0

        row         = chart_row.prev("tr.row")
        wrapper     = $("td:first div.wrapper", chart_row)
        compare_key = row.attr("data-compare-key")

        return unless compare_key

        table   = $("table", element)
        toolbox = $("<div class=\"toolbox\"><span class=\"title\"></span><span class=\"desc\"></span><a href=\"#\"></a></div>")
        title   = $("span.title", toolbox).html(_.truncate(row.attr("data-compare-title"), 16, "&hellip;"))
        desc    = $("span.desc",  toolbox).html(compare_key.split(":")[3])
        ctrl    = $("a",          toolbox).attr("data-control", "remove").html(localization.toolbox.remove[mx.locale()])

        wrapper.css('position', 'relative').append toolbox
        toolbox.css('position', 'absolute')

        position = chart_row.data("compare-toolbox-position")
        unless position
            position =
                top:  default_toolbox_position.top
                left: (if default_toolbox_position.right then (wrapper.width() - toolbox.outerWidth() - default_toolbox_position.right) else default_toolbox_position.left)
            chart_row.data("compare-toolbox-position", position)

        if position.left + toolbox.outerWidth()  > wrapper.width()  then position.left = wrapper.width()  - toolbox.outerWidth()
        if position.top  + toolbox.outerHeight() > wrapper.height() then position.top  = default_toolbox_position.top
        if position.left < 0 then position.left = 0
        if position.top  < 0 then position.top  = 0


        toolbox.css({
            top:       position.top
            left:      position.left
        })

        toolbox.draggable({
            start: () ->
                table.data("drag-lock", true)
            stop:  () ->
                table.data("drag-lock", false).data("dropover-time", + new Date)
            drag:  (event, ui) ->
                $(this).closest("tr.chart").data("compare-toolbox-position", $(this).position())
            containment: "parent"
        })


    remove_comparable_security = (chart_row) ->
        row = chart_row.prev("tr.row")
        row.removeAttr("data-compare-key").removeAttr("data-compare-title")
        if row.hasClass("current") then refresh_chart(chart_row, { force: true })



    refresh_chart = (chart_row, refresh_options = {}) ->
        row         = chart_row.prev("tr.row")
        key         = row.attr("data-key")
        compare_key = row.attr("data-compare-key")
        wrapper     = $("div.wrapper", chart_row)
        toolbox     = $("div.toolbox", wrapper)

        if compare_key
            chart_key = [key, compare_key].join(':')
            add_compare_toolbox(chart_row)
        else
            chart_key = key

        return if charts_times[chart_key]? and charts_times[chart_key] + chart_refresh_delay > + new Date and !refresh_options.force
        
        parts   = row.attr("data-key").split(":")
        wrapper  = $("td:first div.wrapper", chart_row)

        chart_options = {}
        if compare_key
            cparts   = compare_key.split(":")
            cparts.splice(2, 1)
            chart_options =
                width:   chart_width
                height:  chart_height
                compare: cparts.join(":")
        else
            chart_options =
                width:   chart_width
                height:  chart_height
                compare: ""

        url = mx.widgets.chart_url(wrapper, parts[0], parts[1], parts[3], _.extend(options.chart_option, chart_options))

        wrapper.css("height", chart_height)
        add_spinner(wrapper) if refresh_options.force or !(_.size($("img", wrapper)) > 0)
        
        write_cache(element, cache_key) if cacheable

        row.data("chart-is-loading", true)
        image = $("<img>")

        image.on 'load', ->
            return if chart_row.data("drag-lock")
            compare_key = row.attr("data-compare-key")

            row.removeData("chart-is-loading")
            remove_spinner(wrapper)
            wrapper.html(image)
            
            if compare_key
                add_compare_toolbox(chart_row)
                
            charts_times[chart_key] = + new Date
            write_cache(element, cache_key) if cacheable
        
        image.on 'error', ->
            row.removeData("chart-is-loading")
            chart_row.prev("tr.row").removeClass("current")
            chart_row.data('defunct', true).hide()
            wrapper.empty()
            write_cache(element, cache_key) if cacheable

        image.attr('src', url)

        
    
    activate_row = (row, refresh_options = {}) ->
        chart_row   = row.next("tr.chart")
        
        $("tr.row", element).not(row).removeClass("current")
        $("tr.chart", element).not(chart_row).hide()

        chart_row.toggle()

        row.toggleClass("current", chart_row.is(":visible"))
        
        if chart_row.is(":visible")
            refresh_chart(chart_row, refresh_options)
    
    observe = _.once ->
        element.on 'click', 'tr.row', (event) ->
            activate_row $(event.currentTarget)

        element.on 'click', "tr.chart div.toolbox a['data-control'=remove]", (event) ->
            remove_comparable_security $(event.currentTarget).closest("tr.chart")

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

            header_row   = $("<tr>").addClass("header")
            
            for record, record_index in data

                [engine, market] = [record['ENGINE'], record['MARKET']]

                _columns    = columns["#{engine}:#{market}"]

                if _.isArray(options.filter_name)
                  _filters    = ({ alias: col.name, filter_name: 'custom', id: col.id, name: col.name } for col in _.filter _columns, (obj) -> (_.include options.filter_name, obj.name))
                  _filters    = _.sortBy(_filters, (obj) -> (_.indexOf(options.filter_name, obj.name )) )
                else
                  _filters    = filters["#{engine}:#{market}"][options.filter_name || filter_name]

                record = mx.utils.process_record record, _columns
                
                record_key = [record['ENGINE'], record['MARKET'], record['BOARDID'], record['SECID']].join(":")
                
                row = $("<tr>")
                    .addClass("row")
                    .toggleClass('first',   record_index       == 0)
                    .toggleClass('last',    (record_index + 1) == records_size)
                    .toggleClass('even',    (record_index + 1) %  2 == 0)
                    .toggleClass('odd',     (record_index + 1) %  2 == 1)
                    .attr
                        'data-key':   record_key
                        'data-title': record[_columns[_filters[0].id].name]

                for field, index in _filters
                    
                    column  = _columns[field.id]
                    
                    trend   = record.trends[column.name]
                    
                    value = record[column.name]

                    if !record_index and options.show_header
                        header_cell = $("<td>")
                            .attr
                                'data-name':    column.name
                                'title':        column.title
                            .addClass(column.type)
                            .html(column.short_title)
                        header_row.append header_cell
                    
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

                if _.size(old_row = $("tr.row[data-key=#{escape_selector record_key}]")) > 0 and is_droppable
                    row.attr("data-compare-key",   old_row.attr("data-compare-key"))
                    row.attr("data-compare-title", old_row.attr("data-compare-title"))
                
                table_body.append row
                
                if has_chart
                    chart_row = $("<tr>")
                        .addClass("chart")
                        .html( $("<td>")
                                .attr('colspan', _.size( row.children() ))
                                .append($("<div>").addClass("wrapper")) )
                    row.after chart_row

                    if _.size(old_chart_row = $("tr.row[data-key=#{escape_selector record_key}] + tr.chart")) > 0
                        if url = $("img", old_chart_row).attr('src')
                            wrapper = $("div.wrapper", chart_row)
                                .css('height', $("div.wrapper", old_chart_row).height())
                                .html($("<img>").attr('src', url))
                        if old_chart_row.prev("tr.row").data("chart-is-loading")
                            wrapper.append $("div.toolbox", old_chart_row)
                            add_spinner wrapper

                        chart_row.data('defunct',                  old_chart_row.data('defunct'))
                        chart_row.data('compare-toolbox-position', old_chart_row.data('compare-toolbox-position'))

            
            table_head.append header_row if options.show_header

            element.children().remove()
            element.html(table)


            chart_width  = $("tr.chart div.wrapper", table).width()
            chart_height = if chart_width then chart_width / 2 else 0
            if options.chart_option then (chart_height = if options.chart_option.proportions then chart_width / options.chart_option.proportions else options.chart_option.height || chart_width / 2)

            $("tr.chart", table).hide()

            activate_row $("tr.row[data-key=#{escape_selector current_row_key}]", table) if current_row_key
            current_row_key = undefined

            if is_draggable
                make_rows_draggable    $("tr.row",   table)
                make_charts_draggable  $("tr.chart", table)
            if is_droppable
                make_rows_droppable    $("tr.row",   table)
                make_charts_droppable  $("tr.chart", table)
            if has_chart
                observe()
            
            write_cache(element, cache_key) if cacheable
                
        
        refresh = ->
            refresh_timeout = options.refresh_timeout
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

                table = $("table", element)
                if table.data("drag-lock") or table.data("drop-lock") or ( table.data("dropover-time") + dropover_delay > + new Date )
                    delay = calculate_delay(refresh_timeout) + dropover_delay
                else
                    render data if _.size(data) > 0
                    delay = calculate_delay refresh_timeout

            timeout = _.delay refresh, delay if delay > 0
                
                
        
        refresh()
        
        
    {}


_.extend scope,
    table: widget
