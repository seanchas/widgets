/*!
  * =============================================================
  * Ender: open module JavaScript framework (https://ender.no.de)
  * Build: ender build reqwest bean domready qwery scriptjs bonzo jeesh underscore
  * =============================================================
  */

/*!
  * Ender: open module JavaScript framework (client-lib)
  * copyright Dustin Diaz & Jacob Thornton 2011 (@ded @fat)
  * http://ender.no.de
  * License MIT
  */
!function (context) {

  // a global object for node.js module compatiblity
  // ============================================

  context['global'] = context

  // Implements simple module system
  // losely based on CommonJS Modules spec v1.1.1
  // ============================================

  var modules = {}
    , old = context.$

  function require (identifier) {
    var module = modules[identifier] || window[identifier]
    if (!module) throw new Error("Requested module '" + identifier + "' has not been defined.")
    return module
  }

  function provide (name, what) {
    return (modules[name] = what)
  }

  context['provide'] = provide
  context['require'] = require

  // Implements Ender's $ global access object
  // =========================================

  function aug(o, o2) {
    for (var k in o2) k != 'noConflict' && k != '_VERSION' && (o[k] = o2[k])
    return o
  }

  function boosh(s, r, els) {
    // string || node || nodelist || window
    if (ender._select && (typeof s == 'string' || s.nodeName || s.length && 'item' in s || s == window)) {
      els = ender._select(s, r)
      els.selector = s
    } else els = isFinite(s.length) ? s : [s]
    return aug(els, boosh)
  }

  function ender(s, r) {
    return boosh(s, r)
  }

  aug(ender, {
      _VERSION: '0.3.4'
    , fn: boosh // for easy compat to jQuery plugins
    , ender: function (o, chain) {
        aug(chain ? boosh : ender, o)
      }
    , _select: function (s, r) {
        return (r || document).querySelectorAll(s)
      }
  })

  aug(boosh, {
    forEach: function (fn, scope, i) {
      // opt out of native forEach so we can intentionally call our own scope
      // defaulting to the current item and be able to return self
      for (i = 0, l = this.length; i < l; ++i) i in this && fn.call(scope || this[i], this[i], i, this)
      // return self for chaining
      return this
    },
    $: ender // handy reference to self
  })

  ender.noConflict = function () {
    context.$ = old
    return this
  }

  if (typeof module !== 'undefined' && module.exports) module.exports = ender
  // use subscript notation as extern for Closure compilation
  context['ender'] = context['$'] = context['ender'] || ender

}(this);

!function () {

  var module = { exports: {} }, exports = module.exports;

  /*!
    * Reqwest! A general purpose XHR connection manager
    * (c) Dustin Diaz 2011
    * https://github.com/ded/reqwest
    * license MIT
    */
  
  !function (name, definition) {
    if (typeof define == 'function') define(definition)
    else if (typeof module != 'undefined') module.exports = definition()
    else this[name] = definition()
  }('reqwest', function () {
  
    var context = this
      , win = window
      , doc = document
      , old = context.reqwest
      , twoHundo = /^20\d$/
      , byTag = 'getElementsByTagName'
      , readyState = 'readyState'
      , contentType = 'Content-Type'
      , head = doc[byTag]('head')[0]
      , uniqid = 0
      , lastValue // data stored by the most recent JSONP callback
      , xhr = ('XMLHttpRequest' in win) ?
          function () {
            return new XMLHttpRequest()
          } :
          function () {
            return new ActiveXObject('Microsoft.XMLHTTP')
          }
  
    function handleReadyState(o, success, error) {
      return function () {
        if (o && o[readyState] == 4) {
          if (twoHundo.test(o.status)) {
            success(o)
          } else {
            error(o)
          }
        }
      }
    }
  
    function setHeaders(http, o) {
      var headers = o.headers || {}
      headers.Accept = headers.Accept || 'text/javascript, text/html, application/xml, text/xml, */*'
  
      // breaks cross-origin requests with legacy browsers
      if (!o.crossOrigin) {
        headers['X-Requested-With'] = headers['X-Requested-With'] || 'XMLHttpRequest'
      }
      headers[contentType] = headers[contentType] || 'application/x-www-form-urlencoded'
      for (var h in headers) {
        headers.hasOwnProperty(h) && http.setRequestHeader(h, headers[h])
      }
    }
  
    function getCallbackName(o, reqId) {
      var callbackVar = o.jsonpCallback || "callback"
      if (o.url.slice(-(callbackVar.length + 2)) == (callbackVar + "=?")) {
        // Generate a guaranteed unique callback name
        var callbackName = "reqwest_" + reqId
  
        // Replace the ? in the URL with the generated name
        o.url = o.url.substr(0, o.url.length - 1) + callbackName
        return callbackName
      } else {
        // Find the supplied callback name
        var regex = new RegExp(callbackVar + "=([\\w]+)")
        return o.url.match(regex)[1]
      }
    }
  
    // Store the data returned by the most recent callback
    function generalCallback(data) {
      lastValue = data
    }
  
    function getRequest(o, fn, err) {
      if (o.type == 'jsonp') {
        var script = doc.createElement('script')
          , loaded = 0
          , reqId = uniqid++
  
        // Add the global callback
        win[getCallbackName(o, reqId)] = generalCallback
  
        // Setup our script element
        script.type = 'text/javascript'
        script.src = o.url
        script.async = true
        if (typeof script.onreadystatechange !== 'undefined') {
            // need this for IE due to out-of-order onreadystatechange(), binding script
            // execution to an event listener gives us control over when the script
            // is executed. See http://jaubourg.net/2010/07/loading-script-as-onclick-handler-of.html
            script.event = 'onclick'
            script.htmlFor = script.id = '_reqwest_' + reqId
        }
  
        script.onload = script.onreadystatechange = function () {
          if ((script[readyState] && script[readyState] !== "complete" && script[readyState] !== "loaded") || loaded) {
            return false
          }
          script.onload = script.onreadystatechange = null
          script.onclick && script.onclick()
          // Call the user callback with the last value stored
          // and clean up values and scripts.
          o.success && o.success(lastValue)
          lastValue = undefined
          head.removeChild(script)
          loaded = 1
        }
  
        // Add the script to the DOM head
        head.appendChild(script)
      } else {
        var http = xhr()
          , method = (o.method || 'GET').toUpperCase()
          , url = (typeof o === 'string' ? o : o.url)
          // convert non-string objects to query-string form unless o.processData is false 
          , data = o.processData !== false && o.data && typeof o.data !== 'string'
            ? reqwest.toQueryString(o.data)
            : o.data || null
  
        // if we're working on a GET request and we have data then we should append
        // query string to end of URL and not post data
        method == 'GET' && data && data !== '' && (url += (/\?/.test(url) ? '&' : '?') + data) && (data = null)
        http.open(method, url, true)
        setHeaders(http, o)
        http.onreadystatechange = handleReadyState(http, fn, err)
        o.before && o.before(http)
        http.send(data)
        return http
      }
    }
  
    function Reqwest(o, fn) {
      this.o = o
      this.fn = fn
      init.apply(this, arguments)
    }
  
    function setType(url) {
      if (/\.json$/.test(url)) {
        return 'json'
      }
      if (/\.jsonp$/.test(url)) {
        return 'jsonp'
      }
      if (/\.js$/.test(url)) {
        return 'js'
      }
      if (/\.html?$/.test(url)) {
        return 'html'
      }
      if (/\.xml$/.test(url)) {
        return 'xml'
      }
      return 'js'
    }
  
    function init(o, fn) {
      this.url = typeof o == 'string' ? o : o.url
      this.timeout = null
      var type = o.type || setType(this.url)
        , self = this
      fn = fn || function () {}
  
      if (o.timeout) {
        this.timeout = setTimeout(function () {
          self.abort()
        }, o.timeout)
      }
  
      function complete(resp) {
        o.timeout && clearTimeout(self.timeout)
        self.timeout = null
        o.complete && o.complete(resp)
      }
  
      function success(resp) {
        var r = resp.responseText
        if (r) {
          switch (type) {
          case 'json':
            try {
              resp = win.JSON ? win.JSON.parse(r) : eval('(' + r + ')')          
            } catch(err) {
              return error(resp, 'Could not parse JSON in response', err)
            }
            break;
          case 'js':
            resp = eval(r)
            break;
          case 'html':
            resp = r
            break;
          }
        }
  
        fn(resp)
        o.success && o.success(resp)
  
        complete(resp)
      }
  
      function error(resp, msg, t) {
        o.error && o.error(resp, msg, t)
        complete(resp)
      }
  
      this.request = getRequest(o, success, error)
    }
  
    Reqwest.prototype = {
      abort: function () {
        this.request.abort()
      }
  
    , retry: function () {
        init.call(this, this.o, this.fn)
      }
    }
  
    function reqwest(o, fn) {
      return new Reqwest(o, fn)
    }
  
    // normalize newline variants according to spec -> CRLF
    function normalize(s) {
      return s ? s.replace(/\r?\n/g, '\r\n') : ''
    }
  
    var isArray = typeof Array.isArray == 'function' ? Array.isArray : function(a) {
      return Object.prototype.toString.call(a) == '[object Array]'
    }
  
    function serial(el, cb) {
      var n = el.name
        , t = el.tagName.toLowerCase()
        , o
  
      // don't serialize elements that are disabled or without a name
      if (el.disabled || !n) return;
  
      switch (t) {
      case 'input':
        if (!/reset|button|image|file/i.test(el.type)) {
          var ch = /checkbox/i.test(el.type)
            , ra = /radio/i.test(el.type)
            , val = el.value;
          // WebKit gives us "" instead of "on if a checkbox has no value, so correct it here
          (!(ch || ra) || el.checked) && cb(n, normalize(ch && val === '' ? 'on' : val))
        }
        break;
      case 'textarea':
        cb(n, normalize(el.value))
        break;
      case 'select':
        if (el.type.toLowerCase() === 'select-one') {
          o = el.selectedIndex >= 0 ? el.options[el.selectedIndex] : null
          o && !o.disabled && cb(n, normalize(o.value || o.text))
        } else {
          for (var i = 0; el.length && i < el.length; i++) {
            o = el.options[i]
            o.selected && !o.disabled && cb(n, normalize(o.value || o.text))
          }
        }
        break;
      }
    }
  
    // collect up all form elements found from the passed argument elements all
    // the way down to child elements; pass a '<form>' or form fields.
    // called with 'this'=callback to use for serial() on each element
    function eachFormElement() {
      var cb = this
        , serializeSubtags = function(e, tags) {
          for (var i = 0; i < tags.length; i++) {
            var fa = e[byTag](tags[i])
            for (var j = 0; j < fa.length; j++) serial(fa[j], cb)
          }
        }
  
      for (var i = 0; i < arguments.length; i++) {
        var e = arguments[i]
        if (/input|select|textarea/i.test(e.tagName)) serial(e, cb);
        serializeSubtags(e, [ 'input', 'select', 'textarea' ])
      }
    }
  
    // standard query string style serialization
    function serializeQueryString() {
      return reqwest.toQueryString(reqwest.serializeArray.apply(null, arguments))
    }
  
    // { 'name': 'value', ... } style serialization
    function serializeHash() {
      var hash = {}
      eachFormElement.apply(function(name, value) {
        if (name in hash) {
          hash[name] && !isArray(hash[name]) && (hash[name] = [hash[name]])
          hash[name].push(value)
        } else hash[name] = value
      }, arguments)
      return hash
    }
  
    // [ { name: 'name', value: 'value' }, ... ] style serialization
    reqwest.serializeArray = function () {
      var arr = []
      eachFormElement.apply(function(name, value) {
        arr.push({name: name, value: value})
      }, arguments)
      return arr 
    }
  
    reqwest.serialize = function () {
      if (arguments.length === 0) return "";
      var opt, fn
        , args = Array.prototype.slice.call(arguments, 0)
  
      opt = args.pop()
      opt && opt.nodeType && args.push(opt) && (opt = null)
      opt && (opt = opt.type)
  
      if (opt == 'map') fn = serializeHash
      else if (opt == 'array') fn = reqwest.serializeArray
      else fn = serializeQueryString
  
      return fn.apply(null, args)
    }
  
    reqwest.toQueryString = function(o) {
      var qs = '', i
        , enc = encodeURIComponent
        , push = function(k, v) {
            qs += enc(k) + '=' + enc(v) + '&'
          }
  
      if (isArray(o)) {
        for (i = 0; o && i < o.length; i++) push(o[i].name, o[i].value)
      } else {
        for (var k in o) {
          if (!Object.hasOwnProperty.call(o, k)) continue;
          var v = o[k]
          if (isArray(v)) {
            for (i = 0; i < v.length; i++) push(k, v[i])
          } else push(k, o[k])
        }
      }
  
      // spaces should be + according to spec
      return qs.replace(/&$/, '').replace(/%20/g,'+')
    }
  
    reqwest.noConflict = function () {
      context.reqwest = old
      return this
    }
  
    return reqwest
  })

  provide("reqwest", module.exports);

  !function ($) {
    var r = require('reqwest')
      , integrate = function(method) {
        return function() {
          var args = (this && this.length > 0 ? this : []).concat(Array.prototype.slice.call(arguments, 0))
          return r[method].apply(null, args)
        }
      }
      , s = integrate('serialize')
      , sa = integrate('serializeArray')
  
    $.ender({
      ajax: r
      , serialize: s
      , serializeArray: sa
      , toQueryString: r.toQueryString
    })
  
    $.ender({
      serialize: s
      , serializeArray: sa
    }, true)
  }(ender);
  

}();

