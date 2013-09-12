global = module?.exports ? ( exports ? this )

global.mx           ||= {}
global.mx.security  ||= {}

scope = global.mx.security

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
    filter:  ['p', 'discount', 'rch', 'rcl', 'rth', 'rtl']
    objects: ['marketrates', 'dynamicrates']


structure = [
    # title, value, index
    [ "p", "p" ]
    [ "discount" ]
    [ "discount_l1", "discount", 0]
    [ "discount_l2", "discount", 1]
    [ "discount_l3", "discount", 2]
    [ "rcs" ]
    [ "rch", "rch", 0 ]
    [ "rcl", "rcl", 0 ]
    [ "rts" ]
    [ "rth_l1", "rth", 0 ]
    [ "rth_l2", "rth", 1 ]
    [ "rth_l3", "rth", 2 ]
    [ "rtl_l1", "rtl", 0 ]
    [ "rtl_l2", "rtl", 1 ]
    [ "rtl_l3", "rtl", 2 ]
]


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

    element = $(element) ; return unless _.size(element) > 0

    l10n = localization[mx.locale()]

    options.refresh_timeout ||= 60 * 1000

    objects = settings.objects
    filter  = settings.filter

    cds = () -> columns_data_source(engine, market, objects)
    rds = () -> records_data_source(engine, market, objects, security, { from: 'today'} )

    timeout = undefined

    render = (columns, records) ->

        table = $('<table>').addClass('mx-security-rms')
        tbody = $('<tbody>')

        console.log columns['rch']

        for row in structure
            tr = $('<tr>')
            switch _.size(row)
                when 1
                    tr.append $('<th>').attr('colspan', 2).html( l10n[row[0]] || columns[row[0]]?.title || '&mdash;' )
                when 2
                    tr.append $('<td>').html( l10n[row[0]] || columns[row[0]]?.short_title || '&mdash;' )
                    tr.append $('<td>').html( mx.utils.render(records[row[1]], columns[row[1]]) || '&mdash;' )
                when 3
                    tr.append $('<td>').html( l10n[row[0]] || columns[row[0]]?.short_title || '&mdash;' )
                    tr.append $('<td>').html( mx.utils.render(records[row[1]][row[2]], columns[row[1]]) || '&mdash;' )

            tbody.append tr

        table.append tbody
        element.html(table)

    $.when(cds()).then (columns) ->

        refresh = () ->
            $.when(rds()).then (records) ->
                records = prepare_records columns, records, filter
                render columns, records
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