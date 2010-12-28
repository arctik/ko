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
		{name: 'cur', title: 'Валюта', pk: true},
		{name: 'value', title: 'Курс'},
		{name: 'date', title: 'На дату', format: 'date'}
	]
};

var VIEW;

var MODELS = window.MODELS = {
	Course: Backbone.Model.extend({
	}, {
		schema: __props__['Course']
	})
};

var Entity = Backbone.Collection.extend({
	updateMany: function(ids, props){
		var url = this.name + '?in(id,$1)';
		var data = {queryParameters: [ids], data: props};
		var meta = {
			url: url,
			toJSON: function(){return data;}
		};
		var self = this;
		Backbone.sync('create', meta, {
			data: JSON.stringify(data),
			success: function(){
				console.log('UPDATED');
				Backbone.history.loadUrl();
			}
		});
	},
	destroyMany: function(ids){
		//this.updateMany(ids, {_deleted: true});
		//return;
		var url = this.name + '?in(id,$1)';
		var data = {queryParameters: [ids]};
		var meta = {
			url: url
		};
		var self = this;
		Backbone.sync('delete', meta, {
			data: JSON.stringify(data),
			success: function(){
				console.log('REMOVED');
				Backbone.history.loadUrl();
			}
		});
	},
	destroyMany000: function(ids){
		//var selected = _.map(ids, function(id){return this.get(id);}, this);
		//console.log('REMOVE', ids, selected);
		//this.remove(selected);
		_.each(ids, function(id){
			this.get(id).destroy();
		}, this);
	},
	initialize: function(){
		this.instance = new Backbone.Model()
	}
});

var COLLECTIONS = window.COLLECTIONS = {
	Course: Entity.extend({
		model: Backbone.Model.extend({
			hz: 'her'
		}),
		url: 'Course'
	})
};

