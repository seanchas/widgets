global = exports ? this

global.mx        ?=  {}
global.mx.utils  ?=  {}

_u = global.mx.utils


number_with_delimiter = (number, options = {}) ->
    delimiter   = options.delimiter || ' '
    separator   = options.separator || ','

    parts = number.toString().split '.'
    
    parts[0] = parts[0].replace /(\d)(?=(\d\d\d)+(?!\d))/g, '$1' + delimiter

    parts.join(separator)


number_with_precision = (number, options = {}) ->
    precision = options.precision || 2
    
    number_with_delimiter(new Number(number.toString()).toFixed(precision), options)


_u.number_with_delimiter = number_with_delimiter
_u.number_with_precision = number_with_precision
