global = module?.exports ? ( exports ? this )

global.mx           ?= {}
global.mx._widget   ?= {}

scope = global.mx._widget

$ = jQuery


area_series_options =
    data: []

line_series_options =
    data: []


widget = (element, args...) ->
    element = $(element); return unless _.size(element) > 0
    
    # [args, options] = extract_options args
    
    console.log args


_.extend scope,
    chart: widget
