global = module?.exports ? ( exports ? this )

global.mx           ||= {}
global.mx.widgets   ||= {}

scope = global.mx.widgets

$ = jQuery

cache = kizzy('mx.widgets.rms2')


l10n         = undefined
localization =
    ru:
        title: 'Риск параметры ценных бумаг'
        filters:
            title: 'Параметры поиска'
            unselected: 'Не выбрано'
            security_types:
                title: 'Тип инструмента'
            board_groups:
                title: 'Режим торгов'
            collateral:
                title: 'Обеспечение'
            listname:
                title: 'Раздел списка'
            index:
                title: 'Индексы'
            q:
                title: 'Поиск по инструменту'
                placeholder: 'Поиск'
                warn: '* Необходимо минимум три символа'
        buttons:
            apply_title: 'Применить'
        no_results: 'По текущим параметрам поиска ничего не найдено.'
        columns:
            'n':                   '№'
            'SECID':               'Код цб'
            'NAME':                'Наименование цб'
            'ISIN':                'ISIN'
            'DISCOUNT1':           'Ставка рыночного риска 1 (S1)'
            'LIMIT1':              'Лимит концентрации 1, шт. (L1)'
            'DISCOUNT2':           'Ставка рыночного риска 2 (S2)'
            'LIMIT2':              'Лимит концентрации 2, шт. (L2)'
            'DISCOUNT3':           'Ставка рыночного риска 3 (S3)'
            'REGISTRY_CLOSE_DATE': 'Дата закрытия реестра'


columns_order       = ['SECID', 'NAME', 'ISIN', 'DISCOUNT1', 'LIMIT1', 'DISCOUNT2', 'LIMIT2', 'DISCOUNT3', 'REGISTRY_CLOSE_DATE']
columns_descriptors =
    'SECID':
        type: 'string'
    'NAME':
        type: 'string'
    'ISIN':
        type: 'string'
    'DISCOUNT1':
        type: 'number'
        precision:  2
        has_percent: 1
    'LIMIT1':
        type: 'number'
        precision:  0
        has_percent: 0
    'DISCOUNT2':
        type: 'number'
        precision:  2
        has_percent: 1
    'LIMIT2':
        type: 'number'
        precision:  0
        has_percent: 0
    'DISCOUNT3':
        type: 'number'
        precision:  2
        has_percent: 1
    'REGISTRY_CLOSE_DATE':
        type: 'date'


filters =
    collateral:
        [   {
            value: 0
            title:
                ru: 'Не активно'
                en: 'Disabled'
        },  {
            value: 1
            title:
                ru: 'Частичное'
                en: 'Partial'
        },  {
            value: 2
            title:
                ru: 'Полное'
                en: 'Full'
        }   ]
    listname:
        [   {
            value: 'А1'
            title:
                ru: 'А1'
                en: 'A1'
        },  {
            value: 'А2'
            title:
                ru: 'А2'
                en: 'A2'
        },  {
            value: 'Б'
            title:
                ru: 'Б'
                en: 'B'
        },  {
            value: 'В'
            title:
                ru: 'В'
                en: 'C'
        },  {
            value: 'И'
            title:
                ru: 'И'
                en: 'I'
        },  {
            value: '_'
            title:
                ru: 'Внесписочные'
                en: 'Unlisted'
        }   ]


filters_defaults =
    sort_column:    'SECID'
    sort_order:     'ASC'
    security_types: ['common_share', 'preferred_share', 'state_bond', 'cb_bond', 'subfederal_bond', 'municipal_bond', 'corporate_bond', 'exchange_bond', 'ifi_bond']
    board_groups:   ['stock_shares_tplus', 'stock_ndm_tplus']
    collateral:     1
    listname:       ['А1','А2','Б','В','И','_']
    index:          null
    q:              null


filters_settings     = {}


save_filter_settings = (name, params) ->
    params =
        if _.isArray params
            if params.length > 0 then arr = _.chain(params).map((param) -> param.replace('__AND__', '&')).filter((param) -> param isnt '__UNSELECTED__').value() else null
        else if _.isString params
            if params is '__UNSELECTED__' then null else params.replace('__AND__', '&')
        else
            null

    filters_settings[name] = params