!function () {

  var module = { exports: {} }, exports = module.exports;

  /*!
    * bean.js - copyright Jacob Thornton 2011
    * https://github.com/fat/bean
    * MIT License
    * special thanks to:
    * dean edwards: http://dean.edwards.name/
    * dperini: https://github.com/dperini/nwevents
    * the entire mootools team: github.com/mootools/mootools-core
    */
  !function (name, definition) {
    if (typeof module != 'undefined') module.exports = definition();
    else if (typeof define == 'function' && typeof define.amd  == 'object') define(definition);
    else this[name] = definition();
  }('bean', function () {
    var win = window,
        __uid = 1,
        registry = {},
        collected = {},
        overOut = /over|out/,
        namespace = /[^\.]*(?=\..*)\.|.*/,
        stripName = /\..*/,
        addEvent = 'addEventListener',
        attachEvent = 'attachEvent',
        removeEvent = 'removeEventListener',
        detachEvent = 'detachEvent',
        doc = document || {},
        root = doc.documentElement || {},
        W3C_MODEL = root[addEvent],
        eventSupport = W3C_MODEL ? addEvent : attachEvent,
  
    isDescendant = function (parent, child) {
      var node = child.parentNode;
      while (node !== null) {
        if (node == parent) {
          return true;
        }
        node = node.parentNode;
      }
    },
  
    retrieveUid = function (obj, uid) {
      return (obj.__uid = uid && (uid + '::' + __uid++) || obj.__uid || __uid++);
    },
  
    retrieveEvents = function (element) {
      var uid = retrieveUid(element);
      return (registry[uid] = registry[uid] || {});
    },
  
    listener = W3C_MODEL ? function (element, type, fn, add) {
      element[add ? addEvent : removeEvent](type, fn, false);
    } : function (element, type, fn, add, custom) {
      if (custom && add && element['_on' + custom] === null) {
        element['_on' + custom] = 0;
      }
      element[add ? attachEvent : detachEvent]('on' + type, fn);
    },
  
    nativeHandler = function (element, fn, args) {
      return function (event) {
        event = fixEvent(event || ((this.ownerDocument || this.document || this).parentWindow || win).event);
        return fn.apply(element, [event].concat(args));
      };
    },
  
    customHandler = function (element, fn, type, condition, args) {
      return function (event) {
        if (condition ? condition.apply(this, arguments) : W3C_MODEL ? true : event && event.propertyName == '_on' + type || !event) {
          event = event ? fixEvent(event || ((this.ownerDocument || this.document || this).parentWindow || win).event) : null;
          fn.apply(element, Array.prototype.slice.call(arguments, event ? 0 : 1).concat(args));
        }
      };
    },
  
    addListener = function (element, orgType, fn, args) {
      var type = orgType.replace(stripName, ''),
          events = retrieveEvents(element),
          handlers = events[type] || (events[type] = {}),
          originalFn = fn,
          uid = retrieveUid(fn, orgType.replace(namespace, ''));
      if (handlers[uid]) {
        return element;
      }
      var custom = customEvents[type];
      if (custom) {
        fn = custom.condition ? customHandler(element, fn, type, custom.condition) : fn;
        type = custom.base || type;
      }
      var isNative = nativeEvents[type];
      fn = isNative ? nativeHandler(element, fn, args) : customHandler(element, fn, type, false, args);
      isNative = W3C_MODEL || isNative;
      if (type == 'unload') {
        var org = fn;
        fn = function () {
          removeListener(element, type, fn) && org();
        };
      }
      element[eventSupport] && listener(element, isNative ? type : 'propertychange', fn, true, !isNative && type);
      handlers[uid] = fn;
      fn.__uid = uid;
      fn.__originalFn = originalFn;
      return type == 'unload' ? element : (collected[retrieveUid(element)] = element);
    },
  
    removeListener = function (element, orgType, handler) {
      var uid, names, uids, i, events = retrieveEvents(element), type = orgType.replace(stripName, '');
      if (!events || !events[type]) {
        return element;
      }
      names = orgType.replace(namespace, '');
      uids = names ? names.split('.') : [handler.__uid];
  
      function destroyHandler(uid) {
        handler = events[type][uid];
        if (!handler) {
          return;
        }
        delete events[type][uid];
        if (element[eventSupport]) {
          type = customEvents[type] ? customEvents[type].base : type;
          var isNative = W3C_MODEL || nativeEvents[type];
          listener(element, isNative ? type : 'propertychange', handler, false, !isNative && type);
        }
      }
  
      destroyHandler(names); //get combos
      for (i = uids.length; i--; destroyHandler(uids[i])) {} //get singles
  
      return element;
    },
  
    del = function (selector, fn, $) {
      return function (e) {
        var array = typeof selector == 'string' ? $(selector, this) : selector;
        for (var target = e.target; target && target != this; target = target.parentNode) {
          for (var i = array.length; i--;) {
            if (array[i] == target) {
              return fn.apply(target, arguments);
            }
          }
        }
      };
    },
  
    add = function (element, events, fn, delfn, $) {
      if (typeof events == 'object' && !fn) {
        for (var type in events) {
          events.hasOwnProperty(type) && add(element, type, events[type]);
        }
      } else {
        var isDel = typeof fn == 'string', types = (isDel ? fn : events).split(' ');
        fn = isDel ? del(events, delfn, $) : fn;
        for (var i = types.length; i--;) {
          addListener(element, types[i], fn, Array.prototype.slice.call(arguments, isDel ? 4 : 3));
        }
      }
      return element;
    },
  
    remove = function (element, orgEvents, fn) {
      var k, m, type, events, i,
          isString = typeof(orgEvents) == 'string',
          names = isString && orgEvents.replace(namespace, ''),
          rm = removeListener,
          attached = retrieveEvents(element);
      names = names && names.split('.');
      if (isString && /\s/.test(orgEvents)) {
        orgEvents = orgEvents.split(' ');
        i = orgEvents.length - 1;
        while (remove(element, orgEvents[i]) && i--) {}
        return element;
      }
      events = isString ? orgEvents.replace(stripName, '') : orgEvents;
      if (!attached || names || (isString && !attached[events])) {
        for (k in attached) {
          if (attached.hasOwnProperty(k)) {
            for (i in attached[k]) {
              for (m = names.length; m--;) {
                attached[k].hasOwnProperty(i) && new RegExp('^' + names[m] + '::\\d*(\\..*)?$').test(i) && rm(element, [k, i].join('.'));
              }
            }
          }
        }
        return element;
      }
      if (typeof fn == 'function') {
        rm(element, events, fn);
      } else if (names) {
        rm(element, orgEvents);
      } else {
        rm = events ? rm : remove;
        type = isString && events;
        events = events ? (fn || attached[events] || events) : attached;
        for (k in events) {
          if (events.hasOwnProperty(k)) {
            rm(element, type || k, events[k]);
            delete events[k]; // remove unused leaf keys
          }
        }
      }
      return element;
    },
  
    fire = function (element, type, args) {
      var evt, k, i, m, types = type.split(' ');
      for (i = types.length; i--;) {
        type = types[i].replace(stripName, '');
        var isNative = nativeEvents[type],
            isNamespace = types[i].replace(namespace, ''),
            handlers = retrieveEvents(element)[type];
        if (isNamespace) {
          isNamespace = isNamespace.split('.');
          for (k = isNamespace.length; k--;) {
            for (m in handlers) {
              handlers.hasOwnProperty(m) && new RegExp('^' + isNamespace[k] + '::\\d*(\\..*)?$').test(m) && handlers[m].apply(element, [false].concat(args));
            }
          }
        } else if (!args && element[eventSupport]) {
          fireListener(isNative, type, element);
        } else {
          for (k in handlers) {
            handlers.hasOwnProperty(k) && handlers[k].apply(element, [false].concat(args));
          }
        }
      }
      return element;
    },
  
    fireListener = W3C_MODEL ? function (isNative, type, element) {
      evt = document.createEvent(isNative ? "HTMLEvents" : "UIEvents");
      evt[isNative ? 'initEvent' : 'initUIEvent'](type, true, true, win, 1);
      element.dispatchEvent(evt);
    } : function (isNative, type, element) {
      isNative ? element.fireEvent('on' + type, document.createEventObject()) : element['_on' + type]++;
    },
  
    clone = function (element, from, type) {
      var events = retrieveEvents(from), obj, k;
      var uid = retrieveUid(element);
      obj = type ? events[type] : events;
      for (k in obj) {
        obj.hasOwnProperty(k) && (type ? add : clone)(element, type || from, type ? obj[k].__originalFn : k);
      }
      return element;
    },
  
    fixEvent = function (e) {
      var result = {};
      if (!e) {
        return result;
      }
      var type = e.type, target = e.target || e.srcElement;
      result.preventDefault = fixEvent.preventDefault(e);
      result.stopPropagation = fixEvent.stopPropagation(e);
      result.target = target && target.nodeType == 3 ? target.parentNode : target;
      if (~type.indexOf('key')) {
        result.keyCode = e.which || e.keyCode;
      } else if ((/click|mouse|menu/i).test(type)) {
        result.rightClick = e.which == 3 || e.button == 2;
        result.pos = { x: 0, y: 0 };
        if (e.pageX || e.pageY) {
          result.clientX = e.pageX;
          result.clientY = e.pageY;
        } else if (e.clientX || e.clientY) {
          result.clientX = e.clientX + document.body.scrollLeft + document.documentElement.scrollLeft;
          result.clientY = e.clientY + document.body.scrollTop + document.documentElement.scrollTop;
        }
        overOut.test(type) && (result.relatedTarget = e.relatedTarget || e[(type == 'mouseover' ? 'from' : 'to') + 'Element']);
      }
      for (var k in e) {
        if (!(k in result)) {
          result[k] = e[k];
        }
      }
      return result;
    };
  
    fixEvent.preventDefault = function (e) {
      return function () {
        if (e.preventDefault) {
          e.preventDefault();
        }
        else {
          e.returnValue = false;
        }
      };
    };
  
    fixEvent.stopPropagation = function (e) {
      return function () {
        if (e.stopPropagation) {
          e.stopPropagation();
        } else {
          e.cancelBubble = true;
        }
      };
    };
  
    var nativeEvents = { click: 1, dblclick: 1, mouseup: 1, mousedown: 1, contextmenu: 1, //mouse buttons
      mousewheel: 1, DOMMouseScroll: 1, //mouse wheel
      mouseover: 1, mouseout: 1, mousemove: 1, selectstart: 1, selectend: 1, //mouse movement
      keydown: 1, keypress: 1, keyup: 1, //keyboard
      orientationchange: 1, // mobile
      touchstart: 1, touchmove: 1, touchend: 1, touchcancel: 1, // touch
      gesturestart: 1, gesturechange: 1, gestureend: 1, // gesture
      focus: 1, blur: 1, change: 1, reset: 1, select: 1, submit: 1, //form elements
      load: 1, unload: 1, beforeunload: 1, resize: 1, move: 1, DOMContentLoaded: 1, readystatechange: 1, //window
      error: 1, abort: 1, scroll: 1 }; //misc
  
    function check(event) {
      var related = event.relatedTarget;
      if (!related) {
        return related === null;
      }
      return (related != this && related.prefix != 'xul' && !/document/.test(this.toString()) && !isDescendant(this, related));
    }
  
    var customEvents = {
      mouseenter: { base: 'mouseover', condition: check },
      mouseleave: { base: 'mouseout', condition: check },
      mousewheel: { base: /Firefox/.test(navigator.userAgent) ? 'DOMMouseScroll' : 'mousewheel' }
    };
  
    var bean = { add: add, remove: remove, clone: clone, fire: fire };
  
    var clean = function (el) {
      var uid = remove(el).__uid;
      if (uid) {
        delete collected[uid];
        delete registry[uid];
      }
    };
  
    if (win[attachEvent]) {
      add(win, 'unload', function () {
        for (var k in collected) {
          collected.hasOwnProperty(k) && clean(collected[k]);
        }
        win.CollectGarbage && CollectGarbage();
      });
    }
  
    bean.noConflict = function () {
      context.bean = old;
      return this;
    };
  
    return bean;
  });

  provide("bean", module.exports);

  !function ($) {
    var b = require('bean'),
        integrate = function (method, type, method2) {
          var _args = type ? [type] : [];
          return function () {
            for (var args, i = 0, l = this.length; i < l; i++) {
              args = [this[i]].concat(_args, Array.prototype.slice.call(arguments, 0));
              args.length == 4 && args.push($);
              !arguments.length && method == 'add' && type && (method = 'fire');
              b[method].apply(this, args);
            }
            return this;
          };
        };
  
    var add = integrate('add'),
        remove = integrate('remove'),
        fire = integrate('fire');
  
    var methods = {
  
      on: add,
      addListener: add,
      bind: add,
      listen: add,
      delegate: add,
  
      unbind: remove,
      unlisten: remove,
      removeListener: remove,
      undelegate: remove,
  
      emit: fire,
      trigger: fire,
  
      cloneEvents: integrate('clone'),
  
      hover: function (enter, leave, i) { // i for internal
        for (i = this.length; i--;) {
          b.add.call(this, this[i], 'mouseenter', enter);
          b.add.call(this, this[i], 'mouseleave', leave);
        }
        return this;
      }
    };
  
    var i, shortcuts = [
      'blur', 'change', 'click', 'dblclick', 'error', 'focus', 'focusin',
      'focusout', 'keydown', 'keypress', 'keyup', 'load', 'mousedown',
      'mouseenter', 'mouseleave', 'mouseout', 'mouseover', 'mouseup', 'mousemove',
      'resize', 'scroll', 'select', 'submit', 'unload'
    ];
  
    for (i = shortcuts.length; i--;) {
      methods[shortcuts[i]] = integrate('add', shortcuts[i]);
    }
  
    $.ender(methods, true);
  }(ender);

}();

