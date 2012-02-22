global = module?.exports ? ( exports ? this )

global.mx       ||= {}
global.mx.i18n  ||= {}

$ = jQuery

scope = global.mx.i18n

default_locale = 'ru'

scope.locale = default_locale
