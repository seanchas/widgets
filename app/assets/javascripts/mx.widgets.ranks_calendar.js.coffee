global = module?.exports ? ( exports ? this )

global.mx           ||= {}
global.mx.widgets   ||= {}

scope = global.mx.widgets

$ = jQuery

widget = (element) ->
    return

_.extend scope,
    ranks_calendar: widget