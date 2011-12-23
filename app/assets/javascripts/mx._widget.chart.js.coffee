global = module?.exports ? ( exports ? this )

global.mx           ?= {}
global.mx._widget   ?= {}

scope = global.mx._widget

$ = jQuery


extract_options = (args) ->
    [
        args
        if _.isObject(_.last(args)) and !_.isArray(_.last(args)) then args.pop() else {}
    ]


area_series_options =
    data: []


line_series_options =
    data: []


widget = (element, args...) ->
    element = $(element); return unless _.size(element) > 0
    
    [args, options] = extract_options args
    
    mx.iss.defaults().then (json) ->
        $.noop()


_.extend scope,
    chart: widget
