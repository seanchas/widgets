global           = @
global.mx      ||= {}
global.mx.auth ||= {}
scope            = global.mx.auth

# underscore.string mixin
_.mixin(_.str.exports());

locale = if mx.locale?      then mx.locale()      else 'ru'
server = if mx.auth.server? then mx.auth.server() else 'beta'

subdomains =
    web:   ''
    beta:  'beta.'

subdomain = subdomains[server] ? 'beta.'

domains = ["passport.#{subdomain}micex.ru", "passport.#{subdomain}micex.com"]

l10n =
    ru:
        login:        'Вход'
        logout:       'Выход из системы'
        registration: 'Регистрация'
        user:         'Пользователь:'
        auth_domain:  "passport.#{subdomain}micex.ru"
        portals_urls: [
            ['Профиль пользователя на сайте', "http://passport.#{subdomain}micex.ru/user"]
            ['Профиль пользователя на форуме',       "http://forums.#{subdomain}micex.ru/user"]
            ['Платежные реквизиты',                "http://services.#{subdomain}micex.ru/requisite"]
        ]

    en:
        login:        'Login'
        logout:       'Logout'
        registration: 'Registration'
        user:         'User:'
        auth_domain:  "passport.#{subdomain}micex.com"
        portals_urls: [
            ['MICEX user profile',      "http://passport.#{subdomain}micex.com/user"]
            ['Payment requisites',      "http://services.#{subdomain}micex.com/requisite"]
            ['Forums profile settings', "http://forums.#{subdomain}micex.com/user"]
        ]

cache = kizzy('cu')




class PassportManager


    constructor: (container, @options = {}) ->
        @container = $(container) ; unless @container then return
        @container.addClass('mx-passport')
        @setup();
        @start();


    setup: () ->
        @domains          = domains
        @return_to        = if _.include( @domains, _.first(window.location.host.split(':')) ) then '' else "?return_to=#{window.location.href}"

        @login_url        = [l10n[locale].login,        "http://#{l10n[locale].auth_domain}/login#{@return_to}"]
        @logout_url       = [l10n[locale].logout,       "http://#{l10n[locale].auth_domain}/logout#{@return_to}"]
        @registration_url = [l10n[locale].registration, "http://#{l10n[locale].auth_domain}/registration"]
        @portals_urls     =  l10n[locale].portals_urls

        @portals_container = $("<div>")
            .attr({ id: 'authentication_portals' })
            .addClass('mx-passport-portals')
            .css({ display: 'none' })
        $(document.body).append(@portals_container)

        $(document).click (e) =>
            if $(e.current) then ''
            if _.size( $("li.user", $(e.currentTarget)) ) > 0 then @toggle()
        @portals_container.click (e) => @hide()


    toggle: () ->
        if @portals_container.is(":visible") then @hide() else @show()

    show: () ->
        @portals_container.slideDown(150)

    hide: () ->
        @portals_container.slideUp(150)

    positioning: () ->
        container_position       = @container.offset()
        container_position.top  += @container.outerHeight()
        container_position.left += @container.outerWidth() - @portals_container.outerWidth()
        @portals_container.css
            top:  container_position.top
            left: container_position.left


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
        ]).join(' ') || @authenticated_user.nickname


    prerender: () ->
        user_screen_name = cache.get('MicexPassportUser')
        if user_screen_name?
            @authenticated_user =
                nickname: user_screen_name
        @update()


    update: () ->
        @cleanup()

        if @authenticated()
            @portals_container.html(@portals_html())
            @positioning()
            @container.html(@authenticated_html())
            cache.set("MicexPassportUser", @user_screen_name(), 86400 * 1000)
        else
            @container.html(@unauthenticated_html())
            cache.remove("MicexPassportUser")


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
        @_authenticated_html ||= $("<ul>").append( $("<li>").addClass("user").append( $("<span>") ).append(@to_link([@user_screen_name(), '#'])) )


    unauthenticated_html: () ->
        @_unauthenticated_html ||= $("<ul>").append( @to_list_link(@login_url) ).append( @to_list_link(@registration_url))


    portals_html: () ->
        @_portals_html ||= $("<ul>")#.append( $("<li>").addClass("user").append(@to_link([@user_screen_name(), '#'])) )
        _.map(@portals_urls, (portal) => @_portals_html.append(@to_list_link(portal)) )
        @_portals_html.append( $("<li>").addClass("htube").append( $("<span>").html("&nbsp;") ) )
        @_portals_html.append( $("<li>").addClass("logout").append(@to_link(@logout_url) ) )




widget = (element) ->
    manager = new PassportManager(element)


_.extend scope,
    passport: widget

