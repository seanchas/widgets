##= require_self
##= require_tree ./mx.widgets.tiny

global = module?.exports ? ( exports ? this )

global.mx               ||= {}
global.mx.widgets       ||= {}
global.mx.widgets.tiny  ||= {}

scope = global.mx.widgets.tiny

$ = jQuery

