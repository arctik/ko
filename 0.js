(function() {
  'use strict';  var a, course, fn1, fn2, fn3, now, sys, _;
  require.paths.unshift(__dirname + '/lib/node');
  sys = require('util');
  'C = require \'compose\'\n\np = C.create {foo: \'bar\'},\n	m1: () -> \'IAMM1P\'\n\nu = C.create p,\n	m1: () -> \'IAMM1U\'\n	m2: () -> \'IAMM2U\'\n\nFacet = (model) ->\n	f = {}\n	[\'m1\', \'m2\'].forEach (m) ->\n		#f[m] = C.from.call(model, m, m).bind(model)\n		f[m] = C.from.call(model, m) #.bind(model)\n		#f[m] = model[m].bind model if model[m]\n	f\n\n#Facet(u).m1()\n\nf = {}\nf.a1 =\n	U: {f:\'f\'}\nf.a2 =\n	X: {g:\'g\'}\n\na = C.create.apply null, [{}].concat([\'a1\', \'a2\'].map (x) -> f[x])\n\nstdin = process.openStdin()\nstdin.on \'close\', process.exit\nrepl = require(\'repl\').start \'node>\', stdin\nrepl.context.C = C\nrepl.context.Facet = Facet\nrepl.context.p = p\nrepl.context.u = u\nrepl.context.a = a';
  _ = require('underscore');
  course = [
    {
      id: 1,
      cur: 'USD',
      value: 5,
      date: 1
    }, {
      id: 2,
      cur: 'RUR',
      value: 4,
      date: 2
    }, {
      id: 3,
      cur: 'USD',
      value: 3,
      date: 3
    }, {
      id: 4,
      cur: 'RUR',
      value: 2,
      date: 4
    }, {
      id: 5,
      cur: 'USD',
      value: 1,
      date: 5
    }
  ];
  'map1 = {\n	\'USD\': [{id: 1, d: 5}, {id: 3, d: 3}, {id: 5, d: 1}]\n	\'RUR\': [{id: 2, d: 4}, {id: 4, d: 2}]\n}\n\nreduce1 = [\n	{id: 5}\n	{id: 4}\n]\n\nfinal1 = [\n	{id: 4, cur: \'RUR\', value: 2, date: 4}\n	{id: 5, cur: \'USD\', value: 1, date: 5}\n]';
  now = 6;
  fn1 = function(memo, item) {
    memo[item.cur] || (memo[item.cur] = []);
    memo[item.cur].push({
      id: item.id,
      d: now - item.date
    });
    return memo;
  };
  fn2 = function(item, key) {
    var y;
    y = _.min(item, function(x) {
      return x.d;
    });
    y = y.id;
    return _.detect(course, function(x) {
      return x.id === y;
    });
  };
  fn3 = function(memo, item) {
    var id, _ref;
    id = item.cur;
    if (item.date > (((_ref = memo[id]) != null ? _ref.date : void 0) || 0)) {
      memo[id] = item;
    }
    return memo;
  };
  a = _(course).chain().reduce(fn1, {}).map(fn2).value();
  console.log(a);
  a = _(course).chain().reduce(function(memo, item) {
    var id, _ref;
    id = item.cur;
    if (item.date > (((_ref = memo[id]) != null ? _ref.date : void 0) || 0)) {
      memo[id] = item;
    }
    return memo;
  }, {}).toArray().value();
  console.log(a);
}).call(this);
