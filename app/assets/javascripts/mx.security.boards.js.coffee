global = module?.exports ? ( exports ? this )

global.mx           ||= {}
global.mx.security  ||= {}

scope = global.mx.security

$ = jQuery


cache = kizzy('security.boards')


format_date = (date) ->
    return '&mdash;' unless date
    date = if date instanceof Date then date else mx.utils.parse_date(date)
    mx.utils.render date, { type: 'date' }


widget = (element, engine, market, board, param, options = {}) ->
    element = $(element); return if element.length == 0
    
    cache_key = mx.utils.sha1(JSON.stringify(_.rest(arguments).join("/")) + mx.locale())
    
    element.html cache.get(cache_key) if options.cache
    
    make_container = ->
        $("<table>")
            .addClass("mx-security-boards")
            .html("<thead></thead><tbody></tbody>")

    make_url = (b) ->
        if options.url? and _.isFunction(options.url)
            options.url b.engine, b.market, b.boardid, param
        else
            "##{b.engine}:#{b.market}:#{b.boardid}:#{param}"

    make_row = (b) ->
        row = $("<tr>")
            .html("<th><a href=\"#{make_url b}\">#{b.title}</a></th><td>#{format_date b.history_from} &ndash; По н. вр.</td>")
        
        cell = $('th', row)
        row.toggleClass('current', b.boardid == board)
        
        row

    render = (boards) ->
        table = make_container()
        
        table_body = $('tbody', table)
        
        for board in boards
            table_body.append make_row(board) if board.is_traded == 1
        
        element.html(table)
    
    refresh = ->
        mx.iss.boards(param).then (boards) ->
            if boards and _.size(boards) > 0
                render boards
                cache.set cache_key, element.html() if options.cache

                element.trigger('render', { status: 'success' })
            else
                element.trigger('render', { status: 'failure' })
    
    refresh()
    
    {
        destroy: ->
            element.children().remove()
    }


_.extend scope,
    boards: widget
