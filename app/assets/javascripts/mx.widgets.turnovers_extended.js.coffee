global = module?.exports ? ( exports ? this )

global.mx           ||= {}
global.mx.widgets   ||= {}

scope = global.mx.widgets

$ = jQuery


whitespace  = '&mdash;'
multiplier  = 1000 * 1000

totals_key  = 'TOTALS'


fields = [
    { name: 'TITLE',        type: 'string' },
    { name: 'VALTODAY',     type: 'number', precision: 0, multiplier: multiplier },
    { name: 'NUMTRADES',    type: 'number', precision: 0 }
]


timeout = 60 * 1000


cache = kizzy('widgets.extended_turnovers')




widget = (element, options = {}) ->
    element = $(element)
    return if _.size(element) == 0

    render = (records) ->
        
        table = $("<table>")
            .addClass("mx-widget-turnovers")
            .html("<thead></thead><tbody></tbody>")
        
        table_body = $("tbody", table)
        
        for record in records
            console.log record
            table_body.append render_row(record)
        
        element.empty().html table
    
    render_row = (record) ->
        row = $("<tr>")
        
        for field in fields
            cell = $("<td>")
                .addClass(field.type)
                .html(mx.utils.render(record[field.name], field) or whitespace)
            
            row.append cell
        
        row
            
    
    refresh = ->
        mx.iss.turnovers().then (turnovers) ->
            
            totals      = _.first(record for record in turnovers when record.NAME == totals_key)
            turnovers   = _.without turnovers, totals

            turnovers.unshift totals
            
            render turnovers
        
    refresh()




_.extend scope,
    extended_turnovers: widget
