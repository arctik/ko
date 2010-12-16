var model;
require([
	'js/bundle.js',
	'js/tablify.js',
	'rql',
	'/home?callback=define'
], function(x1, x2, RQL, session){
	window.RQL = RQL;
	console.log('SESSION', session);

window.Bar = [{"user":"root","pass":"124","id":"4d04fcff6988cd3a27000000"},{"user":"root","pass":"124","id":"4d04fd006988cd3a27000001"},{"user":"root","pass":"124","id":"4d04fd016988cd3a27000002"},{"user":"root","pass":"124","id":"4d04fffe6988cd3a27000003"},{"user":"root","pass":"124","id":"4d04ffff6988cd3a27000004"},{"user":"root","pass":"124","id":"4d0500006988cd3a27000005"},{"user":"root","pass":"124","id":"4d0500006988cd3a27000006"},{"user":"root","pass":"124","id":"4d0500096988cd3a27000007"},{"user":"root","pass":"124","id":"4d05000a6988cd3a27000008"},{"user":"root","pass":"124","id":"4d05000b6988cd3a27000009"},{"user":"root","pass":"125","id":"4d05000c6988cd3a2700000a"},{"id":"4d0505b12583f5c027000000"},{"id":"4d0505eee03e9dd027000000"},{"id":"4d0505f1e03e9dd027000001"},{"id":"4d0505fbe03e9dd027000002"},{"id":"4d05060c4a8ee7d827000000"},{"id":"4d05060e4a8ee7d827000001"},{"id":"4d0506174a8ee7d827000002"},{"id":"4d05064175feb2e127000000"},{"id":"4d0506767b51a5e927000000"},{"id":"4d05069d64f77ff227000000"},{"id":"4d0506b964f77ff227000001"},{"id":"4d0507070aa759fd27000000"},{"id":"4d0507110aa759fd27000001"},{"id":"4d0507200aa759fd27000002"},{"user":"root","pass":"123","id":"4d0535e0791554b22b000000"}];

model = {
	//
	// user authorization
	//
	login: function(form){
		//var action = $(form).attr('action') || location.href;
		var data = $(form).serializeObject();
		$.ajax({
			type: 'POST',
			url: '/login',
			data: data,
			success: function(newSession){
				//location = '';
				session = newSession;
				model.userEmail(session.user.email);
			},
			error: function(){
				alert('Hope you just forgot your credentials... Try once more');
			}
		});
		return false;
	},
	logout: function(){
		$.post('/login', {}, function(){
			//location = '';
			model.userEmail(null);
		});
		return false;
	},
	signup: function(form){
		var data = $(form).serializeObject();
		$.ajax({
			type: 'POST',
			url: '/signup',
			data: data,
			success: function(newSession){
				//location = '';
				session = newSession;
				model.userEmail(session.user.email);
			},
			error: function(){
				alert('Sorry... Try once more');
			}
		});
		return false;
	},
	// current user email. truthy iff the user is logged in
	userEmail: ko.observable(session.user.email),
	//
	// 4-digit year as string -- to be used in copyright (c) 2010-XXXX
	//
	year: (new Date()).toISOString().substring(0, 4),
	//
	// global search string
	//
	search: ko.observable(null),
	// perform global search
	doSearch: function(form){
		var text = $(form).find('input').val();
		if (!text) return false;
		alert('TODO SEARCH FOR ' + text);
	},
	query: ko.observable(location.href),
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
		}
	}
	/*hash: ko.dependentObservable(function(){
		return location.href;
	})*/
};

	var Controller = Backbone.Controller.extend({
		routes: {
			'*query': 'catchAll'
			//':entity/:id': 'viewInstance',
			//':entity': 'viewEntity'
		},
		form: function(){
			//$('#content').html('<div data-bind="template: \'tmpl-login\'"></div>');
			//ko.applyBindings(model.User, $('#content >div')[0]);
			$('#content').html($('#tmpl-login').tmpl()).delegate('form', 'submit', function(){
				var action = $(this).attr('action') || location.href;
				var data = $(this).serializeObject();
				//var data = ko.mapping.toJS(model.User);
				//console.log('SUBMIT', data);
				$.ajax({
					type: 'POST',
					url: action,
					data: data,
					success: function(session){
						console.log('POSTANSWER', arguments);
					},
					error: function(){
						console.log('BUMP', arguments);
					}
				});
				return false;
			});
		},
		viewEntity: function(entity, query){
			console.log('ENTITY', this, arguments);
			var callback;
			$.ajax({
				url: entity + '?' + query,
				dataType: 'json',
				success: callback = function(data){
					model.entity.name(entity);
					model.entity.props(_.keys(data[0] || {}) || ['id']);
					model.entity.items = ko.mapping.fromJS(data);
					model.entity.query(query);
					/*$('#content').html('<div data-bind="template: \'tmpl-list\', data: \'entity\'"></div>');
					ko.applyBindings(model, $('#content')[0]);
					$('.list').tablify({
						entity: entity,
						query: query,
						data: data // raw data?!
					});*/
				},
				error: function(){
					callback([]);
				}
			});
		},
		/*viewInstance: function(entity, id, query){
			console.log('INSTANCE', this, arguments);
			$('#content').html('<div data-bind="template: \'tmpl-list\'"></div>');
			ko.applyBindings({
				props: ['id', 'user', 'pass'],
				query: ko.observable(query),
				items: ko.observableArray(Bar)
			}, $('#content')[0]);
		},*/
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
					// set entity name
					model.entity.name(parts[0]);
					// update sorter, filters and pager
					var parsed = RQL.parse(qs).normalize({hardLimit: 20});
					console.log('PARSED', parsed);
					model.entity.query = parsed;
					// update columns
					var props = _.keys(parsed.selectObj || {});
					if (!props.length) props = ['id'];
					model.entity.props(props);
					// update rows
					model.entity.items = ko.mapping.updateFromJS(model.entity.items, data);
					/*$('.list').tablify({
						entity: entity,
						query: query,
						data: data // raw data?!
					});*/
				},
				error: function(){
					callback([]);
				}
			});


			return false;
			var props = [];
			var id = query;
			var k = query.indexOf('?');
			if (k >= 0) {
				id = query.substring(0, k);
				query = RQL.parse(query.substring(k+1)).normalize({hardLimit: 100, clear: props});
			} else {
				query = RQL.Query().normalize({hardLimit: 100, clear: props});
			}
			id = id.split('/').filter(function(x){return !!x;});
			var entity = id.shift();
			if (id.length > 0) {
				query.pk = id.shift();
			}
			//console.log('QUERY', id, query);
			if (query.pk) this.viewInstance(entity, id, query); else this.viewEntity(entity, query);
		}
	});

	$(function(){

/*myViewModel.personName.subscribe(function(newValue) {
//		alert("The person's new name is " + newValue);
});

		myViewModel.personGirlsEnough = ko.dependentObservable(function(){
				return this.personGirls().length > 2 ? "enough?" : "need more";
		}, myViewModel);


		//ko.applyBindings(myViewModel, $('#content')[0]);
		ko.applyBindings(window.model);

		setTimeout(function(){
			myViewModel.personName('Vladimir');
		}, 2000);
*/
		// let the history begin
		var controller = new Controller();
			//console.log('INIT', Object.keys(this.routes));
			//controller.route(/^(.*?)\/^([^?]*?)(\?(.*?))?$/, 'viewInstance1', function(){
			//	console.log('INSTANCE', this, arguments);
			//	// ?123=as
			//});
		//console.log('CONTR', controller);
		ko.applyBindings(model);
		Backbone.history.start();


/*
var text = 'id=123&user=456&pass=789&sort(pass,-user)&limit(10,3)';
window.query = norm(RQL.parse(text).normalize());
function norm(q){
	q.sort = q.sortObj; delete q.sortObj; delete q.sortArr;
	delete q.search; delete q.needCount;
	q.select = q.selectObj; delete q.selectObj; delete q.selectArr;
	q.skip = q.limit[1];
	q.limit = q.limit[0];
	for (var i in q.last) {
		if (q.last[i].name === 'eq') {
			q.last[i] = String(q.last[i].args[1]);
		} else {
			delete q.last[i];
		}
	}
	return q;
}
window.qqq = ko.mapping.fromJS(query);
ko.applyBindings({
	text: ko.observable(text),
	query: qqq
}, $('#content')[0]);
*/

		$(document).delegate('a.toggle', 'click', function(){
			$(this).next().toggle(0, function(){
				// autofocus the first input
				if ($(this).is(':visible')) $(this).find('input:enabled:first').focus();
			});
			return false;
		});
		$(document).delegate('a.button-close, button[type=reset]', 'click', function(){
			$(this).parents('form').hide();
			return false;
		});

	});
});

function norm(q){
	q.sort = q.sortObj; delete q.sortObj; delete q.sortArr;
	delete q.search; delete q.needCount;
	q.select = q.selectObj; delete q.selectObj; delete q.selectArr;
	q.skip = q.limit[1];
	q.limit = q.limit[0];
	for (var i in q.last) {
		if (q.last[i].name === 'eq') {
			q.last[i] = String(q.last[i].args[1]);
		} else {
			delete q.last[i];
		}
	}
	return q;
}
