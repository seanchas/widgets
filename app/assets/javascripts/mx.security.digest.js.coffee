global = module?.exports ? ( exports ? this )

global.mx           ||= {}
global.mx.security  ||= {}

scope = global.mx.security

$ = jQuery

cache = kizzy('security.digest')

filter = 'status'


make_container = ->
    $('<ul>')
        .addClass('mx-security-digest')

make_field = (value, column, options = {}) ->
    field = $('<span>').html(mx.utils.render(value, column))

    field.prepend $('<label>').html(column.short_title).attr({ title: column.title }) if options.title

    field

make_trend_field = (value, column, options = {}) ->
    field = make_field(arguments...)

    field.toggleClass('trend_up',       options.trend >  0)
    field.toggleClass('trend_down',     options.trend <  0)
    field.toggleClass('trend_equal',    options.trend == 0)

    field


render = (element, security, columns, filters) ->
    container = make_container()
    
    security = mx.utils.process_record security, columns

    container.append $("<li>").addClass('last').html(make_field(security[filters[0].name], columns[filters[0].id]))

    container.append $("<li>")
        .append(make_trend_field(security[filters[1].name], columns[filters[1].id], { trend: security.trends[filters[1].name] }))
        .append($("<br />"))
        .append(make_field(security['FACEUNIT']))
    
    for index in [2...filters.length] by 2
        container.append $("<li>")
            .append(make_field(security[filters[index + 0].name], columns[filters[index + 0].id], { title: true }))
            .append($("<br />"))
            .append(make_field(security[filters[index + 1].name], columns[filters[index + 1].id], { title: true }))
    
    element.html container


widget = (element, engine, market, board, param, options = {}) ->
    element = $(element); return if element.length == 0
    
    cache_key = mx.utils.sha1(JSON.stringify(_.rest(arguments).join("/")))
    
    element.html cache.get(cache_key) if options.cache
    
    cds = mx.iss.columns(engine, market)
    fds = mx.iss.filters(engine, market)

    refresh_timeout = options.refresh_timeout || 60 * 1000
    
    timeout = null

    refresh = ->
        sds = mx.iss.security(engine, market, board, param)

        $.when(cds, fds, sds).then (columns, filters, security) ->
            if security? and columns and filters and filters[filter]
                render element, security, columns, filters[filter] 
                cache.set cache_key, element.html() if options.cache
                
                element.trigger('render:success')
            else
                element.trigger('render:failure')
            

            timeout = _.delay refresh, refresh_timeout

    refresh()
    
    {
        destroy: ->
            clearTimeout timeout
            element.children().remove()
    }


_.extend scope,
    digest: widget
