##= require jquery
##= require underscore
##= require mx.utils
##= require mx.iss
##= require kizzy

$ = jQuery

global = module?.exports ? this

global.mx       ||= {}
global.mx.iss   ||= {}

scope = global.mx.iss

cache = kizzy('iss')

names = ['filters', 'columns', 'records']

timeout = 60 * 60 * 1000


cached_method = (name) ->
    (args...) ->
        deferred = $.Deferred()
    
        options = mx.utils.extract_options args
    
        cache_key   = mx.utils.sha1(['widgets', 'table', location.path_name, JSON.stringify(_.rest arguments)].join('/'))
        cache_data  = cache.get(cache_key) unless options.force

        return deferred.resolve(cache_data).promise() if cache_data?
    
        scope["#{name}_without_cache"](args...).then (json) ->
            deferred.resolve cache.set cache_key, json, timeout
    
        deferred.promise()


for name in names
    scope["#{name}_without_cache"]  = scope[name]
    scope["#{name}_with_cache"]     = cached_method(name)
    scope["#{name}"]                = scope["#{name}_with_cache"]

