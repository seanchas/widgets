global = module?.exports ? ( exports ? this )

global.mx           ||= {}
global.mx.security  ||= {}

scope = global.mx.security

$ = jQuery


calculation_base =
    ru: 'База расчета'
    en: 'Calculation base'

indices_inclusion =
    ru: 'Входит в индексы'
    en: 'Included in indices'

create_table = ->
    $('<table>')
        .addClass('mx-security-description')
        .html('<thead></thead><tbody></tbody>')

make_row = (title, value) ->
    $('<tr>')
        .html("<th>#{title}</th><td>#{value || '&mdash;'}</td>")

make_divider_row = ->
    $('<tr>')
        .addClass('divider')
        .html("<td colspan=\"2\"></td>")

render = (element, description, security, columns, filters, indices, index_securities, options = {}) ->

    table = create_table()
    
    table_body = $ 'tbody', table
    
    description_names = _.pluck description, 'name'


    make_url = (id) ->
        if options.url? and _.isFunction(options.url)
            options.url undefined, undefined, undefined, id
        else
            "##{id}"

    for field in description
        field.value = mx.utils.parse_date(field.value) if field.type == 'date'
        field.value = 'RUB' if field.name == 'FACEUNIT' and field.value == 'SUR'


    mx.utils.process_record security, columns
    
    columns = _.compact(
        for filter in filters
            columns[filter.id]
    )
    
    columns = _.reduce columns, (memo, column) ->
        memo.push column if column.is_system == 0 and column.is_hidden == 0 and !_.include(description_names, column.name)
        memo
    , []
    
    for record in description
        table_body.append make_row record['title'], mx.utils.render(record['value'], record) if record.is_hidden == 0
    
    table_body.append make_divider_row

    for column in columns
        table_body.append make_row column.short_title, mx.utils.render(security[column.name], column) unless _.isEmpty(security)
    
    table_body.append make_row indices_inclusion[mx.locale()], ("<a href=\"#{make_url index['SECID']}\">#{index['SHORTNAME']}</a>" for index in indices).join(", ") if _.size(indices) > 0
    
    index_securities = _.reduce index_securities, (memo, ticker) ->
        memo.push ticker.secids.split(',')...
        memo
    , []

    table_body.append make_row calculation_base[mx.locale()], ("<a href=\"#{make_url ticker}\">#{ticker}</a>" for ticker in index_securities).join(", ") if _.size(index_securities) > 0
    
    element.html table


widget = (element, engine, market, board, param, options = {}) ->
    element = $ element
    
    return unless element.length > 0
    
    cds = mx.iss.columns(engine, market, { only: 'securities' })
    fds = mx.iss.filters(engine, market)
    sds = mx.iss.security(engine, market, board, param, { only: 'securities' })
    dds = mx.iss.description(param)
    ids = mx.iss.security_indices(param)
    isds = if engine == 'stock' and market == 'index' then mx.iss.index_securities(engine, market, param) else []
    
    $.when(dds, sds, cds, fds, ids, isds).then (description, security, columns, filters, indices, index_securities) ->
        
        unless _.isEmpty(filters)

            security = _.first(security)
        
            if security or description
                render element, description, security, columns, filters['full'], indices, index_securities, options
                element.trigger('render', { status: 'success' })
            else
                element.trigger('render', { status: 'failure' })
    
    {
        destroy: ->
            clearTimeout timeout if timeout?
            element.children().remove()
    }


_.extend scope,
    description: widget
