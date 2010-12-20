var model;
require([
	'js/bundle.js',
	'rql',
	'/home?callback=define'
], function(x1, RQL, session){
	window.RQL = RQL;
	console.log('SESSION', session);

_.mixin({
	partial: function(ids, data){
		if (!_.isArray(ids)) {
			ids = [ids, 'notfound'];
		}
		var text = null;
		_.each(ids, function(id){
			//console.log('PART', id);
			var t = $('#tmpl-'+id);
			if (t && !text) {
				text = t.text();
			}
		});
		return text ? _.template(text, data) : '';
	}
});

var __props__ = {
	Bar: [
		{name: 'user', title: 'Логин'},
		{name: 'pass', title: 'Пароль'},
		{name: 'email', title: 'Мыло'}
	],
	Course: [
		{name: 'id', title: 'Валюта'},
		{name: 'value', title: 'Курс'},
	]
};

var Model = Backbone.Model.extend({
	//entity:
});

var Entity = Backbone.Collection.extend({
	updateMany: function(ids, props){
		var url = getUrl(this) || urlError();
		url += '?in(id,$1)';
		var data = {queryParameters: [ids]};
		var method = 'POST';
	},
	destroyMany: function(ids){
		var url = getUrl(this) || urlError();
		url += '?in(id,$1)';
		var data = {queryParameters: [ids]};
		var method = 'DELETE';
	}
});

var model = window.model = new Model({
	entity: new Entity()
});
model.bind('change', function(){
	console.log('MODELCHANGE', this, arguments);
});

var HeaderApp = Backbone.View.extend({
	model: model,
	el: $('#header'),
	template: _.partial('header'),
	render: function(){
		this.el.html(this.template(this.model.toJSON()));
		return this;
	},
	events: {
		'submit #login': 'login',
		'submit #logout': 'logout',
		'submit #signup': 'signup'
	},
	initialize: function(){
		_.bindAll(this, 'render');
		this.model.bind('change', this.render);
	},
	//
	// user authorization
	//
	login: function(e){
		//var action = $(form).attr('action') || location.href;
		var view = this;
		var data = $(e.target).serializeObject();
		$.ajax({
			type: 'POST',
			url: '/login',
			data: JSON.stringify(data),
			contentType: 'application/json',
			success: function(newSession){
				view.model.set(newSession);
			},
			error: function(){
				alert('Hope you just forgot your credentials... Try once more');
			}
		});
		return false;
	},
	logout: function(e){
		var view = this;
		$.ajax({
			type: 'POST',
			url: '/login',
			data: JSON.stringify({}),
			contentType: 'application/json',
			success: function(newSession){
				view.model.set(newSession);
			},
			error: function(){
				alert('Could not log off... Try once more');
			}
		});
		return false;
	},
	signup: function(e){
		var view = this;
		var data = $(e.target).serializeObject();
		$.ajax({
			type: 'POST',
			url: '/signup',
			data: JSON.stringify(data),
			contentType: 'application/json',
			success: function(newSession){
				view.model.set(newSession);
			},
			error: function(){
				alert('Sorry... Try once more');
			}
		});
		return false;
	}
});

var FooterApp = Backbone.View.extend({
	model: model,
	el: $('#footer'),
	template: _.partial('footer'),
	render: function(){
		this.el.html(this.template({
			//
			// 4-digit year as string -- to be used in copyright (c) 2010-XXXX
			//
			year: (new Date()).toISOString().substring(0, 4),
		}));
		return this;
	},
	initialize: function(){
		_.bindAll(this, 'render');
		this.model.bind('change', this.render);
	}
});

var NavApp = Backbone.View.extend({
	model: model,
	el: $('#nav'),
	template: _.partial('navigation'),
	render: function(){
		this.el.html(this.template(this.model.toJSON()));
		return this;
	},
	events: {
		'submit form': 'doSearch'
	},
	initialize: function(){
		_.bindAll(this, 'render');
		this.model.bind('change', this.render);
	},
	doSearch: function(e){
		var text = $(e.target).find('input').val();
		if (!text) return false;
		alert('TODO SEARCH FOR ' + text);
		return false;
	}
});

var App = Backbone.View.extend({
	model: model,
	el: $('#content'),
	template: _.partial('content'),
	render: function(){
		this.el.html(this.template(this.model.toJSON()));
		return this;
	},
	initialize: function(){
		_.bindAll(this, 'render');
		this.model.bind('change', this.render);
	}
});

var EntityView = Backbone.View.extend({
	model: model.get('entity'),
	_lastClickedRow: 0,
	render: function(){
		var name = this.model.name;
		var items = this.model.toJSON();
		var query = this.model.query;
		var props = this.model.props;
		if (query.selectArr.length) {
			var selectedProps = _.map(query.selectObj, function(show, name){if (show) return _.detect(props, function(x){return x.name === name});});
			//if (!query.selectObj.id) selectedProps.unshift(_.detect(props, function(x){return x.name === 'id'}));
			props = selectedProps;
		}
		//console.log('RENDER', query, props);
		$(this.el).html(_.partial([name+'-list', 'list'], {
			name: name,
			items: items,
			query: query,
			props: props
		})).appendTo($('#entity'));

		// N.B. workaround: textchange event can not be delegated...
		// reload the View after a 1 sec timeout elapsed after the last textchange event on filters
		var self = this;
		var timeout;
		$(this.el).find(':input.filter').bind('textchange', function(){
			clearTimeout(timeout);
			var $this = $(this);
			var name = $this.attr('name');
			timeout = setTimeout(function(){
				self.reload();
			}, 1000);
			return false;
		});

		return this;
	},
	events: {
		'change .action-select:enabled': 'selectRow',
		'click .action-select:enabled': 'selectSequence',
		'change .actions': 'command',
		//'textchange .filter': 'filter',
		'click .action-sort': 'sort',
		'change .action-limit': 'setPageSize',
		'click .pager a': 'gotoPage',
		'submit form': 'act'
	},
	act: function(e){
		console.log('FORM SUBMIT!');
		return false;
	},
	reload: function(){
		var query = this.model.query;
		var filters = $(this.el).find(':input.filter');
		filters.each(function(i, x){
			var name = $(x).attr('name');
			var val = $(x).val();
			// TODO: treat val as RQL?!
			if (val)
				query.filter(RQL.Query().match(name, val, 'i'));
		});
		console.log('FILTER', query, query+'');
		// FIXME: location is bad, consider manually calling controller + saveLocation
		location.href = location.href.split('?')[0] + '?' + query;
	},
	filter: function(e){
		this.reload();
	},
	// mark checked checkbox container as selected
	selectRow: function(e){
		e.preventDefault();
		var fn = $(e.target).attr('checked');
		// FIXME: template assumption!
		$(e.target).parents('tr:first').toggleClass('selected', fn);
	},
	// gmail-style selection, shift-click selects the sequence
	selectSequence: function(e){
		var t = e.target;
		// FIXME: template assumption!
		var parent = $(t).parents('table:first');
		var all = parent.find('.action-select:enabled');
		var first = all.index(t);
		if (e.shiftKey) {
			var last = this._lastClickedRow;
			var start = Math.min(first, last);
			var end = Math.max(first, last);
			//console.log('SHI', start, end, all.slice(start, end+1));
			var fn = $(t).attr('checked');
			all.slice(start, end+1).attr('checked', fn).change();
		}
		this._lastClickedRow = first;
	},
	// execute a command from commands combo
	command: function(e){
		e.preventDefault();
		var cmd = $(e.target).val();
		//console.log('COMMAND', cmd, this);
		switch (cmd) {
			case 'all':
			case 'none':
			case 'toggle':
				var fn = cmd === 'all' ? true : cmd === 'none' ? false : function(){return !this.checked;};
				$(this.el).find('.action-select:enabled').attr('checked', fn).change();
				break;
		}
		$(e.target).val(null);
	},
	/*sort: function(e){
		var t = e.target;
		// FIXME: template assumption!
		var parent = $(t).parents('table:first');
		var cols = parent.find('.action-sort');
		var maxSort = 0;
		var sorts = [];
		cols.each(function(i, c){
			var $c = $(c);
			sorts[i] = {
				id: $c.attr('rel'),
				value: $c.attr('data-sort')
			};
		});
		//console.log('SORTS', sorts);
		var me = cols.index(t);
		var state = sorts[me].value;
		if (!e.shiftKey) {
			for (var i = 0; i < sorts.length; i += 1) sorts[i].value = undefined;
			// unshifted click always sorts ascending clicked column
			state = 0;
		}
		if (!state) state = cols.length; else if (state > 0) state = -state; else state = undefined;
		sorts[me].value = state;
		var sss = [];
		_.each(sorts, function(x){
			if (!x.value) return;
			if (x.value < 0) {
				x.id = '-'+x.id;
				x.value = -x.value;
			}
			sss.push(x);
		});
		sss = _.pluck(_.sortBy(sss, function(x){return x.value;}), 'id');
		// re-sort
		this.model.query.sort = sss;
		this.reload();
		return false;
	},*/
	// handle multi-column sort
	sort: function(e){
		var prop = $(e.target).attr('rel');
		var query = this.model.query;
		var sortOrder = query.sort;
		var state = query.sortObj[prop];
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
				var i = Object.keys(query.sortObj).indexOf(prop);
				sortOrder[i] = p;
			}
		}
		// re-sort
		query.sort = sortOrder;
		this.reload();
		return false;
	},
	// handle pagination
	setPageSize: function(e){
		this.model.query.limit[0] = +($(e.target).val());
		this.reload();
		return false;
	},
	gotoPage: function(e){
		var items = this.model.toJSON();
		var query = this.model.query;
		var limit = query.limit[0];
		var start = Math.floor(query.limit[1] / limit);
		// FIXME: we have no .total!
		var count = Math.floor(((items.total || items.length) + limit - 1) / limit);
		var el = $(e.target);
		var page = start;
		console.log('OP', page, limit, count, items.total);
		if (el.is('.page-first')) page = 0;
		else if (el.is('.page-last')) page = count > 0 ? count - 1 : 0;
		else if (el.is('.page-prev')) page = Math.max(page - 1, 0);
		else if (el.is('.page-next')) page = count > 0 ? Math.min(page + 1, count - 1) : 0;
		//else if (el.is('.page-last')) page = count - 1;
		// goto new page
		//console.log('NP', page, limit);
		query.limit[1] = page * limit;
		this.reload();
		return false;
	},
	initialize: function(){
		_.bindAll(this, 'render');
		this.model.bind('change', this.render);
		this.model.bind('refresh', this.render);
	}
});

	var Controller = Backbone.Controller.extend({
		routes: {
			'contact': 'contactUs'
		},
		initialize: function(){
			this.route(/^([^/?]+)(?:\?(.*))?$/, 'entity', function(entity, query){
				query = query || '';
				console.log('QUERY', this, arguments);
				var m = model.get('entity');
				console.log('MO', m);
				m.name = entity;
				m.url = entity + '?' + query;
				m.props = __props__[m.name];
				m.query = RQL.parse(query).normalize({clear: _.pluck(m.props, 'name')});
				m.fetch();
			});
		},
		contactUs: function(){
			console.log('CONTACTUS');
		}
	});

	$(function(){

		//
		new HeaderApp;
		new NavApp;
		new FooterApp;
		new App;
		new EntityView;
		window.model.set(session);

		// let the history begin
		var controller = window.controller = new Controller();
		Backbone.history.start();

		// a.toggle toggles the next element visibility
		$(document).delegate('a.toggle', 'click', function(){
			$(this).next().toggle(0, function(){
				// autofocus the first input
				if ($(this).is(':visible')) $(this).find('input:enabled:first').focus();
			});
			return false;
		});
		// a.button-close hides parent form
		$(document).delegate('a.button-close, button[type=reset]', 'click', function(){
			$(this).parents('form').hide();
			return false;
		});

	});
});
