global = module?.exports ? ( exports ? this )

global.mx           ||= {}
global.mx.widgets   ||= {}

scope = global.mx.widgets

$ = jQuery

cache = kizzy('mx.widgets.rms')

localization =
    ru:
        n:              '№'
        'SECID':        'Код цб'
        'NAME':         'Наименование цб'
        'ISIN':         'ISIN'
        'DISCOUNT_MIN': ['Ставка 1*', 'Ставка 2*', 'Ставка 3*']
        'LIMIT':        ['', 'Лимит 1** (тыс. руб.)', 'Лимит 2** (тыс. руб.)']
        'REGISTRY_CLOSE_DATE': 'Дата закрытия реестра'
    en:
        n:              'N'
        'SECID':        'SecID'
        'NAME':         'Security name'
        'ISIN':         'ISIN'
        'DISCOUNT_MIN': ['Discount 1*', 'Discount 2*', 'Discount 3*']
        'LIMIT':        ['', 'Limit 1**', 'Limit 2**']
        'REGISTRY_CLOSE_DATE': 'Registry close date'



single_keys       = ['SECID', 'SHORTNAME', 'NAME', 'ISIN', 'TRADEDATE', 'TRADETIME', 'precisions', 'trends', 'REGISTRY_CLOSE_DATE']
table_columns     = [
    'n'
    'SECID'
    'NAME'
    'ISIN'
    ['DISCOUNT_MIN', 0]
    ['LIMIT',        1]
    ['DISCOUNT_MIN', 1]
    ['LIMIT',        2]
    ['DISCOUNT_MIN', 2]
    'REGISTRY_CLOSE_DATE'
]


collect_records = (engine, market, object) ->
    deferred    = new $.Deferred()
    records     = []
    get_records = (index) ->
        $.when(mx.iss.rms_securities engine, market, object, {from: 'today', with_description: 1, start: index }).then (data) ->
            unless _.size(data) > 0
                deferred.resolve(records)
                return

            records.push data.records...

            index    = data.cursor['INDEX'] + data.cursor['PAGESIZE']
            total    = data.cursor['TOTAL']

            if index < total then get_records(index) else deferred.resolve(records)

    get_records(0)
    deferred.promise()


process_records = (records, columns) ->
    records = _.map     records, (record) -> mx.utils.process_record(record, columns)
    records = _.sortBy  records, (record) -> record['LIMIT']
    records = _.groupBy records, (record) -> record['SECID']

    _.each records, (group, sec) ->
        records[sec] = _.reduce group, (memo, record, index) ->
            _.each record, (value, key) ->
                if index is 0
                    memo[key] = if _.include(single_keys, key) then record[key] else [record[key]]
                else
                    memo[key].push(record[key]) unless _.include(single_keys, key)
            return memo
        , {}

    records = _.sortBy records, (record) -> _.max(record?['LIMIT'])
    records.reverse()


process_columns = (columns) ->
    columns = _.reduce columns, (memo, column) ->
        memo[column.name] = column
        memo
    , {}
    columns


widget = (element, engine, market, options = {}) ->
    element = $(element) ; return unless _.size(element) > 0

    element.addClass 'mx-widget-rms'
    l10n   = localization[mx.locale()]
    object = "extendedparams"

    cacheable = !!options.cache

    cache_key = mx.utils.sha1([engine, market, object, mx.locale()].join('/'))

    element.html(cache.get(cache_key)) if cacheable and cache.get(cache_key)

    render = (records, columns) ->
        table = $('<table>').addClass('mx-widget-table')
        thead = $('<thead>')
        tbody = $('<tbody>')

        tr = $('<tr>')

        for column in table_columns
            is_arr     = _.isArray(column)
            [key, pos] = if is_arr then [_.first(column), _.last(column)] else [column, 0]
            desc       = if is_arr then l10n[key]?[pos] else l10n[key]
            td = $('<td>')
                .addClass(columns[key]?.type || 'number')
                .addClass('nowrap')
                .html(desc)
            tr.append td

        thead.append tr

        for record, index in records

            tr = $('<tr>')
            tr.addClass('row')
            tr.addClass(['odd', 'even'][index%2])
            tr.addClass('first') if index is 0
            tr.addClass('last')  if index is records.length - 1

            for column in table_columns
                td = $('<td>')
                is_arr = _.isArray(column)
                [key, pos] = if is_arr then [_.first(column), _.last(column)] else [column, 0]
                if key is 'n'
                    td.addClass('number').html(index + 1)
                else
                    td.addClass(columns[key]?.type)
                    value = if is_arr then record[key]?[pos] else record[key]
                    descriptor = _.extend columns[key] || {}, { precision: record?.precisions?[key]}
                    td.html(mx.utils.render(value, descriptor))

                tr.append td

            tbody.append tr


        table.append thead
        table.append tbody

        element.empty()
        element.append(table)


    $.when(mx.iss.rms_columns(engine, market, object)).then (columns) ->

        $.when(collect_records(engine, market, object)).then (records) ->
            records = process_records(records, columns)
            columns = process_columns(columns)

            render(records, columns)
            cache.set(cache_key, element.html()) if cacheable


    destroy = (options = {}) ->
        element.empty()                                 # remove from DOM
        remove_cache cache_key if options.force == true # remove cache if forced
        element.trigger('destroy');                     # sent 'destroy' event to widget's container


    {
    destroy: destroy
    }



_.extend scope,
    rms: widget