load_filter_settings = (name) -> filters_settings[name] || filters_defaults[name] || null


make_url = (row) ->
    key = row.data('key')
    records_urls[key] ?= if options.url and _.isFunction(options.url) then options.url(key.split(":")...) else "##{key}"


overlay_select = (element) ->
    element  = $(element) ; return unless _.size(element) > 0 or element.is('select')
    multiple = !!element.attr('multiple')

    element.hide()
    container = $('<ul>').addClass('select-list')
    container.addClass('multiple') if multiple
    options   = $("option", element)

    for option in options
        option    = $(option)
        list_item = $('<li>').addClass('select-list-item').attr('data-value', option.attr('value')).html(option.html())
        list_item.addClass('selected') if option.prop('selected')
        container.append(list_item)

    container.on 'click', 'li', (e) ->
        el    = $ @
        value = el.attr('data-value')
        option = $("option[value=#{value}]", element)
        option.prop('selected', !option.prop('selected')).change()
        el.removeClass('selected').siblings().removeClass('selected')
        _.each $('option:selected', element), (el) -> $("li[data-value=#{ $(el).attr('value') }]", container).addClass('selected')

    return container


render_select_filter = (container, name, objects, selected_objects, options = {}) ->

    container = $(container) ; return unless _.size(container) > 0

    container.addClass("rms-filter #{if !!options.multiple then 'multiple'} #{name}")
    selected_objects = [selected_objects] unless _.isArray(selected_objects)


    title_el  = $('<h3>').addClass('rms-filter-title').html(l10n.filters[name]?.title)
    select_el = if !!options.multiple then $('<select multiple>') else $('<select>')

    for obj in objects
        option = $('<option>')
        .attr( "value", obj.value )
        .text( obj.title )
        option.prop('selected', true) if _.include(selected_objects, obj.value)
        select_el.append( option )

    if _.isFunction options.callback
        select_el.on 'change', (e) ->
            selected_options = _.map $('option:selected', @), (option) -> $(option).val()
            selected_options = _.first(selected_options) unless options.multiple is true
            options.callback selected_options

    container.append title_el
    container.append select_el
    container.append overlay_select(select_el)

    return container


render_search_filter = (container) ->
    container = $(container) ; return unless _.size(container) > 0
    container.addClass('rms-filter search')

    title = $('<h3>').addClass('rms-filter-title').html(l10n.filters.q.title)
    input = $("<input>").attr({ placeholder: l10n.filters.q.placeholder })
    warn  = $("<p>").addClass('warning').html(l10n.filters.q.warn).hide()

    input.on 'input', ->
        value = $(@).val()
        if 0 < value.length and value.length < 3 then warn.show() else warn.hide()
        save_filter_settings 'q', (if value.length > 2 then value else null)

    container.append(title)
    container.append(input)
    container.append(warn)

    return container


render_applybtn_filter = (container) ->
    container = $(container) ; return unless _.size(container) > 0
    container.addClass('rms-filter button')

    btn = $('<a>').addClass('apply-filters-btn').text(l10n.buttons.apply_title).on('click', -> render_data() )
    container.append(btn)

    return container



render_filters = ( container, options = {} ) ->
    container = $(container) ; return unless _.size(container) > 0
    container.addClass('rms-filters-container')

    title = $('<h3>').addClass('rms-filters-title').html(l10n.filters.title)
    container.prepend(title)

    filter_security_types_container = $('<div>')
    filter_board_groups_container   = $('<div>')
    filter_collateral_container     = $('<div>')
    filter_listname_container       = $('<div>')
    filter_index_container          = $('<div>')
    filter_q_container              = $('<div>')
    filter_applybtn_container       = $('<div>')

    container.append filter_security_types_container
    container.append filter_board_groups_container
    container.append filter_index_container
    container.append filter_collateral_container
    container.append filter_listname_container
    container.append filter_q_container
    container.append filter_applybtn_container


    render_select_filter   filter_security_types_container, 'security_types', options.objects.security_types || [], options.selected_objects.security_types || [], { multiple: true,  callback: (params) -> save_filter_settings('security_types', params) }
    render_select_filter   filter_board_groups_container,   'board_groups',   options.objects.board_groups   || [], options.selected_objects.board_groups   || [], { multiple: true,  callback: (params) -> save_filter_settings('board_groups',   params) }
    render_select_filter   filter_collateral_container,     'collateral',     options.objects.collateral     || [], options.selected_objects.collateral     || [], { multiple: false, callback: (params) -> save_filter_settings('collateral',     params) }
    render_select_filter   filter_listname_container,       'listname',       options.objects.listname       || [], options.selected_objects.listname       || [], { multiple: true,  callback: (params) -> save_filter_settings('listname',       params) }
    render_select_filter   filter_index_container,          'index',          options.objects.index          || [], options.selected_objects.index          || [], { multiple: false, callback: (params) -> save_filter_settings('index',          params) }
    render_search_filter   filter_q_container
    render_applybtn_filter filter_applybtn_container


