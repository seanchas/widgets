global = module?.exports ? ( exports ? this )

global.mx           ||= {}
global.mx.security  ||= {}

scope = global.mx.security

$ = jQuery

cache = kizzy('security.orderbook')


create_table = ->
    $('<table>')
        .addClass('mx-security-orderbook')
        .html('<thead></thead><tbody></tbody>')

create_table_header = ->
    $('<tr>')
        .html('<td class="buy" colspan="2">Покупка</td><td></td><td class="sell" colspan="2">Продажа</td>')

create_row = (record, max_quantity, precision) ->
    row = $('<tr>')
        .toggleClass('buy', record['BUYSELL'] == 'B')
        .toggleClass('sell', record['BUYSELL'] == 'S')
        .html("<td class=\"buy\"></td><td class=\"buy_bar\"><td class=\"price\">#{mx.utils.number_with_precision record['PRICE'], { precision: precision }}</td><td class=\"sell_bar\"></td><td class=\"sell\"></td>")
    
    quantity = record['QUANTITY']
    
    [cell, bar_cell] = switch record['BUYSELL']
        when 'B' then [$('td.buy',   row), $('td.buy_bar',   row)]
        when 'S' then [$('td.sell',  row), $('td.sell_bar',  row)]
    
    cell.html mx.utils.number_with_delimiter quantity
    
    bar_cell.html $('<span>').css({ width: Math.ceil(100 * quantity / max_quantity) + '%' }).html('&nbsp;')
    
    row
    

render = (element, orderbook, security) ->
    table           = create_table()
    table_header    = create_table_header()
    
    $('thead', table).html(table_header)
    
    max_quantity = _.max(_.pluck(orderbook, 'QUANTITY'))
        
    for record in orderbook
        $('tbody', table).append create_row record, max_quantity, security['DECIMALS']
    
    element.html table


widget = (element, engine, market, board, param, options = {}) ->
    element = $ element; return if element.length == 0
    
    cache_key = mx.utils.sha1(JSON.stringify(_.rest(arguments).join("/")))
    
    element.html cache.get(cache_key) if options.cache

    sds = mx.iss.security(engine, market, board, param)
    
    refresh_timeout = options.refresh_timeout || 60 * 1000
    
    timeout = null
    
    refresh = ->
        ods = mx.iss.orderbook(engine, market, board, param, { force: true })

        $.when(sds, ods).then (security, orderbook) ->
            
            if security and orderbook and _.size(orderbook) > 0
                render element, orderbook, security
                cache.set cache_key, element.html() if options.cache
                element.trigger('render:success', { last: _.first(orderbook)['UPDATETIME'] })
            else
                element.trigger('render:failure')

            timeout = _.delay refresh, refresh_timeout

    refresh()

    {
        destroy: ->
            clearTimeout timeout
            element.children().remove()
    }

_.extend scope,
    orderbook: widget