!function () {

  var module = { exports: {} }, exports = module.exports;

  !function (name, definition) {
    if (typeof define == 'function') define(definition)
    else if (typeof module != 'undefined') module.exports = definition()
    else this[name] = this['domReady'] = definition()
  }('domready', function (ready) {
  
    var fns = [], fn, f = false
      , doc = document
      , testEl = doc.documentElement
      , hack = testEl.doScroll
      , domContentLoaded = 'DOMContentLoaded'
      , addEventListener = 'addEventListener'
      , onreadystatechange = 'onreadystatechange'
      , loaded = /^loade|c/.test(doc.readyState)
  
    function flush(f) {
      loaded = 1
      while (f = fns.shift()) f()
    }
  
    doc[addEventListener] && doc[addEventListener](domContentLoaded, fn = function () {
      doc.removeEventListener(domContentLoaded, fn, f)
      flush()
    }, f)
  
  
    hack && doc.attachEvent(onreadystatechange, (fn = function () {
      if (/^c/.test(doc.readyState)) {
        doc.detachEvent(onreadystatechange, fn)
        flush()
      }
    }))
  
    return (ready = hack ?
      function (fn) {
        self != top ?
          loaded ? fn() : fns.push(fn) :
          function () {
            try {
              testEl.doScroll('left')
            } catch (e) {
              return setTimeout(function() { ready(fn) }, 50)
            }
            fn()
          }()
      } :
      function (fn) {
        loaded ? fn() : fns.push(fn)
      })
  })

  provide("domready", module.exports);

  !function ($) {
    var ready = require('domready')
    $.ender({domReady: ready})
    $.ender({
      ready: function (f) {
        ready(f)
        return this
      }
    }, true)
  }(ender);

}();

