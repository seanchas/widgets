global = module?.exports ? ( exports ? this )

global.mx           ||= {}

scope = global.mx

available_locales = ['ru', 'en']
default_locale = 'ru'

scope.__locale = default_locale

scope.locale = (locale) ->
    scope.__locale = locale if locale and _.include(available_locales, locale)
    scope.__locale
