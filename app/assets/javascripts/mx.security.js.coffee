##= require jquery
##= require underscore
##= require_self
##= require mx.utils
##= require mx.iss
##= require mx.cs
##= require mx.security.digest
##= require mx.security.chart
##= require mx.security.orderbook

global = module?.exports ? ( exports ? this )

global.mx           ||= {}
global.mx.security  ||= {}

scope = global.mx.security

