global = module?.exports ? ( exports ? this )

global.mx           ||= {}
global.mx.widgets   ||= {}

scope = global.mx.widgets

$ = jQuery

cache = kizzy("widgets.ranks")

thead_columns = ["SECID", "UPDATETIME"]
tbody_columns = ["RANK",  "VALUE"]


localization =
    ru:
        select:   "Выделить все!"
        deselect: "Очистить все!"
    en:
        select:   "Select all!"
        deselect: "Deselect all!"


l10n = undefined


read_cache = (element, key) ->
    element.html cache.get key


write_cache = (element, key) ->
    cache.set key, element.html()


widget = (element, options = {}) ->

    element = $(element) ; return unless element.length > 0
    element.addClass("mx-widget-ranks")

    # localize
    l10n = localization[mx.locale()]

    # widget options
    show_threshold      = options.show_threshold? and options.show_threshold != false
    show_controls       = options.show_controls?  and options.show_controls  != false
    refresh_timeout     = options.refresh_timeout || 60 * 1000 # 1 minute default
    cacheable           = options.cache == true


    # cache_keys_for_widget
    cache_key            = mx.utils.sha1 JSON.stringify( [show_threshold, show_controls, mx.locale()].join("/") )
    securities_cache_key = mx.utils.sha1 "securities"

    read_cache(element, cache_key) if cacheable


    active_securities  = []
    refresh_timer      = undefined

    create_thead = (security, columns) ->

        thead        = $("<thead>")
        column_span  = tbody_columns.length + 1

        for column, index in columns
            row = $("<tr>")
            row.addClass("header") if index is 0

            cell = if index is 0 then $("<th>") else $("<td>")
            cell.addClass(column.name.toLowerCase())
                .addClass(column.type)
                .html(mx.utils.render(security[column.name], column))
                .attr
                    title:   column.title
                    colspan: column_span

            row.append cell
            thead.append row

        thead


    create_tbody = (securities, columns) ->

        tbody = $("<tbody>")

        title_row = $("<tr>").addClass("header")
        for column, col_index in columns
            last = col_index is (columns.length - 1)
            title_cell = $("<th>")
                .addClass(column.name.toLowerCase())
                .addClass(column.type)
                .html(column.short_title)
            title_row.append title_cell
        tbody.append title_row

        for security, index in securities
            row = $("<tr>")
            row.addClass("first") if index is 0
            row.addClass("last")  if index is (securities.length - 1)
            row.addClass( ["odd", "even"][index % 2] )
            row.addClass("threshold") if security["IS_THRESHOLD_AMOUNT"] is 1

            for column, col_index in columns
                value =  mx.utils.render(security[column.name], column)
                last  = col_index is (columns.length - 1)

                cell  = $("<td>")
                    .addClass(column.type)
                    .addClass(column.name.toLowerCase())
                    .attr("title", column.title)
                    .html(value)

                if column.name is "RANK" and value is "0" then cell.html("") else cell.html(value)
                row.append cell
            tbody.append row unless security["IS_THRESHOLD_AMOUNT"] is 1 and !show_threshold

        tbody


    render_tables = (securities, columns) ->

        securities_groups = _.groupBy securities, (sec) -> sec["SECID"]
        thead_cols     = _.filter  columns,    (col) -> _.include(thead_columns, col.name)
        tbody_cols     = _.filter  columns,    (col) -> _.include(tbody_columns, col.name)

        ul = $("<ul>").addClass("ranks-wrapper")

        _.each securities_groups, (group, name) ->

            li = $("<li>")
            table = $("<table>").addClass("mx-widget-ranks-table").attr("data-secid", name)

            group_sorted_by_value = _.sortBy group, (sec) -> -sec["VALUE"]
            security              = _.first(group)

            table.addClass("finished") if security["STATUS"] is "F"
            table.append create_thead security,              thead_cols
            table.append create_tbody group_sorted_by_value, tbody_cols

            li.append table
            ul.append li

        element.append ul


    render_securities = (securities) ->

        sec_list = $("<ul>").addClass("securities")

        for security, index in securities
            a = $("<a>").html(security["SECID"])
            a.addClass("active") if security.is_active
            a.addClass("first")  if index is 0
            a.addClass("last")   if index is securities.length - 1
            a.addClass( ["odd", "even"][index % 2] )
            a.attr("data-secid", security["SECID"])

            li = $("<li>").append(a)
            sec_list.append(li)

        element.append(sec_list)


    render_controls = () ->
        ul = $("<ul>").addClass("controls")

        show_all = $("<li>").append $("<a>").addClass("select").html(l10n.select)
        hide_all = $("<li>").append $("<a>").addClass("deselect").html(l10n.deselect)

        ul.append(show_all).append(hide_all)
        element.append(ul)


    start_events = () ->
        $(element).on "click", "ul.securities li a", () ->
            el    = $(this)
            secid = el.attr("data-secid")
            if _.include(active_securities, secid)
                active_securities = _.without(active_securities, secid)
                el.removeClass("active")
                $("table[data-secid='#{secid}']", element).parent("li").remove()
                write_cache(element, cache_key) if cacheable
            else
                el.parent("li").addClass("loading")
                active_securities.push(secid)
                clearTimeout(refresh_timer) if refresh_timer
                refresh()
            cache.set securities_cache_key, active_securities

        $(element).on "click", "ul.controls li a.select", () ->
            $("ul.securities li").addClass("loading")
            active_securities = "ALL"
            clearTimeout(refresh_timer) if refresh_timer
            cache.set securities_cache_key, active_securities
            refresh()


        $(element).on "click", "ul.controls li a.deselect", () ->
            $("ul.securities li a").removeClass("active")
            $("ul.ranks-wrapper li").remove()
            active_securities = []
            cache.set securities_cache_key, active_securities
            write_cache(element, cache_key) if cacheable


    render = (securities, ranks, columns) ->
        element.empty()
        render_controls() if show_controls
        render_securities(securities)
        render_tables(ranks, columns) if ranks? and columns?

        write_cache(element, cache_key) if cacheable


    refresh = () ->

        $.when(mx.iss.mmakers_ranks_securities( { force: true } )).then (securities) ->

            securities = _.sortBy securities, (security) -> security["SECID"]

            active_securities = cache.get securities_cache_key

            if active_securities is undefined
                securities = _.map securities, (security) ->
                    security.is_active = if security["IS_DEFAULT"] is 1 then true else false
                    return security
            else if active_securities is "ALL"
                securities = _.map securities, (security) ->
                    security.is_active = true
                    return security
            else
                securities = _.map securities, (security) ->
                    security.is_active = if _.include(active_securities, security["SECID"]) then true else false
                    return security

            active_securities = _.pluck _.filter(securities, (security) -> security.is_active), "SECID"
            cache.set securities_cache_key, active_securities


            if active_securities.length is 0
                render(securities)
                refresh_timer = setTimeout refresh, refresh_timeout
            else
                deffered = $.when mx.iss.mmakers_ranks(active_securities, { force: true }), mx.iss.mmakers_ranks_columns()
                deffered.then (ranks, columns) ->
                    render(securities, ranks, columns)
                    refresh_timer = setTimeout refresh, refresh_timeout



    refresh()
    start_events()
    return


_.extend scope,
    ranks: widget




