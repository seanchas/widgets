global = module?.exports ? ( exports ? this )

scope = global.mx.widgets.tiny

$ = jQuery

f = (x) -> if 0 < x < 10 then "0" + x else x
d = (d) -> "#{f d.getDate()}.#{f( d.getMonth() + 1 )}.#{d.getFullYear()} #{f d.getHours()}:#{f d.getMinutes()}"


cache = kizzy('mx.widgets.tiny.currency_fixing')

filter = _.invoke(['secid', 'boardid', 'updatetime', 'marketpricetoday', 'marketprice2'], 'toUpperCase')


widget = (element, options = {}) ->
    element = $(element) ; return unless element.length > 0
    element.addClass('mx-tiny-widget').addClass('currency-fixing')

    refresh_timeout = options.refresh_timeout || 60 * 1000 # 5sec
    cacheable       = options.cache? and options.cache is true

    cache_key = mx.utils.sha1(mx.locale()) if cacheable

    cells = {}
    init   = _.once ->
        table = $("""
                  <table class="mx-widget-table">
                    <tbody>
                        <tr>
                            <td class="string">USDRUB</td>
                            <td data-name="UPDATETIME"></td>
                            <td data-name="MARKETPRICETODAY"></td>
                        </tr>
                        <tr>
                            <td class="string">USDRUB</td>
                            <td class="time">12:00</td>
                            <td data-name="MARKETPRICE2"></td>
                        </tr>
                    </tbody>
                  </table>
                  """)

        element.append(table)

        _.each filter, (column) ->
            cell = $("td[data-name=#{column}]")
            cells[column] = cell if _.size(cell) > 0

    render = (data, columns) ->
        return unless data?
        init() # once
        _.each filter, (column) ->
            descriptor = _.extend({}, columns[column], { precision: data.precisions[column] })
            cells[column]?.addClass(descriptor.type).attr('title', descriptor.title)
            cells[column]?.html(mx.utils.render(data[column], descriptor ))

    render cache.get(cache_key)?.data, cache.get(cache_key)?.columns if cacheable and cache.get(cache_key)?

    $.when(mx.iss.columns('currency', 'selt')).then (columns) ->
        return unless columns?
        columns = _.filter columns, (column) -> _.include(filter, column.name)
        columns = _.reduce columns, ((memo, column) -> memo[column.name] = column ; memo ), {}
        refresh = ->
            $.when(mx.iss.security('currency', 'selt', 'cets', 'USD000UTSTOM')).then (data) ->
                if data.length > 0
                    data = mx.utils.process_record(_.first(data), columns)
                    cache.set(cache_key, { data: data, columns: columns }) if cacheable
                    render(data, columns)

                _.delay refresh, refresh_timeout
        refresh()

_.extend scope,
    currency_fixing: widget