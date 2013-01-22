global = module?.exports ? ( exports ? this )

global.mx           ||= {}
global.mx.widgets   ||= {}

scope = global.mx.widgets

$ = jQuery

cache = kizzy("widgets.ranks")

columns_to_show_in_thead = ["SECID", "UPDATETIME"]
columns_to_show_in_tbody = ["RANK",  "VALUE"]

read_cache = (element, key) ->
    element.html cache.get key


write_cache = (element, key) ->
    cache.set key, element.html()


widget = (element, options = {}) ->

    element = $(element) ; return unless element.length > 0
    element.addClass("mx-widget-ranks")

    # widget options
    show_header         = options.show_header?    and options.show_header    != false
    show_threshold      = options.show_threshold? and options.show_threshold != false
    is_callback_present = (typeof options.afterRefresh == "function")
    refresh_timeout     = options.refresh_timeout || 60 * 1000 # 1 minute default
    cacheable           = options.cache == true


    # cache_keys_for_widget
    cache_key            = mx.utils.sha1 JSON.stringify( [show_header, mx.locale()].join("/") )
    securities_cache_key = mx.utils.sha1 "securities"

    read_cache(element, cache_key) if cacheable


    active_securities = []
    refresh_timer     = undefined

    create_thead = (security, columns) ->

        thead = $("<thead>")
        thead.addClass("finished") if security["STATUS"] is "F"

        column_span  = columns_to_show_in_tbody.length - columns.length + 1

        title_row = $("<tr>").addClass("header")
        data_row  = $("<tr>").addClass("data")

        for column, index in columns
            title_cell = $("<th>")
                .addClass(column.name.toLowerCase())
                .addClass(column.type)
                .html(column.short_title)

            data_cell  = $("<td>")
                .addClass(column.name.toLowerCase())
                .addClass(column.type)
                .attr("title", column.title)
                .html(mx.utils.render(security[column.name], column))

            if index is (columns.length - 1) and column_span > 1
                title_cell.attr("colspan", column_span)
                data_cell.attr("colspan",  column_span)

            title_row.append title_cell
            data_row.append  data_cell

        thead.append title_row if show_header
        thead.append data_row

        thead


    create_tbody = (securities, columns) ->

        tbody = $("<tbody>")

        column_span  = columns_to_show_in_thead.length - columns.length + 1

        title_row = $("<tr>").addClass("header")
        for column, col_index in columns
            last = col_index is (columns.length - 1)
            title_cell = $("<th>")
                .addClass(column.name.toLowerCase())
                .addClass(column.type)
                .html(column.short_title)
            title_cell.attr("colspan", column_span) if last and column_span >1
            title_row.append title_cell

        tbody.append title_row if show_header

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
                cell.attr("colspan", column_span) if last and column_span > 1
                row.append cell
            tbody.append row

        tbody


    render_tables = (securities, columns) ->

        securities_groups = _.groupBy securities, (sec) -> sec["SECID"]
        thead_columns     = _.filter  columns,    (col) -> _.include(columns_to_show_in_thead, col.name)
        tbody_columns     = _.filter  columns,    (col) -> _.include(columns_to_show_in_tbody, col.name)

        _.each securities_groups, (group, name) ->

            table = $("<table>").addClass("mx-widget-table").attr("data-secid", name)


            group_sorted_by_value = _.sortBy group, (sec) -> -sec["VALUE"]
            security              = _.first(group)

            table.append create_thead security,              thead_columns
            table.append create_tbody group_sorted_by_value, tbody_columns

            element.append(table)

        element


    render_securities = (securities) ->

        sec_list = $("<ul>").addClass("securities")

        for security, index in securities
            li = $("<li>").html(security["SECID"])
            li.addClass("active") if security.is_active
            li.addClass("first")  if index is 0
            li.addClass("last")   if index is securities.length - 1
            li.addClass( ["odd", "even"][index % 2] )
            li.attr("data-secid", security["SECID"])
            sec_list.append(li)

        element.append(sec_list)

    start_events = () ->
        $("ul.securities li", element).live "click", () ->
            console.log "click"
            el    = $(this)
            secid = el.attr("data-secid")
            if _.include(active_securities, secid) and active_securities.length > 1
                active_securities = _.without(active_securities, secid)
                el.removeClass("active")
                $("table[data-secid='#{secid}']", element).hide()
            else
                active_securities.push(secid)
                clearTimeout(refresh_timer) if refresh_timer
                refresh()
            cache.set securities_cache_key, active_securities


    refresh = () ->

        $.when(mx.iss.mmakers_ranks_securities()).then (securities) ->

            securities = _.sortBy securities, (security) -> security["SECID"]

            active_securities = cache.get securities_cache_key

            if active_securities is undefined or active_securities.length is 0
                securities = _.map securities, (security) ->
                    security.is_active = if security["IS_DEFAULT"] is 1 then true else false
                    return security
            else
                securities = _.map securities, (security) ->
                    security.is_active = if _.include(active_securities, security["SECID"]) then true else false
                    return security

            active_securities = _.pluck _.filter(securities, (security) -> security.is_active), "SECID"
            cache.set securities_cache_key, active_securities

            deffered = $.when mx.iss.mmakers_ranks(active_securities, { force: true }), mx.iss.mmakers_ranks_columns()

            deffered.then (ranks, columns) ->
                element.empty()
                render_securities(securities)
                render_tables(ranks, columns)

                write_cache(element, cache_key) if cacheable

                if is_callback_present
                    date = new Date [ ranks[0]["TRADEDATE"], ranks[0]["UPDATETIME"] ].join(" ")
                    options.afterRefresh(date)

                refresh_timer = setTimeout refresh, refresh_timeout

    refresh()
    start_events()
    return


_.extend scope,
    ranks: widget




