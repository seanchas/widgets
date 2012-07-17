global           = @
global.mx      ||= {}
global.mx.auth ||= {}
scope            = global.mx.auth

# underscore.string mixin
_.mixin(_.str.exports());

locale = if mx.locale?      then mx.locale()      else 'ru'
server = if mx.auth.server? then mx.auth.server() else 'beta'

console.log mx.auth.server()

subdomains =
    web:   ''
    beta:  'beta.'

subdomain = subdomains[server] ? 'beta.'

domains = ["passport.#{subdomain}micex.ru", "passport.#{subdomain}micex.com"]

l10n =
    ru:
        login_url:    'Вход'
        logout:       'Выход из системы'
        registration: 'Регистрация'
        auth_domain:  "passport.#{subdomain}micex.ru"
        portals_urls: [
            ['Профиль пользователя на сайте ММВБ', "http://passport.#{subdomain}micex.ru/user"]
            ['Платежные реквизиты',                "http://services.#{subdomain}micex.ru/requisite"]
            ['Настройка профиля на форумах',       "http://forums.#{subdomain}micex.ru/user"]
        ]




CookieJar =

    options:
        expires: 300
        path:    ''
        domain:  ''
        secure:  ''

    get: (key) ->
        cookies = document.cookie.match("#{escape(String(key))}=(.*?)(;|$)")
        if cookies then unescape(cookies[1]) else null

    put: (key, value, options) ->
        try
            document.cookie = "#{escape(String(key))}=#{escape(String(value)) + @cookie_options(options)}"
            true
        catch error
            false

    remove: (key) ->
        @put(key, null, { expires: - 3600 })

    cookie_options: (options) ->
        result = Object.extend(Object.clone(@options), options || {})

        result.expires = if result.expires then "; expires=#{new Date(new Date().getTime() + result.expires * 1000).toGMTString()}" else ''
        result.path    = if result.path then "; path=#{escape(result.path)}" else ''
        result.domain  = if result.domain then "; domain=#{escape(result.domain)}" else ''
        result.secure  = if result.secure == 'secure' then '; secure' else '';

        result.expires + result.path + result.domain + result.secure;




class PassportManager


    constructor: (container, @options = {}) ->
        @container = $(container) ; unless @container then return
        @setup();
        @start();


    setup: () ->
        @domains          = domains
        @return_to        = if _.include( @domains, _.first(window.location.host.split(':')) ) then '' else "?return_to=#{window.location.href}"

        @login_url        = [l10n[locale].login,        "http://#{l10n[locale].auth_domain}/login#{@return_to}"]
        @logout_url       = [l10n[locale].logout,       "http://#{l10n[locale].auth_domain}/logout#{@return_to}"]
        @registration_url = [l10n[locale].registration, "http://#{l10n[locale].auth_domain}/registration"]
        @portals_urls     =  l10n[locale].portals_urls

        @portals_container = $("<div>").attr({ id: 'authentication_portals' }).css({ display: 'none' })
        $(document.body).append(@portals_container)

        @container.click (e) =>
            if _.size $(e.target).parent("li.user") > 0 then e.stop
            @portals_container.show()

        @portals_container.click (e) =>
            console.log e.currentTarget
            @portals_container.hide()



    start: () ->
        @prerender()
        @fetch_authenticated_user()


    authenticated: () ->
        !!@authenticated_user


    user_screen_name: () ->
        unless @authenticated() then return ''
        @_user_screen_name ||= @user_full_name() ? @authenticated_user.nickname
        _.truncate(@_user_screen_name, 35)


    user_full_name: () ->
        unless @authenticated() then return ''
        @_user_full_name   ||= _.compact([
            @authenticated_user.last_name
            @authenticated_user.first_name
            @authenticated_user.middle_name
        ]).join(' ')


    prerender: () ->
        user_screen_name = CookieJar.get('MicexPassportUser')
        if user_screen_name?
            @authenticated_user =
                nickname: user_screen_name
        @update()


    update: () ->
        @cleanup()

        if @authenticated()
            @portals_container.html(@portals_html())
            @container.html(@authenticated_html())
            CookieJar.put("MicexPassportUser", @user_screen_name())
        else
            @container.html(@unauthenticated_html())
            CookieJar.remove("MicexPassportUser")


    cleanup: () ->
        @_unauthenticated_html  = null;
        @_authenticated_html    = null;
        @_portals_html          = null;

        @_user_full_name        = null;
        @_user_screen_name      = null;


    fetch_authenticated_user: () ->
        @authenticated_user = null
        request = $.ajax
            url:   "/cu"
            type:  "GET"
            dataType: 'json'
            cache: false

        request.success (json) =>
            @authenticated_user = json

        request.complete () =>
            @update()


    to_link: (arr) ->
        $("<a>").attr('href', arr[1]).html(arr[0])


    to_list_link: (arr) ->
        $("<li>").append(@to_link(arr))


    authenticated_html: () ->
        @_authenticated_html ||= $("<ul>").append( $("<li>").addClass("user").append(@to_link([@user_screen_name(), '#'])) )


    unauthenticated_html: () ->
        @_unauthenticated_html ||= $("<ul>").append( @to_list_link(@login_url) ).append( @to_list_link(@registration_url))


    portals_html: () ->
        @_portals_html ||= $("<ul>").append( $("<li>").addClass("user").append(@to_link([@user_screen_name(), '#'])) )
        _.map(@portals_urls, (portal) => @_portals_html.append(@to_list_link(portal)) )
        @_portals_html.append( $("<li>").addClass("footer").append(@to_link(@logout_url) ) )




widget = (element) ->
    manager = new PassportManager(element)
    console.log "Ok! It works!"


_.extend scope,
    passport: widget

