global = module?.exports ? ( exports ? this )

global.mx           ||= {}
global.mx.security  ||= {}

scope = global.mx.security

$ = jQuery

create_table = ->
    $('<table>')
        .addClass('mx-security-description')
        .html('<thead></thead><tbody></tbody>')

make_row = (title, value) ->
    $('<tr>')
        .html("<th>#{title}</th><td>#{value}</td>")

make_divider_row = ->
    $('<tr>')
        .addClass('divider')
        .html("<td colspan=\"2\"></td>")

render = (element, description, security, columns, filters) ->

    table = create_table()
    
    table_body = $ 'tbody', table
    
    description_names = _.pluck description, 'name'


    for field in description
        field.value = mx.utils.parse_date(field.value) if field.type == 'date'


    mx.utils.process_record security, columns
    
    
    columns = _.compact(
        for filter in filters
            columns[filter.id]
    )
    
    columns = _.reduce columns, (memo, column) ->
        memo.push column if column.is_system == 0 and column.is_hidden == 0 and !_.include(description_names, column.name)
        memo
    , []
    
    for record in description
        table_body.append make_row record['title'], mx.utils.render(record['value'], record) if record.is_hidden == 0
    
    table_body.append make_divider_row
    
    for column in columns
        table_body.append make_row column.short_title, mx.utils.render(security[column.name], column)
    
    element.html table


widget = (element, engine, market, board, param, options = {}) ->
    element = $ element
    
    return unless element.length > 0
    
    cds = mx.iss.columns(engine, market, { only: 'securities' })
    fds = mx.iss.filters(engine, market)
    sds = mx.iss.security(engine, market, board, param, { only: 'securities' })
    dds = mx.iss.description(param)
    
    $.when(dds, sds, cds, fds).then (description, security, columns, filters) ->
        render element, description, security, columns, filters['full']
    
    {}


_.extend scope,
    description: widget