!function () {

  var module = { exports: {} }, exports = module.exports;

  /*!
    * Qwery - A Blazing Fast query selector engine
    * https://github.com/ded/qwery
    * copyright Dustin Diaz & Jacob Thornton 2011
    * MIT License
    */
  
  !function (name, definition) {
    if (typeof module != 'undefined') module.exports = definition()
    else if (typeof define == 'function' && typeof define.amd == 'object') define(definition)
    else this[name] = definition()
  }('qwery', function () {
    var context = this
      , doc = document
      , old = context.qwery
      , c, i, j, k, l, m, o, p, r, v
      , el, node, found, classes, item, items, token
      , html = doc.documentElement
      , id = /#([\w\-]+)/
      , clas = /\.[\w\-]+/g
      , idOnly = /^#([\w\-]+$)/
      , classOnly = /^\.([\w\-]+)$/
      , tagOnly = /^([\w\-]+)$/
      , tagAndOrClass = /^([\w]+)?\.([\w\-]+)$/
      , normalizr = /\s*([\s\+\~>])\s*/g
      , splitters = /[\s\>\+\~]/
      , splittersMore = /(?![\s\w\-\/\?\&\=\:\.\(\)\!,@#%<>\{\}\$\*\^'"]*\]|[\s\w\+\-]*\))/
      , specialChars = /([.*+?\^=!:${}()|\[\]\/\\])/g
      , simple = /^([a-z0-9]+)?(?:([\.\#]+[\w\-\.#]+)?)/
      , attr = /\[([\w\-]+)(?:([\|\^\$\*\~]?\=)['"]?([ \w\-\/\?\&\=\:\.\(\)\!,@#%<>\{\}\$\*\^]+)["']?)?\]/
      , pseudo = /:([\w\-]+)(\(['"]?([\s\w\+\-]+)['"]?\))?/
      , dividers = new RegExp('(' + splitters.source + ')' + splittersMore.source, 'g')
      , tokenizr = new RegExp(splitters.source + splittersMore.source)
      , chunker = new RegExp(simple.source + '(' + attr.source + ')?' + '(' + pseudo.source + ')?')
      , walker = {
        ' ': function (node) {
          return node && node !== html && node.parentNode
        }
      , '>': function (node, contestant) {
          return node && node.parentNode == contestant.parentNode && node.parentNode
        }
      , '~': function (node) {
          return node && node.previousSibling
        }
      , '+': function (node, contestant, p1, p2) {
          if (!node) return false
          p1 = previous(node)
          p2 = previous(contestant)
          return p1 && p2 && p1 == p2 && p1
        }
    }
    function cache() {
      this.c = {}
    }
    cache.prototype = {
        g: function (k) {
          return this.c[k] || undefined
        }
      , s: function (k, v) {
          this.c[k] = v
          return v
        }
    }
  
    var classCache = new cache()
      , cleanCache = new cache()
      , attrCache = new cache()
      , tokenCache = new cache()
  
    function flatten(ar) {
      r = []
      for (i = 0, l = ar.length; i < l; i++) {
        if (arrayLike(ar[i])) r = r.concat(ar[i])
        else r.push(ar[i])
      }
      return r
    }
  
    function previous(n) {
      while (n = n.previousSibling) if (n.nodeType == 1) break;
      return n
    }
  
    function q(query) {
      return query.match(chunker)
    }
  
    // this next method expect at most these args
    // given => div.hello[title="world"]:foo('bar')
  
    // div.hello[title="world"]:foo('bar'), div, .hello, [title="world"], title, =, world, :foo('bar'), foo, ('bar'), bar]
  
    function interpret(whole, tag, idsAndClasses, wholeAttribute, attribute, qualifier, value, wholePseudo, pseudo, wholePseudoVal, pseudoVal) {
      var m, c, k;
      if (tag && this.tagName.toLowerCase() !== tag) return false
      if (idsAndClasses && (m = idsAndClasses.match(id)) && m[1] !== this.id) return false
      if (idsAndClasses && (classes = idsAndClasses.match(clas))) {
        for (i = classes.length; i--;) {
          c = classes[i].slice(1)
          if (!(classCache.g(c) || classCache.s(c, new RegExp('(^|\\s+)' + c + '(\\s+|$)'))).test(this.className)) {
            return false
          }
        }
      }
      if (pseudo && qwery.pseudos[pseudo] && !qwery.pseudos[pseudo](this, pseudoVal)) {
        return false
      }
      if (wholeAttribute && !value) {
        o = this.attributes
        for (k in o) {
          if (Object.prototype.hasOwnProperty.call(o, k) && (o[k].name || k) == attribute) {
            return this
          }
        }
      }
      if (wholeAttribute && !checkAttr(qualifier, this.getAttribute(attribute) || '', value)) {
        return false
      }
      return this
    }
  
    function clean(s) {
      return cleanCache.g(s) || cleanCache.s(s, s.replace(specialChars, '\\$1'))
    }
  
    function checkAttr(qualify, actual, val) {
      switch (qualify) {
      case '=':
        return actual == val
      case '^=':
        return actual.match(attrCache.g('^=' + val) || attrCache.s('^=' + val, new RegExp('^' + clean(val))))
      case '$=':
        return actual.match(attrCache.g('$=' + val) || attrCache.s('$=' + val, new RegExp(clean(val) + '$')))
      case '*=':
        return actual.match(attrCache.g(val) || attrCache.s(val, new RegExp(clean(val))))
      case '~=':
        return actual.match(attrCache.g('~=' + val) || attrCache.s('~=' + val, new RegExp('(?:^|\\s+)' + clean(val) + '(?:\\s+|$)')))
      case '|=':
        return actual.match(attrCache.g('|=' + val) || attrCache.s('|=' + val, new RegExp('^' + clean(val) + '(-|$)')))
      }
      return 0
    }
  
    function _qwery(selector) {
      var r = [], ret = [], i, j = 0, k, l, m, p, token, tag, els, root, intr, item, children
        , tokens = tokenCache.g(selector) || tokenCache.s(selector, selector.split(tokenizr))
        , dividedTokens = selector.match(dividers), dividedToken
      tokens = tokens.slice(0) // this makes a copy of the array so the cached original is not effected
  
      if (!tokens.length) return r
  
      token = tokens.pop()
      root = tokens.length && (m = tokens[tokens.length - 1].match(idOnly)) ? doc.getElementById(m[1]) : doc
  
      if (!root) return r
  
      intr = q(token)
      els = dividedTokens && /^[+~]$/.test(dividedTokens[dividedTokens.length - 1]) ? function (r) {
          while (root = root.nextSibling) {
            root.nodeType == 1 && (intr[1] ? intr[1] == root.tagName.toLowerCase() : 1) && r.push(root)
          }
          return r
        }([]) :
        root.getElementsByTagName(intr[1] || '*')
      for (i = 0, l = els.length; i < l; i++) if (item = interpret.apply(els[i], intr)) r[j++] = item
      if (!tokens.length) return r
  
      // loop through all descendent tokens
      for (j = 0, l = r.length, k = 0; j < l; j++) {
        p = r[j]
        // loop through each token backwards crawling up tree
        for (i = tokens.length; i--;) {
          // loop through parent nodes
          while (p = walker[dividedTokens[i]](p, r[j])) {
            if (found = interpret.apply(p, q(tokens[i]))) break;
          }
        }
        found && (ret[k++] = r[j])
      }
      return ret
    }
  
    function isNode(el) {
      return (el && el.nodeType && (el.nodeType == 1 || el.nodeType == 9))
    }
  
    function uniq(ar) {
      var a = [], i, j;
      label:
      for (i = 0; i < ar.length; i++) {
        for (j = 0; j < a.length; j++) {
          if (a[j] == ar[i]) continue label;
        }
        a[a.length] = ar[i]
      }
      return a
    }
  
    function arrayLike(o) {
      return (typeof o === 'object' && isFinite(o.length))
    }
  
    function normalizeRoot(root) {
      if (!root) return doc
      if (typeof root == 'string') return qwery(root)[0]
      if (arrayLike(root)) return root[0]
      return root
    }
  
    function qwery(selector, _root) {
      var root = normalizeRoot(_root)
  
      if (!root || !selector) return []
      if (selector === window || isNode(selector)) {
        return !_root || (selector !== window && isNode(root) && isAncestor(selector, root)) ? [selector] : []
      }
      if (selector && arrayLike(selector)) return flatten(selector)
      if (m = selector.match(idOnly)) return (el = doc.getElementById(m[1])) ? [el] : []
      if (m = selector.match(tagOnly)) return flatten(root.getElementsByTagName(m[1]))
      return select(selector, root)
    }
  
    var isAncestor = 'compareDocumentPosition' in html ?
      function (element, container) {
        return (container.compareDocumentPosition(element) & 16) == 16
      } : 'contains' in html ?
      function (element, container) {
        container = container == doc || container == window ? html : container
        return container !== element && container.contains(element)
      } :
      function (element, container) {
        while (element = element.parentNode) if (element === container) return 1
        return 0
      },
  
    supportsCSS3 = function () {
      if (!doc.querySelector || !doc.querySelectorAll) return false
  
      try { return (doc.querySelectorAll(':nth-of-type(1)').length) }
      catch (e) { return false }
    }(),
  
    select = supportsCSS3 ?
      function (selector, root) {
        return doc.getElementsByClassName && (m = selector.match(classOnly)) ?
          flatten(root.getElementsByClassName(m[1])) :
          flatten(root.querySelectorAll(selector))
      } :
      function (selector, root) {
        selector = selector.replace(normalizr, '$1')
        var result = [], element, collection, collections = [], i
        if (m = selector.match(tagAndOrClass)) {
          items = root.getElementsByTagName(m[1] || '*');
          r = classCache.g(m[2]) || classCache.s(m[2], new RegExp('(^|\\s+)' + m[2] + '(\\s+|$)'));
          for (i = 0, l = items.length, j = 0; i < l; i++) {
            r.test(items[i].className) && (result[j++] = items[i]);
          }
          return result
        }
        for (i = 0, items = selector.split(','), l = items.length; i < l; i++) {
          collections[i] = _qwery(items[i])
        }
        for (i = 0, l = collections.length; i < l && (collection = collections[i]); i++) {
          var ret = collection
          if (root !== doc) {
            ret = []
            for (j = 0, m = collection.length; j < m && (element = collection[j]); j++) {
              // make sure element is a descendent of root
              isAncestor(element, root) && ret.push(element)
            }
          }
          result = result.concat(ret)
        }
        return uniq(result)
      }
  
    qwery.uniq = uniq
    qwery.pseudos = {}
  
    qwery.noConflict = function () {
      context.qwery = old
      return this
    }
  
    return qwery
  })

  provide("qwery", module.exports);

  !function (doc, $) {
    var q = require('qwery')
      , table = 'table'
      , nodeMap = {
            thead: table
          , tbody: table
          , tfoot: table
          , tr: 'tbody'
          , th: 'tr'
          , td: 'tr'
          , fieldset: 'form'
          , option: 'select'
        }
    function create(node, root) {
      var tag = /^\s*<([^\s>]+)\s*/.exec(node)[1]
        , el = (root || doc).createElement(nodeMap[tag] || 'div'), els = []
  
      el.innerHTML = node
      var nodes = el.childNodes
      el = el.firstChild
      el.nodeType == 1 && els.push(el)
      while (el = el.nextSibling) (el.nodeType == 1) && els.push(el)
      return els
    }
  
    $._select = function (s, r) {
      return /^\s*</.test(s) ? create(s, r) : q(s, r)
    }
  
    $.pseudos = q.pseudos
  
    $.ender({
      find: function (s) {
        var r = [], i, l, j, k, els
        for (i = 0, l = this.length; i < l; i++) {
          els = q(s, this[i])
          for (j = 0, k = els.length; j < k; j++) r.push(els[j])
        }
        return $(q.uniq(r))
      }
      , and: function (s) {
        var plus = $(s)
        for (var i = this.length, j = 0, l = this.length + plus.length; i < l; i++, j++) {
          this[i] = plus[j]
        }
        return this
      }
    }, true)
  }(document, ender);
  

}();

!function () {

  var module = { exports: {} }, exports = module.exports;

  /*!
    * $script.js Async loader & dependency manager
    * https://github.com/ded/script.js
    * (c) Dustin Diaz, Jacob Thornton 2011
    * License: MIT
    */
  !function (name, definition) {
    if (typeof define == 'function') define(definition)
    else if (typeof module != 'undefined') module.exports = definition()
    else this[name] = definition()
  }('$script', function() {
    var win = this, doc = document
      , head = doc.getElementsByTagName('head')[0]
      , validBase = /^https?:\/\//
      , old = win.$script, list = {}, ids = {}, delay = {}, scriptpath
      , scripts = {}, s = 'string', f = false
      , push = 'push', domContentLoaded = 'DOMContentLoaded', readyState = 'readyState'
      , addEventListener = 'addEventListener', onreadystatechange = 'onreadystatechange'
  
    function every(ar, fn, i) {
      for (i = 0, j = ar.length; i < j; ++i) if (!fn(ar[i])) return f
      return 1
    }
    function each(ar, fn) {
      every(ar, function(el) {
        return !fn(el)
      })
    }
  
    if (!doc[readyState] && doc[addEventListener]) {
      doc[addEventListener](domContentLoaded, function fn() {
        doc.removeEventListener(domContentLoaded, fn, f)
        doc[readyState] = 'complete'
      }, f)
      doc[readyState] = 'loading'
    }
  
    function $script(paths, idOrDone, optDone) {
      paths = paths[push] ? paths : [paths]
      var idOrDoneIsDone = idOrDone && idOrDone.call
        , done = idOrDoneIsDone ? idOrDone : optDone
        , id = idOrDoneIsDone ? paths.join('') : idOrDone
        , queue = paths.length
      function loopFn(item) {
        return item.call ? item() : list[item]
      }
      function callback() {
        if (!--queue) {
          list[id] = 1
          done && done()
          for (var dset in delay) {
            every(dset.split('|'), loopFn) && !each(delay[dset], loopFn) && (delay[dset] = [])
          }
        }
      }
      setTimeout(function () {
        each(paths, function(path) {
          if (scripts[path]) {
            id && (ids[id] = 1)
            return scripts[path] == 2 && callback()
          }
          scripts[path] = 1
          id && (ids[id] = 1)
          create(!validBase.test(path) && scriptpath ? scriptpath + path + '.js' : path, callback)
        })
      }, 0)
      return $script
    }
  
    function create(path, fn) {
      var el = doc.createElement('script')
        , loaded = f
      el.onload = el.onerror = el[onreadystatechange] = function () {
        if ((el[readyState] && !(/^c|loade/.test(el[readyState]))) || loaded) return;
        el.onload = el[onreadystatechange] = null
        loaded = 1
        scripts[path] = 2
        fn()
      }
      el.async = 1
      el.src = path
      head.insertBefore(el, head.firstChild)
    }
  
    $script.get = create
  
    $script.order = function (scripts, id, done) {
      (function callback(s) {
        s = scripts.shift()
        if (!scripts.length) $script(s, id, done)
        else $script(s, callback)
      }())
    }
  
    $script.path = function(p) {
      scriptpath = p
    }
    $script.ready = function(deps, ready, req) {
      deps = deps[push] ? deps : [deps]
      var missing = [];
      !each(deps, function(dep) {
        list[dep] || missing[push](dep);
      }) && every(deps, function(dep) {return list[dep]}) ?
        ready() : !function(key) {
        delay[key] = delay[key] || []
        delay[key][push](ready)
        req && req(missing)
      }(deps.join('|'))
      return $script
    }
  
    $script.noConflict = function () {
      win.$script = old;
      return this
    }
  
    return $script
  })

  provide("scriptjs", module.exports);

  var s = require('scriptjs')
  ender.ender({
      script: s
    , require: s
    , ready: s.ready
    , getScript: s.get
  })

}();

!function () {

  var module = { exports: {} }, exports = module.exports;

  /*!
    * Bonzo: DOM Utility (c) Dustin Diaz 2011
    * https://github.com/ded/bonzo
    * License MIT
    */
  !function (name, definition) {
    if (typeof module != 'undefined') module.exports = definition()
    else if (typeof define == 'function' && typeof define.amd == 'object') define(definition)
    else this[name] = definition()
  }('bonzo', function() {
    var context = this
      , win = window
      , doc = win.document
      , html = doc.documentElement
      , parentNode = 'parentNode'
      , query = null
      , specialAttributes = /^checked|value|selected$/
      , specialTags = /select|fieldset|table|tbody|tfoot|td|tr|colgroup/i
      , table = 'table'
      , tagMap = { thead: table, tbody: table, tfoot: table, tr: 'tbody', th: 'tr', td: 'tr', fieldset: 'form', option: 'select' }
      , stateAttributes = /^checked|selected$/
      , ie = /msie/i.test(navigator.userAgent)
      , uidList = []
      , uuids = 0
      , digit = /^-?[\d\.]+$/
      , px = 'px'
      , setAttribute = 'setAttribute'
      , getAttribute = 'getAttribute'
      , trimReplace = /(^\s*|\s*$)/g
      , unitless = { lineHeight: 1, zoom: 1, zIndex: 1, opacity: 1 }
      , transform = function () {
          var props = ['webkitTransform', 'MozTransform', 'OTransform', 'msTransform', 'Transform'], i
          for (i = 0; i < props.length; i++) {
            if (props[i] in doc.createElement('a').style) {
              return props[i]
            }
          }
        }()
      , trim = String.prototype.trim ?
          function (s) {
            return s.trim()
          } :
          function (s) {
            return s.replace(trimReplace, '')
          }
  
    function classReg(c) {
      return new RegExp("(^|\\s+)" + c + "(\\s+|$)")
    }
  
    function each(ar, fn, scope) {
      for (var i = 0, l = ar.length; i < l; i++) fn.call(scope || ar[i], ar[i], i, ar)
      return ar
    }
  
    function camelize(s) {
      return s.replace(/-(.)/g, function (m, m1) {
        return m1.toUpperCase()
      })
    }
  
    function is(node) {
      return node && node.nodeName && node.nodeType == 1
    }
  
    function some(ar, fn, scope, i) {
      for (i = 0, j = ar.length; i < j; ++i) {
        if (fn.call(scope, ar[i], i, ar)) return true
      }
      return false
    }
  
    var getStyle = doc.defaultView && doc.defaultView.getComputedStyle ?
      function (el, property) {
        property = property == 'transform' ? transform : property
        property = property == 'transform-origin' ? transform + "Origin" : property
        var value = null
        if (property == 'float') {
          property = 'cssFloat'
        }
        var computed = doc.defaultView.getComputedStyle(el, '')
        computed && (value = computed[camelize(property)])
        return el.style[property] || value
      } : (ie && html.currentStyle) ?
  
      function (el, property) {
        property = camelize(property)
        property = property == 'float' ? 'styleFloat' : property
  
        if (property == 'opacity') {
          var val = 100
          try {
            val = el.filters['DXImageTransform.Microsoft.Alpha'].opacity
          } catch (e1) {
            try {
              val = el.filters('alpha').opacity
            } catch (e2) {}
          }
          return val / 100
        }
        var value = el.currentStyle ? el.currentStyle[property] : null
        return el.style[property] || value
      } :
  
      function (el, property) {
        return el.style[camelize(property)]
      }
  
    function insert(target, host, fn) {
      var i = 0, self = host || this, r = []
        , nodes = query && typeof target == 'string' && target.charAt(0) != '<' ? query(target) : target
      each(normalize(nodes), function (t) {
        each(self, function (el) {
          var n = !el[parentNode] || (el[parentNode] && !el[parentNode][parentNode]) ?
            function () {
              var c = el.cloneNode(true)
              self.$ && self.cloneEvents && self.$(c).cloneEvents(el)
              return c
            }() : el
          fn(t, n)
          r[i] = n
          i++
        })
      }, this)
      each(r, function (e, i) {
        self[i] = e
      })
      self.length = i
      return self
    }
  
    function xy(el, x, y) {
      var $el = bonzo(el)
        , style = $el.css('position')
        , offset = $el.offset()
        , rel = 'relative'
        , isRel = style == rel
        , delta = [parseInt($el.css('left'), 10), parseInt($el.css('top'), 10)]
  
      if (style == 'static') {
        $el.css('position', rel)
        style = rel
      }
  
      isNaN(delta[0]) && (delta[0] = isRel ? 0 : el.offsetLeft)
      isNaN(delta[1]) && (delta[1] = isRel ? 0 : el.offsetTop)
  
      x != null && (el.style.left = x - offset.left + delta[0] + px)
      y != null && (el.style.top = y - offset.top + delta[1] + px)
  
    }
  
    function hasClass(el, c) {
      return classReg(c).test(el.className)
    }
    function addClass(el, c) {
      el.className = trim(el.className + ' ' + c)
    }
    function removeClass(el, c) {
      el.className = trim(el.className.replace(classReg(c), ' '))
    }
  
    // this allows method calling for setting values
    // example:
  
    // bonzo(elements).css('color', function (el) {
    //   return el.getAttribute('data-original-color')
    // })
  
    function set(el, v) {
      return typeof v == 'function' ? v(el) : v
    }
  
    function Bonzo(elements) {
      this.length = 0
      if (elements) {
        elements = typeof elements !== 'string' &&
          !elements.nodeType &&
          typeof elements.length !== 'undefined' ?
            elements :
            [elements]
        this.length = elements.length
        for (var i = 0; i < elements.length; i++) {
          this[i] = elements[i]
        }
      }
    }
  
    Bonzo.prototype = {
  
        get: function (index) {
          return this[index]
        }
  
      , each: function (fn, scope) {
          return each(this, fn, scope)
        }
  
      , map: function (fn, reject) {
          var m = [], n, i
          for (i = 0; i < this.length; i++) {
            n = fn.call(this, this[i], i)
            reject ? (reject(n) && m.push(n)) : m.push(n)
          }
          return m
        }
  
      , first: function () {
          return bonzo(this[0])
        }
  
      , last: function () {
          return bonzo(this[this.length - 1])
        }
  
      , html: function (h, text) {
          var method = text ?
            html.textContent === null ?
              'innerText' :
              'textContent' :
            'innerHTML', m;
          function append(el) {
            while (el.firstChild) el.removeChild(el.firstChild)
            each(normalize(h), function (node) {
              el.appendChild(node)
            })
          }
          return typeof h !== 'undefined' ?
              this.each(function (el) {
                (m = el.tagName.match(specialTags)) ?
                  append(el, m[0]) :
                  (el[method] = h)
              }) :
            this[0] ? this[0][method] : ''
        }
  
      , text: function (text) {
          return this.html(text, 1)
        }
  
      , addClass: function (c) {
          return this.each(function (el) {
            hasClass(el, set(el, c)) || addClass(el, set(el, c))
          })
        }
  
      , removeClass: function (c) {
          return this.each(function (el) {
            hasClass(el, set(el, c)) && removeClass(el, set(el, c))
          })
        }
  
      , hasClass: function (c) {
          return some(this, function (el) {
            return hasClass(el, c)
          })
        }
  
      , toggleClass: function (c, condition) {
          return this.each(function (el) {
            typeof condition !== 'undefined' ?
              condition ? addClass(el, c) : removeClass(el, c) :
              hasClass(el, c) ? removeClass(el, c) : addClass(el, c)
          })
        }
  
      , show: function (type) {
          return this.each(function (el) {
            el.style.display = type || ''
          })
        }
  
      , hide: function (elements) {
          return this.each(function (el) {
            el.style.display = 'none'
          })
        }
  
      , append: function (node) {
          return this.each(function (el) {
            each(normalize(node), function (i) {
              el.appendChild(i)
            })
          })
        }
  
      , prepend: function (node) {
          return this.each(function (el) {
            var first = el.firstChild
            each(normalize(node), function (i) {
              el.insertBefore(i, first)
            })
          })
        }
  
      , appendTo: function (target, host) {
          return insert.call(this, target, host, function (t, el) {
            t.appendChild(el)
          })
        }
  
      , prependTo: function (target, host) {
          return insert.call(this, target, host, function (t, el) {
            t.insertBefore(el, t.firstChild)
          })
        }
  
      , next: function () {
          return this.related('nextSibling')
        }
  
      , previous: function () {
          return this.related('previousSibling')
        }
  
      , related: function (method) {
          return this.map(
            function (el) {
              el = el[method]
              while (el && el.nodeType !== 1) {
                el = el[method]
              }
              return el || 0
            },
            function (el) {
              return el
            }
          )
        }
  
      , before: function (node) {
          return this.each(function (el) {
            each(bonzo.create(node), function (i) {
              el[parentNode].insertBefore(i, el)
            })
          })
        }
  
      , after: function (node) {
          return this.each(function (el) {
            each(bonzo.create(node), function (i) {
              el[parentNode].insertBefore(i, el.nextSibling)
            })
          })
        }
  
      , insertBefore: function (target, host) {
          return insert.call(this, target, host, function (t, el) {
            t[parentNode].insertBefore(el, t)
          })
        }
  
      , insertAfter: function (target, host) {
          return insert.call(this, target, host, function (t, el) {
            var sibling = t.nextSibling
            if (sibling) {
              t[parentNode].insertBefore(el, sibling);
            }
            else {
              t[parentNode].appendChild(el)
            }
          })
        }
  
      , replaceWith: function(html) {
          return this.each(function (el) {
            el.parentNode.replaceChild(bonzo.create(html)[0], el)
          })
        }
  
      , css: function (o, v, p) {
          // is this a request for just getting a style?
          if (v === undefined && typeof o == 'string') {
            // repurpose 'v'
            v = this[0]
            if (!v) {
              return null
            }
            if (v == doc || v == win) {
              p = (v == doc) ? bonzo.doc() : bonzo.viewport()
              return o == 'width' ? p.width : o == 'height' ? p.height : ''
            }
            return getStyle(v, o)
          }
          var iter = o
          if (typeof o == 'string') {
            iter = {}
            iter[o] = v
          }
  
          if (ie && iter.opacity) {
            // oh this 'ol gamut
            iter.filter = 'alpha(opacity=' + (iter.opacity * 100) + ')'
            // give it layout
            iter.zoom = o.zoom || 1;
            delete iter.opacity;
          }
  
          if (v = iter['float']) {
            // float is a reserved style word. w3 uses cssFloat, ie uses styleFloat
            ie ? (iter.styleFloat = v) : (iter.cssFloat = v);
            delete iter['float'];
          }
  
          function fn(el, p, v) {
            for (var k in iter) {
              if (iter.hasOwnProperty(k)) {
                v = iter[k];
                // change "5" to "5px" - unless you're line-height, which is allowed
                (p = camelize(k)) && digit.test(v) && !(p in unitless) && (v += px)
                p = p == 'transform' ? transform : p
                p = p == 'transformOrigin' ? transform + 'Origin' : p
                el.style[p] = set(el, v)
              }
            }
          }
          return this.each(fn)
        }
  
      , offset: function (x, y) {
          if (typeof x == 'number' || typeof y == 'number') {
            return this.each(function (el) {
              xy(el, x, y)
            })
          }
          var el = this[0]
            , width = el.offsetWidth
            , height = el.offsetHeight
            , top = el.offsetTop
            , left = el.offsetLeft
          while (el = el.offsetParent) {
            top = top + el.offsetTop
            left = left + el.offsetLeft
          }
  
          return {
              top: top
            , left: left
            , height: height
            , width: width
          }
        }
  
      , attr: function (k, v) {
          var el = this[0]
          if (typeof k != 'string' && !(k instanceof String)) {
            for (var n in k) {
              k.hasOwnProperty(n) && this.attr(n, k[n])
            }
            return this
          }
          return typeof v == 'undefined' ?
            specialAttributes.test(k) ?
              stateAttributes.test(k) && typeof el[k] == 'string' ?
                true : el[k] : el[getAttribute](k) :
            this.each(function (el) {
              specialAttributes.test(k) ? (el[k] = set(el, v)) : el[setAttribute](k, set(el, v))
            })
        }
  
      , val: function (s) {
          return (typeof s == 'string') ? this.attr('value', s) : this[0].value
        }
  
      , removeAttr: function (k) {
          return this.each(function (el) {
            stateAttributes.test(k) ? (el[k] = false) : el.removeAttribute(k)
          })
        }
  
      , data: function (k, v) {
          var el = this[0]
          if (typeof v === 'undefined') {
            el[getAttribute]('data-node-uid') || el[setAttribute]('data-node-uid', ++uuids)
            var uid = el[getAttribute]('data-node-uid')
            uidList[uid] || (uidList[uid] = {})
            return uidList[uid][k]
          } else {
            return this.each(function (el) {
              el[getAttribute]('data-node-uid') || el[setAttribute]('data-node-uid', ++uuids)
              var uid = el[getAttribute]('data-node-uid')
                , o = uidList[uid] || (uidList[uid] = {})
              o[k] = v
            })
          }
        }
  
      , remove: function () {
          return this.each(function (el) {
            el[parentNode] && el[parentNode].removeChild(el)
          })
        }
  
      , empty: function () {
          return this.each(function (el) {
            while (el.firstChild) {
              el.removeChild(el.firstChild)
            }
          })
        }
  
      , detach: function () {
          return this.map(function (el) {
            return el[parentNode].removeChild(el)
          })
        }
  
      , scrollTop: function (y) {
          return scroll.call(this, null, y, 'y')
        }
  
      , scrollLeft: function (x) {
          return scroll.call(this, x, null, 'x')
        }
  
      , toggle: function(callback) {
          this.each(function (el) {
            el.style.display = (el.offsetWidth || el.offsetHeight) ? 'none' : 'block'
          })
          callback && callback()
          return this
        }
    }
  
    function normalize(node) {
      return typeof node == 'string' ? bonzo.create(node) : is(node) ? [node] : node // assume [nodes]
    }
  
    function scroll(x, y, type) {
      var el = this[0]
      if (x == null && y == null) {
        return (isBody(el) ? getWindowScroll() : { x: el.scrollLeft, y: el.scrollTop })[type]
      }
      if (isBody(el)) {
        win.scrollTo(x, y)
      } else {
        x != null && (el.scrollLeft = x)
        y != null && (el.scrollTop = y)
      }
      return this
    }
  
    function isBody(element) {
      return element === win || (/^(?:body|html)$/i).test(element.tagName)
    }
  
    function getWindowScroll() {
      return { x: win.pageXOffset || html.scrollLeft, y: win.pageYOffset || html.scrollTop }
    }
  
    function bonzo(els, host) {
      return new Bonzo(els, host)
    }
  
    bonzo.setQueryEngine = function (q) {
      query = q;
      delete bonzo.setQueryEngine
    }
  
    bonzo.aug = function (o, target) {
      for (var k in o) {
        o.hasOwnProperty(k) && ((target || Bonzo.prototype)[k] = o[k])
      }
    }
  
    bonzo.create = function (node) {
      return typeof node == 'string' && node !== '' ?
        function () {
          var tag = /^<([^\s>]+)/.exec(node)
            , el = doc.createElement(tag && tagMap[tag[1].toLowerCase()] || 'div'), els = []
          el.innerHTML = node
          var nodes = el.childNodes
          el = el.firstChild
          el.nodeType == 1 && els.push(el)
          while (el = el.nextSibling) (el.nodeType == 1) && els.push(el)
          return els
  
        }() : is(node) ? [node.cloneNode(true)] : []
    }
  
    bonzo.doc = function () {
      var vp = this.viewport()
      return {
          width: Math.max(doc.body.scrollWidth, html.scrollWidth, vp.width)
        , height: Math.max(doc.body.scrollHeight, html.scrollHeight, vp.height)
      }
    }
  
    bonzo.firstChild = function (el) {
      for (var c = el.childNodes, i = 0, j = (c && c.length) || 0, e; i < j; i++) {
        if (c[i].nodeType === 1) {
          e = c[j = i]
        }
      }
      return e
    }
  
    bonzo.viewport = function () {
      return {
          width: ie ? html.clientWidth : self.innerWidth
        , height: ie ? html.clientHeight : self.innerHeight
      }
    }
  
    bonzo.isAncestor = 'compareDocumentPosition' in html ?
      function (container, element) {
        return (container.compareDocumentPosition(element) & 16) == 16
      } : 'contains' in html ?
      function (container, element) {
        return container !== element && container.contains(element);
      } :
      function (container, element) {
        while (element = element[parentNode]) {
          if (element === container) {
            return true
          }
        }
        return false
      }
  
    var old = context.bonzo
    bonzo.noConflict = function () {
      context.bonzo = old
      return this
    }
  
    return bonzo
  })
  

  provide("bonzo", module.exports);

  !function ($) {
  
    var b = require('bonzo')
    b.setQueryEngine($)
    $.ender(b)
    $.ender(b(), true)
    $.ender({
      create: function (node) {
        return $(b.create(node))
      }
    })
  
    $.id = function (id) {
      return $([document.getElementById(id)])
    }
  
    function indexOf(ar, val) {
      for (var i = 0; i < ar.length; i++) {
        if (ar[i] === val) return i
      }
      return -1
    }
  
    function uniq(ar) {
      var a = [], i, j
      label:
      for (i = 0; i < ar.length; i++) {
        for (j = 0; j < a.length; j++) {
          if (a[j] == ar[i]) {
            continue label
          }
        }
        a[a.length] = ar[i]
      }
      return a
    }
  
    $.ender({
      parents: function (selector, closest) {
        var collection = $(selector), j, k, p, r = []
        for (j = 0, k = this.length; j < k; j++) {
          p = this[j]
          while (p = p.parentNode) {
            if (~indexOf(collection, p)) {
              r.push(p)
              if (closest) break;
            }
          }
        }
        return $(uniq(r))
      },
  
      closest: function (selector) {
        return this.parents(selector, true)
      },
  
      first: function () {
        return $(this[0])
      },
  
      last: function () {
        return $(this[this.length - 1])
      },
  
      next: function () {
        return $(b(this).next())
      },
  
      previous: function () {
        return $(b(this).previous())
      },
  
      appendTo: function (t) {
        return b(this.selector).appendTo(t, this)
      },
  
      prependTo: function (t) {
        return b(this.selector).prependTo(t, this)
      },
  
      insertAfter: function (t) {
        return b(this.selector).insertAfter(t, this)
      },
  
      insertBefore: function (t) {
        return b(this.selector).insertBefore(t, this)
      },
  
      siblings: function () {
        var i, l, p, r = []
        for (i = 0, l = this.length; i < l; i++) {
          p = this[i]
          while (p = p.previousSibling) p.nodeType == 1 && r.push(p)
          p = this[i]
          while (p = p.nextSibling) p.nodeType == 1 && r.push(p)
        }
        return $(r)
      },
  
      children: function () {
        var i, el, r = []
        for (i = 0, l = this.length; i < l; i++) {
          if (!(el = b.firstChild(this[i]))) continue;
          r.push(el)
          while (el = el.nextSibling) el.nodeType == 1 && r.push(el)
        }
        return $(uniq(r))
      },
  
      height: function (v) {
        return dimension(v, this, 'height')
      },
  
      width: function (v) {
        return dimension(v, this, 'width')
      }
    }, true)
  
    function dimension(v, self, which) {
      return v ?
        self.css(which, v) :
        function (r) {
          r = parseInt(self.css(which), 10);
          return isNaN(r) ? self[0]['offset' + which.replace(/^\w/, function (m) {return m.toUpperCase()})] : r
        }()
    }
  
  }(ender);
  

}();

!function () {

  var module = { exports: {} }, exports = module.exports;

  //     Underscore.js 1.2.0
  //     (c) 2011 Jeremy Ashkenas, DocumentCloud Inc.
  //     Underscore is freely distributable under the MIT license.
  //     Portions of Underscore are inspired or borrowed from Prototype,
  //     Oliver Steele's Functional, and John Resig's Micro-Templating.
  //     For all details and documentation:
  //     http://documentcloud.github.com/underscore
  
  (function() {
  
    // Baseline setup
    // --------------
  
    // Establish the root object, `window` in the browser, or `global` on the server.
    var root = this;
  
    // Save the previous value of the `_` variable.
    var previousUnderscore = root._;
  
    // Establish the object that gets returned to break out of a loop iteration.
    var breaker = {};
  
    // Save bytes in the minified (but not gzipped) version:
    var ArrayProto = Array.prototype, ObjProto = Object.prototype, FuncProto = Function.prototype;
  
    // Create quick reference variables for speed access to core prototypes.
    var slice            = ArrayProto.slice,
        unshift          = ArrayProto.unshift,
        toString         = ObjProto.toString,
        hasOwnProperty   = ObjProto.hasOwnProperty;
  
    // All **ECMAScript 5** native function implementations that we hope to use
    // are declared here.
    var
      nativeForEach      = ArrayProto.forEach,
      nativeMap          = ArrayProto.map,
      nativeReduce       = ArrayProto.reduce,
      nativeReduceRight  = ArrayProto.reduceRight,
      nativeFilter       = ArrayProto.filter,
      nativeEvery        = ArrayProto.every,
      nativeSome         = ArrayProto.some,
      nativeIndexOf      = ArrayProto.indexOf,
      nativeLastIndexOf  = ArrayProto.lastIndexOf,
      nativeIsArray      = Array.isArray,
      nativeKeys         = Object.keys,
      nativeBind         = FuncProto.bind;
  
    // Create a safe reference to the Underscore object for use below.
    var _ = function(obj) { return new wrapper(obj); };
  
    // Export the Underscore object for **CommonJS**, with backwards-compatibility
    // for the old `require()` API. If we're not in CommonJS, add `_` to the
    // global object.
    if (typeof module !== 'undefined' && module.exports) {
      module.exports = _;
      _._ = _;
    } else {
      // Exported as a string, for Closure Compiler "advanced" mode.
      root['_'] = _;
    }
  
    // Current version.
    _.VERSION = '1.2.0';
  
    // Collection Functions
    // --------------------
  
    // The cornerstone, an `each` implementation, aka `forEach`.
    // Handles objects with the built-in `forEach`, arrays, and raw objects.
    // Delegates to **ECMAScript 5**'s native `forEach` if available.
    var each = _.each = _.forEach = function(obj, iterator, context) {
      if (obj == null) return;
      if (nativeForEach && obj.forEach === nativeForEach) {
        obj.forEach(iterator, context);
      } else if (obj.length === +obj.length) {
        for (var i = 0, l = obj.length; i < l; i++) {
          if (i in obj && iterator.call(context, obj[i], i, obj) === breaker) return;
        }
      } else {
        for (var key in obj) {
          if (hasOwnProperty.call(obj, key)) {
            if (iterator.call(context, obj[key], key, obj) === breaker) return;
          }
        }
      }
    };
  
    // Return the results of applying the iterator to each element.
    // Delegates to **ECMAScript 5**'s native `map` if available.
    _.map = function(obj, iterator, context) {
      var results = [];
      if (obj == null) return results;
      if (nativeMap && obj.map === nativeMap) return obj.map(iterator, context);
      each(obj, function(value, index, list) {
        results[results.length] = iterator.call(context, value, index, list);
      });
      return results;
    };
  
    // **Reduce** builds up a single result from a list of values, aka `inject`,
    // or `foldl`. Delegates to **ECMAScript 5**'s native `reduce` if available.
    _.reduce = _.foldl = _.inject = function(obj, iterator, memo, context) {
      var initial = memo !== void 0;
      if (obj == null) obj = [];
      if (nativeReduce && obj.reduce === nativeReduce) {
        if (context) iterator = _.bind(iterator, context);
        return initial ? obj.reduce(iterator, memo) : obj.reduce(iterator);
      }
      each(obj, function(value, index, list) {
        if (!initial) {
          memo = value;
          initial = true;
        } else {
          memo = iterator.call(context, memo, value, index, list);
        }
      });
      if (!initial) throw new TypeError("Reduce of empty array with no initial value");
      return memo;
    };
  
    // The right-associative version of reduce, also known as `foldr`.
    // Delegates to **ECMAScript 5**'s native `reduceRight` if available.
    _.reduceRight = _.foldr = function(obj, iterator, memo, context) {
      if (obj == null) obj = [];
      if (nativeReduceRight && obj.reduceRight === nativeReduceRight) {
        if (context) iterator = _.bind(iterator, context);
        return memo !== void 0 ? obj.reduceRight(iterator, memo) : obj.reduceRight(iterator);
      }
      var reversed = (_.isArray(obj) ? obj.slice() : _.toArray(obj)).reverse();
      return _.reduce(reversed, iterator, memo, context);
    };
  
    // Return the first value which passes a truth test. Aliased as `detect`.
    _.find = _.detect = function(obj, iterator, context) {
      var result;
      any(obj, function(value, index, list) {
        if (iterator.call(context, value, index, list)) {
          result = value;
          return true;
        }
      });
      return result;
    };
  
    // Return all the elements that pass a truth test.
    // Delegates to **ECMAScript 5**'s native `filter` if available.
    // Aliased as `select`.
    _.filter = _.select = function(obj, iterator, context) {
      var results = [];
      if (obj == null) return results;
      if (nativeFilter && obj.filter === nativeFilter) return obj.filter(iterator, context);
      each(obj, function(value, index, list) {
        if (iterator.call(context, value, index, list)) results[results.length] = value;
      });
      return results;
    };
  
    // Return all the elements for which a truth test fails.
    _.reject = function(obj, iterator, context) {
      var results = [];
      if (obj == null) return results;
      each(obj, function(value, index, list) {
        if (!iterator.call(context, value, index, list)) results[results.length] = value;
      });
      return results;
    };
  
    // Determine whether all of the elements match a truth test.
    // Delegates to **ECMAScript 5**'s native `every` if available.
    // Aliased as `all`.
    _.every = _.all = function(obj, iterator, context) {
      var result = true;
      if (obj == null) return result;
      if (nativeEvery && obj.every === nativeEvery) return obj.every(iterator, context);
      each(obj, function(value, index, list) {
        if (!(result = result && iterator.call(context, value, index, list))) return breaker;
      });
      return result;
    };
  
    // Determine if at least one element in the object matches a truth test.
    // Delegates to **ECMAScript 5**'s native `some` if available.
    // Aliased as `any`.
    var any = _.some = _.any = function(obj, iterator, context) {
      iterator = iterator || _.identity;
      var result = false;
      if (obj == null) return result;
      if (nativeSome && obj.some === nativeSome) return obj.some(iterator, context);
      each(obj, function(value, index, list) {
        if (result |= iterator.call(context, value, index, list)) return breaker;
      });
      return !!result;
    };
  
    // Determine if a given value is included in the array or object using `===`.
    // Aliased as `contains`.
    _.include = _.contains = function(obj, target) {
      var found = false;
      if (obj == null) return found;
      if (nativeIndexOf && obj.indexOf === nativeIndexOf) return obj.indexOf(target) != -1;
      any(obj, function(value) {
        if (found = value === target) return true;
      });
      return found;
    };
  
    // Invoke a method (with arguments) on every item in a collection.
    _.invoke = function(obj, method) {
      var args = slice.call(arguments, 2);
      return _.map(obj, function(value) {
        return (method.call ? method || value : value[method]).apply(value, args);
      });
    };
  
    // Convenience version of a common use case of `map`: fetching a property.
    _.pluck = function(obj, key) {
      return _.map(obj, function(value){ return value[key]; });
    };
  
    // Return the maximum element or (element-based computation).
    _.max = function(obj, iterator, context) {
      if (!iterator && _.isArray(obj)) return Math.max.apply(Math, obj);
      if (!iterator && _.isEmpty(obj)) return -Infinity;
      var result = {computed : -Infinity};
      each(obj, function(value, index, list) {
        var computed = iterator ? iterator.call(context, value, index, list) : value;
        computed >= result.computed && (result = {value : value, computed : computed});
      });
      return result.value;
    };
  
    // Return the minimum element (or element-based computation).
    _.min = function(obj, iterator, context) {
      if (!iterator && _.isArray(obj)) return Math.min.apply(Math, obj);
      if (!iterator && _.isEmpty(obj)) return Infinity;
      var result = {computed : Infinity};
      each(obj, function(value, index, list) {
        var computed = iterator ? iterator.call(context, value, index, list) : value;
        computed < result.computed && (result = {value : value, computed : computed});
      });
      return result.value;
    };
  
    // Shuffle an array.
    _.shuffle = function(obj) {
      var shuffled = [], rand;
      each(obj, function(value, index, list) {
        if (index == 0) {
          shuffled[0] = value;
        } else {
          rand = Math.floor(Math.random() * (index + 1));
          shuffled[index] = shuffled[rand];
          shuffled[rand] = value;
        }
      });
      return shuffled;
    };
  
    // Sort the object's values by a criterion produced by an iterator.
    _.sortBy = function(obj, iterator, context) {
      return _.pluck(_.map(obj, function(value, index, list) {
        return {
          value : value,
          criteria : iterator.call(context, value, index, list)
        };
      }).sort(function(left, right) {
        var a = left.criteria, b = right.criteria;
        return a < b ? -1 : a > b ? 1 : 0;
      }), 'value');
    };
  
    // Groups the object's values by a criterion produced by an iterator
    _.groupBy = function(obj, iterator) {
      var result = {};
      each(obj, function(value, index) {
        var key = iterator(value, index);
        (result[key] || (result[key] = [])).push(value);
      });
      return result;
    };
  
    // Use a comparator function to figure out at what index an object should
    // be inserted so as to maintain order. Uses binary search.
    _.sortedIndex = function(array, obj, iterator) {
      iterator || (iterator = _.identity);
      var low = 0, high = array.length;
      while (low < high) {
        var mid = (low + high) >> 1;
        iterator(array[mid]) < iterator(obj) ? low = mid + 1 : high = mid;
      }
      return low;
    };
  
    // Safely convert anything iterable into a real, live array.
    _.toArray = function(iterable) {
      if (!iterable)                return [];
      if (iterable.toArray)         return iterable.toArray();
      if (_.isArray(iterable))      return slice.call(iterable);
      if (_.isArguments(iterable))  return slice.call(iterable);
      return _.values(iterable);
    };
  
    // Return the number of elements in an object.
    _.size = function(obj) {
      return _.toArray(obj).length;
    };
  
    // Array Functions
    // ---------------
  
    // Get the first element of an array. Passing **n** will return the first N
    // values in the array. Aliased as `head`. The **guard** check allows it to work
    // with `_.map`.
    _.first = _.head = function(array, n, guard) {
      return (n != null) && !guard ? slice.call(array, 0, n) : array[0];
    };
  
    // Returns everything but the last entry of the array. Especcialy useful on
    // the arguments object. Passing **n** will return all the values in
    // the array, excluding the last N. The **guard** check allows it to work with
    // `_.map`.
    _.initial = function(array, n, guard) {
      return slice.call(array, 0, array.length - ((n == null) || guard ? 1 : n));
    };
  
    // Get the last element of an array. Passing **n** will return the last N
    // values in the array. The **guard** check allows it to work with `_.map`.
    _.last = function(array, n, guard) {
      return (n != null) && !guard ? slice.call(array, array.length - n) : array[array.length - 1];
    };
  
    // Returns everything but the first entry of the array. Aliased as `tail`.
    // Especially useful on the arguments object. Passing an **index** will return
    // the rest of the values in the array from that index onward. The **guard**
    // check allows it to work with `_.map`.
    _.rest = _.tail = function(array, index, guard) {
      return slice.call(array, (index == null) || guard ? 1 : index);
    };
  
    // Trim out all falsy values from an array.
    _.compact = function(array) {
      return _.filter(array, function(value){ return !!value; });
    };
  
    // Return a completely flattened version of an array.
    _.flatten = function(array) {
      return _.reduce(array, function(memo, value) {
        if (_.isArray(value)) return memo.concat(_.flatten(value));
        memo[memo.length] = value;
        return memo;
      }, []);
    };
  
    // Return a version of the array that does not contain the specified value(s).
    _.without = function(array) {
      return _.difference(array, slice.call(arguments, 1));
    };
  
    // Produce a duplicate-free version of the array. If the array has already
    // been sorted, you have the option of using a faster algorithm.
    // Aliased as `unique`.
    _.uniq = _.unique = function(array, isSorted, iterator) {
      var initial = iterator ? _.map(array, iterator) : array;
      var result = [];
      _.reduce(initial, function(memo, el, i) {
        if (0 == i || (isSorted === true ? _.last(memo) != el : !_.include(memo, el))) {
          memo[memo.length] = el;
          result[result.length] = array[i];
        }
        return memo;
      }, []);
      return result;
    };
  
    // Produce an array that contains the union: each distinct element from all of
    // the passed-in arrays.
    _.union = function() {
      return _.uniq(_.flatten(arguments));
    };
  
    // Produce an array that contains every item shared between all the
    // passed-in arrays. (Aliased as "intersect" for back-compat.)
    _.intersection = _.intersect = function(array) {
      var rest = slice.call(arguments, 1);
      return _.filter(_.uniq(array), function(item) {
        return _.every(rest, function(other) {
          return _.indexOf(other, item) >= 0;
        });
      });
    };
  
    // Take the difference between one array and another.
    // Only the elements present in just the first array will remain.
    _.difference = function(array, other) {
      return _.filter(array, function(value){ return !_.include(other, value); });
    };
  
    // Zip together multiple lists into a single array -- elements that share
    // an index go together.
    _.zip = function() {
      var args = slice.call(arguments);
      var length = _.max(_.pluck(args, 'length'));
      var results = new Array(length);
      for (var i = 0; i < length; i++) results[i] = _.pluck(args, "" + i);
      return results;
    };
  
    // If the browser doesn't supply us with indexOf (I'm looking at you, **MSIE**),
    // we need this function. Return the position of the first occurrence of an
    // item in an array, or -1 if the item is not included in the array.
    // Delegates to **ECMAScript 5**'s native `indexOf` if available.
    // If the array is large and already in sort order, pass `true`
    // for **isSorted** to use binary search.
    _.indexOf = function(array, item, isSorted) {
      if (array == null) return -1;
      var i, l;
      if (isSorted) {
        i = _.sortedIndex(array, item);
        return array[i] === item ? i : -1;
      }
      if (nativeIndexOf && array.indexOf === nativeIndexOf) return array.indexOf(item);
      for (i = 0, l = array.length; i < l; i++) if (array[i] === item) return i;
      return -1;
    };
  
    // Delegates to **ECMAScript 5**'s native `lastIndexOf` if available.
    _.lastIndexOf = function(array, item) {
      if (array == null) return -1;
      if (nativeLastIndexOf && array.lastIndexOf === nativeLastIndexOf) return array.lastIndexOf(item);
      var i = array.length;
      while (i--) if (array[i] === item) return i;
      return -1;
    };
  
    // Generate an integer Array containing an arithmetic progression. A port of
    // the native Python `range()` function. See
    // [the Python documentation](http://docs.python.org/library/functions.html#range).
    _.range = function(start, stop, step) {
      if (arguments.length <= 1) {
        stop = start || 0;
        start = 0;
      }
      step = arguments[2] || 1;
  
      var len = Math.max(Math.ceil((stop - start) / step), 0);
      var idx = 0;
      var range = new Array(len);
  
      while(idx < len) {
        range[idx++] = start;
        start += step;
      }
  
      return range;
    };
  
    // Function (ahem) Functions
    // ------------------
  
    // Create a function bound to a given object (assigning `this`, and arguments,
    // optionally). Binding with arguments is also known as `curry`.
    // Delegates to **ECMAScript 5**'s native `Function.bind` if available.
    // We check for `func.bind` first, to fail fast when `func` is undefined.
    _.bind = function(func, obj) {
      if (func.bind === nativeBind && nativeBind) return nativeBind.apply(func, slice.call(arguments, 1));
      var args = slice.call(arguments, 2);
      return function() {
        return func.apply(obj, args.concat(slice.call(arguments)));
      };
    };
  
    // Bind all of an object's methods to that object. Useful for ensuring that
    // all callbacks defined on an object belong to it.
    _.bindAll = function(obj) {
      var funcs = slice.call(arguments, 1);
      if (funcs.length == 0) funcs = _.functions(obj);
      each(funcs, function(f) { obj[f] = _.bind(obj[f], obj); });
      return obj;
    };
  
    // Memoize an expensive function by storing its results.
    _.memoize = function(func, hasher) {
      var memo = {};
      hasher || (hasher = _.identity);
      return function() {
        var key = hasher.apply(this, arguments);
        return hasOwnProperty.call(memo, key) ? memo[key] : (memo[key] = func.apply(this, arguments));
      };
    };
  
    // Delays a function for the given number of milliseconds, and then calls
    // it with the arguments supplied.
    _.delay = function(func, wait) {
      var args = slice.call(arguments, 2);
      return setTimeout(function(){ return func.apply(func, args); }, wait);
    };
  
    // Defers a function, scheduling it to run after the current call stack has
    // cleared.
    _.defer = function(func) {
      return _.delay.apply(_, [func, 1].concat(slice.call(arguments, 1)));
    };
  
    // Internal function used to implement `_.throttle` and `_.debounce`.
    var limit = function(func, wait, debounce) {
      var timeout;
      return function() {
        var context = this, args = arguments;
        var throttler = function() {
          timeout = null;
          func.apply(context, args);
        };
        if (debounce) clearTimeout(timeout);
        if (debounce || !timeout) timeout = setTimeout(throttler, wait);
      };
    };
  
    // Returns a function, that, when invoked, will only be triggered at most once
    // during a given window of time.
    _.throttle = function(func, wait) {
      return limit(func, wait, false);
    };
  
    // Returns a function, that, as long as it continues to be invoked, will not
    // be triggered. The function will be called after it stops being called for
    // N milliseconds.
    _.debounce = function(func, wait) {
      return limit(func, wait, true);
    };
  
    // Returns a function that will be executed at most one time, no matter how
    // often you call it. Useful for lazy initialization.
    _.once = function(func) {
      var ran = false, memo;
      return function() {
        if (ran) return memo;
        ran = true;
        return memo = func.apply(this, arguments);
      };
    };
  
    // Returns the first function passed as an argument to the second,
    // allowing you to adjust arguments, run code before and after, and
    // conditionally execute the original function.
    _.wrap = function(func, wrapper) {
      return function() {
        var args = [func].concat(slice.call(arguments));
        return wrapper.apply(this, args);
      };
    };
  
    // Returns a function that is the composition of a list of functions, each
    // consuming the return value of the function that follows.
    _.compose = function() {
      var funcs = slice.call(arguments);
      return function() {
        var args = slice.call(arguments);
        for (var i = funcs.length - 1; i >= 0; i--) {
          args = [funcs[i].apply(this, args)];
        }
        return args[0];
      };
    };
  
    // Returns a function that will only be executed after being called N times.
    _.after = function(times, func) {
      return function() {
        if (--times < 1) { return func.apply(this, arguments); }
      };
    };
  
    // Object Functions
    // ----------------
  
    // Retrieve the names of an object's properties.
    // Delegates to **ECMAScript 5**'s native `Object.keys`
    _.keys = nativeKeys || function(obj) {
      if (obj !== Object(obj)) throw new TypeError('Invalid object');
      var keys = [];
      for (var key in obj) if (hasOwnProperty.call(obj, key)) keys[keys.length] = key;
      return keys;
    };
  
    // Retrieve the values of an object's properties.
    _.values = function(obj) {
      return _.map(obj, _.identity);
    };
  
    // Return a sorted list of the function names available on the object.
    // Aliased as `methods`
    _.functions = _.methods = function(obj) {
      var names = [];
      for (var key in obj) {
        if (_.isFunction(obj[key])) names.push(key);
      }
      return names.sort();
    };
  
    // Extend a given object with all the properties in passed-in object(s).
    _.extend = function(obj) {
      each(slice.call(arguments, 1), function(source) {
        for (var prop in source) {
          if (source[prop] !== void 0) obj[prop] = source[prop];
        }
      });
      return obj;
    };
  
    // Fill in a given object with default properties.
    _.defaults = function(obj) {
      each(slice.call(arguments, 1), function(source) {
        for (var prop in source) {
          if (obj[prop] == null) obj[prop] = source[prop];
        }
      });
      return obj;
    };
  
    // Create a (shallow-cloned) duplicate of an object.
    _.clone = function(obj) {
      return _.isArray(obj) ? obj.slice() : _.extend({}, obj);
    };
  
    // Invokes interceptor with the obj, and then returns obj.
    // The primary purpose of this method is to "tap into" a method chain, in
    // order to perform operations on intermediate results within the chain.
    _.tap = function(obj, interceptor) {
      interceptor(obj);
      return obj;
    };
  
    // Internal recursive comparison function.
    function eq(a, b, stack) {
      // Identical objects are equal. `0 === -0`, but they aren't identical.
      // See the Harmony `egal` proposal: http://wiki.ecmascript.org/doku.php?id=harmony:egal.
      if (a === b) return a !== 0 || 1 / a == 1 / b;
      // A strict comparison is necessary because `null == undefined`.
      if (a == null) return a === b;
      // Compare object types.
      var typeA = typeof a;
      if (typeA != typeof b) return false;
      // Optimization; ensure that both values are truthy or falsy.
      if (!a != !b) return false;
      // `NaN` values are equal.
      if (_.isNaN(a)) return _.isNaN(b);
      // Compare string objects by value.
      var isStringA = _.isString(a), isStringB = _.isString(b);
      if (isStringA || isStringB) return isStringA && isStringB && String(a) == String(b);
      // Compare number objects by value.
      var isNumberA = _.isNumber(a), isNumberB = _.isNumber(b);
      if (isNumberA || isNumberB) return isNumberA && isNumberB && +a == +b;
      // Compare boolean objects by value. The value of `true` is 1; the value of `false` is 0.
      var isBooleanA = _.isBoolean(a), isBooleanB = _.isBoolean(b);
      if (isBooleanA || isBooleanB) return isBooleanA && isBooleanB && +a == +b;
      // Compare dates by their millisecond values.
      var isDateA = _.isDate(a), isDateB = _.isDate(b);
      if (isDateA || isDateB) return isDateA && isDateB && a.getTime() == b.getTime();
      // Compare RegExps by their source patterns and flags.
      var isRegExpA = _.isRegExp(a), isRegExpB = _.isRegExp(b);
      if (isRegExpA || isRegExpB) {
        // Ensure commutative equality for RegExps.
        return isRegExpA && isRegExpB &&
               a.source == b.source &&
               a.global == b.global &&
               a.multiline == b.multiline &&
               a.ignoreCase == b.ignoreCase;
      }
      // Ensure that both values are objects.
      if (typeA != 'object') return false;
      // Unwrap any wrapped objects.
      if (a._chain) a = a._wrapped;
      if (b._chain) b = b._wrapped;
      // Invoke a custom `isEqual` method if one is provided.
      if (_.isFunction(a.isEqual)) return a.isEqual(b);
      // Assume equality for cyclic structures. The algorithm for detecting cyclic structures is
      // adapted from ES 5.1 section 15.12.3, abstract operation `JO`.
      var length = stack.length;
      while (length--) {
        // Linear search. Performance is inversely proportional to the number of unique nested
        // structures.
        if (stack[length] == a) return true;
      }
      // Add the first object to the stack of traversed objects.
      stack.push(a);
      var size = 0, result = true;
      if (a.length === +a.length || b.length === +b.length) {
        // Compare object lengths to determine if a deep comparison is necessary.
        size = a.length;
        result = size == b.length;
        if (result) {
          // Deep compare array-like object contents, ignoring non-numeric properties.
          while (size--) {
            // Ensure commutative equality for sparse arrays.
            if (!(result = size in a == size in b && eq(a[size], b[size], stack))) break;
          }
        }
      } else {
        // Deep compare objects.
        for (var key in a) {
          if (hasOwnProperty.call(a, key)) {
            // Count the expected number of properties.
            size++;
            // Deep compare each member.
            if (!(result = hasOwnProperty.call(b, key) && eq(a[key], b[key], stack))) break;
          }
        }
        // Ensure that both objects contain the same number of properties.
        if (result) {
          for (key in b) {
            if (hasOwnProperty.call(b, key) && !size--) break;
          }
          result = !size;
        }
      }
      // Remove the first object from the stack of traversed objects.
      stack.pop();
      return result;
    }
  
    // Perform a deep comparison to check if two objects are equal.
    _.isEqual = function(a, b) {
      return eq(a, b, []);
    };
  
    // Is a given array or object empty?
    _.isEmpty = function(obj) {
      if (_.isArray(obj) || _.isString(obj)) return obj.length === 0;
      for (var key in obj) if (hasOwnProperty.call(obj, key)) return false;
      return true;
    };
  
    // Is a given value a DOM element?
    _.isElement = function(obj) {
      return !!(obj && obj.nodeType == 1);
    };
  
    // Is a given value an array?
    // Delegates to ECMA5's native Array.isArray
    _.isArray = nativeIsArray || function(obj) {
      return toString.call(obj) === '[object Array]';
    };
  
    // Is a given variable an object?
    _.isObject = function(obj) {
      return obj === Object(obj);
    };
  
    // Is a given variable an arguments object?
    _.isArguments = function(obj) {
      return !!(obj && hasOwnProperty.call(obj, 'callee'));
    };
  
    // Is a given value a function?
    _.isFunction = function(obj) {
      return !!(obj && obj.constructor && obj.call && obj.apply);
    };
  
    // Is a given value a string?
    _.isString = function(obj) {
      return !!(obj === '' || (obj && obj.charCodeAt && obj.substr));
    };
  
    // Is a given value a number?
    _.isNumber = function(obj) {
      return !!(obj === 0 || (obj && obj.toExponential && obj.toFixed));
    };
  
    // Is the given value `NaN`? `NaN` happens to be the only value in JavaScript
    // that does not equal itself.
    _.isNaN = function(obj) {
      return obj !== obj;
    };
  
    // Is a given value a boolean?
    _.isBoolean = function(obj) {
      return obj === true || obj === false || toString.call(obj) == '[object Boolean]';
    };
  
    // Is a given value a date?
    _.isDate = function(obj) {
      return !!(obj && obj.getTimezoneOffset && obj.setUTCFullYear);
    };
  
    // Is the given value a regular expression?
    _.isRegExp = function(obj) {
      return !!(obj && obj.test && obj.exec && (obj.ignoreCase || obj.ignoreCase === false));
    };
  
    // Is a given value equal to null?
    _.isNull = function(obj) {
      return obj === null;
    };
  
    // Is a given variable undefined?
    _.isUndefined = function(obj) {
      return obj === void 0;
    };
  
    // Utility Functions
    // -----------------
  
    // Run Underscore.js in *noConflict* mode, returning the `_` variable to its
    // previous owner. Returns a reference to the Underscore object.
    _.noConflict = function() {
      root._ = previousUnderscore;
      return this;
    };
  
    // Keep the identity function around for default iterators.
    _.identity = function(value) {
      return value;
    };
  
    // Run a function **n** times.
    _.times = function (n, iterator, context) {
      for (var i = 0; i < n; i++) iterator.call(context, i);
    };
  
    // Escape a string for HTML interpolation.
    _.escape = function(string) {
      return (''+string).replace(/&(?!\w+;|#\d+;|#x[\da-f]+;)/gi, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;').replace(/'/g, '&#x27;').replace(/\//g,'&#x2F;');
    };
  
    // Add your own custom functions to the Underscore object, ensuring that
    // they're correctly added to the OOP wrapper as well.
    _.mixin = function(obj) {
      each(_.functions(obj), function(name){
        addToWrapper(name, _[name] = obj[name]);
      });
    };
  
    // Generate a unique integer id (unique within the entire client session).
    // Useful for temporary DOM ids.
    var idCounter = 0;
    _.uniqueId = function(prefix) {
      var id = idCounter++;
      return prefix ? prefix + id : id;
    };
  
    // By default, Underscore uses ERB-style template delimiters, change the
    // following template settings to use alternative delimiters.
    _.templateSettings = {
      evaluate    : /<%([\s\S]+?)%>/g,
      interpolate : /<%=([\s\S]+?)%>/g,
      escape      : /<%-([\s\S]+?)%>/g
    };
  
    // JavaScript micro-templating, similar to John Resig's implementation.
    // Underscore templating handles arbitrary delimiters, preserves whitespace,
    // and correctly escapes quotes within interpolated code.
    _.template = function(str, data) {
      var c  = _.templateSettings;
      var tmpl = 'var __p=[],print=function(){__p.push.apply(__p,arguments);};' +
        'with(obj||{}){__p.push(\'' +
        str.replace(/\\/g, '\\\\')
           .replace(/'/g, "\\'")
           .replace(c.escape, function(match, code) {
             return "',_.escape(" + code.replace(/\\'/g, "'") + "),'";
           })
           .replace(c.interpolate, function(match, code) {
             return "'," + code.replace(/\\'/g, "'") + ",'";
           })
           .replace(c.evaluate || null, function(match, code) {
             return "');" + code.replace(/\\'/g, "'")
                                .replace(/[\r\n\t]/g, ' ') + "__p.push('";
           })
           .replace(/\r/g, '\\r')
           .replace(/\n/g, '\\n')
           .replace(/\t/g, '\\t')
           + "');}return __p.join('');";
      var func = new Function('obj', tmpl);
      return data ? func(data) : func;
    };
  
    // The OOP Wrapper
    // ---------------
  
    // If Underscore is called as a function, it returns a wrapped object that
    // can be used OO-style. This wrapper holds altered versions of all the
    // underscore functions. Wrapped objects may be chained.
    var wrapper = function(obj) { this._wrapped = obj; };
  
    // Expose `wrapper.prototype` as `_.prototype`
    _.prototype = wrapper.prototype;
  
    // Helper function to continue chaining intermediate results.
    var result = function(obj, chain) {
      return chain ? _(obj).chain() : obj;
    };
  
    // A method to easily add functions to the OOP wrapper.
    var addToWrapper = function(name, func) {
      wrapper.prototype[name] = function() {
        var args = slice.call(arguments);
        unshift.call(args, this._wrapped);
        return result(func.apply(_, args), this._chain);
      };
    };
  
    // Add all of the Underscore functions to the wrapper object.
    _.mixin(_);
  
    // Add all mutator Array functions to the wrapper.
    each(['pop', 'push', 'reverse', 'shift', 'sort', 'splice', 'unshift'], function(name) {
      var method = ArrayProto[name];
      wrapper.prototype[name] = function() {
        method.apply(this._wrapped, arguments);
        return result(this._wrapped, this._chain);
      };
    });
  
    // Add all accessor Array functions to the wrapper.
    each(['concat', 'join', 'slice'], function(name) {
      var method = ArrayProto[name];
      wrapper.prototype[name] = function() {
        return result(method.apply(this._wrapped, arguments), this._chain);
      };
    });
  
    // Start chaining a wrapped Underscore object.
    wrapper.prototype.chain = function() {
      this._chain = true;
      return this;
    };
  
    // Extracts the result from a wrapped and chained object.
    wrapper.prototype.value = function() {
      return this._wrapped;
    };
  
  })();
  

  provide("underscore", module.exports);

  $.ender(module.exports);

}();