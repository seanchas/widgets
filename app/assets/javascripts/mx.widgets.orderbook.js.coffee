global = module?.exports ? ( exports ? this )

global.mx           ||= {}
global.mx.widgets   ||= {}

scope = global.mx.widgets

$ = jQuery


create_table = ->
    $('<table>')
        .addClass('mx-widget-orderbook')
        .html('<thead></thead><tbody></tbody>')

create_table_header = ->
    $('<tr>')
        .html('<td class="buy" colspan="2">Покупка</td><td></td><td class="sell" colspan="2">Продажа</td>')

create_row = (record, max_quantity) ->
    row = $('<tr>')
        .html("<td class=\"buy\"></td><td class=\"buy_bar\"><td class=\"price\">#{mx.utils.number_with_precision record['PRICE'], { precision: 2 }}</td><td class=\"sell_bar\"></td><td class=\"sell\"></td>")
    
    quantity = record['QUANTITY']
    
    [cell, bar_cell] = switch record['BUYSELL']
        when 'B' then [$('td.buy',   row), $('td.buy_bar',   row)]
        when 'S' then [$('td.sell',  row), $('td.sell_bar',  row)]
    
    cell.html mx.utils.number_with_delimiter quantity
    
    bar_cell.html $('<span>').css({ width: Math.ceil(100 * quantity / max_quantity) + '%' }).html('&nbsp;')
    
    row
    

render = (element, orderbook) ->
    table           = create_table()
    table_header    = create_table_header()
    
    $('thead', table).html(table_header)
    
    max_quantity = _.max(_.pluck(orderbook, 'QUANTITY'))
        
    for record in orderbook
        $('tbody', table).append create_row record, max_quantity
    
    element.html table


orderbook_widget = (element, engine, market, param, options = {}) ->
    element = $ element
    return unless element.length > 0
    
    
    refresh = ->
        ods = mx.iss.orderbook(engine, market, param)

        $.when(ods).then (orderbook) ->
            render element, orderbook
            _.delay refresh, 5 * 1000

    refresh()


_.extend scope,
    orderbook: orderbook_widget
