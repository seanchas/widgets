global = module?.exports ? ( exports ? this )

global.mx           ||= {}
global.mx.widgets   ||= {}

scope = global.mx.widgets

$ = jQuery

localization =
    en:
        rank:   "Rank"
        value:  "Value"
        volume: "Volume"
    ru:
        rank:   "Ранг"
        value:  "Объем, руб."
        volume: "Объем, шт."

l10n = localization[mx.locale()]

table_columns = ["rank", "volume", "value"]

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
    refresh_timout      = options.refresh_timeout || 60 * 1000 # 1 minute default

    cache_key = mx.utils.sha1 JSON.stringify( [show_header, mx.locale()].join("/") )
    cacheable = options.cache == true

    read_cache(element, cache_key) if cacheable

    create_thead = () ->
        thead = $("<thead>")
        thead.append $("<tr>").addClass("header")

        for column in table_columns
            cell = $("<td>").addClass("#{column} number").html(l10n[column])
            $("tr", thead).append(cell)

        thead


    render = (securities) ->
        table = $("<table>").addClass("mx-widget-table")
        tbody = $("<tbody>")

        uniq_sec_ids = _.uniq _.map(securities, ((security) -> security["SECID"]))
        for sec_id in uniq_sec_ids
            securities_group = _.filter securities, ((security) -> security["SECID"] == sec_id)
            securities_group = _.sortBy securities_group, ((security) -> security["RANK"])

            sec_id_row = $("<tr>").addClass("sec_id")
            sec_id_row.append $("<td>")
                .addClass("string")
                .attr("colspan", table_columns.length).html(sec_id)
            tbody.append sec_id_row

            for security, index in securities_group
                row = $("<tr>")
                row.addClass("first") if index == 0
                row.addClass("last")  if index == securities_group.length - 1
                row.addClass(["odd", "even"][index % 2])

                for column in table_columns
                    cell = $("<td>").addClass("#{column} number")
                    cell.html mx.utils.number_with_delimiter(security[column.toUpperCase()])
                    row.append cell
                tbody.append(row)

        table.append create_thead() if show_header
        table.append tbody

        element.html(table)



    refresh = () ->

        deffered = $.when mx.iss.mmakers_ranks({ force: true}), mx.iss.mmakers_ranks_columns()

        deffered.then (ranks, columns) ->
            console.log ranks, columns
            render(ranks)
            write_cache(element, cache_key) if cacheable

            if is_callback_present
                date = new Date [ ranks[0]["TRADEDATE"], ranks[0]["UPDATETIME"] ].join(" ")
                options.afterRefresh(date)

            setTimeout refresh, refresh_timout

    refresh()
    return


_.extend scope,
    ranks: widget




