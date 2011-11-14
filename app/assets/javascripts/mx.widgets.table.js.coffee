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

filter_scope = 'small'


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



# entry point

table_widget = (element, engine, market, securities, options = {}) ->
    
    # ensure element
    element = $ element; return unless element.exists()

    # fetch filters data
    fds = mx.iss.filters engine, market

    # fetch columns data
    cds = mx.iss.columns engine, market

    # cache
    cache_key       = mx.utils.sha1(['widgets', 'table', location.path_name, JSON.stringify(_.rest arguments)].join('/'))
    cached_widget   = cache.get cache_key if options.cache

    # clean element to be sure
    # no content exists and
    # no callback are present
    element.empty()

    table = if cached_widget
        $('table', element.html(cached_widget))
    else
        _.tap $('<table>')
            .addClass('mx-widget-table')
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
    
    # observe chart render event
    element.bind 'render:chart', (event, security) ->
        # [board, security] = security.split(':')
        # find or create chart row
        # hide row if it's new
        # hide all charts except this one
    

    # observe row clicks
    ###
    element.delegate 'tbody tr', 'click', (event) ->
        row = $ event.currentTarget
        chart_row   = row.next('.chart')
        if chart_row.exists() then toggle_chart chart_row else build_chart row
    ###


    # build chart
    build_chart = (row) ->
        chart_cell = $('<td>')
            .attr('colspan', $('td', row).size())
        
        chart_row = $('<tr>')
            .addClass('chart')
            .html(chart_cell)
            .insertAfter(row)
        
        chart_cell.bind 'render:complete', () ->
            chart_row.hide()
            toggle_chart chart_row
        
        mx.widgets.chart chart_cell, 
            engine: engine
            market: market
            security: row.data('security')
        

    # toggle chart
    toggle_chart = (row) ->
        row.siblings('.chart').hide()
        row.toggle()
        element.trigger 'render:complete'
        
    # refresh table
    refresh = ->
        rds = mx.iss.records engine, market, securities, _.extend(options, { force: true })
        $.when(fds, cds, rds).then (filters, columns, records) ->
            render filters[filter_scope], columns, records, table
    
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
        
        for row in rows
            do (row) ->
                table_row = find_or_create_row row, table_body
                for cell in row.cells
                    do (cell) ->
                        table_cell = find_or_create_cell cell, table_row
                        table_cell.html(cell.value)
                
        # show table
        table.show()
        
        # refresh table records
        _.delay refresh, (options.refresh_timeout || 60 * 1000)
        
        element.trigger 'render:complete'
        
    
    # first update with old data
    refresh()
    
    # element.trigger 'render:chart', options.chart if options.chart
    
    undefined


_.extend scope,
    table: table_widget
