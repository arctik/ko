//
// list template helper
//
// depends on RQL, autocomplete
//
;(function($){

$.fn.tablify = function(options){

	options = $.extend({
		//query: ???,
		searchTimeout: 1000
	}, options || {});

//
// autocomplete helper
//
function autocomplete(el, uri, select, multi){
	// http://jqueryui.com/demos/autocomplete/#multiple-remote
	function split(val){
		return val.split(/,\s*/);
	}
	function extractLast(term){
		return split(term).pop();
	}
	var options = multi ?
	{
		delay: 100,
		source: function(req, res){
			$.getJSON(uri + '?' + RQL.Query().eq('id', new RegExp(extractLast(req.term), 'i')).select(select), res);
		},
		/*search: function(){
			// custom minLength
			var term = extractLast(this.value);
			if (term.length < 2) {
				return false;
			}
		},*/
		focus: function(){
			// prevent value inserted on focus
			return false;
		},
		select: function(event, ui){
			var terms = split(this.value);
			// remove the current input
			terms.pop();
			// add the selected item
			terms.push(ui.item.value);
			// add placeholder to get the comma-and-space at the end
			terms.push('');
			this.value = terms.join(', ');
			return false;
		}
	} : {
		delay: 100,
		source: function(req, res){
			//$.getJSON(uri + '?' + RQL.Query().eq('id', new RegExp(req.term, 'i')).select(select), res);
			var field = select ? select : 'id';
			//$.getJSON(uri + '?' + RQL.Query().eq(field, new RegExp(req.term, 'i')).select(['id',field]), res);
			$.getJSON(uri + '?' + RQL.Query().match(field, req.term, 'i').values(field), res);
		}
	};
	/*if (multi) $.each(el, function(i, x){
		console.log('PATCHVALUE', x);
		var oldVal = $(x).val;
		$(x).val = function(){
			console.log('GETVALUE');
			var value = oldVal.apply(this);
			return split(value);
		};
	});*/
	return el.autocomplete(options);
}

return $(this).each(function(i, el){

	var target = $(el);

	// command executor
	function docmd(cmd){
		switch (cmd) {
			case 'all':
			case 'none':
			case 'toggle':
				var fn = cmd === 'all' ? true : cmd === 'none' ? false : function(){return !this.checked;};
				$('.action-select:enabled', target).attr('checked', fn).change();
				break;
		}
	}

	// gmail-style selection, shift-click handled
	var lastClicked;
	target.delegate('.action-select:enabled', 'click', function(e){
		if (e.shiftKey) {
			var all = $('.action-select:enabled', target);
			var last = all.index(lastClicked);
			var first = all.index(this);
			var start = Math.min(first, last);
			var end = Math.max(first, last);
			//console.log('SHI', start, end, all.slice(start, end+1));
			var fn = $(this).attr('checked');
			all.slice(start, end+1).attr('checked', fn).change();
		}
		lastClicked = this;
	});
	target.delegate('.action-select:enabled', 'change', function(e){
		e.preventDefault();
		var fn = $(this).attr('checked');
		$(this).parents('tr[rel]').toggleClass('selected', fn);
	});
	//target.delegate('.action-all', 'change', function(e){
	//	docmd('toggle');
	//});

	// selecting command from combo executes it
	target.delegate('.actions', 'change', function(e){
		e.preventDefault();
		var cmd = $(this).val();
		docmd(cmd);
		$(this).val(null);
	});

	// handle searches
	var searches = $(':input.search', target);

	function reload(){
		searches.each(function(i, x){
			var name = $(x).attr('name');
			var val = $(x).val();
			// TODO: treat val as RQL?!
			if (val)
				options.query.filter(RQL.Query().match(name, val, 'i'));
		});
		console.log('SEARCH', options.query, options.query+'');
		location.href = '#'+options.entity+'?'+options.query;
	}

	// search text changed
	require(['js/jquery.textchange.min.js'], function(){
		var timeout;
		searches.bind('textchange', function(){
			clearTimeout(timeout);
			var $this = $(this);
			var name = $this.attr('name');
			timeout = setTimeout(function(){
				reload();
			}, options.searchTimeout);
			return false;
		});
		// use autocomplete if available
		if ($.autocomplete) {
			searches.each(function(i, x){
				$(x).attr('name').replace(/(\w+)/, function(dummy, name){
					autocomplete($(x), options.entity, name);
				});
			});
		}
	});

	// handle multi-sort
	target.delegate('.action-sort[rel]', 'click', function(e){
		e.preventDefault();
		var prop = $(this).attr('rel');
		var sortOrder = options.query.sort;
		var state = options.query.sortObj[prop];
		var multi = sortOrder.length > 1;
		// TODO: switch off a column if multi
		if (!state) {
			if (!e.shiftKey) sortOrder = [];
			sortOrder.push(prop);
		} else {
			var p = state > 0 ? '-'+prop : prop;
			if (!e.shiftKey) {
				sortOrder = [multi ? prop : p];
			} else {
				var i = Object.keys(options.query.sortObj).indexOf(prop);
				sortOrder[i] = p;
			}
		}
		// re-sort
		options.query.sort = sortOrder;
		reload();
		return false;
	});

	// handle pagination
	target.find('.action-limit').change(function(e){
		console.log('LIMIT!');
		e.preventDefault();
		options.query.limit[0] = +($(this).val());
		reload();
		return false;
	});
	target.find('.pagination a').click(function(e){
		e.preventDefault();
		var limit = options.query.limit[0];
		var start = Math.floor(options.query.limit[1] / limit);
		var count = Math.floor(((options.data.total || options.data.length) + limit - 1) / limit);
		var el = $(this);
		var page = start;
		console.log('OP', page, limit, count, options.data.total);
		if (el.is('.page-first')) page = 0;
		else if (el.is('.page-last')) page = count > 0 ? count - 1 : 0;
		else if (el.is('.page-prev')) page = Math.max(page - 1, 0);
		else if (el.is('.page-next')) page = count > 0 ? Math.min(page + 1, count - 1) : 0;
		//else if (el.is('.page-last')) page = count - 1;
		// goto new page
		//console.log('NP', page, limit);
		options.query.limit[1] = page * limit;
		reload();
		return false;
	});

	// handle actions
	target.delegate('button[name=action]', 'click', function(e){
		//console.log('BUT', $(this).val());
		$(this).parents('form:eq(0)').attr('method', $(this).val());
	});

	return this;

})}})(jQuery);
