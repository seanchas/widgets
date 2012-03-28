##= require jquery
##= require jquery-ui
##= require underscore
##= require backbone
##= require mx.utils
##= require mx.iss
##= require mx.widgets.chart
##= require kizzy

global = module?.exports ? ( exports ? this )

global.mx           ||= {}
global.mx.widgets   ||= {}

scope = global.mx.widgets

$ = jQuery

cache = kizzy('widgets.table_dragdrop')


#_.extend scope,
#  table_dragdrop: widget
