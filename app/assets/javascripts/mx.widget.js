//= require ender
//= require q

!(function() {
	
	var mx = this.mx || (this.mx = {}); mx.widget || (mx.widget = {});

	function t(s, d) { for (var p in d) s = s.replace(new RegExp('{{' + p + '}}', 'g'), d[p]); return s; }

	function query(e) { return isNode(e) ? e : document.getElementById(e); }

	function isNode(e) { return (e && e.nodeType && (e.nodeType == 1 || e.nodeType == 9)); }

	function url(engine, market, params) {
		return t('/widgets/widget.json?engine={{engine}}&market={{market}}&params={{params}}', {
			engine: encodeURIComponent(engine),
			market: encodeURIComponent(market),
			params: encodeURIComponent(params.join(','))
		});
	}
	
	function iframe_document(iframe) {
		return iframe.contentWindow.document;
	}
	
	function ensure_content(document) {
		return $('body > table', document);
	}

	// entry point
	
	$(window).bind('widget:loaded', function() {
		console.log('widget loaded!')
	})
	

	mx.widget.table = function(element, engine, market, params, options) {
		$.domReady(function() {
			element = $(element); if (!element) return;
			//var iframe = $('<iframe>').attr('style', 'border: none;').attr('src', url(engine, market, params));
			//$(element).append(iframe);

			$.ajax({
				url: '/widgets/widget.jsonp?callback=?',
				type: 'jsonp',
				success: function(promise) {
				}
			});

		});


		/*
		element = query(element); if (!element) return;
		
		query(element).innerHTML = t('<iframe src="{{url}}" style="border: none;"></iframe>', {
			url: url(engine, market, params)
		});
		*/

	}

})();
