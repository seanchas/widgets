global = module?.exports ? ( exports ? this )

global.mx           ||= {}
global.mx.widgets   ||= {}

scope = global.mx.widgets

$ = jQuery

fields = [
    { name: 'SHORT_TITLE',              title: 'Краткое наименование' }
    { name: 'TRANSLITERATION_TITLE',    title: 'Транслитерация' }
    { name: 'OKPO',                     title: 'ОКПО' }
    { name: 'OGRN',                     title: 'ОГРН' }
    { name: 'INN',                      title: 'ИНН' }
]

create_table = ->
    $("<table>")
        .addClass('mx-widget-emitter')
        .html("<thead></thead><tbody></tbody>")


render = (element, emitter) ->
    table = create_table()
    
    table_head = $('thead', table)
    
    table_head.html "<tr><td colspan=\"2\">#{emitter['TITLE']}</td></tr>"
    
    table_body = $('tbody', table)
    
    for field in fields
        table_body.append $("<tr><th>#{field.title}</th><td>#{emitter[field.name] ? '&mdash;'}</td></tr>")
    
    element.html table


widget = (element, engine, market, board, param, options = {}) ->
    
    element = $(element); return if element.length == 0
    
    mx.iss.description(param).then (description) ->
        emitter_id = _.first(field.value for field in description when field.name == 'EMITTER_ID')
        if emitter_id?
            mx.iss.emitter(emitter_id).then (emitter) ->
                render element, emitter
    

_.extend scope,
    security_emitter: widget
