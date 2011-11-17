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


make_DELTA_CURRENCY_field = (security) ->
    trend = security.trends['WAPTOPREVWAPRICEPRCNT']

    trend = if trend > 0
        'up'
    else if trend < 0
        'down'
    else
        'equal'

    $('<li>')
        .addClass('delta')
        .html("<span class=\"delta #{trend}\">#{security['WAPTOPREVWAPRICEPRCNT']}</span><br /><span class=\"currency\">#{security['FACEUNIT']}</span>")


make_BID_OFFER_field = (security, columns) ->
    
    bid_column = _.detect columns, (column) ->
        column.name == 'BID'
    
    offer_column = _.detect columns, (column) ->
        column.name == 'OFFER'


    $('<li>')
        .html("<span><span class=\"title\">#{bid_column.short_title}</span> #{security['BID']}</span><br /><span><span class=\"title\">#{offer_column.short_title}</span> #{security['OFFER']}</span>")


make_HIGH_LOW_field = (security, columns) ->

    high_column = _.detect columns, (column) ->
        column.name == 'HIGH'

    low_column = _.detect columns, (column) ->
        column.name == 'LOW'


    $('<li>')
        .html("<span><span class=\"title\">#{high_column.short_title}</span> #{security['HIGH']}</span><br /><span><span class=\"title\">#{low_column.short_title}</span> #{security['LOW']}</span>")


make_NUMTRADES_VOLUME_field = (security, columns) ->

    numtrades_column = _.detect columns, (column) ->
        column.name == 'NUMTRADES'

    volume_column = _.detect columns, (column) ->
        column.name == 'VALTODAY'


    $('<li>')
        .html("<span><span class=\"title\">#{numtrades_column.short_title}</span> #{security['NUMTRADES']}</span><br /><span><span class=\"title\">#{volume_column.short_title}</span> #{security['VALTODAY']}</span>")


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
        $.when(sds, cds).then (security, columns) ->
            render element, security, columns
            _.delay refresh, refresh_timeout

    refresh()

_.extend scope,
    security: security_widget
