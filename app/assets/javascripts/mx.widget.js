//= require widget

!(function($) {
	
	var mx = this.mx || (this.mx = {}); mx.widget || (mx.widget = {});
	
	function t(s, d) { for (var p in d) s = s.replace(new RegExp('{{' + p + '}}', 'g'), d[p]); return s; }

    number_with_delimiter = function(number, options) {
    	options = $.extend({}, options || {});

    	var delimiter = options.delimiter || ' ';
    	var separator = options.separator || ',';

    	var parts = number.toString().split(".");

    	parts[0] = parts[0].replace(/(\d)(?=(\d\d\d)+(?!\d))/g, "$1" + delimiter);

    	return parts.join(separator);
    }

    number_with_precision = function(number, options) {
    	options = $.extend({}, options || {});

    	var precision = options.precision || 2;

    	return number_with_delimiter(new Number(number).toFixed(precision), options);
    }

	var iss = {
		host: 'http://beta.micex.ru',
		
		merge: function(data) {
			return $.map(data.data, function(record) {
				return $.reduce(record, function(memo, value, index) {
					return memo[data.columns[index]] = value, memo; 
				}, {});
			});
		},
		
		prepare_filters: function(filters) {
			return $.reduce(filters, function(memo, record) {
				return (memo[record.filter_name] || (memo[record.filter_name] = [])).push({ id: record.id, name: record.name }), memo;
			}, {});
		},
		
		prepare_columns: function(securities, marketdata) {
			return $.extend(
				$.reduce(securities, function(memo, record) { return memo[record.id] = record, memo; }, {}),
				$.reduce(marketdata, function(memo, record) { return memo[record.id] = record, memo; }, {})
			);
		},
		
		prepare_records: function(securities, marketdata) {
			securities = $.reduce(securities, function(memo, record) { return memo[[record.BOARDID, record.SECID].join('/')] = record, memo; }, {})
			marketdata = $.reduce(marketdata, function(memo, record) { return memo[[record.BOARDID, record.SECID].join('/')] = record, memo; }, {})
			return $.reduce($.keys(securities), function(memo, key) { return memo.push($.extend(securities[key], marketdata[key])), memo; }, []);
		},
		
		cache: $.cache('iss/widgets')
	}
	

	iss.filters = function(engine, market) {
		
		var defer = Q.defer();
		
		var cache_key	= ['filters', engine, market].join('/');
		var cached_data	= iss.cache.get(cache_key);

		if (cached_data) {
			defer.resolve(cached_data);
			return defer.promise;
		}
		
		function onSuccess(json) {
			defer.resolve(iss.cache.set(cache_key, iss.prepare_filters(iss.merge(json.filters)), 60 * 60 * 1000));
		}
		
		$.ajax({
			url: t('{{host}}/iss/engines/{{engine}}/markets/{{market}}/securities/columns/filters.jsonp?iss.meta=off&iss.only=filters&callback=?', {
				host: 	iss.host,
				engine: encodeURIComponent(engine),
				market: encodeURIComponent(market)
			}),
			type: 'jsonp',
			success: onSuccess
		})
		
		return defer.promise;
		
	};

	iss.columns = function(engine, market) {

		var defer = Q.defer();
		
		var cache_key	= ['columns', engine, market].join('/');
		var cached_data	= iss.cache.get(cache_key);

		if (cached_data) {
			defer.resolve(cached_data);
			return defer.promise;
		}

		function onSuccess(json) {
			defer.resolve(iss.cache.set(cache_key, iss.prepare_columns(iss.merge(json.securities), iss.merge(json.marketdata)), 60 * 60 * 1000));
		}
		
		$.ajax({
			url: t('{{host}}/iss/engines/{{engine}}/markets/{{market}}/securities/columns.jsonp?iss.meta=off&iss.only=securities,marketdata&callback=?', {
				host: 	iss.host,
				engine: encodeURIComponent(engine),
				market: encodeURIComponent(market)
			}),
			type: 'jsonp',
			success: onSuccess
		})
		
		return defer.promise;

	}
	
	iss.records = function(engine, market, params, force) {

		var defer = Q.defer();
		
		var cache_key	= ['records', engine, market, params].join('/');
		if (force)
		    iss.cache.remove(cache_key);
		var cached_data	= iss.cache.get(cache_key);

		if (cached_data) {
			defer.resolve(cached_data);
			return defer.promise;
		}

		function onSuccess(json) {
			defer.resolve(iss.cache.set(cache_key, iss.prepare_records(iss.merge(json.securities), iss.merge(json.marketdata))));
		}
		
		$.ajax({
			url: t('{{host}}/iss/engines/{{engine}}/markets/{{market}}/securities.jsonp?iss.meta=off&iss.only=securities,marketdata&securities={{params}}&callback=?', {
				host: 	iss.host,
				engine: encodeURIComponent(engine),
				market: encodeURIComponent(market),
				params: encodeURIComponent(params)
			}),
			type: 'jsonp',
			success: onSuccess
		})
		
		return defer.promise;

	}
	
	function render(element, filters, columns, records, cache_key, options) {
		
		function prepare_value(value, column) {
		    switch(column.type) {
		        case 'time':
		            return $.initial(value.split(':')).join(':');
		        case 'number':
		            return number_with_precision(value, column.precision);
		    }
		    return value;
		}
		
		function prepare_cell(column) {
			return { 
				type: 	column.type,
				value: 	prepare_value(this[column.name], column)
			}
		}
		
		function prepare_row(record) {
			return $.map(visible_columns, prepare_cell, record);
		}
		
		function render_cell(cell, index, row) {
			return $.create('<td>')
				.addClass(cell.type)
				.toggleClass('first', index === $.first(row))
				.toggleClass('last', cell === $.last(row))
				.html($.create('<span>').html(cell.value));
		}
		
		function render_row(row, index) {
			var el = $.create('<tr>').addClass(index % 2 ? 'even' : 'odd').append($.flatten($.map(row, render_cell)));
			return el;
		}

		var visible_columns = (function() { return $.map($.pluck(filters[options.filter], 'id'), function(id) { return columns[id]; }); })();

		var rows = (function() { return $.map(records, prepare_row) })();


		var table = $.create('<table>').addClass('mx-widget-table');
		
		table.append($.create('<tbody>').append($.flatten($.map(rows, render_row))));
		
		element.html('').append(table);
		iss.cache.set(cache_key, element.html());
	}

	var default_options = {
		filter: 'small'
	}

	mx.widget.table = function(element, engine, market, params, options) {
		element = $(element); if (!element) return;
		
		$.defaults(options || (options = {}), default_options);
		
		var cache_key = ['render', engine, market, params].join('/');
		var cached_render = iss.cache.get(cache_key);
		
		if (cached_render)
		    element.html(cached_render);
		
		var filters = iss.filters(engine, market);
		var columns = iss.columns(engine, market);
		var records = iss.records(engine, market, params, true);

		Q.join(filters, columns, records, function() { render(element, filters.valueOf(), columns.valueOf(), records.valueOf(), cache_key, options); });
		
		setInterval(function() {
			
			records = iss.records(engine, market, params, true);
			Q.join(filters, columns, records, function() { render(element, filters.valueOf(), columns.valueOf(), records.valueOf(), cache_key, options); });
			
		}, 60 * 1000);
		
	}
	
	var cs = {
	    
	    host: 'http://beta.micex.ru',
	    
	    calculate_dimensions: function(element) {
	        var width = element.offset().width, height = Math.round(width / 2);
	        return {
	            'z1.width': width,
	            'z1_c.height': height,
	            'c.width': width,
	            'c.height': height + 20
	        }
	    }
	    
	};

	
	cs.chart = function(element, engine, market, security) {

        var dimensions = cs.calculate_dimensions(element);

	    var url = t('{{host}}/cs/engines/{{engine}}/markets/{{market}}/securities/{{security}}.png?template=adv_no_volume&{{dimensions}}', {
	        host: cs.host,
	        engine: engine,
	        market: market,
	        security: security,
	        dimensions: $.toQueryString(dimensions)
	    });
	    
        var image = $.create('<img>').attr('src', url);
        
        image.bind('load', function() {
            element.html('').append(image);
        });
	    
	}
	
	mx.widget.chart = function(element, engine, market, security, options) {
	    element = $(element); if (!element) return;
	    cs.chart(element, engine, market, security);
	}

})(ender.noConflict());
