##= require jquery
##= require json
##= require underscore
##= require highstock
##= require_self
##= require mx.widgets.table
##= require mx.widgets.chart
##= require mx.widgets.orderbook
##= require mx.widgets.description
##= require mx.widgets.security
##= require mx.widgets.security.emitter
##= require mx.widgets.security.chart
##= require mx.widgets.turnovers
##= require mx.widgets.ticker
##= require mx.widgets.indices
##= require mx.widgets.shares
##= require mx.cs

global = module?.exports ? ( exports ? this )

global.mx           ||= {}
global.mx.widgets   ||= {}

scope = global.mx.widgets


render = (value, descriptor = {}) ->
    switch descriptor.type
        when 'number'   then render_number  value, descriptor
        when 'date'     then render_date    value
        else value


render_number = (value, descriptor = {}) ->
    return value unless value? and typeof value == 'number'
    
    value_for_render = mx.utils.number_with_precision value, { precision: descriptor.precision }
    
    if descriptor.is_singed == 1 and value > 0
        value_for_render = '+' + value_for_render
    
    if descriptor.has_percent == 1
        value_for_render = value_for_render + '%'

    value_for_render


render_date = (value) ->
    return value unless value? and value instanceof Date
    
    f = (n) -> if n > 10 then '' + n else '0' + n
    
    "#{f value.getDate()}.#{f value.getMonth() + 1}.#{value.getFullYear()}"


_.extend scope,
    utils:
        render_value:    render
