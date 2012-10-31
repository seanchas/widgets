##= require mx.locale

global = module?.exports ? ( exports ? this )

global.mx        ?=  {}
global.mx.utils  ?=  {}

scope = global.mx.utils

number_with_delimiter_options =
    ru:
        delimiter: ' '
        separator: ','
    en:
        delimiter: ','
        separator: '.'

number_with_delimiter = (number, options = {}) ->
    return '-' unless number?

    delimiter   = options.delimiter || number_with_delimiter_options[mx.locale()].delimiter
    separator   = options.separator || number_with_delimiter_options[mx.locale()].separator

    parts = number.toString().split '.'
    
    parts[0] = parts[0].replace /(\d)(?=(\d\d\d)+(?!\d))/g, '$1' + delimiter

    parts.join(separator)


number_with_precision = (number, options = {}) ->
    return '-' unless number?
    
    precision = options.precision ? 2
    
    number_with_delimiter(new Number(number.toString()).toFixed(precision), options)


power_amounts =
    6:      { ru: 'Млн', en: 'M' }
    9:      { ru: 'Млрд', en: 'G' }
    12:     { ru: 'Трлн', en: 'T' }

number_with_power = (number, options = {}) ->
    return '-' unless number?

    degree_shift = (parseInt(options.shift || 0) * 3)
    
    digits      = Math.ceil(Math.log(number) / Math.LN10);
    max_amount  = 0;

    for amount, label of power_amounts
        amount = parseInt(amount)
        max_amount = amount if max_amount < amount and amount <= digits

    max_amount = max_amount - degree_shift if max_amount >= degree_shift

    base = if max_amount > 0 then ' ' + power_amounts[max_amount][mx.locale()] else ''

    number_with_precision(number / Math.pow(10, max_amount), options) + (base)
    

extract_options = (args) ->
    options = _.last(args)
    if typeof options == 'object' then options else {}


date_re = /^(\d{4})-(\d{2})-(\d{2})$/
time_re = /^(\d{2}):(\d{2}):(\d{2})$/

parse_date = (value) ->
    if _.isString(value)
        [date, time] = value.split(' ')
        date_parts = date_re.exec(date)
        time_parts = time_re.exec(time) ? []
        if date_parts
            value = new Date(
                +date_parts[1],
                +date_parts[2] - 1,
                +date_parts[3],
                +time_parts[1] || 0,
                +time_parts[2] || 0,
                +time_parts[3] || 0
            )
    value

process_record = (record, columns, by_name = false) ->
    return record unless record?
    
    decimals = record['DECIMALS']

    record.precisions = {}

    for name, value of record

        column = _.first(column for id, column of columns when column.name == name)

        continue unless column?

        record[name] = switch column.type
            when 'string'
                if name == 'FACEUNIT' and value == 'SUR' then 'RUB' else value
            when 'number'
                record.precisions[name] = if column.has_percent == 1 then 2 else column.precision ? decimals
                if value? then parseFloat(new Number(value).toFixed(record.precisions[name])) else value
            when 'date'
                parse_date value
            when 'time'
                if value? then _.first(value.split(':'), 2).join(':') else value
    
    record.trends = {}

    for id, column of columns
        if column.trend_by
            trending_column = columns[column.trend_by]
            record.trends[column.name] = record[trending_column.name] if trending_column?

    record
        
render = (value, descriptor = {}) ->
    switch descriptor.type
        when 'number'   then render_number  value, descriptor
        when 'date'     then render_date    value
        else value


render_number = (value, descriptor = {}) ->
    return value unless value?

    value_for_render = mx.utils.number_with_precision value, { precision: descriptor.precision }

    if descriptor.is_signed == 1 and value > 0
        value_for_render = '+' + value_for_render

    if descriptor.has_percent == 1
        value_for_render = value_for_render + '%'

    value_for_render


render_date = (value) ->
    return value unless value? and value instanceof Date

    f = (n) -> if n < 10 then '0' + n else '' + n

    "#{f value.getDate()}.#{f value.getMonth() + 1}.#{value.getFullYear()}"


sha1 = (string) ->
    
    digits = '0123456789abcdef'
    
    rotate = (number, shift) ->
        (number << shift) | (number >>> (32 - shift))
    
    digest = (data) ->
        result = ''
        for i in [0 ... 20]
            result +=   digits.charAt((data[i >> 2] >> ((3 - i % 4) * 8 + 4)) & 0xf) +
                        digits.charAt((data[i >> 2] >> ((3 - i % 4) * 8 + 0)) & 0xf)
        result
        
    
    h = [
        0x67452301
        0xEFCDAB89
        0x98BADCFE
        0x10325476
        0xC3D2E1F0
    ]
    
    k = [
        0x5A827999
        0x6ED9EBA1
        0x8F1BBCDC
        0xCA62C1D6
    ]
    
    n = 0x0ffffffff
    
    # prepare
    
    l = string.length
    
    words = for i in [0 ... l - 3] by 4
        string.charCodeAt(i + 0) << 24 |
        string.charCodeAt(i + 1) << 16 |
        string.charCodeAt(i + 2) <<  8 |
        string.charCodeAt(i + 3)

    words.push switch l % 4
        when 0 then 0x080000000
        when 1 then string.charCodeAt(l - 1) << 24 | 0x0800000
        when 2 then string.charCodeAt(l - 2) << 24 | string.charCodeAt(l - 1) << 16 | 0x08000
        when 3 then string.charCodeAt(l - 3) << 24 | string.charCodeAt(l - 2) << 16 | string.charCodeAt(l - 1) << 8 | 0x080

    while (words.length % 16) != 14
        words.push 0
    
    words.push l >>> 29
    words.push (l << 3) & n
    
    # calculation
    
    w = []
    
    for i in [0 ... words.length] by 16
        
        w[j] = words[i + j]                                             for j in [0 ... 16]
        w[j] = rotate w[j - 3] ^ w[j - 8] ^ w[j - 14] ^ w[j - 16], 1    for j in [16 ... 80]
        
        a = h[0]
        b = h[1]
        c = h[2]
        d = h[3]
        e = h[4]
        
        for j in [0 ... 80]
            
            t = if (j < 20)
                (rotate(a, 5) + ((b & c) | (~ b & d)) + e + w[j] + k[0]) & n
            else if (j < 40)
                (rotate(a, 5) + (b ^ c ^ d) + e + w[j] + k[1]) & n
            else if (j < 60)
                (rotate(a, 5) + ((b & c) | (b & d) | (c & d)) + e + w[j] + k[2]) & n
            else
                (rotate(a, 5) + (b ^ c ^ d) + e + w[j] + k[3]) & n
            
            e = d
            d = c
            c = rotate b, 30
            b = a
            a = t
        
        h[0] = (h[0] + a) & n
        h[1] = (h[1] + b) & n
        h[2] = (h[2] + c) & n
        h[3] = (h[3] + d) & n
        h[4] = (h[4] + e) & n
    
    # formatting
    
    digest h


_.extend scope,
    number_with_delimiter:  number_with_delimiter
    number_with_precision:  number_with_precision
    number_with_power:      number_with_power
    extract_options:        extract_options
    process_record:         process_record
    parse_date:             parse_date
    sha1:                   sha1
    render:                 render


# console.log sha1('')