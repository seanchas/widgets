global = module?.exports ? ( exports ? this )

global.mx           ||= {}
global.mx.widgets   ||= {}

scope = global.mx.widgets

$ = jQuery


widget = (element, params, options = {}) ->
    element = $(element) ; return unless _.size(element)

    element.html( $("<div>").addClass("mx-widget-ticker") )

    frame  = $(".mx-widget-ticker", element)
    screen = $("<ul>")

    pending_data = []

    queries = _.reduce params, (memo, param) ->
        parts = param.split(":")
        (memo[_.first(parts, 2).join(":")] ?= []).push _.last(parts, 2).join(":")
        memo
    , {}

    fetch = ->
        deferred = new $.Deferred

        records = []

        complete = _.after _.size(queries), ->
            deferred.resolve _.sortBy records, (record) ->
                _.indexOf params, [record['ENGINE'], record['MARKET'], record['BOARDID'], record['SECID']].join(":")

        _.each queries, (params, key) ->
            [engine, market] = key.split(":")
            mx.iss.records(engine, market, params, { force: true }).then (json) ->
                for record in json
                    record['ENGINE'] = engine
                    record['MARKET'] = market
                records.push json...
                complete()

        deferred.promise()


    fetch_filters = ->
        deferred = new $.Deferred

        filters = {}

        complete = _.after _.size(queries), ->
            deferred.resolve filters

        _.each queries, (params, key) ->
            mx.iss.filters(key.split(":")...).then (json) ->
                filters[key] = json
                complete()

        deferred.promise()


    fetch_columns = ->
        deferred = new $.Deferred

        columns = {}

        complete = _.after _.size(queries), ->
            deferred.resolve columns

        _.each queries, (params, key) ->
            mx.iss.columns(key.split(":")...).then (json) ->
                columns[key] = json
                complete()

        deferred.promise()

    $.when(fetch_filters(), fetch_columns()).then (filters, columns) ->

        for id, filter of filters
            filter = _.reduce filter.widget, (memo, field) ->
                memo[field.alias] = field
                memo
                , {}
            filters[id] = filter

        render = (records) ->
            return if _.size(records) == 0

            screens = $("ul", element)

            for record in records

                key = "#{record['ENGINE']}:#{record['MARKET']}"

                _filters = filters[key]
                _columns = columns[key]

                record = mx.utils.process_record record, _columns

                tick = $(".tick:last", element)

                record_key = "#{record['BOARDID']}:#{record['SECID']}"

                views = $("li[data-key=#{escape_selector record_key}]", element)

                if _.size(views) == 0
                    for screen in screens
                        $(screen).append $("<li>").addClass('tick').attr({ 'data-key': record_key })


                views = $("li[data-key=#{escape_selector record_key}]", element)

                for name in ['SHORTNAME', 'LAST', 'CHANGE']
                    fields = $("span.#{name.toLowerCase()}", views)

                    if _.size(fields) == 0
                        for view in views
                            $(view).append $("<span>").addClass(name.toLowerCase())

                    fields = $("span.#{name.toLowerCase()}", views)

                    fields.html(mx.utils.render(record[_filters[name].name], _columns[_filters[name].id]) ? '&mdash;')

                if trend = record.trends[_filters['CHANGE'].name]
                    cell = $("span.change", views)
                    cell.toggleClass('trend_up',    trend > 0)
                    cell.toggleClass('trend_down',  trend < 0)

                if url_constructor
                    cell= $("span.shortname", views)
                    cell.html($("<a>").attr({ href: url_constructor(record['ENGINE'], record['MARKET'], record['BOARDID'], record['SECID']) }).html(cell.html()))

            animate()



        refresh = ->
            fetch().then (records) ->
                element.removeClass("loading")

                render records

                _.delay refresh, 10 * 1000

        refresh()

_.extend scope,
    ticker_v2: widget