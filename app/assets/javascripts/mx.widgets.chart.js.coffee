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
    query = $.param(extend(dimensions, { template: cs_template, rnd: +new Date}))
    "#{cs_host}/cs/engines/#{engine}/markets/#{market}/securities/#{security}.#{cs_extension}?#{query}"


make_image = (element, engine, market, security, width, height) ->
    $('<img>').attr
        src:    make_url(element, engine, market, security)
        width:  width
        height: height

    



class ChartWidget
    constructor: (element, options = {}) ->
        @state = undefined
        
        @element = $(element)

        return unless @element

        @engine     = options['engine']
        @market     = options['market']
        @security   = options['security']
        
        return unless @engine
        return unless @market
        return unless @security

        @state = on
        
        @refresh_timeout = parseInt('' + options['refresh_timeout'])

        @render()
    
    render: =>
        return unless @state is on
        make_image(@element, @engine, @market, @security).bind 'load', @onImageLoad

    refresh: =>
        setTimeout @render, @refresh_timeout
    
    onImageLoad: (event) =>
        @element.html(event.currentTarget)

        @element.css('height', @element.height())

        @element.trigger('render:complete')

        @refresh() if @refresh_timeout
        


chart_widget = (element, options) ->
    chart = new ChartWidget($(element), options)


scope.chart = chart_widget
scope.chart_url = make_url