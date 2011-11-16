##= require jquery
##= require underscore

global = module?.exports ? ( exports ? this )

global.mx       ||= {}
global.mx.iss   ||= {}


$ = jQuery


scope = global.mx.iss

iss_host = "http://www.beta.micex.ru/iss"


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



cache_key = (args...) ->
    args.join('/')


filters = (engine, market) ->
    deferred = $.Deferred();
    
    $.ajax
        url: "#{iss_host}/engines/#{engine}/markets/#{market}/securities/columns/filters.jsonp?callback=?"
        data:
            'iss.meta': 'off'
            'iss.only': 'filters'
        dataType: 'jsonp'
    .then (json) ->
        deferred.resolve iss_prepare_filters(iss_merge_columns_and_data(json?.filters))
    
    deferred.promise()


columns = (engine, market, options = {}) ->
    deferred = $.Deferred();

    $.ajax
        url: "#{iss_host}/engines/#{engine}/markets/#{market}/securities/columns.jsonp?callback=?"
        data:
            'iss.meta': 'off'
            'iss.only': options.only || 'securities,marketdata'
        dataType: 'jsonp'
    .then (json) ->
        deferred.resolve iss_prepare_columns(iss_merge_columns_and_data(json?.securities), iss_merge_columns_and_data(json?.marketdata))
    
    deferred.promise()


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
    .then (json) ->
        deferred.resolve iss_prepare_records(iss_merge_columns_and_data(json?.securities), iss_merge_columns_and_data(json?.marketdata))
    
    deferred.promise()


orderbook = (engine, market, board, param) ->
    deferred = $.Deferred()
    
    data =
        'iss.meta': 'off'
        'iss.only': 'orderbook'
    
    $.ajax
        url: "#{iss_host}/engines/#{engine}/markets/#{market}/boards/#{board}/securities/#{param}/orderbook.jsonp?callback=?"
        data: data
        dataType: 'jsonp'
    .then (json) ->
        deferred.resolve iss_merge_columns_and_data(json?.orderbook)
    
    deferred.promise()

security = (engine, market, board, param, options = {}) ->
    deferred = $.Deferred()
    
    data = 
        'iss.meta': 'off'
        'iss.only': options.only || 'securities,marketdata'

    $.ajax
        url: "#{iss_host}/engines/#{engine}/markets/#{market}/boards/#{board}/securities/#{param}.jsonp?callback=?"
        data: data
        dataType: 'jsonp'
    .then (json) ->
        deferred.resolve _.first(iss_prepare_records(iss_merge_columns_and_data(json?.securities), iss_merge_columns_and_data(json?.marketdata)))
    
    deferred.promise()


description = (param) ->
    deferred = $.Deferred()
    
    data = 
        'iss.meta': 'off'
        'iss.only': 'description'
    
    $.ajax
        url: "#{iss_host}/securities/#{param}.jsonp?callback=?"
        data: data
        dataType: 'jsonp'
    .then (json) ->
        deferred.resolve iss_merge_columns_and_data(json?.description)
    
    deferred.promise()


_.extend scope,
    filters:        filters
    columns:        columns
    records:        records
    security:       security
    orderbook:      orderbook
    description:    description