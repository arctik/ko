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
			console.log('PART', id);
			var t = $('#tmpl-'+id);
			if (t && !text) {
				text = t.text();
			}
		});
		return text ? _.template(text, data) : '';
	}
});

window.Model = Backbone.Model.extend({
});

window.model = new window.Model;
window.model.bind('change', function(){
	console.log('MODELCHANGE', this, arguments);
});

var HeaderApp = Backbone.View.extend({
	model: window.model,
	el: $('#header'),
	template: _.partial('header'),
	render: function(){
		this.el.html(this.template(this.model.toJSON()));
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
	model: window.model,
	el: $('#footer'),
	//template: _.template($('#footer').text()),
	template: _.partial('footer'),
	render: function(){
		this.el.html(this.template({
			//
			// 4-digit year as string -- to be used in copyright (c) 2010-XXXX
			//
			year: (new Date()).toISOString().substring(0, 4),
		}));
	},
	initialize: function(){
		_.bindAll(this, 'render');
		this.model.bind('change', this.render);
	}
});

var NavApp = Backbone.View.extend({
	model: window.model,
	el: $('#nav'),
	template: _.partial('navigation'),
	render: function(){
		this.el.html(this.template(this.model.toJSON()));
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

var Entity = Backbone.Collection.extend({
});

var App = Backbone.View.extend({
	model: window.model,
	el: $('#content'),
	template: _.partial('content'),
	render: function(){
		this.el.html(this.template(this.model.toJSON()));
	},
	initialize: function(){
		_.bindAll(this, 'render');
		this.model.bind('change', this.render);
	}
});

var EntityView = Backbone.View.extend({
	model: window.model,
	el: $('#list'),
	template: _.partial('list'),
	render: function(){
		this.el.html(this.template(this.model.toJSON()));
	},
	initialize: function(){
		_.bindAll(this, 'render');
		this.model.bind('change', this.render);
	}
});

/*
model = {
	entity: {
		name: ko.observable(),
		props: ko.observable([]),
		items: ko.mapping.fromJS([]),
		query: RQL.Query().normalize(),
		listActions: [
			{cmd: 'all', title: 'All'},
			{cmd: 'none', title: 'None'},
			{cmd: 'toggle', title: 'Toggle'}
		],
		listCommand: ko.observable(),
		post: function(){
			console.log('POSTENTITY', arguments);
		},
		removeSelected: function(){
			// get ids from selected rows
			var ids = []; $('#list-'+this.name()).find('tr.selected').each(function(i, row){ids.push($(row).attr('rel'))});
			console.log('REMOVE', ids, this.name());
			// issue POST to /<Entity> with body set to array of ids
			$.ajax({
				type: 'POST',
				url: '/'+this.name()+'?in(id,$1)',
				data: JSON.stringify({queryParameters: [ids]}),
				contentType: 'application/json',
				beforeSend: function(xhr){
					xhr.setRequestHeader('x-http-method-override', 'DELETE');
				},
				success: function(session){
					console.log('POSTANSWER', arguments);
					controller.catchAll(Backbone.history.fragment);
				},
				error: function(){
					console.log('BUMP', arguments);
				}
			});
		},
		addNew: function(){
			// issue POST to /<Entity> to create blank record
			$.ajax({
				type: 'POST',
				url: '/'+this.name(),
				contentType: 'application/json',
				success: function(session){
					console.log('POSTANSWER', arguments);
					controller.catchAll(Backbone.history.fragment);
				},
				error: function(){
					console.log('BUMP', arguments);
				}
			});
		}
	}
};
*/

	var Controller = Backbone.Controller.extend({
		routes: {
			'contact': 'contactUs',
			'*query': 'catchAll'
		},
		contactUs: function(){
			console.log('CONTACTUS');
		},
		catchAll: function(query){
			var callback;
			var url = query.replace(/^#*/, '');
			var parts = query.split('?');
			var qs = parts[1];
			parts = _.filter(parts[0].split('/'), function(x){return !!x;}); // _.???
			$.ajax({
				url: url,
				dataType: 'json',
				success: callback = function(data){
					// update sorter, filters and pager
					var parsed = RQL.parse(qs).normalize();
					console.log('PARSED', parsed);
					var entity = new Entity({
						url: parts[0]
					});
					/***
					// update columns
					var props = _.keys(parsed.selectObj || {});
					if (!props.length) props = ['id'];
					model.entity.props(props);
					// update rows
					// TODO: MAKE OWN MAPPING BASED ON PROPS OF MODEL
					if (parts[0] === model.entity.name()) {
						console.log('UPDATINGITEMS', data);
						ko.mapping.updateFromJS(model.entity.items, data);
					} else {
						console.log('LOADINGITEMS', data);
						model.entity.items = ko.mapping.fromJS(data);
						// set entity name
						model.entity.name(parts[0]);
					}
					***/
				},
				error: function(){
					callback([]);
				}
			});
		}
	});

	$(function(){

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
		// gmail-style selection, shift-click selects the sequence
		$(document)
		.delegate('.action-select:enabled', 'click', function(e){
			var parent = $(this).parents('table:first');
			var all = parent.find('.action-select:enabled');
			var first = all.index(this);
			if (e.shiftKey) {
				var last = +parent.attr('data-lastclicked'); if (isNaN(last)) last = 0;
				var start = Math.min(first, last);
				var end = Math.max(first, last);
				//console.log('SHI', start, end, all.slice(start, end+1));
				var fn = $(this).attr('checked');
				all.slice(start, end+1).attr('checked', fn).change();
			}
			parent.attr('data-lastclicked', first);
		})
		// mark table rows containing checked checkboxes as selected
		.delegate('.action-select:enabled', 'change', function(e){
			e.preventDefault();
			var fn = $(this).attr('checked');
			$(this).parents('tr:first').toggleClass('selected', fn);
		})
		// handle multi-sort
		.delegate('th[rel]', 'click', function(e){
			e.preventDefault();
			var parent = $(this).parents('table:first');
			var cols = parent.find('th[rel]');
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
			var me = cols.index(this);
			var state = sorts[me].value;
			if (!e.shiftKey) {
				for (var i = 0; i < sorts.length; i += 1) sorts[i].value = undefined;
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
			console.log('SORTS', sss);
			// re-sort
			model.entity.query.sort = sss;
			location.href = location.href.replace(/\?.*$/, '?'+model.entity.query);
			//reload();
			return false;
		});



	});
});
