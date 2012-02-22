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
    
    cache_key = mx.utils.sha1(mx.locale())
    
    element.html cache.get cache_key
    
    columns_data_source = mx.iss.columns('stock', 'shares')
    
    options.url = $.noop unless options.url and _.isFunction(options.url);
    
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
            
            for record in records
                row = $("<tr>")
                    .attr({ 'data-key': "#{record.BOARDID}:#{record.SECID}" })
                
                for column, index in filtered_columns
                    cell = $("<td>")
                        .addClass(column.type)
                        .html(mx.utils.render(record[column.name], column) or whitespace)
                    
                    if index == 0
                        url = options.url(record.ENGINE, record.MARKET, record.BOARDID, record.SECID)
                        cell.html $("<a>").attr('href', url).html(cell.html()) if url?

                    if trend = record.trends[column.name]
                        prefix = if column.trend_by == column.id then 'trend' else 'trending'
                        cell.addClass prefix + if trend > 0 then '_up' else if trend < 0 then '_down' else '_none'

                    row.append cell
                
                table_body.append row
        
            rows = $("tr", table_body)

            rows.filter(":first").addClass("first")
            rows.filter(":last").addClass("last")
            rows.filter(":even").addClass("even")
            rows.filter(":odd").addClass("odd")

            element.empty().html table
            
            cache.set cache_key, element.html()


        render_table_head = (table_head) ->
            table_head.append $("<td>").html(column.short_title) for column in filtered_columns
        

        refresh = ->
            mx.iss.records('stock', 'shares', params, { force: true }).then (records) ->
                
                if records? and _.size(records) > 0
                    
                    records = _.sortBy records, (record) ->
                        record.ENGINE = 'stock'
                        record.MARKET = 'shares'
                        mx.utils.process_record record, columns
                        _.indexOf params, "#{record.BOARDID}:#{record.SECID}"
                    
                    render records
                
                _.delay refresh, options.refresh_timeout ? timeout
                
        
        refresh()

_.extend scope,
    shares: widget
