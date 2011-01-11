var model;

var currentLocale = 'ru'; // FIXME: force locale here. cookie?
require({
	locale: currentLocale
}, [
	'js/bundle.js',
	'rql',
	'i18n!nls/forms', // i18n 
], function(x1, RQL, i18nForms){
	window.RQL = RQL;
$.getJSON('/home', function(session){
	console.log('SESSION', session);

// improve _
_.mixin({
	partial: function(ids, data){
		if (!_.isArray(ids)) {
			ids = [ids, 'notfound'];
		}
		var text = null;
		_.each(ids, function(id){
			//console.log('PART?', id);
			var t = $('#tmpl-'+id);
			if (t && !text) {
				text = t.text();
				//console.log('PART!', text);
			}
		});
		//if (data) {
		//	data = _.extend(data, {i18n: i18nForms});
		//}
		//console.log('DATA', data);
		return text ? _.template(text, data) : '';
	},
	// i18n-aware strings
	T: function(id){
		var text = i18nForms[id] || id;
		if (arguments.length > 1) {
			var args = Array.prototype.slice.call(arguments);
			args[0] = text;
			text = _.sprintf.apply(null, args);
		}
		return text;
	}
});

// DOM is loaded
require.ready(function(){

var MODELS = window.MODELS = {
	Course: Backbone.Model.extend({
	}, {
		schema: [
			{name: 'cur', title: 'Валюта'},
			{name: 'value', title: 'Курс'},
			{name: 'date', title: 'На дату', format: 'date'}
		]
	}),
	Language: Backbone.Model.extend({
	}, {
		schema: [
			{name: 'id', title: 'ID'},
			{name: 'name', title: 'Имя'},
			{name: 'localName', title: 'Нацназвание'}
		]
	}),
	Affiliate: Backbone.Model.extend({
	}, {
		schema: [
			{name: 'id', title: 'ID'},
			{name: 'name', title: 'Имя'},
			{name: 'email', title: 'Мыло'},
			{name: 'regDate', title: 'С какого', format: 'date'},
			{name: 'active', title: 'В строю?'}
		]
	}),
	Merchant: Backbone.Model.extend({
	}, {
		schema: [
			{name: 'id', title: 'ID'},
			{name: 'name', title: 'Имя'},
			{name: 'email', title: 'Мыло'},
			{name: 'regDate', title: 'С какого', format: 'date'},
			{name: 'active', title: 'В строю?'}
		]
	}),
	Admin: Backbone.Model.extend({
	}, {
		schema: [
			{name: 'id', title: 'ID'},
			{name: 'name', title: 'Имя'},
			{name: 'email', title: 'Мыло'},
			{name: 'regDate', title: 'С какого', format: 'date'},
			{name: 'active', title: 'В строю?'}
		]
	})
};

var Entity = Backbone.Collection.extend({
	error: function(xhr){
		console.log('ERR', arguments, model);
		var err = xhr.responseText;
		try {
			err = JSON.parse(err);
			model.set({errors: err});
			/*_.each(err, function(e){
				alert(e.property + ': ' + e.message);
			});*/
		} catch (x) {
			alert(err && err.message || err);
		}
	},
	dispose: function(){
		delete this.name;
		delete this.url;
		delete this.query;
		this.refresh();
	},
	create: function(data, options){
		var meta = {
			url: this.name,
			toJSON: function(){return data;}
		};
		Backbone.sync('create', meta, {
			data: JSON.stringify(data),
			success: function(){
				console.log('CREATED');
				Backbone.history.loadUrl();
			},
			error: this.error
		});
	},
	updateMany: function(ids, props){
		var url = this.name + '?in(id,$1)';
		var data = {queryParameters: [ids], data: props};
		var meta = {
			url: url,
			toJSON: function(){return data;}
		};
		Backbone.sync('create', meta, {
			data: JSON.stringify(data),
			success: function(){
				console.log('UPDATED');
				Backbone.history.loadUrl();
			},
			error: this.error
		});
	},
	destroyMany: function(ids){
		var url = this.name + '?in(id,$1)';
		var data = {queryParameters: [ids]};
		var meta = {
			url: url
		};
		Backbone.sync('delete', meta, {
			data: JSON.stringify(data),
			success: function(){
				console.log('REMOVED');
				Backbone.history.loadUrl();
			},
			error: this.error
		});
	},
	initialize: function(){
	}
});

// central model
var model = window.model = new Backbone.Model({
	errors: [],
	entity: new Entity(),
	ids: []
});

var ErrorApp = Backbone.View.extend({
	model: model,
	el: $('#errors'),
	template: _.partial('errors'),
	render: function(){
		console.log('SHOWERRS', this.model.toJSON());
		this.el.html(this.template(this.model.toJSON()));
		return this;
	},
	events: {
	},
	initialize: function(){
		_.bindAll(this, 'render');
		this.model.bind('change:errors', this.render);
	}
});

var HeaderApp = Backbone.View.extend({
	model: model,
	el: $('#header'),
	render: function(){
		this.el.html(_.partial('header', this.model.toJSON()));
		return this;
	},
	events: {
		'submit #login': 'login',
		'click a[href=#logout]': 'logout',
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
	render: function(){
		this.el.html(_.partial('footer', {
			//
			// 4-digit year as string -- to be used in copyright (c) 2010-XXXX
			//
			year: (new Date()).toISOString().substring(0, 4)
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
	render: function(){
		this.el.html(_.partial('navigation', this.model.toJSON()));
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
	_selected: [], // TODO: should belong to Collection?
	render: function(){
		var entity = model.get('entity');
		var name = entity.name;
		console.log('VIEWRENDER', this, name, entity.query+'');
		//var schema = MODELS[name] && MODELS[name].schema || [{name: 'id', title: 'ID', pk: true}];
		var schema = model.get('schema');
		schema = schema && schema[name] && schema[name].properties || {};
		var query = this.query = RQL.Query(entity.query+'').normalize({clear: _.pluck(schema, 'name')});
		var props = schema;
		if (query.selectArr.length) {
			var selectedProps = _.map(query.selectObj, function(show, name){if (show) return _.detect(props, function(x){return x.name === name});});
			//if (!query.selectObj.id) selectedProps.unshift(_.detect(props, function(x){return x.name === 'id'}));
			props = selectedProps;
		}
		//console.log('RENDER ENTITY', items);
		$(this.el).html(name ? _.partial([name+'-list', 'list'], {
			name: name,
			items: entity.toJSON(),
			//selected: _selected,
			query: query,
			props: props
		}) : 'XXX');
		this.delegateEvents();

		// render inspector
		model.set({ids: []}, {silent: true});
		this.$('#inspector').html(this.inspector.render().el);

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
		'click .action-open': 'open'
	},
	getSelected: function(){
		// get ids from selected containers
		var ids = []; $(this.el).find('.action-select-row.selected').each(function(i, row){ids.push($(row).attr('rel'))});
		return ids;
	},
	removeSelected: function(e){
		var m = model.get('entity');
		var ids = this.getSelected();
		m.destroyMany(ids);
		return false;
	},
	open: function(e){
		var id = [$(e.target).attr('rel')];
		//this.inspect(id);
		return false;
	},
	inspect: function(ids){
		model.set({ids: ids});
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
		// TODO: reflect "all selected" status in master checkbox
		var id = $(e.target).parents('.action-select-row:first').toggleClass('selected', fn).attr('rel');
		//
		if (!this._inBulkSelect) {
			this.selectBulk();
		}
	},
	selectBulk: function(){
		var ids = this.getSelected();
		//console.log('SELECTED', ids);
		this.inspect(ids);
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
			try {
				this._inBulkSelect = true;
				all.slice(start, end+1).attr('checked', fn).change();
			} finally {
				this._inBulkSelect = false;
				this.selectBulk();
			}
		}
		this._lastClickedRow = first;
	},
	// master checkbox checks/unchecks all siblings
	selectAll: function(e){
		try {
			this._inBulkSelect = true;
			$(this.el).find('.action-select:enabled').attr('checked', $(e.target).attr('checked')).change();
		} finally {
			this._inBulkSelect = false;
			this.selectBulk();
		}
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
				try {
					this._inBulkSelect = true;
					$(this.el).find('.action-select:enabled').attr('checked', fn).change();
				} finally {
					this._inBulkSelect = false;
					this.selectBulk();
				}
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
				var i = _.keys(query.sortObj).indexOf(prop);
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
	gotoPage: function(e){
		var m = model.get('entity');
		var items = m.toJSON();
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
		if (query.limit[1] !== lastSkip) {
			this.reload();
		}
		return false;
	},
	initialize: function(){
		_.bindAll(this, 'render');
		// re-render upon model changes
		var entity = model.get('entity');
		entity.bind('change', this.render);
		entity.bind('add', this.render);
		entity.bind('remove', this.render);
		entity.bind('refresh', this.render);
		entity.bind('all', function(){
			console.log('ENTITYEVENT', arguments);
		});
		// create instance viewer/editor
		this.inspector = new EditorView;
	}
});

var EditorView = Backbone.View.extend({
	render: function(){
		var entity = model.get('entity');
		var name = entity.name;
		var ids = model.get('ids');
		var m;
		console.log('INSPECT', ids);
		if (ids.length === 1) {
			m = entity.get(ids[0]);
		}
		if (!m) {
			m = new Backbone.Model;
			m.collection = entity;
		}
		$(this.el).html(_.partial([name+'-form', 'form'], {
			ids: ids,
			data: m.toJSON()
		}));
		this.delegateEvents();
		return this;
	},
	events: {
		'submit form': 'act'
	},
	initialize: function(){
		_.bindAll(this, 'render');
		model.bind('change:ids', this.render);
	},
	act: function(e){
		var entity = model.get('entity');
		var ids = model.get('ids');
		var props = $(e.target).serializeObject({filterEmpty: true});
		console.log('TOSAVE?', ids, props);
		try {
			// multi update
			if (ids.length > 0) {
				entity.updateMany(ids, props);
			// create new
			} else {
				entity.create(props);
			}
		} catch (x) {
			console.log('EXC', x, props);
		}
		return false;
	}
});

var AccountView = Backbone.View.extend({
	render: function(){
		var user = model.get('user');
		$(this.el).html(_.partial(['account'], {
			user: user.toJSON()
		}));
		this.delegateEvents();
		return this;
	},
	events: {
	},
	initialize: function(){
		_.bindAll(this, 'render');
		model.bind('change:user', this.render);
	}
});

var App = Backbone.View.extend({
	model: model,
	el: $('#content'),
	render: function(){
		console.log('APPRENDER1', this.model);
		// render content element
		this.el.html(_.partial('content', this.model.toJSON()));
		// render entity explorer to content element
		this.$('#entity').html(this.view.render().el);
		return this;
	},
	initialize: function(){
		_.bindAll(this, 'render');
		// re-render upon model change
		this.model.bind('change:user', this.render);
		this.model.bind('change:entity', this.render);
		// create entity viewer
		this.view = new EntityView;
		// create account EditorView
		this.account = new AccountView;
	}
});

var Controller = Backbone.Controller.extend({
	routes: {
		// url --> handler
		'contact': 'contactUs'
	},
	initialize: function(){
		// entity viewer
		this.route(/^admin\/([^/?]+)(?:\?(.*))?$/, 'entity', function(name, query){
			var entity = model.get('entity');
			entity.name = name;
			entity.url = name;
			entity.query = RQL.Query(query);
			console.log('ROUTE', arguments, entity);
			//console.log('QUERY', name, query, entity);
			entity.fetch({
				url: entity.url + (query ? '?' + query : ''),
				error1: function(x, xhr, y){
					alert('FAILED: ' + xhr.responseText);
				},
				error: entity.error,
				success: function(data){
					model.set({errors: []});
					console.log('FETCHED', data);
				}
			});
		});
		// root
		this.route(/^$/, 'root', function(){
			console.log('ROOT');
			var entity = model.get('entity');
			entity.dispose();
		});
		// account
		this.route(/^account$/, 'account', function(){
			console.log('ACCOUNT');
			var entity = model.get('entity');
			entity.dispose();
		});
	},
	contactUs: function(){
		console.log('CONTACTUS');
	}
});

/////////////////////

Backbone.emulateHTTP = true;
Backbone.emulateJSON = true;

//
new ErrorApp;
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
})
// actions just make requests
.delegate('.list-actions a', 'click', function(){
	console.log('ACTION', $(this).attr('href').replace('#', '/'));
	return false;
});

/////////////////////

});

});

});
