global = module?.exports ? ( exports ? this )

global.mx           ||= {}
global.mx.widgets   ||= {}

scope = global.mx.widgets

$ = jQuery



locales = 
    title:
        ru: 'Индикаторы ставки РЕПО'
        en: 'REPO Rates'


columns = [
    {
        id: 'NAME'
        title:
            ru: 'Индикатор РЕПО'
            en: 'REPO Indicator'
        short_title:
            ru: 'Индикатор'
            en: 'Indicator'
        type: 'string'
    }
    {
        id: 'SHORTNAME'
        title:
            ru: 'Краткое наименование индикатора'
            en: 'Short Indicator`s Name'
        short_title:
            ru: 'Краткое наименование'
            en: 'Short Name'
        type: 'string'
    }
    {
        id: 'CLOSE'
        title:
            ru: 'Текущее значение индекса, %'
            en: 'Current Value, %'
        short_title:
            ru: 'Значение, %'
            en: 'Value, %'
        type: 'number'
        has_percent: true
    }
    {
        id: 'TRENDCLOSEBP'
        title:
            ru: 'Изменение к закрытию предыдущего торгового дня, базисных пунктов'
            en: 'Change from the close of previous day, basis point'
        short_title:
            ru: 'Изм.к закр., б.п.'
            en: 'Change, b.p.'
        type: 'number'
        precision: 0
    }
    {
        id: 'VALUE'
        title:
            ru: 'Объем торгов ценными бумагами, входящими в индикатор'
            en: 'Trading volume'
        short_title:
            ru: 'Объем, руб.'
            en: 'Volume, RUB'
        type: 'number'
        precision: 0
    }
    {
        id: 'TRADEDATE'
        title:
            ru: 'Дата/время последнего обновления'
            en: 'Last modification date/time'
        short_title:
            ru: 'Дата/время обновления'
            en: 'Date/time'
        type: 'time'
    }
    {
        id: 'MONTHCHANGEBP'
        title:
            ru: 'Изменение с начала календарного месяца, базисных пунктов'
            en: 'Change from the beginning of month, basis point'
        short_title:
            ru: 'Изм. с начала месяца, б.п.'
            en: 'MTD, b.p.'
        type: 'number'
        precision: 0
    }
    {
        id: 'YEARCHANGEBP'
        title:
            ru: 'Изменение с начала календарного года, базисных пунктов'
            en: 'Change from the beginning of year, basis point'
        short_title:
            ru: 'Изм. с начала года, б.п.'
            en: 'YTD, b.p.'
        type: 'number'
        precision: 0
    }
]


marketdata_2_history =
    'CLOSE':        'CURRENTVALUE'
    'VALUE':        'VALTODAY'
    'TRADEDATE':    'TIME'
    'TRENDCLOSEBP': 'LASTCHANGEBP'


make_header_view = (container) ->
    view = $('<h4>')
        .html(locales.title[mx.locale()])
        .appendTo(container)



make_table_view = (container) ->
    view = $('<table>')
        .addClass('mx-widget-table mx-widget-repo-rates')
        .html('<thead></thead><tbody></tbody>')
        .appendTo(container)


render_table_head = (container) ->
    container.empty()
    
    row_view = $('<tr>')

    for column in columns
        cell_view = $('<td>')
            .addClass(column.type)
            .attr('title', column.title[mx.locale()])
            .html(column.short_title[mx.locale()])
            .appendTo(row_view)

    row_view
        .appendTo(container)
    
    container


render_table_body = (container, marketdata) ->
    container.empty()
    
    for record, index in marketdata
        row_view = $('<tr>')
            .toggleClass('odd',     (index + 1) % 2 == 1)
            .toggleClass('even',    (index + 1) % 2 == 0)
        
        for column in columns
            value = record[column.id]

            if record.VALTODAY
                value = record[marketdata_2_history[column.id] ? column.id]
            
            cell_view = $('<td>')
                .addClass(column.type)
                .html(mx.utils.render(value, column) || '&mdash;')
                .appendTo(row_view)
        
        row_view
            .appendTo(container)
    
    container


widget = (container, options = {}) ->
    container = $(container) ; return if container.length == 0
    
    
    securities_data_source  = mx.iss.repo_rates_securities()
    securities              = undefined


    header_view     = undefined
    table_view      = undefined
    table_head_view = undefined
    table_body_view = undefined


    ready = $.when(securities_data_source)
    
    
    refresh = ->
        $.when(mx.iss.repo_rates_marketdata(), mx.iss.repo_rates_history()).then (marketdata, history) ->
            
            marketdata  = _.filter(marketdata, (record) -> _.include(securities, record.SECID))
            marketdata  = _.sortBy(marketdata, (record) -> _.indexOf(securities, record.SECID))
            history     = _.filter(history, (record) -> _.include(securities, record.SECID))
            
            for record in marketdata
                unless record.VALTODAY
                    history_record = _.find(history, (history_record) -> history_record.SECID == record.SECID)
                    _.extend(record, history_record)
            
            render_table_head(table_head_view)
            render_table_body(table_body_view, marketdata)
            
    

    ready.then (securities_data) ->
        
        header_view     = make_header_view(container)
        table_view      = make_table_view(container)
        table_head_view = $('thead', table_view)
        table_body_view = $('tbody', table_view)
        
        securities = _.pluck(securities_data, 'SECID')
        
        refresh()




_.extend scope,
    repo_rates: widget
