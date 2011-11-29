##= require jquery
##= require underscore
##= require json
##= require kizzy
##= require_self
##= require mx.utils
##= require mx.iss
##= require mx.cs
##= require mx.security.digest
##= require mx.security.chart
##= require mx.security.orderbook
##= require mx.security.emitter
##= require mx.security.description
##= require mx.security.boards



global = module?.exports ? ( exports ? this )

global.mx           ||= {}
global.mx.security  ||= {}

scope = global.mx.security

