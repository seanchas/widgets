global = module?.exports ? ( exports ? this )

global.mx           ||= {}
global.mx.widgets   ||= {}

scope = global.mx.widgets

$ = jQuery

escape_selector = (string) ->
    string.replace /([\W])/g, "\\$1"


widget = (element, params, options = {}) ->
    element = $(element) ; return unless _.size(element)

    element.html( $("<div>").addClass("mx-widget-vertical-ticker loading") )

    flip_speed       = options.flip_speed       || 500          # 0.5 sec. (lower - faster)
    flip_delay       = options.flip_delay       || 8  * 1000    # 8 sec.
    refresh_timeout  = options.refresh_timeout  || 10 * 1000    # 10 sec.
    outer_margin     = options.outer_margin     || 20           # 20px each side
    intercell_margin = options.intercell_margin || 20           # 20px min between tickers


    frame     = $(".mx-widget-vertical-ticker", element)
    screens   = [$("<ul>").addClass("screen i1"), $("<ul>").addClass("screen i2")]
    container = $("<ul>").addClass("container")
    frame.append(container)

    url_constructor = options.url if options.url and _.isFunction(options.url)

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
            records_options = { force: true }
            _.extend(records_options, { nearest: 1, params_name: 'sectypes' }) if engine is 'futures' and options.nearest
            mx.iss.records(engine, market, params, records_options).then (json) ->
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

    tickers_count    = 0;
    ticker_position  = 0;
    frame_width      = 0;

    prepare_screens = ->
        frame.append(screen) for screen in screens
        screen.css({ padding: 0, margin: 0, position: 'absolute', top: frame.innerHeight() * index, left: 0 }).width(frame.innerWidth()).height(frame.innerHeight()) for screen, index in screens

    prepare_screens()

    fill_screen = ->
        screen          = _.last screens
        screen_width    = screen.innerWidth() - 2 * outer_margin
        tickers         = $("li", container)
        ticker_count    = _.size(tickers)
        tickers_width   = _.map(tickers, (t) -> $(t).outerWidth())

        ticker_position = 0 unless ticker_position < ticker_count
        full_width      = 0

        screen.empty()

        until full_width + tickers_width[ticker_position] > screen_width
            screen.append($(tickers[ticker_position]).clone())
            full_width += tickers_width[ticker_position] + intercell_margin
            ticker_position += 1
            ticker_position = 0 unless ticker_position < ticker_count


        compute_margins = ->
            cloned_tickers = $('li', screen)
            cloned_tickers.first().css('margin-left', "#{outer_margin}px")
            addition_margin = Math.floor((screen_width - (full_width - intercell_margin)) / (_.size(cloned_tickers) - 1))
            _.each(_.rest(cloned_tickers), (t) -> $(t).css('margin-left', "#{intercell_margin + addition_margin}px") )

        compute_margins()

    reanimate = ->
        _.first(screens).css('top', "#{frame.innerHeight()}px")
        screens = screens.reverse()
        _.delay animate, flip_delay

    animate = ->
        fill_screen()
        _.first(screens).animate({ top: "-=#{frame.innerHeight()}" }, { easing: 'linear', duration: flip_speed})
        _.last(screens) .animate({ top: "-=#{frame.innerHeight()}" }, { easing: 'linear', duration: flip_speed, complete: reanimate })

    start_animation = _.once ->
        frame.removeClass('loading')
        animate()



    $.when(fetch_filters(), fetch_columns()).then (filters, columns) ->

        for id, filter of filters
            filter = _.reduce filter.widget, (memo, field) ->
                memo[field.alias] = field
                memo
            , {}
            filters[id] = filter

        render_to_container = (records) ->
            return if _.size(records) == 0

            container = $("ul.container", element)

            for record in records

                key = "#{record['ENGINE']}:#{record['MARKET']}"

                _filters = filters[key]
                _columns = columns[key]

                record = mx.utils.process_record record, _columns

                tick = $(".tick:last", container)

                record_key = "#{record['BOARDID']}:#{record['SECID']}"

                views = $("li[data-key=#{escape_selector record_key}]", container)

                if _.size(views) == 0
                    container.append $("<li>").addClass('tick').attr({ 'data-key': record_key })


                views = $("li[data-key=#{escape_selector record_key}]", container)

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

            start_animation()



        refresh = ->
            fetch().then (records) ->
                element.removeClass("loading")

                render_to_container records

                _.delay refresh, refresh_timeout

        refresh()

_.extend scope,
    vertical_ticker: widget