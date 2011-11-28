global = module?.exports ? ( exports ? this )

global.mx           ||= {}
global.mx.security  ||= {}

scope = global.mx.security

$ = jQuery


format_date = (date) ->
    return '&mdash;' unless date
    date = if date instanceof Date then date else mx.utils.parse_date(date)
    mx.utils.render date, { type: 'date' }


widget = (element, engine, market, board, param, options = {}) ->
    element = $(element); return if element.length == 0
    
    make_container = ->
        $("<table>")
            .addClass("mx-security-boards")
            .html("<thead></thead><tbody></tbody>")

    make_row = (b) ->
        row = $("<tr>")
            .html("<th><a href=\"##{b.engine}:#{b.market}:#{b.boardid}:#{param}\">#{b.title}</a></th><td>#{format_date b.history_from} &ndash; #{format_date b.history_till}</td>")
        
        cell = $('th', row)
        row.toggleClass('current', b.boardid == board)
        
        row

    render = (boards) ->
        table = make_container()
        
        table_body = $('tbody', table)
        
        for board in boards
            table_body.append make_row(board)
        
        element.html(table)
    
    refresh = ->
        mx.iss.boards(param).then render
    
    refresh()
    
    {}


_.extend scope,
    boards: widget
