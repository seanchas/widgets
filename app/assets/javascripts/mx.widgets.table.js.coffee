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

cache = kizzy('widgets')

default_filter_name = 'small'


$.fn.exists = ->
    $(@).length > 0

$.fn.if_exists = ->
    if $(@).exists() then @ else null

escape_selector = (string) ->
    string.replace /([\W])/g, "\\$1"



prepare_value = (column, value, record) ->
    switch column.type
        when 'number'   then mx.utils.number_with_precision value, { precision: column.precision || record['DECIMALS'] }
        when 'time'     then value.split(':')[0..1].join(':')
        else value



prepare_cell = (field, record) ->
    type:   field.type
    name:   field.name
    value:  prepare_value field, record[field.name], record



prepare_row = (record, fields) ->
    board:      record.BOARDID
    security:   record.SECID
    cells:      (prepare_cell field, record for field in fields)



filter_columns = (columns, filters) ->
    columns[filter.id] for filter in filters


# table methods

# row methods

find_or_create_row = (row, container) ->
    find_row(row, container) ? create_row(row, container)

find_row = (row, container) ->
    $("tr[data-board=#{escape_selector row.board}][data-security=#{escape_selector row.security}]", container).if_exists()

create_row = (row, container) ->
    $('<tr>')
        .addClass('row')
        .attr(
            'data-board':       row.board
            'data-security':    row.security
        )
        .appendTo(container)


# cell methods

find_or_create_cell = (cell, container) ->
    find_cell(cell, container) ? create_cell(cell, container)

find_cell = (cell, container) ->
    $("td[data-name=#{escape_selector cell.name}]", container).if_exists()

create_cell = (cell, container) ->
    $('<td>')
        .attr({ 'data-name': cell.name })
        .addClass(cell.type)
        .appendTo(container)

# chart row methods

find_or_create_chart_row = (row) ->
    find_chart_row(row) ? create_chart_row(row)

find_chart_row = (row) ->
    row.next('tr.chart').if_exists()

create_chart_row = (row) ->
    $('<tr>')
        .addClass('chart')
        .addClass('new')
        .attr({ 'data-security': row.data('security') })
        .html("<td colspan=\"#{_.size $('td', row)}\">asd</td>")
        .insertAfter(row)
    

# entry point

table_widget = (element, engine, market, securities, options = {}) ->
    
    # ensure element
    element = $ element; return unless element.exists()

    # fetch filters data
    fds = mx.iss.filters engine, market

    # fetch columns data
    cds = mx.iss.columns engine, market
    
    # filter name
    filter_name = options.filter || default_filter_name

    # cache
    cache_key       = mx.utils.sha1(['widgets', 'table', location.path_name, JSON.stringify(_.rest arguments)].join('/'))
    cached_widget   = cache.get cache_key if options.cache

    # clean element to be sure
    # no content exists and
    # no callbacks are present
    element.empty()

    table = if cached_widget
        $('table', element.html(cached_widget))
    else
        _.tap $('<table>')
            .addClass('mx-widget-table')
            .toggleClass('chart', options.chart?)
            .attr(
                'data-engine': engine
                'data-market': market
            )
            .html('<thead></thead><tbody></tbody>')
            .hide()
        , (table) ->
            element.html table
            

    # observe widget render event
    element.bind 'render:complete', () ->
        cache.set cache_key, element.html() if options.cache
    
    # refresh table
    refresh = ->
        rds = mx.iss.records engine, market, securities, _.extend(options, { force: true })
        $.when(fds, cds, rds).then (filters, columns, records) ->
            render filters[filter_name], columns, records, table
    
    # refresh chart
    refresh_chart = (row) ->
        return unless row.exists()

        cell    = $('td', row)
        source  = mx.widgets.chart_url(cell, engine, market, row.data('security'))
        image   = $("<img>").attr({ src: source })

        image.on 'load', ->
            cell.html image
            element.trigger 'render:complete'
    
    # render chart
    render_chart_for_row = (row) ->
        return unless row.exists()
        
        row = find_or_create_chart_row(row)

        unless row.hasClass('new')
            if row.is(':visible') then row.hide() else row.show()
        row.removeClass('new')

        $('tr.chart', table).not(row).hide()

        if row.is(":visible")
            refresh_chart(row)
    
    # on row click
    
    on_row_click = (event) -> 
        render_chart_for_row($(event.currentTarget))


    
    # render function
    render = (filters, columns, records, table) ->
        
        element.trigger 'render:started'

        # select visible fields
        fields  = (filter_columns columns, filters)
        
        if options.sortBy
            records = _.sortBy(records,
                _.wrap(options.sortBy, (sorter, record) ->
                    return sorter(securities, record)
                )
            )
        
        # prepare rows data
        rows    = (prepare_row record, fields for record in records)

        # container
        table_body = $('tbody', table)
        
        for row, index in rows
            do (row, index) ->
                table_row = find_or_create_row row, table_body
                for cell in row.cells
                    do (cell) ->
                        table_cell = find_or_create_cell cell, table_row
                        table_cell.html(cell.value)
                
        # show table
        table.show()
        
        if options.chart? and _.isString(options.chart) and !cached_widget
            render_default_chart options.chart
        
        refresh_chart $('tr.chart:visible', table)
        
        # refresh table records
        _.delay refresh, (options.refresh_timeout || 10 * 1000)
        
        # trigger after render callbacks
        element.trigger 'render:complete'
    
    # first update with old data
    refresh()
    
    # render default chart
    render_default_chart = _.once (instrument) ->
        [board, security] = instrument.split(':')
        render_chart_for_row $("tr.row[data-board=#{escape_selector board}][data-security=#{escape_selector security}]", table)
        
    
    # observe row clicks for chart rendering
    
    if options.chart?
        table.on('click', 'tr.row', on_row_click)
    
    undefined


_.extend scope,
    table: table_widget
