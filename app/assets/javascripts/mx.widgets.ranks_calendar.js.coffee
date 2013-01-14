global = module?.exports ? ( exports ? this )

global.mx           ||= {}
global.mx.widgets   ||= {}

scope = global.mx.widgets

$ = jQuery

localization =
    ru:
        datepicker_locale: "ru"
    en:
        datepicker_locale: "en-GB"

l10n = localization[mx.locale()]

$.datepicker.regional['ru'] =
    closeText:          'Закрыть'
    prevText:           '&#x3C;'
    nextText:           '&#x3E;'
    currentText:        'Сегодня'
    monthNames:         ['Январь','Февраль','Март','Апрель','Май','Июнь','Июль','Август','Сентябрь','Октябрь','Ноябрь','Декабрь']
    monthNamesShort:    ['Янв','Фев','Мар','Апр','Май','Июн','Июл','Авг','Сен','Окт','Ноя','Дек']
    dayNames:           ['воскресенье','понедельник','вторник','среда','четверг','пятница','суббота']
    dayNamesShort:      ['вск','пнд','втр','срд','чтв','птн','сбт']
    dayNamesMin:        ['Вс','Пн','Вт','Ср','Чт','Пт','Сб']
    weekHeader:         'Нед'
    dateFormat:         'dd.mm.yy'
    firstDay:           1
    isRTL:              false
    showMonthAfterYear: false
    yearSuffix:         ''

$.datepicker.setDefaults $.datepicker.regional[l10n.datepicker_locale]

widget = (element) ->
    element = $(element) ; return unless element.length > 0
    element.addClass("mx-widget-ranks-calendar")

    datepicker = $("<div>")

    link = mx.iss.iss_host + "/statistics/engines/stock/mmakers/ranks"

    links_container = $("<div>").addClass("links-container")
    link_to_csv = $("<a>").attr("href", "#").addClass("link-to-format csv")
    link_to_xml = $("<a>").attr("href", "#").addClass("link-to-format xml")
    alternate   = $("<input>")
        .addClass("datepicker-alternate")
        .attr
            disabled: "disabled"

    links_container
        .append(alternate)
        .append(link_to_csv)
        .append(link_to_xml)

    element.append(datepicker)
    element.append(links_container)

    render_links = (date) ->
        link_to_csv.attr("href", [link, ".csv", "?date=#{date}"].join("")).html("CSV")
        link_to_xml.attr("href", [link, ".xml", "?date=#{date}"].join("")).html("XML")


    datepicker.datepicker
        onSelect:          (date) -> render_links($(this).attr("value"))
        dateFormat:        "yy-mm-dd"
        altField:          alternate
        altFormat:         "DD, d M, yy"
        numberOfMonths:    1
        showOtherMonths:   true
        selectOtherMonths: true
        maxDate:           "-1D"

    render_links($.datepicker.formatDate( "yy-mm-dd", datepicker.datepicker("getDate") ) )

_.extend scope,
    ranks_calendar: widget