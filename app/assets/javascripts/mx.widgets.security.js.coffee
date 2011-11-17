global = module?.exports ? ( exports ? this )

global.mx           ||= {}
global.mx.widgets   ||= {}

scope = global.mx.widgets

$ = jQuery


make_list = ->
    $('<ul>')
        .addClass('mx-widget-security')


make_LAST_field = (security) ->
    $('<li>')
        .addClass('last')
        .html(security['WAPRICE'])


make_field = (field, column, options = {}) ->
    view = $('<span>').html(field)
    view.prepend $('<label>').html(column.short_title).attr({ title: column.title }) if options.title
    view

make_DELTA_CURRENCY_field = (security) ->
    trend = security.trends['WAPTOPREVWAPRICEPRCNT']
    trend = if trend > 0 then 'up' else if trend < 0 then 'down' else 'equal'

    view = $('<li>').addClass('delta')
    
    view.append make_field(security['WAPTOPREVWAPRICEPRCNT']).addClass("trend_#{trend}")
    view.append $("<br>")
    view.append make_field(security['FACEUNIT'])
    
    view


make_BID_OFFER_field = (security, columns) ->
    
    bid_column = _.detect columns, (column) ->
        column.name == 'BID'
    
    offer_column = _.detect columns, (column) ->
        column.name == 'OFFER'

    view = $('<li>')
    
    view.append make_field(scope.utils.render_value(security['BID'], bid_column), bid_column, { title: true })
    view.append $("<br>")
    view.append make_field(security['OFFER'], offer_column, { title: true })
    
    view

make_HIGH_LOW_field = (security, columns) ->

    high_column = _.detect columns, (column) ->
        column.name == 'HIGH'

    low_column = _.detect columns, (column) ->
        column.name == 'LOW'

    view = $('<li>')

    view.append make_field(security['HIGH'], high_column, { title: true })
    view.append $("<br>")
    view.append make_field(security['LOW'], low_column, { title: true })

    view


make_NUMTRADES_VOLUME_field = (security, columns) ->

    numtrades_column = _.detect columns, (column) ->
        column.name == 'NUMTRADES'

    volume_column = _.detect columns, (column) ->
        column.name == 'VALTODAY'


    view = $('<li>')

    view.append make_field(security['NUMTRADES'], numtrades_column, { title: true })
    view.append $("<br>")
    view.append make_field(security['VALTODAY'], volume_column, { title: true })

    view


render = (element, security, columns) ->
    list = make_list()
    
    security = mx.utils.process_record security, columns
    
    list.append make_LAST_field security
    list.append make_DELTA_CURRENCY_field security
    list.append make_BID_OFFER_field security, columns
    list.append make_HIGH_LOW_field security, columns
    list.append make_NUMTRADES_VOLUME_field security, columns
    
    element.html list


security_widget = (element, engine, market, board, param, options = {}) ->
    element = $(element)

    return if element.length == 0
    
    cds = mx.iss.columns(engine, market)

    refresh_timeout = options.refresh_timeout || 60 * 1000

    refresh = ->
        sds = mx.iss.security(engine, market, board, param)

        $.when(cds, sds).then (columns, security) ->
            render element, security, columns
            _.delay refresh, refresh_timeout

    refresh()

_.extend scope,
    security: security_widget
