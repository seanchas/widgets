global = module?.exports ? ( exports ? this )

global.mx           ||= {}
global.mx.widgets   ||= {}

scope = global.mx.widgets

$ = jQuery

localization =
    ru:
        datepicker_locale: "ru"
        csv_options: "Параметры"
        csv_options_title: "Параметры выгрузки CSV"
        dp_label: "Разделитель для десятичных знаков"
        dp: "comma"
        delimiter_label: "Разделитель полей"
        delimiter: ";"
    en:
        datepicker_locale: "en-GB"
        csv_options: "Options"
        csv_options_title: "CSV rendering parameters"
        dp_label: "Decimals separator"
        dp: "point"
        delimiter_label: "Fields delimiter"
        delimiter: ";"

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

$.datepicker.regional['en-GB'] =
    prevText:           '&#x3C;'
    nextText:           '&#x3E;'

$.datepicker.setDefaults $.datepicker.regional[l10n.datepicker_locale]

widget = (element, options = {}) ->
    element = $(element) ; return unless element.length > 0
    element.addClass("mx-widget-ranks-calendar")


    iss_dp        = options.iss_dp        || l10n.dp
    iss_delimiter = options.iss_delimiter || l10n.delimiter

    link          = mx.iss.iss_host + "/statistics/engines/stock/mmakers/ranks"
    params        = "&iss.only=ranks&ranks.columns=TRADEDATE,SECID,RANK,VALUE,IS_THRESHOLD_AMOUNT"
    archive_date  = ""


    datepicker = $("<div>").addClass("ranks-archive-datepicker")

    alternate   = $("<input>")
        .addClass("datepicker-alternate")
        .attr({ disabled: "disabled" })

    csv_options_template  = """
    <ul class="links-container">
        <li class="link_to_format">
            <a href="#" class="csv-link">CSV</a>
            <a class="csv-options-link">#{l10n.csv_options}</a>
        </li>
        <li class="link_to_format">
            <a href="#" class="xml-link">XML</a>
        </li>
    </ul>
    <div id="csv-options-container">
        <fieldset>
            <legend>#{l10n.csv_options_title}</legend>
            <label>#{l10n.dp_label}</label>
            <select id="csv-dp-select">
                <option value="comma" #{"selected=\"selected\"" if iss_dp is "comma"}>,</option>
                <option value="point" #{"selected=\"selected\"" if iss_dp is "point"}>.</option>
            </select><br />
            <label>#{l10n.delimiter_label}</label>
            <input id="csv-delimiter-input" size="1" value="#{iss_delimiter}"><br />
        </fieldset>
    </div>
    """

    element.append(datepicker)
    element.append(alternate)
    element.append(csv_options_template)

    datepicker.datepicker
        onSelect:          (date) ->
            archive_date = $(this).attr("value")
            update_links()
        dateFormat:        "yy-mm-dd"
        altField:          alternate
        altFormat:         "DD, d M, yy"
        numberOfMonths:    1
        showOtherMonths:   true
        selectOtherMonths: true
        maxDate:           "-1D"

    archive_date = $.datepicker.formatDate( "yy-mm-dd", datepicker.datepicker("getDate") )

    links_container       = $(".links-container", element)
    csv_options_container = $("#csv-options-container", element)
    csv_options_link      = $(".csv-options-link", links_container)
    link_to_csv           = $(".csv-link", links_container)
    link_to_xml           = $(".xml-link", links_container)

    csv_options_container.hide()

    start_events = () ->
        csv_options_link.click () ->
            $(this).toggleClass("active")
            csv_options_container.toggle()

        $("#csv-dp-select", csv_options_container).change () ->
            iss_dp = $(this).find(":selected").val()
            update_links()
        $("#csv-delimiter-input", csv_options_container).keyup () ->
            iss_delimiter = $(this).val()
            update_links()

    update_links = () ->
        link_to_csv.attr("href", [link, ".csv", "?iss.dp=#{iss_dp}&iss.delimiter=#{iss_delimiter}&date=#{archive_date}", params].join("")).html("CSV")
        link_to_xml.attr("href", [link, ".xml", "?date=#{archive_date}", params].join("")).html("XML")

    start_events()
    update_links()

_.extend scope,
    ranks_calendar: widget