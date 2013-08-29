global = module?.exports ? ( exports ? this )

scope = global.mx.widgets
$     = jQuery

cache          = kizzy('mx.widgets.fixing')
default_filter = _.invoke(['secid', 'updatetime', 'marketpricetoday', 'marketprice2', 'decimals'], 'toUpperCase')


make_url = (key, callback) ->
    if callback and _.isFunction(callback) then callback(key.split(":")...) else "##{key}"


columns_data_source = (params) ->
    deferred = new $.Deferred

    complete = _.after _.size(params), ->
        deferred.resolve params

    _.each params, (param, key) ->
        [engine, market] = key.split(':')
        mx.iss.columns(engine, market).done (json) ->
            json = _.reduce json, (memo, column) ->
                memo[column.name] = column if _.include param.filters, column.name
                memo
            , {}
            params[key].columns = json
            complete()

    deferred


records_data_source = (params) ->
    deferred = new $.Deferred

    complete = _.after _.size(params), ->
        deferred.resolve params

    _.each params, (param, key) ->
        [engine, market, boardid] = key.split(':')

        options = {}
        options.boardid = boardid
        options.force   = true

        mx.iss.records(engine, market, param.securities, options).done (json) ->
            json = _.reduce json, (memo, record) ->
                memo[record['SECID']] = _.pick record, param.filters
                memo
            , {}
            params[key].records = json
            complete()

    deferred


create_table = (element) ->
    element.append '<table><tbody></tbody></table>'
    $('table', element).addClass('mx-widget-table')
    $('tbody', element)


render_data = (tbody_el, data, url_cb) ->
    tbody_el.empty()
    _.each data.show_order, (key, index) ->
        [engine, market, boardid, security] = key.split(':')
        tr_upd = $('<tr>').addClass('row').addClass('odd')
        tr_fix = $('<tr>').addClass('row').addClass('even')
        tr_upd.addClass('first') if index is 0
        tr_fix.addClass('last')  if index is data.show_order.length - 1

        param_key = [engine, market, boardid].join(':')
        raw       = data[param_key]
        record    = mx.utils.process_record(raw.records[security], raw.columns)

        tds = {}

        tds['UPDCOL'] = $('<td>').addClass('string').attr('title', record['SECID'])
        link_upd   = $('<a>').attr('href', make_url(key, url_cb)).html( $('<span>').html( raw.aliases[security]?['MARKETPRICETODAY'] || 'MARKETPRICETODAY' ) )
        tds['UPDCOL'].append(link_upd)

        tds['FIXCOL'] = $('<td>').addClass('string').attr('title', record['SECID'])
        link_fix   = $('<a>').attr('href', make_url(key, url_cb)).html( $('<span>').html( raw.aliases[security]?['MARKETPRICE2'] || 'MARKETPRICE2' ) )
        tds['FIXCOL'].append(link_fix)

        _.each ['UPDATETIME', 'MARKETPRICETODAY', 'MARKETPRICE2'], (column) ->
            span = $('<span>').html( mx.utils.render(record[column], { type: raw.columns[column].type, precision: record.precisions[column]}) || '&mdash;' )
            tds[column] = $('<td>').addClass(raw.columns[column].type).attr('title', raw.columns[column].title).append(span)

        tds['FIXTIME'] = $('<td>').addClass(raw.columns['UPDATETIME'].type).append($('<span>').html( '12:30' ))

        tr_upd.append(tds['UPDCOL']).append(tds['UPDATETIME']).append(tds['MARKETPRICETODAY'])
        tr_fix.append(tds['FIXCOL']).append(tds['FIXTIME']   ).append(tds['MARKETPRICE2'])

        tbody_el.append tr_upd
        tbody_el.append tr_fix


widget = (element, params, options = {}) ->
    element = $(element) ; return unless element.length > 0
    params  = if _.isArray(params) then _.compact(params) else _.compact([params])
    return unless params

    refresh_timeout = options.refresh_timeout or  60 * 1000             # 60 sec default
    cacheable       = options.cache?          and options.cache is true # use cache or not
    url_cb          = options.url

    cache_key = mx.utils.sha1(mx.locale()) if cacheable

    element.addClass('mx-widget-fixing')

    data = {}
    data.show_order = []

    for param, index in params

        [key, aliases] = if _.isObject(param) then [_.first(_.keys(param)), _.first(_.values(param))] else [param, null]

        [engine, market, boardid, security] = key.split(':')

        param_key = [engine, market, boardid].join(':')

        data[param_key] ||=
            securities: []
            filters:    []
            aliases:    {}
            columns:    {}
            records:    {}

        data[param_key].securities.push security
        data[param_key].aliases[security] = aliases
        data[param_key].filters = if aliases then _.uniq _.union(_.keys(aliases), default_filter) else default_filter
        data.show_order.push key

    table = create_table(element)
    render_data(table, cache.get(cache_key)) if cacheable and _.isObject(cache.get(cache_key))


    $.when(columns_data_source(data)).then ->
        refresh = () ->
            $.when(records_data_source(data)).then ->
                cache.set(cache_key, data) if cacheable

                render_data(table, data, url_cb)

            _.delay refresh, refresh_timeout

        refresh()


_.extend scope,
    fixing: widget