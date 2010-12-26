'use strict'
require.paths.unshift __dirname + '/lib/node'
sys = require 'util'

'''
C = require 'compose'

p = C.create {foo: 'bar'},
	m1: () -> 'IAMM1P'

u = C.create p,
	m1: () -> 'IAMM1U'
	m2: () -> 'IAMM2U'

Facet = (model) ->
	f = {}
	['m1', 'm2'].forEach (m) ->
		#f[m] = C.from.call(model, m, m).bind(model)
		f[m] = C.from.call(model, m) #.bind(model)
		#f[m] = model[m].bind model if model[m]
	f

#Facet(u).m1()

f = {}
f.a1 =
	U: {f:'f'}
f.a2 =
	X: {g:'g'}

a = C.create.apply null, [{}].concat(['a1', 'a2'].map (x) -> f[x])

stdin = process.openStdin()
stdin.on 'close', process.exit
repl = require('repl').start 'node>', stdin
repl.context.C = C
repl.context.Facet = Facet
repl.context.p = p
repl.context.u = u
repl.context.a = a
'''

_ = require 'underscore'

course = [
	{id: 1, cur: 'USD', value: 5, date: 1}
	{id: 2, cur: 'RUR', value: 4, date: 2}
	{id: 3, cur: 'USD', value: 3, date: 3}
	{id: 4, cur: 'RUR', value: 2, date: 4}
	{id: 5, cur: 'USD', value: 1, date: 5}
]

'''
map1 = {
	'USD': [{id: 1, d: 5}, {id: 3, d: 3}, {id: 5, d: 1}]
	'RUR': [{id: 2, d: 4}, {id: 4, d: 2}]
}

reduce1 = [
	{id: 5}
	{id: 4}
]

final1 = [
	{id: 4, cur: 'RUR', value: 2, date: 4}
	{id: 5, cur: 'USD', value: 1, date: 5}
]
'''

now = 6

fn1 = (memo, item) ->
	#console.log 'IT', item
	memo[item.cur] or memo[item.cur] = []
	memo[item.cur].push {id: item.id, d: now - item.date}
	memo

fn2 = (item, key) ->
	y = _.min item, (x) -> x.d
	y = y.id
	_.detect course, (x) -> x.id is y

fn3 = (memo, item) ->
	id = item.cur
	memo[id] = item if item.date > (memo[id]?.date or 0)
	memo

a = _(course).chain().reduce(fn1, {}).map(fn2).value()
console.log a

#a = _(course).chain().reduce(fn3, {}).toArray().value()
a = _(course).chain().reduce((memo, item) ->
	id = item.cur
	memo[id] = item if item.date > (memo[id]?.date or 0)
	memo
, {}).toArray().value()
console.log a

a = new Array course.reduce((memo, item) ->
	id = item.cur
	memo[id] = item if item.date > (memo[id]?.date or 0)
	memo
, {})
console.log a

