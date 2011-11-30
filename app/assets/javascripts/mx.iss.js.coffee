##= require jquery
##= require underscore

global = module?.exports ? ( exports ? this )

global.mx       ||= {}
global.mx.iss   ||= {}

$ = jQuery

scope = global.mx.iss

iss_host = "http://www.beta.micex.ru/iss"

cache = {}

request_meta =
    filters:
        url: (engine, market) ->
            "#{iss_host}/engines/#{engine}/markets/#{market}/securities/columns/filters.jsonp?callback=?"
        data: ->
            'iss.meta': 'off'
            'iss.only': 'filters'
        parse: (json) ->
            iss_prepare_filters(iss_merge_columns_and_data(json?.filters))
        key: (engine, market) ->
            [engine, market]

    columns:
        url: (engine, market) ->
            "#{iss_host}/engines/#{engine}/markets/#{market}/securities/columns.jsonp?callback=?"
        data: (engine, market, options = {}) ->
            'iss.meta': 'off'
            'iss.only': options.only || 'securities,marketdata'
        parse: (json) ->
            iss_prepare_columns(iss_merge_columns_and_data(json?.securities), iss_merge_columns_and_data(json?.marketdata))
        key: (engine, market, options = {}) ->
            [engine, market, options.only]

    security:
        url: (engine, market, board, param) ->
            "#{iss_host}/engines/#{engine}/markets/#{market}/boards/#{board}/securities/#{param}.jsonp?callback=?"
        data: (engine, market, board, param, options = {}) ->
            'iss.meta': 'off'
            'iss.only': options.only || 'securities,marketdata'
        parse: (json) ->
            _.first(iss_prepare_records(iss_merge_columns_and_data(json?.securities), iss_merge_columns_and_data(json?.marketdata)))
        key: (engine, market, board, param, options = {}) ->
            [engine, market, board, param, options.only]
    
    description:
        url: (param) ->
            "#{iss_host}/securities/#{param}.jsonp?callback=?"
        data: ->
            'iss.meta': 'off'
            'iss.only': 'description'
        parse: (json) ->
            iss_merge_columns_and_data(json?.description)
        key: (param) ->
            [param]
    
    orderbook:
        url: (engine, market, board, param) ->
            "#{iss_host}/engines/#{engine}/markets/#{market}/boards/#{board}/securities/#{param}/orderbook.jsonp?callback=?"
        data: ->
            'iss.meta': 'off'
            'iss.only': 'orderbook'
        parse: (json) ->
            iss_merge_columns_and_data(json?.orderbook)
        key: (engine, market, board, param) ->
            [engine, market, board, param]


request = (name, args...) ->
    meta    = request_meta[name]
    key     = mx.utils.sha1 JSON.stringify [name, meta.key(args...)]
    options = mx.utils.extract_options(args)

    if cache[key]?
        return cache[key].promise() if cache[key].state() == 'pending'
        return cache[key].promise() unless options.force == true
    
    cache[key] = new $.Deferred
    
    $.ajax
        url: meta.url(args...)
        data: meta.data(args...)
        dataType: 'jsonp'
    .then (json) ->
        cache[key].resolve meta.parse(json)
    
    cache[key].promise()


iss_merge_columns_and_data = (json) ->
    return [] unless json?.data and json?.columns
    _.map json.data, (record, index) ->
     _.reduce record, (memo, value, index) ->
         memo[json.columns[index]] = value
         memo
     , {}


iss_prepare_filters = (data) ->
    _.reduce data, (memo, record) ->
        (memo[record.filter_name] ||= []).push({ id: record.id, name: record.name }); memo
    , {}

iss_prepare_columns = (securities, marketdata) ->
    securities = _.reduce securities, ( (memo, record) -> memo[record.id] = record; memo ), {}
    marketdata = _.reduce marketdata, ( (memo, record) -> memo[record.id] = record; memo ), {}
    _.extend securities, marketdata

