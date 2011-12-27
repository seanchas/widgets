global = module?.exports ? ( exports ? this )

global.mx           ?= {}
global.mx._widget   ?= {}

scope = global.mx._widget

$ = jQuery

cs_host = "http://www.beta.micex.ru/cs"

cs_data = (engine, market, boardgroup, security, options = {}) ->
    deferred = new $.Deferred
    
    $.ajax
        url: "#{cs_host}/engines/#{engine}/markets/#{market}/boardgroups/#{boardgroup}/securities/#{security}.hs?callback=?&candles=540&interval=5"
        dataType: 'jsonp'
    .then (json) ->
        deferred.resolve(_.first(json))
    
    deferred.promise()


extract_options = (args) ->
    [
        args
        if _.isObject(_.last(args)) and !_.isArray(_.last(args)) then args.pop() else {}
    ]

merge = (args...) ->
    $.extend(true, args...)

area_series_options =
    data: []


line_series_options =
    data: []


chart_options =
    chart:
        alignTicks: false
        borderRadius: 0
        
        spacingTop: 0
        spacingRight: 0
        spacingBottom: 5
        spacingLeft: 0
        
    credits:
        enabled: false
    navigator:
        enabled: false
    rangeSelector:
        enabled: false
    scrollbar:
        enabled: false
    series: [
        data: []
        type: 'area'
        threshold: null
        gapSize: 6
    ]
    xAxis:
        labels:
            style:
                fontSize: '9px'
    yAxis:
        labels:
            style:
                fontSize: '9px'
        opposite: true


widget = (element, args...) ->
    element = $(element); return unless _.size(element) > 0
    
    [args, options] = extract_options args
    
    mx.iss.defaults().then (json) ->
        
        chart = _.once ->
            _options = merge({}, chart_options, { chart: { renderTo: element[0] }})
            new Highcharts.StockChart _options
        
        cs_data('stock', 'index', '9', 'MICEXINDEXCF').then (json) ->
            
            for serie in json
                chart().series[0].setData(serie.data)
            


_.extend scope,
    chart: widget
