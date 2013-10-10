root              = @
root.mx         ||= {}
root.mx.widgets ||= {}
scope             = root.mx.widgets

cache = kizzy('mx.widgets.aggregates')

localization =
    ru:
        type_bond:         'Группа бумаг'
        iss_nominal:       'Объем по номинальной стоимости, млн.руб.'
        avg_years:         'Средневзвешанный срок до погашения, лет'
        vol_nominal:       'Оборот по номинальной стоимости, млн.руб.'
        vol_price_trade:   'Оборот по цене сделок, млн.руб'
        coeff_nominal:     'Коэффициент оборачиваемости по номинальной стоимости, %'
        o:                 'Основной режим'
        r:                 'РПС'
    en:
        type_bond:         ''
        iss_nominal:       ''
        avg_years:         ''
        vol_nominal:       ''
        vol_price_trade:   ''
        coeff_nominal:     ''
        o:                 ''
        r:                 ''


render_row   = (data_row) ->


widget = (element, options = {}) ->

    element = $(element) ; return unless _.size(element) > 0
    element.addClass('mx-widgets-aggregates')

    l10n = localization[mx.locale()]

    render = (columns, records) ->

        element.empty()

        table = $('<table><thead></thead><tbody></tbody></table>').addClass('mx-widget-table')
        thead = $('thead', table)
        tbody = $('tbody', table)

        columns_order = [
            'TYPE_BOND'
            'ISS_NOMINAL'
            'AVG_YEARS'
            'VOL_NOMINAL_O'
            'VOL_NOMINAL_R'
            'VOL_PRICE_TRADE_O'
            'VOL_PRICE_TRADE_R'
            'COEFF_NOMINAL_O'
            'COEFF_NOMINAL_R'
        ]

        thead_tmpl = """
            <tr>
                <td rowspan="2" class="string">#{l10n.type_bond}</td>
                <td rowspan="2" class="number">#{l10n.iss_nominal}</td>
                <td rowspan="2" class="number">#{l10n.avg_years}</td>
                <td colspan="2" class="number">#{l10n.vol_nominal}</td>
                <td colspan="2" class="number">#{l10n.vol_price_trade}</td>
                <td colspan="2" class="number">#{l10n.coeff_nominal}</td>
            </tr>
            <tr>
                <td class="number">#{l10n.o}</td>
                <td class="number">#{l10n.r}</td>
                <td class="number">#{l10n.o}</td>
                <td class="number">#{l10n.r}</td>
                <td class="number">#{l10n.o}</td>
                <td class="number">#{l10n.r}</td>
            </tr>
        """

        thead.html(thead_tmpl)

        for record, index in records

            tr = $('<tr>')
            tr.addClass('row')
            tr.addClass(['odd', 'even'][index%2])
            tr.addClass('first') if index is 0
            tr.addClass('last')  if index is records.length - 1

            record = mx.utils.process_record(record, columns)

            for colname in columns_order
                column = _.find(columns, (c) -> c.name is colname)
                td = $('<td>').addClass(column.type)
                descriptor = _.extend column, { precision: record?.precisions?[column.name]}
                td.html mx.utils.render( record[column.name], descriptor)
                tr.append td

            tbody.append tr

        element.append table


    cacheable = !!options.cache
    cache_key = mx.utils.sha1(['mx.widgets.aggregates', mx.locale()].join('/'))
    callback  = if _.isFunction(options.afterRenderDate) then options.afterRenderDate else undefined

    element.html(cache.get(cache_key)) if cacheable and cache.get(cache_key)

    $.when(mx.iss.aggregates_columns()).then (columns) ->
        $.when(mx.iss.aggregates()).then (records) ->
            render(columns, records)
            cache.set(cache_key, element.html()) if cacheable
            callback mx.utils.parse_date(_.first(records)['TRADEDATE']) if callback


_.extend scope,
    aggregates: widget