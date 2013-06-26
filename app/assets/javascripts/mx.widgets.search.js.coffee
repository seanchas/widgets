## Work in progress

global = module?.exports ? ( exports ? this )

global.mx           ||= {}
global.mx.widgets   ||= {}

scope = global.mx.widgets

# widget preset
preset =
    default_locale:           'ru'
    default_search_limit:      10
    cursor_threshold_timeout:  300


# returns localized labels
localize = (locale) ->

    localization =
        ru:
            placeholder: 'Поиск'
        en:
            placeholder: 'Search'

    return if _.contains _.keys(localization), locale
        localization[locale]
    else
        localization[preset.default_locale]


# preceed search query with options
search = _.debounce (query, callback, options = {}) ->
    return if typeof(query) is not 'string' and typeof(callback) is not 'function'

    known_keys = ['engine', 'market', 'limit', 'is_trading', 'group_by', 'force']
    options    = _.reduce options, (memo, value, key) ->
        memo[key] = value if _.contains known_keys, key
        return memo
    , {}

    $.when(mx.iss.search(query, options)).then (data) -> callback(data)
, preset.cursor_threshold_timeout


# fill list element
fill_list = (element, data) ->
    element = $(element) ; return unless element?.size() > 0

    element.empty()

    return unless data?.length

    for row in data
        option = $("<li>").html(row.name)
        element.append(option)


# initialize widget
widget = (element, options = {}) ->
    element = $(element) ; return unless element?.size() > 0

    # localize by current language
    l10n = localize mx.locale()

    element
        .empty()
        .addClass('mx-widget-search')

    is_callback_present = options.onSelect? and typeof(options.onSelect) is 'function'
    callback            = options.onSelect  if is_callback_present


    # setting default options
    options.limit      ?= preset.default_search_limit


    #main elements reference
    els =
        wrapper:    $('<div>').addClass('search-field-wrapper')
        search:     $('<input>').attr({ type: 'text' }).addClass('search-field clearable')
        icon_clear: $('<span>').addClass('icon-clear')
        list:       $('<ul>').addClass('list-results')


    #prerender
    prerender = () ->
        els.wrapper
            .append(els.search)
            .append(els.icon_clear)
        element
            .append(els.wrapper)
            .append(els.list)


    # events listners
    start_events = () ->
        search_callback = (data) ->
            fill_list(els.list, data)
            els.wrapper.removeClass('loading')

        #search text writing event
        els.search.on 'keyup',  (event) ->
            el    = $(@)
            value = el.val()
            if value.length > 2
                els.wrapper.addClass('loading')
                search(value, search_callback, options)
            else els.list.empty()


    prerender()
    start_events()


_.extend scope,
    search: widget