var model = window.model = new Backbone.Model({
	entity: new Entity(),
	instance: new Backbone.Model()
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
				Backbone.history.saveLocation(null);
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
				Backbone.history.saveLocation(null);
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
			data: JSON.stringify({
				id: data.user,
				password: data.pass
			}),
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

var EntityView = Backbone.View.extend({
	_lastClickedRow: 0,
	render: function(){
		console.log('VIEWRENDER', this);
		var name = this.model.name;
		var schema = MODELS[name] && MODELS[name].schema || [{name: 'id', title: 'id'}];
		var items = this.model.toJSON();
		var query = this.query = this.model.query.normalize({clear: _.pluck(schema, 'name')});
		var props = schema;
		if (query.selectArr.length) {
			var selectedProps = _.map(query.selectObj, function(show, name){if (show) return _.detect(props, function(x){return x.name === name});});
			//if (!query.selectObj.id) selectedProps.unshift(_.detect(props, function(x){return x.name === 'id'}));
			props = selectedProps;
		}
		//console.log('RENDER ENTITY', items);
		$(this.el).html(_.partial([name+'-list', 'list'], {
			name: name,
			items: items,
			query: query,
			props: props
		}));//.appendTo($('#entity'));

		// render entity explorer to content element
		var instance = model.get('instance');
		if (instance) {
			$('#inspector').replaceWith(this.inspector.render().el);
		}

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
		'change .action-select-all': 'selectAll',
		'change .actions': 'command',
		//'textchange .filter': 'filter',
		'click .action-sort': 'sort',
		'change .action-limit': 'setPageSize',
		'click .pager a': 'gotoPage',
		'click .action-remove': 'removeSelected',
		'click .action-add': 'addNew',
		'click .action-open': 'open'
		//'submit form': 'act'
	},
	removeSelected: function(e){
		// get ids from selected containers
		var ids = []; $(this.el).find('.action-select-row.selected').each(function(i, row){ids.push($(row).attr('rel'))});
		//console.log('REMOVE', ids, this.model);
		this.model.destroyMany(ids);
		return false;
	},
	addNew: function(e){
		this.model.create();
		console.log('ADD!');
		return false;
	},
	open: function(e){
		var id = $(e.target).attr('rel');
		var item = this.model.get(id);
		console.log('OPEN?', item);
		//model.set({instance: item}, {silent: true});
		//model.get('instance').change();
		//model.set({id: id}, {silent: true});
		return false;
		//var url = $(e.target).attr('href');
		item.fetch({
			success: function(){
				model.get('instance').set(item);
			}
		});
		//console.log('OPEN', item);
		return false;
	},
	reload: function(){
		var query = this.query;
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
		// TODO: reflect all-selected status in master checkbox
		var id = $(e.target).parents('.action-select-row:first').toggleClass('selected', fn).attr('rel');
		//
		console.log('SELECTED', id);
	},
	// gmail-style selection, shift-click selects the sequence
	selectSequence: function(e){
		var t = e.target;
		var parent = $(t).parents('.action-select-list:first');
		var all = parent.find('.action-select:enabled');
		var first = all.index(t);
		if (e.shiftKey) {
			var last = this._lastClickedRow;
			var start = Math.min(first, last);
			var end = Math.max(first, last);
			var fn = $(t).attr('checked');
			all.slice(start, end+1).attr('checked', fn).change();
		}
		this._lastClickedRow = first;
	},
	// master checkbox checks/unchecks all siblings
	selectAll: function(e){
		$(this.el).find('.action-select:enabled').attr('checked', $(e.target).attr('checked')).change();
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
	// handle multi-column sort
	sort: function(e){
		var prop = $(e.target).attr('rel');
		var query = this.query;
		var sortOrder = query.sort;
		var state = query.sortObj[prop];
		var multi = sortOrder.length > 1;
		if (!state) {
			if (!e.shiftKey) sortOrder = [];
			sortOrder.push(prop);
		} else {
			var p = state > 0 ? '-'+prop : prop;
			if (!e.shiftKey) {
				sortOrder = [multi ? prop : p];
			} else {
				var i = Object.keys(query.sortObj).indexOf(prop);
				if (state < 0)
					sortOrder.splice(i, 1);
				else
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
		this.query.limit[0] = +($(e.target).val());
		this.reload();
		return false;
	},
	gotoPage11111111111111: function(e){
		var items = this.model.toJSON();
		var query = this.query;
		//console.log('PAGE', query);
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
	gotoPage: function(e){
		var items = this.model.toJSON();
		var query = this.query;
		var lastSkip = query.limit[1];
		var delta = query.limit[0]; if (delta === Infinity) delta = 100;
		var el = $(e.target);
		if (el.is('.page-prev')) delta = -delta;
		else if (el.is('.page-next')) {
			//if (items.length < delta) delta = 0;
			if (!items.length) delta = 0;
		}
		// goto new page
		query.limit[1] += delta; if (query.limit[1] < 0) query.limit[1] = 0;
		if (query.limit[1] !== lastSkip)
			this.reload();
		return false;
	},
	initialize: function(){
		_.bindAll(this, 'render');
		// re-render upon model changes
		this.model.bind('change', this.render);
		this.model.bind('add', this.render);
		this.model.bind('remove', this.render);
		this.model.bind('refresh', this.render);
		// create instance viewer/editor
		//var instance = this.model.get('instance');
		var instance = model.get('instance');
		this.inspector = new EditorView({model: instance});
	}
});

var EditorView = Backbone.View.extend({
	render: function(){
		var name = 'Course';
		console.log('INSPECT', this.model.toJSON());
		$(this.el).html(_.partial([name+'-form', 'form'], {
			data: this.model.toJSON()
		})).appendTo($('#inspector'));
		return this;
	},
	events: {
		'submit form': 'act'
	},
	initialize: function(){
		_.bindAll(this, 'render');
		this.model.bind('change', this.render);
		this.model.bind('refresh', this.render);
	},
	act: function(e){
		var data = $(e.target).serializeObject();
		try {
			this.model.save(data);
		} catch (x) {
			console.log('EXC', x, this.model);
		}
		//console.log('SUBMIT', data, this.model);
		return false;
	}
});

var App = Backbone.View.extend({
	model: model,
	el: $('#content'),
	template: _.partial('content'),
	render: function(){
		console.log('APPRENDER', this.model);
		// render content element
		this.el.html(this.template(this.model.toJSON()));
		// render entity explorer to content element
		var entity = this.model.get('entity');
		if (entity && entity.url) {
			$('#entity').replaceWith(this.view.render().el);
		}
		return this;
	},
	initialize: function(){
		_.bindAll(this, 'render');
		// re-render upon model change
		this.model.bind('change', this.render);
		// create entity viewer
		var entity = this.model.get('entity');
		this.view = new EntityView({model: entity});
	}
});

var Controller = Backbone.Controller.extend({
	routes: {
		'contact': 'contactUs'
	},
	initialize: function(){
		// entity viewer
		this.route(/^([^/?]+)(?:\?(.*))?$/, 'entity', function(entity, query){
			var m = model.get('entity');
			//console.log('ROUTE', arguments);
			m.name = entity;
			m.url = entity;
			m.query = RQL.Query(query);
			console.log('QUERY', entity, query, m);
			m.fetch({
				url: m.url + (query ? '?' + query : ''),
				error: function(_m, xhr){
					alert('FAILED: ' + xhr.responseText);
				},
				success: function(data){
					console.log('SUCC', m);
				}
			});
		});
		/*
		// instance viewer
		this.route(/^([^/?]+)\/([^/?]+)$/, 'instance', function(entity, id){
			var m = model.get('instance');
			console.log('INST', m);
			m.name = entity;
			m.url = entity + '/' + id;
			m.props = __props__[m.name];
			m.fetch({url: entity + '/' + id});
		});
		*/
	},
	contactUs: function(){
		console.log('CONTACTUS');
	}
});

$(function(){

	Backbone.emulateHTTP = true;
	Backbone.emulateJSON = true;

	//
	new HeaderApp;
	new NavApp;
	new FooterApp;
	new App;
	window.model.set(session);

	// let the history begin
	var controller = new Controller();
	Backbone.history.start();

	// a.toggle toggles the next element visibility
	$(document)
	.delegate('a.toggle', 'click', function(){
		$(this).next().toggle(0, function(){
			// autofocus the first input
			if ($(this).is(':visible')) $(this).find('input:enabled:first').focus();
		});
		return false;
	})
	// a.button-close hides parent form
	.delegate('a.button-close, button[type=reset]', 'click', function(){
		$(this).parents('form').hide();
		return false;
	});

});

});
