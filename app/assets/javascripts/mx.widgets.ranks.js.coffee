global = module?.exports ? ( exports ? this )

global.mx           ||= {}
global.mx.widgets   ||= {}

scope = global.mx.widgets

$ = jQuery

cache = kizzy("widgets.ranks")

read_cache = (element, key) ->
    element.html cache.get key


write_cache = (element, key) ->
    cache.set key, element.html()


widget = (element, options = {}) ->

    element = $(element) ; return unless element.length > 0
    element.addClass("mx-widget-ranks")

    show_header         = options.show_header? and options.show_header != false
    is_callback_present = (typeof options.afterRefresh == "function")
    refresh_timeout      = options.refresh_timeout || 60 * 1000 # 1 minute default

    cache_key = mx.utils.sha1 JSON.stringify( [show_header, mx.locale()].join("/") )
    cacheable = options.cache == true

    read_cache(element, cache_key) if cacheable

    create_thead = (columns) ->
        thead = $("<thead>")
        thead.append $("<tr>").addClass("header")

        for column in columns
            cell = $("<td>")
                .addClass(column.name.toLowerCase())
                .addClass(column.type)
                .html(column.short_title)
            $("tr", thead).append(cell)

        thead


    render = (securities, columns) ->
        table = $("<table>").addClass("mx-widget-table")
        tbody = $("<tbody>")

        securities_groups = _.groupBy securities, (sec) -> sec["SECID"]
        _.each securities_groups, (group, name) ->
            group_sorted_by_rank = _.sortBy group, (sec) -> sec["RANK"]
            security             = _.first(group)
            secid_column         = _.find(columns, (col) -> col.name is "SECID")
            security_title_row   = $("<tr>")
                .addClass("title")
                .append $("<td>")
                    .addClass(secid_column.type)
                    .addClass(secid_column.name.toLowerCase())
                    .attr("title",   secid_column.title)
                    .attr("colspan", columns.length)
                    .html(security["SECID"])
            tbody.append security_title_row

            for security, index in group
                row = $("<tr>")
                row.addClass("first") if index is 0
                row.addClass("last")  if index is (group.length - 1)
                row.addClass( ["odd", "even"][index % 2] )

                for column in columns
                    value = unless column.name is "SECID" then mx.utils.render(security[column.name]) else "&nbsp;"
                    cell  = $("<td>")
                        .addClass(column.type)
                        .addClass(column.name.toLowerCase())
                        .attr("title", column.title)
                        .html(value, column)
                    row.append cell
                tbody.append row

        table.append create_thead(columns) if show_header
        table.append tbody

        element.html(table)



    refresh = () ->

        deffered = $.when mx.iss.mmakers_ranks({ force: true}), mx.iss.mmakers_ranks_columns()

        deffered.then (ranks, columns) ->
            render(ranks, columns)
            write_cache(element, cache_key) if cacheable

            if is_callback_present
                date = new Date [ ranks[0]["TRADEDATE"], ranks[0]["UPDATETIME"] ].join(" ")
                options.afterRefresh(date)

            setTimeout refresh, refresh_timeout

    refresh()
    return


_.extend scope,
    ranks: widget




