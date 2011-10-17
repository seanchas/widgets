//= require jquery
//= require q
//= require underscore
//= require kizzy

!(function($, _) {
	
	var mx = this.mx || (this.mx = {}); mx.widget || (mx.widget = {});
	
	function t(s, d) { for (var p in d) s = s.replace(new RegExp('{{' + p + '}}', 'g'), d[p]); return s; }

    number_with_delimiter = function(number, options) {
    	options = _.extend({}, options || {});

    	var delimiter = options.delimiter || ' ';
    	var separator = options.separator || ',';

    	var parts = number.toString().split(".");

    	parts[0] = parts[0].replace(/(\d)(?=(\d\d\d)+(?!\d))/g, "$1" + delimiter);

    	return parts.join(separator);
    }

    number_with_precision = function(number, options) {
    	options = _.extend({}, options || {});

    	var precision = options.precision || 2;

    	return number_with_delimiter(new Number(number).toFixed(precision), options);
    }

	var iss = {
		host: 'http://beta.micex.ru',
		
		merge: function(data) {
			return _.map(data.data, function(record) {
				return _.reduce(record, function(memo, value, index) {
					return memo[data.columns[index]] = value, memo; 
				}, {});
			});
		},
		
		prepare_filters: function(filters) {
			return _.reduce(filters, function(memo, record) {
				return (memo[record.filter_name] || (memo[record.filter_name] = [])).push({ id: record.id, name: record.name }), memo;
			}, {});
		},
		
		prepare_columns: function(securities, marketdata) {
			return _.extend(
				_.reduce(securities, function(memo, record) { return memo[record.id] = record, memo; }, {}),
				_.reduce(marketdata, function(memo, record) { return memo[record.id] = record, memo; }, {})
			);
		},
		
		prepare_records: function(securities, marketdata) {
			securities = _.reduce(securities, function(memo, record) { return memo[[record.BOARDID, record.SECID].join('/')] = record, memo; }, {})
			marketdata = _.reduce(marketdata, function(memo, record) { return memo[[record.BOARDID, record.SECID].join('/')] = record, memo; }, {})
			return _.reduce(_.keys(securities), function(memo, key) { return memo.push(_.extend(securities[key], marketdata[key])), memo; }, []);
		},
		
		cache: kizzy('iss/widgets')
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
			dataType: 'jsonp',
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
			dataType: 'jsonp',
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
			dataType: 'jsonp',
			success: onSuccess
		})
		
		return defer.promise;

	}
	
	function table_chart_data(row) {
	    var row_data = row.data();
	    var table_data = row.closest('table').data();
	    return {
	        engine:     table_data.engine,
	        market:     table_data.market,
	        board:      row_data.board,
	        security:   row_data.security
	    }
	}
	
	function render_table_chart(row) {
	    var data        = table_chart_data(row);
	    var next_row    = row.next('tr');

	    if (next_row.hasClass('chart')) {
	        if (next_row.is(':hidden'))
	            $('tr.chart', row.closest('table')).hide();
	        next_row.toggle()
	    } else {
    	    $('tr.chart', row.closest('table')).hide();

	        next_row = $('<tr>').addClass('chart').html($('<td>').attr('colspan', _.size($('td', row))));
	        next_row.insertAfter(row);
	        mx.widget.chart($('td', next_row), data.engine, data.market, data.security);
	    }
	    
	}
	
	function bind_table_events(element) {
	    $(element).delegate('tr', 'click', function(event) {
	        render_table_chart($(event.currentTarget));
	    })
	}
	
	function render(element, engine, market, filters, columns, records, cache_key, options) {
		
		function prepare_value(value, column) {
		    switch(column.type) {
		        case 'time':
		            return _.initial(value.split(':')).join(':');
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
			return {
			    board: record['BOARDID'],
			    security: record['SECID'],
			    cells: _.map(visible_columns, prepare_cell, record)
			};
		}
		
		function render_cell(cell, index, row) {
			return $('<td>')
				.addClass(cell.type)
				.toggleClass('first', index === _.first(row))
				.toggleClass('last', cell === _.last(row))
				.html($('<span>').html(cell.value));
		}
		
		function render_row(row, index) {
		    var el = $('<tr>')
		        .data({
		            board: row.board,
		            security: row.security
		        })
		        .addClass(index % 2 ? 'even' : 'odd');
		    
		    _.each(_.map(row.cells, render_cell), function(cell) { el.append(cell); });

		    return el;
		}
		
		var visible_columns = (function() { return _.map(_.pluck(filters[options.filter], 'id'), function(id) { return columns[id]; }); })();

		var rows = (function() { return _.map(records, prepare_row) })();

		var table = $('<table>')
		    .addClass('mx-widget-table')
		    .data({
		        engine: engine,
		        market: market
		    });
		
		_.each(_.map(rows, render_row), function(row) {
		    table.append(row)
		});
		
		element.html(table);
		iss.cache.set(cache_key, element.html());

	}

	var default_options = {
		filter: 'small'
	}

	mx.widget.table = function(element, engine, market, params, options) {
		element = $(element); if (!element) return;
		
		bind_table_events(element);
		
		_.defaults(options || (options = {}), default_options);
		
		var cache_key = ['render', engine, market, params].join('/');
		var cached_render = iss.cache.get(cache_key);
		
		if (cached_render)
		    element.html(cached_render);
		
		var filters = iss.filters(engine, market);
		var columns = iss.columns(engine, market);
		var records = iss.records(engine, market, params, true);

		Q.join(filters, columns, records, function() { render(element, engine, market, filters.valueOf(), columns.valueOf(), records.valueOf(), cache_key, options); });
		
		setInterval(function() {
			
			records = iss.records(engine, market, params, true);
			Q.join(filters, columns, records, function() { render(element, engine, market, filters.valueOf(), columns.valueOf(), records.valueOf(), cache_key, options); });
			
		}, 60 * 1000);
		
	}
	
	var cs = {
	    
	    host: 'http://beta.micex.ru',
	    
	    calculate_dimensions: function(element) {
	        var width = element.width(), height = Math.round(width / 2);
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
	        dimensions: $.param(dimensions)
	    });
	    
        var image = $('<img>').attr('src', url);
        
        image.bind('load', function() {
            element.html('').append(image);
        });
	    
	}
	
	mx.widget.chart = function(element, engine, market, security, options) {
	    element = $(element); if (!element) return;
	    cs.chart(element, engine, market, security);
	}

})($.noConflict(), _.noConflict());
