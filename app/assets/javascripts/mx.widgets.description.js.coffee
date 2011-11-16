global = module?.exports ? ( exports ? this )

global.mx           ||= {}
global.mx.widgets   ||= {}

scope = global.mx.widgets

$ = jQuery


create_table = ->
    $('<table>')
        .addClass('mx-widget-description')
        .html('<thead></thead><tbody></tbody>')

make_row = (title, value) ->
    $('<tr>')
        .html("<th>#{title}</th><td>#{value}</td>")

render = (element, description) ->
    table = create_table()
    
    table_body = $ 'tbody', table
    
    for record in description
        table_body.append make_row record['title'], record['value']
    
    element.html table


description_widget = (element, engine, market, board, param, options = {}) ->
    element = $ element
    
    return unless element.length > 0
    
    dds = mx.iss.description(param)
    
    $.when(dds).then (description) ->
        render element, description


_.extend scope,
    description: description_widget
