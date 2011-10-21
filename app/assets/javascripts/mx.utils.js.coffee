global = module?.exports ? ( exports ? this )

global.mx        ?=  {}
global.mx.utils  ?=  {}

scope = global.mx.utils


number_with_delimiter = (number, options = {}) ->
    delimiter   = options.delimiter || ' '
    separator   = options.separator || ','

    parts = number.toString().split '.'
    
    parts[0] = parts[0].replace /(\d)(?=(\d\d\d)+(?!\d))/g, '$1' + delimiter

    parts.join(separator)


number_with_precision = (number, options = {}) ->
    precision = options.precision || 2
    
    number_with_delimiter(new Number(number.toString()).toFixed(precision), options)

extract_options = (args) ->
    options = _.last(args)
    if typeof options == 'object' then options else {}


_.extend scope,
    number_with_delimiter:  number_with_delimiter
    number_with_precision:  number_with_precision
    extract_options:        extract_options
