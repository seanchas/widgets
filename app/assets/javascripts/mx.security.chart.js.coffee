##= require highstock

global = module?.exports ? ( exports ? this )

global.mx           ||= {}
global.mx.security  ||= {}

scope = global.mx.security

$ = jQuery


cache = kizzy('security/chart')


periods =
    day:
        name: { ru: 'День', en: 'Day' }
        interval: 10
        period: '2d'
        offset: 24 * 60 * 60 * 1000
    week:
        name: { ru: 'Неделя', en: 'Week' }
        interval: 60
        period: '2w'
        offset: 7 * 24 * 60 * 60 * 1000
    month:
        name: { ru: 'Месяц', en: 'Month' }
        interval: 60
        period: '2M'
        offset: 31 * 24 * 60 * 60 * 1000
    year:
        name: { ru: 'Год', en: 'Year' }
        interval: 24
        period: '2y'
        offset: 365 * 24 * 60 * 60 * 1000
    all:
        name: { ru: 'Весь период', en: 'All' }
        interval: 7
        period: 'all'
        offset: 1000 * 365 * 24 * 60 * 60 * 1000


visible_periods = ['day', 'week', 'month', 'year', 'all']


default_period  = 'day'
default_type    = 'line'


cs2hs =
    line:       'line'
    stockbar:   'ohlc'
    candles:    'candlestick'


chart_options = ->
    
    chart:
        alignTicks: false
        
        marginTop: 0
        marginRight: 1
        marginBottom: 0
        marginLeft: 1
    
    lang:
        loading: 'Загрузка...'
    
    global:
        useUTC: false
    
    credits:
        enabled: false
    
    navigator:
        height: 45
        margin: 9
    
    rangeSelector:
        enabled: false
    
    xAxis:
        offset: -29
    
    yAxis: [
        {
            height: 180
            opposite: true
            lineWidth: 1
            labels:
                formatter: ->
                    mx.utils.number_with_delimiter(@value)
            style:
                color: '#000'
        }, {
            height: 105
            top: 200
            opposite: true
            lineWidth: 1
            labels:
                formatter: ->
                    mx.utils.number_with_power(@value)
            style:
                color: '#000'
        }
        
    ]
    
    plotOptions:
        series:
            gapSize: 72
    
    scrollbar:
        height: 12
    
    series: [
        {
            yAxis: 0
            data: [],
            type: 'line'
            name: 'Цена'
            tooltip:
                yDecimals: 2
        }, {
            yAxis: 1
            data: []
            type: 'column'
            name: 'Объем'
            tooltip:
                yDecimals: 0
        }
    ]


process_borders = (borders) ->
    _.reduce borders, (memo, border) ->
        memo[border.interval] = border
        memo
    , {}


l2u = (milliseconds) ->
    milliseconds - (new Date(milliseconds).getTimezoneOffset() * 60 * 1000);

u2l = (milliseconds) ->
    milliseconds + (new Date(milliseconds).getTimezoneOffset() * 60 * 1000);


tonight = ->
    date = new Date
    new Date date.getFullYear(), date.getMonth(), date.getDate()



make_periods = () ->
    list = $("<ul>")
        .addClass('mx-security-chart-periods')

    for period in visible_periods
        item = $("<li>")
            .toggleClass('current', period == default_period)
            .html(
                $("<a>").attr('href', "##{period}").html(periods[period].name[mx.locale()])
            )

        list.append(item)

    list


render_widget = (element) ->
    element.html(make_periods)
    element.append($("<div>").addClass("mx-security-chart-container"));


widget = (element, engine, market, board, param, options = {}) ->
    
    element = $(element); return if element.length == 0

    set_highcharts_options()

    chart = null

    render_widget(element)
    
    element.on 'click', 'a', (event) ->
        event.preventDefault()

        $('li', element).removeClass('current')
        $(event.currentTarget).parent('li').addClass('current')

        element.trigger "period:changed", $(event.currentTarget).attr('href').replace('#', '')


    make_chart = ->
        co = chart_options()
        co.chart.renderTo = $(".mx-security-chart-container", element)[0]
        new Highcharts.StockChart(co);
    

    mx.iss.candle_borders(engine, market, param).then (borders) ->
        
        borders = process_borders(borders)
        
        period = periods[default_period]
        
        
        render = (series) ->

            {begin, end} = borders[period.interval]

            chart ?= make_chart()

            for serie, index in series
                chart.series[index].setData series[index], false
            
            from = _.first(_.first(series))[0]
            till = _.last(_.first(series))[0]
            
            proposedFrom = + tonight() - period.offset
            
            from = proposedFrom if proposedFrom > from
            
            chart.xAxis[0].setExtremes(
                from,
                till
            )
            
            chart.options.plotOptions.series.gapSize = 0
            
            chart.redraw()

            chart.hideLoading() if chart?

        load = (type = default_type) ->
            
            chart.showLoading() if chart?
            
            {begin, end} = borders[period.interval]

            mx.cs.data(engine, market, param, {
                'interval': period.interval
                's1.type':  type
                'period':   period.period
                #'from':     begin
                #'till':     end
            }).then (data) ->
                
                series = for zone in data.zones
                    _.reduce _.first(zone.series).candles, (memo, candle) ->
                        memo.push [l2u(candle.open_time), candle.value]
                        memo
                    , []
                
                render series
                
        if borders[period.interval]
            load()
        else
            destroy()

        
        
        element.on "period:changed", (event, triggered_period) ->
            return if period == periods[triggered_period]
            period = periods[triggered_period]
            load()
    
    destroy = ->
        chart.destroy() if chart?
        chart = null
        element.off('click', 'a')
        element.off('period:changed')
        element.children().remove()
        
    
    {
        destroy: destroy
    }


set_highcharts_options = _.once ->
    Highcharts.setOptions(highcharts_options[mx.locale()])


_.extend scope,
    chart: widget

highcharts_options = 
    ru:
        lang:
            decimalPoint: '.'
            thousandsSep: ' '
            months: ['Январь', 'Февраль', 'Март', 'Апрель', 'Май', 'Июнь', 'Июль', 'Август', 'Сентябрь', 'Октябрь', 'Ноябрь', 'Декабрь']
            shortMonths: ['Янв', 'Фев', 'Мар', 'Апр', 'Май', 'Июнь', 'Июль', 'Авг', 'Сен', 'Окт', 'Ноя', 'Дек']
            weekdays: ['Воскресение', 'Понедельник', 'Вторник', 'Среда', 'Четверг', 'Пятница', 'Суббота']
    en: {}