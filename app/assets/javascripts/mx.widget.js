!(function() {
	
	var mx = this.mx || (this.mx = {}); mx.widget || (mx.widget = {});

	function t(s, d) { for (var p in d) s = s.replace(new RegExp('{{' + p + '}}', 'g'), d[p]); return s; }

	function query(e) { return isNode(e) ? e : document.getElementById(e); }

	function isNode(e) { return (e && e.nodeType && (e.nodeType == 1 || e.nodeType == 9)); }

	function url(engine, market, params) {
		return t('http://beta.micex.ru/widgets/widget?engine={{engine}}&market={{market}}&params={{params}}', {
			engine: encodeURIComponent(engine),
			market: encodeURIComponent(market),
			params: encodeURIComponent(params.join(','))
		});
	}
	
	function i(e) {
		
	}

	// entry point
	
	mx.widget.table = function(element, engine, market, params, options) {
		element = query(element); if (!element) return;
		
		query(element).innerHTML = t('<iframe src="{{url}}" style="border: none;"></iframe>', {
			url: url(engine, market, params)
		});
	}

})();
