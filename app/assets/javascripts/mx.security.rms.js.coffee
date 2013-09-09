global = module?.exports ? ( exports ? this )

global.mx           ||= {}
global.mx.security  ||= {}

scope = global.mx.security

localization =
    ru:
        discounts: 'Ставки рыночного риска'
        rcs:       'Границы ценового коридора'
        rts:       'Границы диапазона оценки рыночных рисков'


settings =
    filter:  ['p', 'discount', 'rch', 'rcl', 'rth', 'rtl']
    objects: ['marketrates', 'dynamicrates']


columns_data_source = (engine, market, objects) ->
    deferred = new $.Deferred()
    columns  = []

    resolve = _.after objects.length, () ->
        columns = _.reduce _.flatten(columns), (memo, column) ->
            memo[column.name] = column
            memo
        , {}
        deferred.resolve columns

    _.each objects, (object) ->
        $.when(mx.iss.rms_columns(engine, market, object)).then (data) ->
            columns.push(data)
            resolve()

    deferred.promise()


records_data_source = (engine, market, objects, security, options = {}) ->
    deferred = new $.Deferred()
    records  = []

    resolve = _.after objects.length, () -> deferred.resolve _.flatten records

    _.each objects, (object) ->
        $.when(mx.iss.rms_security(engine, market, object, security, options)).then (data) ->
            records.push data
            resolve()

    deferred.promise()


prepare_records = (columns, records, filter) ->

    records = _.reduce columns, (memo, column) ->
        if _.include filter, column.name
            _.each records, (record) ->
                memo[column.name] ||= []
                memo[column.name].push record[column.name] if record[column.name]?
        memo
    , {}

    _.each filter, (f) ->
        records[f] = switch records[f]?.length
            when 1 then _.first records[f]
            when 0 then null
            else records[f]

    records

widget = (element, engine, market, boardid, security, options = {}) ->

    options.refresh_timeout ||= 60 * 1000

    objects = settings.objects
    filter  = settings.filter

    cds = () -> columns_data_source(engine, market, objects)
    rds = () -> records_data_source(engine, market, objects, security, { from: 'today'} )

    timeout = undefined

    $.when(cds()).then (columns) ->

        refresh = () ->
            $.when(rds()).then (records) ->
                records = prepare_records columns, records, filter
                console.log columns, records
                timeout = setInterval refresh, options.refresh_timeout

        refresh()




    destroy = (options = {}) ->
        clearTimeout(timeout)                           # clear refresh timer
        element.children().remove()                     # remove from DOM
        remove_cache cache_key if options.force == true # remove cache if forced
        element.trigger('destroy');                     # sent 'destroy' event to widget's container


    {
        destroy: destroy
    }

_.extend scope,
    rms: widget