##= require highstock

global = module?.exports ? ( exports ? this )

global.mx           ||= {}
global.mx.security  ||= {}

scope = global.mx.security

$ = jQuery


cache = kizzy('security/chart')

###

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


chart_options = ->
    
    chart:
        alignTicks: false
        
        marginTop: 0
        marginRight: 1
        marginBottom: 0
        marginLeft: 1
    
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
                $("<a>").attr('href', "##{period}").html(periods[period].name)
            )

        list.append(item)

    list


render_widget = (element) ->
    element.html(make_periods)
    element.append($("<div>").addClass("mx-security-chart-container"));


widget = (element, engine, market, board, param, options = {}) ->
    
    element = $(element); return if element.length == 0


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
###

l2u = (milliseconds) ->
    milliseconds - (new Date(milliseconds).getTimezoneOffset() * 60 * 1000);

u2l = (milliseconds) ->
    milliseconds + (new Date(milliseconds).getTimezoneOffset() * 60 * 1000);

cs_host = "http://www.micex.ru/cs"

defaults = undefined

loader = (param) ->
	[board, security] = param.split(":")
	
	return {} unless security?
	
	board = _.first(b for b in defaults.boards when board == b.boardid)
	
	return {} unless board?
	
	board_group = _.first(g for g in defaults.boardgroups when g.board_group_id == board.board_group_id)
	
	return {} unless board_group?

	market = _.first(m for m in defaults.markets when m.market_id == board_group.market_id)
	
	return {} unless market?
	
	engine = _.first(e for e in defaults.engines when e.id == market.trade_engine_id)
	
	return {} unless engine?
	
	deferred = new $.Deferred
	
	$.ajax
		url: "#{cs_host}/engines/#{engine.name}/markets/#{market.market_name}/boardgroups/#{board_group.board_group_id}/securities/#{security}.json?callback=?&interval=1&period=1d"
		dataType: "jsonp"
		cache: true
	.then (json) ->
		result = []
		
		for zone in json.zones
			result.push([])
			_serie_result = _.last(result)
			for serie in zone.series
				_serie_result.push({ data: [], type: serie.type })
				_candle_result = _.last(_serie_result)
				for candle in serie.candles
					_candle_result.data.push switch _candle_result.type
						when 'line' then [l2u(candle.open_time), candle.value]
						when 'stockbar' then [l2u(candle.open_time), candle.open, candle.high, candle.low, candle.close]
						when 'bar'	then [l2u(candle.close_time), candle.value]
		
		deferred.resolve(result)
	
	deferred.promise()


widget = (element, engine, market, board, security) ->

    element = $(element)
    return if _.size(element) == 0

    chart = new Highcharts.StockChart
        chart:
            renderTo: element[0]
            alignTicks: false
            spacingRight: 0
            spacingLeft: 0
            
        loading:
            hideDuration: 250
            labelStyle:
                top: '50px'
                
        credits:
            enabled: false
            
        rangeSelector:
            enabled: false
            
        series: [
            type: 'line'
            data: [[0, 0]]
            visible: false
            gapSize: 60
            yAxis: 0
        ,
            type: 'column'
            data: [[0, 0]]
            visible: false
            yAxis: 1
        ]
        
        yAxis: [
            id: 'values'
            height: 180
            opposite: true
        ,
            id: 'volumes'
            height:105
            top: 200
            offset: 0
            opposite: true
        ]

    chart.showLoading()

    mx.iss.defaults().then (json) ->
        defaults ?= json

        loader("#{board}:#{security}").then (json) ->
            _.first(chart.series).setData(_.first(_.first(json)).data, true)
            
            chart.series[1].setData(_.first(_.last(json)).data, true)
            
            serie.show() for serie in chart.series
        
            console.log chart.series
            chart.hideLoading()
        
        

    return

_.extend scope,
    chart: widget

Highcharts.setOptions({
    lang: {
        decimalPoint: '.',
        thousandsSep: ' ',
        months: ['Январь', 'Февраль', 'Март', 'Апрель', 'Май', 'Июнь', 'Июль', 'Август', 'Сентябрь', 'Октябрь', 'Ноябрь', 'Декабрь'],
        shortMonths: ['Янв', 'Фев', 'Мар', 'Апр', 'Май', 'Июнь', 'Июль', 'Авг', 'Сен', 'Окт', 'Ноя', 'Дек'],
        weekdays: ['Воскресение', 'Понедельник', 'Вторник', 'Среда', 'Четверг', 'Пятница', 'Суббота']
        loading: "Подождите..."
    }
});
