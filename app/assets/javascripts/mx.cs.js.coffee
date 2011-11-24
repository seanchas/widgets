global = module?.exports ? ( exports ? this )

global.mx       ||= {}
global.mx.cs   ||= {}

scope = global.mx.cs

cs_host = "http://www.beta.micex.ru/cs"

$ = jQuery


data = (engine, market, param, options = {}) ->
    deferred = new $.Deferred
    
    $.ajax
        url: "#{cs_host}/engines/#{engine}/markets/#{market}/securities/#{param}.json?callback=?"
        data: options
        dataType: 'jsonp'
    .then (json) ->
        deferred.resolve json
    
    deferred.promise()


_.extend scope,
    data:            data
