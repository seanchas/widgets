global = module?.exports ? ( exports ? this )

global.mx           ||= {}
global.mx.security  ||= {}

scope = global.mx.security

$ = jQuery


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
    
    cds = mx.iss.columns(engine, market)
    fds = mx.iss.filters(engine, market)

    refresh_timeout = options.refresh_timeout || 60 * 1000

    refresh = ->
        sds = mx.iss.security(engine, market, board, param)

        $.when(cds, fds, sds).then (columns, filters, security) ->
            render element, security, columns, filters['status']
            _.delay refresh, refresh_timeout

    refresh()
    
    {}



_.extend scope,
    digest: widget
