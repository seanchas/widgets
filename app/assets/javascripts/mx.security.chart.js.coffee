##= require highstock

global = module?.exports ? ( exports ? this )

global.mx           ||= {}
global.mx.security  ||= {}

scope = global.mx.security

$ = jQuery


periods =
    day:
        name: 'День'
        interval: 1
        offset: 24 * 60 * 60 * 1000
    week:
        name: 'Неделя'
        interval: 10
        offset: 7 * 24 * 60 * 60 * 1000
    month:
        name: 'Месяц'
        interval: 24
        offset: 31 * 24 * 60 * 60 * 1000
    year:
        name: 'Год'
        interval: 24
        offset: 365 * 24 * 60 * 60 * 1000
    all:
        name: 'Весь период'
        interval: 24
        offset: 1000 * 365 * 24 * 60 * 60 * 1000


visible_periods = ['day', 'week', 'month', 'year', 'all']


default_period  = 'all'
default_type    = 'line'


cs2hs =
    line:       'line'
    stockbar:   'ohlc'
    candles:    'candlestick'


chart_options =
    
    chart:
        alignTicks: false
        
        marginTop: 0
        marginRight: 1
        marginBottom: 0
        marginLeft: 0
    
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
                    mx.utils.number_with_delimiter(@value)
            style:
                color: '#000'
        }
        
    ]
    
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
        .addClass('mx-widget-chart-periods')

    for period in visible_periods
        item = $("<li>")
            .toggleClass('current', period == default_period)
            .html(
                $("<a>").attr('href', "##{period}").html(periods[period].name)
            )

        list.append(item)

    list


render_widget = (element) ->
    element.html(make_periods)
    element.append($("<div>").addClass("chart-container"));


widget = (element, engine, market, board, param, options = {}) ->
    
    element = $(element); return if element.length == 0

    render_widget(element)
    
    element.on 'click', 'a', (event) ->
        event.preventDefault()

        $('li', element).removeClass('current')
        $(event.currentTarget).parent('li').addClass('current')

        element.trigger "period:changed", $(event.currentTarget).attr('href').replace('#', '')


    make_chart = ->
        chart_options.chart.renderTo = $(".chart-container", element)[0]
        new Highcharts.StockChart(chart_options);
    

    mx.iss.candle_borders(engine, market, param).then (borders) ->
        
        borders = process_borders(borders)
        
        period = periods[default_period]
        
        render = (series) ->

            {begin, end} = borders[period.interval]

            chart ?= make_chart()

            for serie, index in series
                chart.series[index].setData series[index], false
            
            from = mx.utils.parse_date(begin)
            till = mx.utils.parse_date(end)
            
            proposedFrom = + tonight() - period.offset
            
            from = proposedFrom if proposedFrom > from
            
            chart.xAxis[0].setExtremes(
                l2u(from),
                l2u(till)
            )
            
            chart.redraw()

        load = (type = default_type) ->
            
            {begin, end} = borders[period.interval]

            mx.cs.data(engine, market, param, {
                'interval': period.interval
                's1.type':  type
                'from':     begin
                'till':     end
            }).then (data) ->
                
                series = for zone in data.zones
                    _.reduce _.first(zone.series).candles, (memo, candle) ->
                        memo.push [l2u(candle.open_time), candle.value]
                        memo
                    , []
                
                render series
                
        load()
        
        element.on "period:changed", (event, triggered_period) ->
            return if period == periods[triggered_period]
            period = periods[triggered_period]
            load()


_.extend scope,
    chart: widget

Highcharts.setOptions({
    lang: {
        decimalPoint: '.',
        thousandsSep: ' ',
        months: ['Январь', 'Февраль', 'Март', 'Апрель', 'Май', 'Июнь', 'Июль', 'Август', 'Сентябрь', 'Октябрь', 'Ноябрь', 'Декабрь'],
        shortMonths: ['Янв', 'Фев', 'Мар', 'Апр', 'Май', 'Июнь', 'Июль', 'Авг', 'Сен', 'Окт', 'Ноя', 'Дек'],
        weekdays: ['Воскресение', 'Понедельник', 'Вторник', 'Среда', 'Четверг', 'Пятница', 'Суббота']
    }
});