render_paginator = (container, cursor = {}) ->
    container = $(container) ; return unless _.size(container) > 0
    container.empty()

    [index, pagesize, total] = _.map ['INDEX', 'PAGESIZE', 'TOTAL'], (prop) -> cursor[prop]

    return if total <= pagesize

    max     = Math.floor(total / pagesize)
    max    -= 1 if max * pagesize is total
    current = Math.floor(index / pagesize)

    ul = $('<ul>').addClass('rms-paginator-pagelist')

    for n in [0..max]
        li = $('<li>').html(n + 1).attr('data-page', n).addClass('rms-paginator-page')
        li.addClass('current') if n is current
        ul.append(li)

    ul.on 'click', 'li', (e) -> render_data($(@).attr('data-page') * pagesize)

    container.append ul
    container.show()



render_data = () ->


widget = (dummy, options = {}) ->

    dummy = $(dummy) ; return unless _.size(dummy) > 0

    l10n = localization[mx.locale()]
    filters_settings = filters_defaults

    known_keys = ['rows_per_page', 'filters', 'selected', 'url']

    default_options =
        rows_per_page:   50
        filters:
            collateral: filters.collateral
            listname:   filters.listname
        selected:       filters_defaults

    # parse options
    options = _.pick options, known_keys
    _.defaults options.filters  ||= {}, default_options.filters
    _.defaults options.selected ||= {}, default_options.selected
    options.rows_per_page ||= default_options.rows_per_page

    el = {} # widget element container

    prerender = do () ->

        title = $('<h2>').addClass('rms-title').html(l10n.title)

        el.filters_container = $('<div>')
        el.data_container    = $('<div>').addClass('rms-data-container')
        el.data_table        = $('<table>').addClass('mx-widget-table')
        el.data_table_thead  = $('<thead>')
        el.data_table_tbody  = $('<tbody>')
        el.data_no_results   = $('<div>').addClass('rms-no-results').html(l10n.no_results)
        el.paginator         = $('<div>').addClass('rms-data-paginator')
        el.paginator_dup     = el.paginator.clone()

        el.data_table.append(el.data_table_thead).append(el.data_table_tbody).hide()
        el.data_container.append el.paginator
        el.data_container.append el.data_table
        el.data_container.append el.data_no_results
        el.data_container.append el.paginator_dup

        dummy.addClass('mx-widget-rms2')

        dummy.append title
        dummy.append el.filters_container
        dummy.append el.data_container

        render_data_table_thead = do ->
            el.data_table_thead.empty()

            tr = $('<tr>').addClass('row')
            tr.append $('<td>').addClass('number').html(l10n.columns.n)
            _.each columns_order, (column) ->
                td = $('<td>')
                    .html(l10n.columns[column])
                    .addClass('sortable')
                    .addClass(columns_descriptors[column].type)
                    .attr('data-column', column)
                td.addClass('current').addClass(load_filter_settings('sort_order').toLowerCase()) if load_filter_settings('sort_column') is column
                tr.append(td)

            el.data_table_thead.on 'click', 'td.sortable', (e) ->
                element = $ @

                sort_order  = 'asc'
                sort_order  = 'desc' if element.hasClass('asc')
                sort_column = element.attr('data-column')

                element
                    .removeClass('asc desc')
                    .addClass("current #{sort_order}")
                    .siblings()
                        .removeClass('current asc desc')

                save_filter_settings 'sort_column', sort_column
                save_filter_settings 'sort_order',  sort_order

                render_data()

            el.data_table_thead.append(tr)


    render_data = (start = 0) ->
        query_params = {}
        prepare_query_params = do ->
            query_params = _.inject ['sort_column', 'sort_order', 'collateral', 'security_types', 'board_groups', 'listname', 'index', 'q'], (memo, key) ->
                if load_filter_settings(key)
                    memo[key] = load_filter_settings(key)
                    memo[key] = memo[key].join(',') if _.isArray(memo[key])
                return memo
            , {}

            _.extend query_params,
                start: start
                limit: options.rows_per_page


        render_data_row = (tbody, record, index) ->
            tr = $('<tr>').addClass('row').addClass(['odd', 'even'][index%2])
            tr.append $('<td>').html(index + 1).addClass('number')
            _.each columns_order, (key, index) ->
                td = $('<td>')
                td.addClass columns_descriptors[key].type
                td.addClass key.toLowerCase()
                rendered_string = mx.utils.render(record[key], columns_descriptors[key])

                td.html(rendered_string) unless key is 'SECID'
                if key is 'SECID'
                    a = $('<a>').attr('href', '#').data('secid', rendered_string)
                    a.html(rendered_string)

                    # add event listner
                    $(a).on 'click', ->
                        element = $(@)
                        unless !!element.data('key')
                            event.preventDefault()
                            event.stopPropagation()

                            deferred = mx.iss.security_index(element.data('secid'))
                            $.when(deferred).then (data) ->
                                datum = _.find data, (datum) -> datum.is_traded is 1
                                href  = options.url(datum.engine, datum.market, datum.boardid, datum.secid) if _.isFunction(options.url)
                                ekey  = [datum.engine, datum.market, datum.boardid, datum.secid].join(':')
                                element.attr('href', href || "##{ekey}")
                                element.data('key',  ekey)
                                a[0].click()

                    td.append(a)
                tr.append(td)
            tbody.append tr

        el.data_container.addClass('loading')

        el.data_table.hide()
        el.data_no_results.hide()

        el.paginator.hide()
        el.paginator_dup.hide()

        $.when(mx.iss.rms_stock(query_params)).then (data) ->
            el.data_container.removeClass('loading')
            if _.size(data.records) > 0
                el.data_table.show()
                el.data_table_tbody.empty()
                _.each data.records, (record, index) ->
                    render_data_row(el.data_table_tbody, record, index + data.cursor['INDEX'])
            else

                el.data_no_results.show()
            render_paginator el.paginator, data.cursor
            render_paginator el.paginator_dup, data.cursor



    ds = {} # data sources
    ds.sectypes   = mx.iss.security_types 'stock', { sectypes_only: true }
    ds.trademodes = mx.iss.trade_modes    'stock', { actual: true }
    ds.indices    = mx.iss.index_groups   'stock_index_listing'

    $.when(ds.sectypes, ds.trademodes, ds.indices).then (security_types, board_groups, index) ->
        security_types  = _.map security_types,    (sectype) -> { value: sectype.security_type_name, title: sectype.security_type_title }
        board_groups    = _.map board_groups,      (group)   -> { value: group.name,                 title: group.title }

        collateral      = _.map options.filters.collateral,(col)  -> { value: col.value,  title: col.title[mx.locale()] }
        listname        = _.map options.filters.listname,  (name) -> { value: name.value, title: name.title[mx.locale()] }

        index           = _.map index, (i) -> { value: i.indexid.replace('&', '__AND__'), title: "#{i.indexid} (#{i.shortname})" }
        index.unshift( { value: '__UNSELECTED__', title: l10n.filters.unselected })

        render_filters  el.filters_container,
            objects:
                security_types: security_types
                board_groups:   board_groups
                collateral:     collateral
                listname:       listname
                index:          index

            selected_objects:
                security_types: options.selected.security_types
                board_groups:   options.selected.board_groups
                collateral:     options.selected.collateral
                listname:       options.selected.listname

        render_data()


_.extend scope,
    rms2: widget