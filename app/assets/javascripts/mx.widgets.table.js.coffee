global = module?.exports ? this

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



prepare_value = (column, value) ->
    switch column.type
        when 'number'   then mx.utils.number_with_precision value, { precision: column.precision }
        when 'time'     then value.split(':')[0..1].join(':')
        else value



prepare_cell = (column, record) ->
    type:   column.type
    name:   column.name
    value:  prepare_value column, record[column.name]



prepare_row = (record, columns) ->
    board:      record.BOARDID
    security:   record.SECID
    cells:      (prepare_cell column, record for column in columns)



filter_columns = (columns, filters) ->
    columns[filter.id] for filter in filters



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
        .appendTo(container)


# entry point

table_widget = (element, engine, market, securities, options) ->

    # ensure element
    element = $ element; return unless element.exists()

    # fetch filters data
    fds = mx.iss.filters engine, market

    # fetch columns data
    cds = mx.iss.columns engine, market

    # fetch records data
    rds = mx.iss.records engine, market, securities
    
    # clean element to be sure
    # no content exists and
    # no callback are present
    element.empty()
    
    # create table
    table = $('<table>')
        .addClass('mx-widget-table')
        .attr(
            'data-engine': engine
            'data-market': market
        )
        .html('<thead></thead><tbody></tbody>')
    
    # insert table into DOM
    element.html table.hide()
    
    # refresh function
    refresh = ->
        rds = mx.iss.records engine, market, securities, { force: true }
        $.when(fds, cds, rds).then (filters, columns, records) ->
            render filters[filter_scope], columns, records, table
    
    # render function
    render = (filters, columns, records, table) ->
        
        # select visible fields
        fields  = (filter_columns columns, filters)
        
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
                

        table.show()
        
        setTimeout refresh, 10000
        
    
    # start async render
    $.when(fds, cds, rds).then (filters, columns, records) ->
        render filters[filter_scope], columns, records, table


    undefined


_.extend scope,
    table: table_widget
