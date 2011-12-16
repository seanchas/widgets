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


trigger_render_event = (element, status, iss, options = {}) ->
    element.trigger('render', _.extend({ iss: iss, status: status }, options))


widget = (element, engine, market, board, param, options = {}) ->
    element = $ element; return if element.length == 0
    
    cache_key = mx.utils.sha1(JSON.stringify(_.rest(arguments).join("/")))
    
    element.html cache.get(cache_key) if options.cache

    sds = mx.iss.security(engine, market, board, param)
    
    refresh_timeout = options.refresh_timeout || 60 * 1000
    
    timeout = null
    
    destroy = (options = {}) ->
        clearTimeout timeout
        element.children().remove()
        cache.remove(cache_key) if options.force == true
    
    refresh = ->
        ods = mx.iss.orderbook(engine, market, board, param, { force: true })
        
        clearTimeout timeout

        $.when(sds, ods).done (security, data) ->
            
            orderbook = _.first(data)
            iss = _.last(data)
            
            if status && status['HTTP_STATUS'] && status['HTTP_STATUS'] != 200
                trigger_render_event(element, 'failure', iss)
                return destroy({ force: true })
            
            if _.size(orderbook) > 0
                render element, orderbook, security
                cache.set cache_key, element.html() if options.cache
                trigger_render_event(element, 'success', iss, { last: _.first(orderbook)['UPDATETIME'] })
            else
                destroy({ force: true })
                trigger_render_event(element, 'failure', iss)

            timeout = _.delay refresh, refresh_timeout

    refresh()

    destroy: destroy

_.extend scope,
    orderbook: widget
