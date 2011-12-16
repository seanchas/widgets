global = module?.exports ? ( exports ? this )

global.mx           ||= {}
global.mx.widgets   ||= {}

scope = global.mx.widgets

$ = jQuery

fields = [
    { name: 'SHORT_TITLE',              title: 'Краткое наименование' }
    { name: 'TRANSLITERATION_TITLE',    title: 'Транслитерация' }
    { name: 'LEGAL_ADDRESS',            title: 'Юридический адрес' }
    { name: 'POSTAL_ADDRESS',           title: 'Почтовый адрес' }
    { name: 'OKPO',                     title: 'ОКПО' }
    { name: 'OGRN',                     title: 'ОГРН' }
    { name: 'INN',                      title: 'ИНН' }
    { name: 'URL',                      title: 'WEB-адрес' }
]

widget = (element, engine, market, board, param, options = {}) ->
    
    element = $(element); return if element.length == 0
    
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


    mx.iss.description(param).then (description) ->
        emitter_id = _.first(field.value for field in description when field.name == 'EMITTER_ID')
        if emitter_id?
            mx.iss.emitter(emitter_id).then (emitter) ->
                render element, emitter
    

securities_widget = (element, engine, market, board, param, options = {}) ->

    element = $(element); return if element.length == 0

    make_table = ->
        $("<table>")
            .addClass('mx-widget-emitter-securities')
            .html("<thead></thead><tbody></tbody>")

    render = (records) ->
        table = make_table()
        
        table_body = $('tbody', table)
        
        for record in records
            table_body.append render_row(record) if record? and record.length > 0
        
        element.html table

    render_row = (record) ->
        $("<tr>")
            .append(
                $("<th>")
                    .html(_.first(record).secid)
            )
            .append(
                $("<td>")
                    .html((security.title for security in record).join('<br />'))
            )

    mx.iss.description(param).then (description) ->
        emitter_id = _.first(field.value for field in description when field.name == 'EMITTER_ID')
        if emitter_id?
            mx.iss.emitter_securities(emitter_id).then (securities) ->
                
                ids = _.pluck securities, 'SECID'

                complete    = _.after securities.length, (records) ->
                    render _.sortBy records, (record) ->
                        _.indexOf(ids, _.first(record).secid) if record? and record.length > 0

                records     = []
                
                for id in ids
                    mx.iss.boards(id).then (json) ->
                        records.push (record for record in json when record.is_traded == 1)
                        complete records
                    


_.extend scope,
    security_emitter: widget
    security_emitter_securities: securities_widget
