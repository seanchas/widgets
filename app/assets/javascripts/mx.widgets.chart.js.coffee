##= require jquery

global = exports ? this

global.mx           ||= {}
global.mx.widgets   ||= {}

scope = global.mx.widgets


cs_host         = "http://www.beta.micex.ru"
cs_extension    = "png"
cs_template     = "adv_no_volume"


$ = jQuery


extend = (obj, mixin) ->
    obj[name] = method for name, method of mixin
    obj

calculate_dimensions = (element) ->
    width   = element.width()
    height  = width / 2

    'c.width':      width
    'z1_c.width':   width
    'z1.width':     width
    'c.height':     height
    'z1_c.height':  height
    'z1.height':    height


make_url = (element, engine, market, security, options = {}) ->
    dimensions = calculate_dimensions(element)

    if options.compare?
        compare = if _.isArray(options.compare) then options.compare.join(',') else options.compare
    
    query = $.param(extend(dimensions, { template: cs_template, rnd: +new Date, compare: compare ? '' }))
    "#{cs_host}/cs/engines/#{engine}/markets/#{market}/securities/#{security}.#{cs_extension}?#{query}"


make_image = (element, engine, market, security, options, width, height) ->
    $('<img>').attr
        src:    make_url(element, engine, market, security, options)
        width:  width
        height: height

    



class ChartWidget
    constructor: (element, @engine, @market, @param, @options = {}) ->
        @state = undefined
        
        @element = $(element)

        return unless @element
        return unless @engine
        return unless @market
        return unless @param

        @state = on
        
        @refresh_timeout = parseInt('' + options['refresh_timeout'])

        @render()
    
    render: =>
        return unless @state is on
        make_image(@element, @engine, @market, @param, @options).bind 'load', @onImageLoad

    refresh: =>
        setTimeout @render, @refresh_timeout
    
    onImageLoad: (event) =>
        @element.html(event.currentTarget)

        @element.css('height', @element.height())

        @element.trigger('render:complete')

        @refresh() if @refresh_timeout
        


chart_widget = (element, engine, market, param, options = {}) ->
    chart = new ChartWidget($(element), engine, market, param, options)


scope.chart = chart_widget
scope.chart_url = make_url