global = module?.exports ? ( exports ? this )

global.mx           ||= {}
global.mx.security  ||= {}

scope = global.mx.security

cache = kizzy('mx.security.rms')

localization =
    ru:
        p:           'Расчетная цена, руб.'
        discount:    'Ставки рыночного риска'
        discount_l1: 'Первого уровня (S_1)'
        discount_l2: 'Второго уровня (S_2)'
        discount_l3: 'Третьего уровня (S_3)'
        rcs:         'Границы ценового коридора'
        rch:         'Верхняя граница (RcH)'
        rcl:         'Нижняя граница (RcL)'
        rts:         'Границы диапазона оценки рыночных рисков'
        rth_l1:      'Верхняя 1-го уровня (PtH_1)'
        rth_l2:      'Верхняя 2-го уровня (PtH_2)'
        rth_l3:      'Верхняя 3-го уровня (PtH_3)'
        rtl_l1:      'Нижняя 1-го уровня (PtL_1)'
        rtl_l2:      'Нижняя 2-го уровня (PtL_2)'
        rtl_l3:      'Нижняя 3-го уровня (PtL_3)'

settings =
    filter:  ['SECID', 'TRADEDATE', 'TRADETIME', 'P', 'DISCOUNT', 'RCH', 'RCL', 'RTH', 'RTL']
    single:  ['SECID', 'TRADEDATE', 'TRADETIME', 'P', 'RCH', 'RCL']
    objects: ['marketrates', 'dynamicrates']

structure = [
    # title, value, index
    [ "p", "P" ]
    [ "discount" ]
    [ "discount_l1", "DISCOUNT", 0]
    [ "discount_l2", "DISCOUNT", 1]
    [ "discount_l3", "DISCOUNT", 2]
    [ "rcs" ]
    [ "rch", "RCH"]
    [ "rcl", "RCL"]
    [ "rts" ]
    [ "rth_l1", "RTH", 0 ]
    [ "rth_l2", "RTH", 1 ]
    [ "rth_l3", "RTH", 2 ]
    [ "rtl_l1", "RTL", 0 ]
    [ "rtl_l2", "RTL", 1 ]
    [ "rtl_l3", "RTL", 2 ]
]

single_keys = settings.single


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


process_records = (columns, records, filter) ->
    records    = _.map records, (record) -> _.pick record, filter
    records    = _.map records, (record) -> mx.utils.process_record(record, columns)

    precisions = {}
    trends     = {}

    records = _.map records, (record) ->
        precisions = _.extend precisions, record.precisions
        trends     = _.extend trends,     record.trends
        _.omit record, 'precisions', 'trends'

    records = _.reduce records, (memo, record) ->
        _.each record, (value, key) ->
            if _.include(single_keys, key)
                memo[key] ||= record[key]
            else
                memo[key] ||= []
                memo[key].push record[key]
        memo
    , {}

    records = _.extend records,
        precisions: precisions
        trends:     trends

    records


process_columns = (columns, filter) ->
    columns = _.reduce columns, (memo, column) ->
        memo[column.name] = column if _.include filter, column.name
        memo
    , {}
    columns


widget = (element, engine, market, boardid, security, options = {}) ->

    element = $(element) ; return unless _.size(element) > 0

    l10n = localization[mx.locale()]

    refresh_timeout =   options.refresh_timeout || 60 * 1000
    cacheable       = !!options.cache

    cache_key = mx.utils.sha1 [engine, market, security, mx.locale()].join('/')
    element.html(cache.get(cache_key)) if cacheable and cache.get(cache_key)

    objects = settings.objects
    filter  = settings.filter

    cds = () -> columns_data_source(engine, market, objects)
    rds = () -> records_data_source(engine, market, objects, security, { from: 'today'} )

    timeout = undefined

    render = (columns, records) ->

        table = $('<table>').addClass('mx-security-rms')
        tbody = $('<tbody>')

        for row in structure
            tr = $('<tr>')
            row_size =  _.size(row)
            if row_size is 1
                tr.append $('<th>').attr('colspan', 2).html( l10n[row[0]] || columns[row[0]]?.title || '&mdash;' )
            else
                descriptor =
                    precisions: records?.precisions?[row[1]]
                    trends:     records?.trends?[row[1]]

                descriptor = _.extend columns[row[1]] || {}, descriptor

                title = l10n[row[0]] || columns[row[0]]?.short_title || '&mdash'
                value = if row_size is 2 then records[row[1]] else records[row[1]]?[row[2]]

                tr.append $('<td>').html( title )
                tr.append $('<td>').html( mx.utils.render(value, descriptor) )

            tbody.append tr

        table.append tbody
        element.html(table)

    $.when(cds()).then (columns) ->
        columns = process_columns(columns, filter)

        refresh = () ->
            $.when(rds()).then (records) ->
                records = process_records(columns, records, filter)
                render columns, records
                cache.set(cache_key, element.html()) if cacheable
                timeout = setTimeout refresh, refresh_timeout

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