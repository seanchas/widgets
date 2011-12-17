global = module?.exports ? ( exports ? this )

global.mx           ||= {}
global.mx.widgets   ||= {}

scope = global.mx.widgets

$ = jQuery

whitespace = '&mdash;'

filter  = ['NAME', 'CURRENTVALUE', 'LASTCHANGEPRC', 'VALTODAY', 'UPDATETIME', 'MONTHCHANGEPRC', 'YEARCHANGEPRC']

params  = ['SNDX:MICEXINDEXCF', 'RTSI:RTSI', 'SNDX:MICEXCBITR', 'SNDX:MICEXMBITR', 'SNDX:MICEXINNOV']

timeout = 60 * 1000


cache = kizzy('widgets.indices')



widget = (element, options = {}) ->
    element = $(element)
    return if _.size(element) == 0
    
    cache_key = mx.utils.sha1("")

    columns_data_source = mx.iss.columns('stock', 'index')
    
    options.url = $.noop unless options.url and _.isFunction(options.url);
    
    element.html cache.get cache_key
    
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
            
            for record in records
                row = $("<tr>")
                
                for column, index in filtered_columns
                    cell = $("<td>").addClass(column.type).html(mx.utils.render(record[column.name], column) || whitespace)
                    
                    if index == 0
                        url = options.url(record.ENGINE, record.MARKET, record.BOARDID, record.SECID)
                        cell.html $("<a>").attr('href', url).html(cell.html()) if url?
                    
                    if column.trend_by == column.id and trend = record.trends[column.name]
                        cell.addClass if trend > 0 then 'trend_up' else if trend < 0 then 'trend_down' else 'trend_none'
                    
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
            mx.iss.records('stock', 'index', params, { force: true }).then (records) ->

                if records? and _.size(records) > 0

                    records = _.sortBy records, (record) ->
                        _.indexOf params, "#{record.BOARDID}:#{record.SECID}"
                
                    for record in records
                        record.ENGINE = 'stock'
                        record.MARKET = 'index'
                        mx.utils.process_record record, columns, true
                
                    render records
                
                _.delay refresh, options.refresh_timeout ? timeout
        

        refresh()


_.extend scope,
    indices: widget
