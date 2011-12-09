global = module?.exports ? ( exports ? this )

global.mx           ||= {}
global.mx.security  ||= {}

scope = global.mx.security

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


make_last_cell = (value, column) ->
    $("<li>")
        .addClass("last")
        .attr('title', column.title)
        .html($("<span>").html(mx.utils.render(value, column) || '&mdash;'))


make_change_cell = (value, unit, column, trend) ->
    trend_field = $("<span>")
        .attr('title', column.title)
        .toggleClass('trend_up', trend > 0)
        .toggleClass('trend_down', trend < 0)
        .toggleClass('trend_none', trend == 0 || not trend)
        .html(mx.utils.render(value, column) || '&mdash;')
    
    unit_field = $("<span>")
        .html(unit || '&mdash;')
    
    $("<li>")
        .addClass("change")
        .append(trend_field)
        .append("<br />")
        .append(unit_field)

make_cell = (record, columns) ->
    cell = $("<li>")

    for column in columns
        cell.append(
            $("<span>")
                .attr('title', column.title)
                .html(mx.utils.render(record[column.name], column) || '&mdash;')
                .prepend($("<label>").html(column.short_title + ':'))
        )
        .append($("<br />"))
        
    cell

widget = (element, engine, market, board, param, options = {}) ->
    element = $(element); return if element.length == 0
    
    cache_key = mx.utils.sha1(JSON.stringify(_.rest(arguments).join("/")))
    
    read_cache(element, cache_key) if options.cache == true
    
    delay   = calculate_delay(options.refresh_timeout)
    timeout = null
    
    
    destroy = (options = {}) ->
        clearTimeout(timeout)
        element.children().remove()
        remove_cache cache_key if options.force == true
        element.trigger('destroy');


    ready = (-> $.when(mx.iss.columns(engine, market), mx.iss.filters(engine, market)))()
    

    $.when(ready).then (columns, filters) ->
    
        consistent = not _.isEmpty(columns) and (_.size(filters['widget']) > 0 || _.size(filters['digest']) > 0)

        render = (record) ->
            return destroy({ force: true }) if _.isEmpty(record)
            
            record = mx.utils.process_record(record, columns)
            
            container = make_container()
            
            if filters['widget']
                column = _.first(columns[filter.id] for filter in filters['widget'] when filter.alias == 'LAST')
                container.append make_last_cell(record[column.name], column) if column
                
                column = _.first(columns[filter.id] for filter in filters['widget'] when filter.alias == 'CHANGE')
                container.append make_change_cell(record[column.name], record['FACEUNIT'], column, record.trends[column.name]) if column
            
            filter  = filters['digest']
            count   = 2
            if filter
                for index in [0 ... _.size(filter)] by count
                    container.append make_cell record, (columns[field.id] for field in filter[index ... index + count])
                    
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
