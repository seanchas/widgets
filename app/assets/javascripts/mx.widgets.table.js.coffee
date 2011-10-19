global = module?.exports ? this

global.mx           ||= {}
global.mx.widgets   ||= {}

scope = global.mx.widgets


$ = jQuery

cache = kizzy('widgets')

filter_scope = 'small'


prepare_value = (column, value) ->
    switch column.type
        when 'number' then  mx.utils.number_with_precision value, { precision: column.precision }
        when 'time' then value.split(':')[0..1].join(':')
        else value


prepare_cell = (column, record) ->
    type:   column.type
    value:  prepare_value column, record[column.name]


prepare_row = (record, columns) ->
    board:      record.BOARDID
    security:   record.SECID
    cells:      (prepare_cell column, record for column in columns)


filter_columns = (columns, filters) ->
    columns[filter.id] for filter in filters


render_cell = (cell, row) ->
    element = $('<td>')
        .addClass(cell.type)
        .toggleClass('first', _.first(row) == cell)
        .toggleClass('last', _.last(row) == cell)
        .html(cell.value)

    element


render_row = (row, index) ->
    element = $('<tr>')
        .attr(
            'data-board':       row.board
            'data-security':    row.security
        )
        .addClass( if index % 2 then 'even' else 'odd' )
    
    element.append render_cell cell, row for cell in row.cells
    
    element


table_widget = (element, engine, market, params) ->
    element = $(element); return unless element
    
    fds = mx.iss.filters engine, market
    cds = mx.iss.columns engine, market
    rds = mx.iss.records engine, market, params, { force: true }

    
    cache_key = ['table', engine, market, params].join('/')
    cache_data = cache.get(cache_key)
    
    element.html(cache_data) if cache_data

    render = (filters, columns, records) ->
        
        rows = (prepare_row record, filter_columns columns, filters for record in records)
        
        table = $('<table>')
            .addClass('mx-widget-table')
            .attr(
                'data-engine': engine,
                'data-market': market
            )
        
        table.append render_row row, index for row, index in rows
        
        element.html table
        
        cache.set cache_key, element.html()
    

    $.when(fds, cds, rds).then (filters, columns, records) ->
        render filters[filter_scope], columns, records
    
    undefined

_.extend scope,
    table: table_widget
