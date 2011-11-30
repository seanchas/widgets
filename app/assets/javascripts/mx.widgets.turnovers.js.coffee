global = module?.exports ? ( exports ? this )

global.mx           ||= {}
global.mx.widgets   ||= {}

scope = global.mx.widgets

$ = jQuery


create_table = ->
    $('<table>')
        .addClass('mx-widget-turnovers')
        .html('<thead></thead><tbody></tbody>')

create_table_head = ->
    $('<tr>')
        .append($('<td>').html('Объемы торгов'))
        .append($('<td>').addClass('number').html(mx.widgets.utils.render_value(new Date, { type: 'date' }) + ' [РУБ]'))

create_row = (record) ->
    $('<tr>')
        .append(
            $('<td>')
                .addClass('title')
                .html(record['TITLE'])
        )
        .append(
            $('<td>')
                .addClass('number')
                .html(mx.widgets.utils.render_value(record['VALTODAY'] * 1000000, { type: 'number', precision: '0' }))
        )

render = (element, turnovers) ->
    table = create_table()
    
    table_head = $('thead', table)
    table_body = $('tbody', table)
    
    table_head.html create_table_head()
    
    for record in turnovers
        table_body.append create_row record
    
    element.html table


widget = (element, options = {}) ->
    element = $(element); return if element.length == 0
    
    refresh_timeout = options.refresh_timeout || 60 * 1000

    refresh = ->
        mx.iss.turnovers().then (turnovers) ->
            render element, turnovers
            _.delay refresh, refresh_timeout

    refresh()

_.extend scope,
    turnovers: widget
