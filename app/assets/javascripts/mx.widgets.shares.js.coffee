global = module?.exports ? ( exports ? this )

global.mx           ||= {}
global.mx.widgets   ||= {}

scope = global.mx.widgets

$ = jQuery

whitespace = '&mdash;'

timeout = 60 * 1000


filter  = ['SECID', 'LAST', 'LASTTOPREVPRICE', 'HIGH', 'LOW', 'OPEN', 'VALTODAY', 'NUMTRADES', 'UPDATETIME']

params  = ['EQBR:SBER', 'EQNE:GAZP', 'EQBR:LKOH', 'EQNL:ROSN', 'EQBR:SBERP', 'EQBS:GMKN', 'EQNL:VTBR', 'EQNL:SNGS', 'EQNL:CHMF', 'EQBR:URKA']


cache = kizzy('widgets.shares')


widget = (element, options = {}) ->

    element = $(element)
    return if _.size(element) == 0
    
    cache_key = mx.utils.sha1("")
    
    columns_data_source = mx.iss.columns('stock', 'shares')
    
    $.when(columns_data_source).then (columns) ->
        
        filtered_columns = _.reduce filter, (memo, name) ->
            memo.push _.first(column for id, column of columns when column.name == name)
            memo
        , []
        
        
        render = (records) ->
            
            table = $("<table>")
                .addClass("mx-widget-table")
                .html("<thead></thead><tbody></tbody>")
            
            table_head = $("thead", table)
            table_body = $("tbody", table)
            
            render_table_head table_head
            
            records_size = _.size(records)
            
            for record, index in records
                row = $("<tr>")
                    .toggleClass('first',   0 == index)
                    .toggleClass('last',    records_size - 1 == index)
                    .toggleClass('even',    (index + 1) % 2 == 0)
                    .toggleClass('odd',     (index + 1) % 2 == 1)
                    .attr({ 'data-key': "#{record.BOARDID}:#{record.SECID}" })
                
                for column in filtered_columns
                    cell = $("<td>")
                        .addClass(column.type)
                        .html(mx.utils.render(record[column.name], column) or whitespace)
                    
                    if trend = record.trends[column.name]
                        prefix = if column.trend_by == column.id then 'trend' else 'trending'
                        cell.addClass prefix + if trend > 0 then '_up' else if trend < 0 then '_down' else '_none'

                    row.append cell
                
                table_body.append row
        
            element.empty().html table


        render_table_head = (table_head) ->
            table_head.append $("<td>").html(column.short_title) for column in filtered_columns
        

        refresh = ->
            mx.iss.records('stock', 'shares', params, { force: true }).then (records) ->
                
                if records? and _.size(records) > 0
                    
                    records = _.sortBy records, (record) ->
                        mx.utils.process_record record, columns
                        _.indexOf params, "#{record.BOARDID}:#{record.SECID}"
                    
                    render records
        
        refresh()

_.extend scope,
    shares: widget
