global = module?.exports ? ( exports ? this )

global.mx           ||= {}
global.mx.widgets   ||= {}

scope = global.mx.widgets

$ = jQuery


sorting_params =
    securities: 'SECID'
    sectypes:   'SECTYPE'


extract_options = (args) ->
    last = _.last(args)
    options = if _.isObject(last) and !_.isArray(last) then args.pop() else {}
    [args, options]


extract_queries_and_orders = (args...) ->

    engine  = undefined
    market  = undefined
    board   = undefined
    params  = args.pop()
    
    args_size = _.size(args)
    
    if args_size > 0 then engine  = args[0]
    if args_size > 1 then market  = args[1]
    if args_size > 2 then board   = args[2]

    orders  = []
    queries = {}
    
    queries["#{engine}:#{market}"] = [] if engine? and market?

    params = [params] unless _.isArray(params)
    
    for param in params
        parts       = param.split(":")
        parts_size  = _.size(parts)
        
        if parts_size < 2 then parts.unshift(board)
        if parts_size < 3 then parts.unshift(market)
        if parts_size < 4 then parts.unshift(engine)
        
        parts = _.compact(parts)
        
        orders.push _.rest(parts, 2).join(":")
        
        (queries[_.first(parts, 2).join(":")] ?= []).push parts.join(":")
    
    [queries, orders]


widget = (element, args...) ->
    element = $(element); return if _.size(element) == 0

    [args, options]     = extract_options(args)
    [queries, orders]   = extract_queries_and_orders(args...)
    
    console.log orders
    console.log queries
    
    undefined


_.extend scope,
    marketdata: widget
