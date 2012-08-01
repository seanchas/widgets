##= require base64
##= require monster
##= require mx.locale
##= require_self
##= require mx.auth.passport

global           = @
global.mx      ||= {}
global.mx.auth ||= {}
scope            = global.mx.auth

server = () ->
    _.intersection((window.location.host.split(':')[0]).split('.'), ['local', 'dev', 'beta', 'web'])[0]

_.extend scope,
    server: server