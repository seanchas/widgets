global = module?.exports ? ( exports ? this )

global.mx           ||= {}
global.mx.widgets   ||= {}

scope = global.mx.widgets

$ = jQuery


locales =
    money_market_mt:
        ru: 'Операции между участниками'
        en: 'Transactions of trading members'

    money_market_ck:
        ru: 'Операции с ЦК'
        en: 'Transactions with the CCP'


keys = ['money_market_mt', 'money_market_ck']


columns = [
    {
        name: 'TITLE'
        type: 'string'
    }
    {
        name: 'VALTODAY'
        type: 'number'
        precision: 0
    }
]


refresh_delay = 5 * 1000


make_table_view = (container) ->
    view = $('<table>')
        .addClass('mx-widget-table mx-widget-money-market-turnovers')
        .html('<thead></thead><tbody></tbody>')
        .appendTo(container)


render = (container, key, data) ->
    title_row = $('<tr>')
        .addClass('title')
    
    $('<th>')
        .html(locales[key]?[mx.locale()] or key)
        .attr('colspan', 2)
        .appendTo(title_row)
    
    title_row
        .appendTo(container)
    
    for record in data
        row = $('<tr>')
        
        for column in columns
            value = record[column.name]
            if column.name == 'VALTODAY'
                value *= 1000000
            
            $('<td>')        
                .addClass(column.type)
                .html(mx.utils.render(value, column) or '&mdash;')
                .appendTo(row)
        
        row.appendTo(container)
    

widget = (container, options = {}) ->
    container = $(container) ; return if container.length == 0
    
    ready = $.when(true)
    
    table_view = undefined
    table_body_view = undefined
    
    refresh = ->
        #table_body_view.empty()
        
        $.when(
            mx.iss.money_market_turnovers('money_market_mt', { force: true })
            mx.iss.money_market_turnovers('money_market_ck', { force: true })
        ).then (args...) ->
            
            for key, index in keys
                render(table_body_view, key, args[index])
            
            #_.delay(refresh, refresh_delay)
        
    
    ready.then ->
        
        table_view      = make_table_view(container)
        table_body_view = $('tbody', table_view)
        
        refresh()


_.extend scope,
    money_market_turnovers: widget
