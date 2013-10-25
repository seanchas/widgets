global = module?.exports ? ( exports ? this )

global.mx           ||= {}
global.mx.security  ||= {}

scope = global.mx.security

custom_filters =
    'stock:shares:FXRB': ['OFFER', 'BID', 'HIGH', 'LOW', 'NUMTRADES', 'VOLTODAY', 'ETFSETTLEPRICE', 'ISSUECAPITALIZATION', 'ETFSETTLECURRENCY']
    'stock:shares:FXGD': ['OFFER', 'BID', 'HIGH', 'LOW', 'NUMTRADES', 'VOLTODAY', 'ETFSETTLEPRICE', 'ISSUECAPITALIZATION', 'ETFSETTLECURRENCY']

$ = jQuery

cache       = kizzy('security.digest')
cacheable   = true

default_delay   = 60 * 1000
min_delay       =  5 * 1000



read_cache = (element, key) ->
    element.html cache.get key

write_cache = (element, key) ->
    cache.set key, element.html()

remove_cache = (key) ->
    cache.remove key



calculate_delay = (delay) ->
    delay = + delay
    delay = default_delay if _.isNaN delay
    delay = _.max [delay, min_delay] unless delay == 0



make_container = ->
    $("<ul>")
        .addClass("mx-security-digest")


make_last_cell = (record, column) ->
    column.precision ||= record.precisions?[column.name]
    $("<li>")
        .addClass("last")
        .attr('title', column.title)
        .html($("<span>").html(mx.utils.render(record[column.name], column) || '&mdash;'))


make_change_cell = (value, unit, column, trend) ->
    trend_field = $("<span>")
        .attr('title', column.title)
        .toggleClass('trend_up', trend > 0)
        .toggleClass('trend_down', trend < 0)
        .toggleClass('trend_none', trend == 0 || not trend)
        .html(mx.utils.render(value, column) || '&mdash;')
    
    if unit == 'SUR' then unit = 'RUB'
    
    unit_field = $("<span>")
        .html(unit ? '&nbsp;')
    
    $("<li>")
        .addClass("change")
        .append(trend_field)
        .append("<br />")
        .append(unit_field)

make_cell = (record, columns) ->
    cell = $("<li>")

    for column in columns
        column.precision ||= record.precisions?[column.name]
        cell.append(
            $("<span>")
                .attr('title', column.title)
                .html(mx.utils.render(record[column.name], column) || '&mdash;')
                .prepend($("<label>").html(column.short_title + ':'))
        )
        .append($("<br />"))
        
    cell


trigger_render_event = (element, status, iss, options = {}) ->
    element.trigger('render', _.extend({ iss: iss, status: status }, options))


widget = (element, engine, market, board, param, options = {}) ->
    element = $(element); return if element.length == 0
    
    cache_key = mx.utils.sha1(JSON.stringify(_.rest(arguments).join("/")) + mx.locale())
    
    read_cache(element, cache_key) if options.cache == true
    
    delay   = calculate_delay(options.refresh_timeout)
    timeout = null
    
    
    destroy = (options = {}) ->
        clearTimeout(timeout)
        element.children().remove()
        remove_cache cache_key if options.force == true
        element.trigger('destroy');


    ready =  do -> $.when(mx.iss.columns(engine, market, {force: true}), mx.iss.filters(engine, market))


    $.when(ready).then (columns, filters) ->

        consistent = not _.isEmpty(columns) and (_.size(filters['widget']) > 0 || _.size(filters['digest']) > 0)

        render = (data) ->

            record  = _.first(data)
            iss     = _.last(data)

            if _.isEmpty(record)
                trigger_render_event(element, 'failure', iss)
                return destroy({ force: true })

            record = mx.utils.process_record(record, columns)
            
            container = make_container()
            
            if filters['widget']
                column = _.first(columns[filter.id] for filter in filters['widget'] when filter.alias == 'LAST')
                container.append make_last_cell(record, column) if column
                
                column = _.first(columns[filter.id] for filter in filters['widget'] when filter.alias == 'CHANGE')
                container.append make_change_cell(record[column.name], record['CURRENCYID'], column, record.trends[column.name]) if column

            security = [engine, market, param].join(':')
            filter   = undefined
            if _.contains _.keys(custom_filters), security
                columns_names = _.intersection(custom_filters[security], _.pluck(columns, 'name'))
                filter        = _.map columns_names, (name) -> _.find(columns, (column) -> column.name is name)
            else
                filter  = filters['digest']

            count   = 2
            if filter
                for index in [0 ... _.size(filter)] by count
                    container.append make_cell record, _.compact(columns[field.id] for field in filter[index ... index + count])
                    
            trigger_render_event(element, 'success', iss)

            element.html(container)

            write_cache(element, cache_key) if options.cache == true
            
    
        refresh = ->
            mx.iss.security(engine, market, board, param, { force: true }).then render
            timeout = _.delay refresh, delay if delay > 0


        if consistent then refresh() else destroy({ force: true })


    {
        destroy: destroy
    }


_.extend scope,
    digest: widget