iss_prepare_records = (securities, marketdata) ->
    securities = _.reduce securities, ( (memo, record) -> memo[record.BOARDID + '/' + record.SECID] = record; memo ), {}
    marketdata = _.reduce marketdata, ( (memo, record) -> memo[record.BOARDID + '/' + record.SECID] = record; memo ), {}
    _.reduce _.keys(securities), (memo, key) ->
        memo.push _.extend(securities[key], marketdata[key]); memo
    , []



records = (engine, market, params, options = {}) ->
    deferred = $.Deferred();

    known_keys = ['nearest', 'leaders']

    params_name = options.params_name || 'securities'

    data =
        'iss.meta': 'off'
        'iss.only': 'securities,marketdata'

    data[params_name] = if _.isArray params then params.join(',') else params
    
    options = _.reduce options, (memo, value, key) ->
        memo[key] = value if _.include known_keys, key
        return memo
    , {}
    
    _.extend data, options
    
    $.ajax
        url: "#{iss_host}/engines/#{engine}/markets/#{market}/securities.jsonp?callback=?"
        data: data
        dataType: 'jsonp'
        scriptCharset: 'utf-8'
    .then (json) ->
        deferred.resolve iss_prepare_records(iss_merge_columns_and_data(json?.securities), iss_merge_columns_and_data(json?.marketdata))
    
    deferred.promise()


boards = (param) ->
    deferred = $.Deferred()

    data = 
        'iss.meta': 'off'
        'iss.only': 'boards'

    $.ajax
        url: "#{iss_host}/securities/#{param}.jsonp?callback=?"
        data: data
        dataType: 'jsonp'
        scriptCharset: 'utf-8'
    .then (json) ->
        deferred.resolve iss_merge_columns_and_data(json?.boards)

    deferred.promise()


emitter = (param) ->
    deferred = $.Deferred()
    
    data =
        'iss.meta': 'off'
        'iss.only': 'emitter'
    
    $.ajax
        url: "#{iss_host}/emitters/#{param}.jsonp?callback=?"
        data: data
        dataType: 'jsonp'
        scriptCharset: 'utf-8'
    .then (json) ->
        deferred.resolve _.first(iss_merge_columns_and_data(json?.emitter))
    
    deferred.promise()


emitter_securities = (param) ->
    deferred = $.Deferred()
    
    data =
        'iss.meta': 'off'
        'iss.only': 'securities'
    
    $.ajax
        url: "#{iss_host}/emitters/#{param}/securities.jsonp?callback=?"
        data: data
        dataType: 'jsonp'
        scriptCharset: 'utf-8'
    .then (json) ->
        deferred.resolve iss_merge_columns_and_data(json?.securities)
    
    deferred.promise()


turnovers = ->
    deferred = new $.Deferred
    
    data =
        'iss.meta': 'off'
        'iss.only': 'turnovers'
    
    $.ajax
        url: "#{iss_host}/turnovers.jsonp?callback=?"
        data: data
        dataType: 'jsonp'
        scriptCharset: 'utf-8'
    .then (json) ->
        deferred.resolve iss_merge_columns_and_data(json?.turnovers)
    
    deferred.promise()

candle_borders = (engine, market, param) ->
    deferred = new $.Deferred
    
    data =
        'iss.meta': 'off'
        'iss.only': 'borders'
    
    $.ajax
        url: "#{iss_host}/engines/#{engine}/markets/#{market}/securities/#{param}/candleborders.jsonp?callback=?"
        data: data
        dataType: 'jsonp'
        scriptCharset: 'utf-8'
    .then (json) ->
        deferred.resolve iss_merge_columns_and_data(json?.borders)

    deferred.promise()


_.extend scope,
    columns:            (args...) -> request('columns', args...)
    records:            records
    security:           (args...) -> request('security', args...)
    orderbook:          (args...) -> request('orderbook', args...)
    description:        (args...) -> request('description', args...)
    boards:             boards
    emitter:            emitter
    emitter_securities: emitter_securities
    turnovers:          turnovers
    candle_borders:     candle_borders
    filters:            (args...) -> request('filters', args...)
