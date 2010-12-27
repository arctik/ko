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

course = [{"cur":"USD","value":0.345,"date":"2010-12-27T08:43:17.941Z","id":"4d1851a571ee9ef341000000"},{"cur":"AED","value":0.345,"date":"2010-12-27T08:43:17.941Z","id":"4d1851a571ee9ef34100003a"},{"cur":"PYG","value":0.345,"date":"2010-12-27T08:43:17.941Z","id":"4d1851a571ee9ef34100002a"},{"cur":"TND","value":0.345,"date":"2010-12-27T08:43:17.941Z","id":"4d1851a571ee9ef341000029"},{"cur":"MAD","value":0.345,"date":"2010-12-27T08:43:17.941Z","id":"4d1851a571ee9ef34100002b"},{"cur":"HNL","value":0.345,"date":"2010-12-27T08:43:17.941Z","id":"4d1851a571ee9ef34100002f"},{"cur":"SYP","value":0.345,"date":"2010-12-27T08:43:17.941Z","id":"4d1851a571ee9ef341000030"},{"cur":"SAR","value":0.345,"date":"2010-12-27T08:43:17.941Z","id":"4d1851a571ee9ef34100002d"},{"cur":"QAR","value":0.345,"date":"2010-12-27T08:43:17.941Z","id":"4d1851a571ee9ef34100002e"},{"cur":"JMD","value":0.345,"date":"2010-12-27T08:43:17.941Z","id":"4d1851a571ee9ef34100002c"},{"cur":"BHD","value":0.345,"date":"2010-12-27T08:43:17.941Z","id":"4d1851a571ee9ef341000032"},{"cur":"KWD","value":0.345,"date":"2010-12-27T08:43:17.941Z","id":"4d1851a571ee9ef341000031"},{"cur":"PAB","value":0.345,"date":"2010-12-27T08:43:17.941Z","id":"4d1851a571ee9ef341000036"},{"cur":"ILS","value":0.345,"date":"2010-12-27T08:43:17.941Z","id":"4d1851a571ee9ef341000038"},{"cur":"EGP","value":0.345,"date":"2010-12-27T08:43:17.941Z","id":"4d1851a571ee9ef341000033"},{"cur":"OMR","value":0.345,"date":"2010-12-27T08:43:17.941Z","id":"4d1851a571ee9ef341000034"},{"cur":"NGN","value":0.345,"date":"2010-12-27T08:43:17.941Z","id":"4d1851a571ee9ef341000035"},{"cur":"PEN","value":0.345,"date":"2010-12-27T08:43:17.941Z","id":"4d1851a571ee9ef341000037"},{"cur":"UYU","value":0.345,"date":"2010-12-27T08:43:17.941Z","id":"4d1851a571ee9ef341000039"},{"cur":"ARS","value":0.345,"date":"2010-12-27T08:43:17.941Z","id":"4d1851a571ee9ef341000026"},{"cur":"SVC","value":0.345,"date":"2010-12-27T08:43:17.941Z","id":"4d1851a571ee9ef341000028"},{"cur":"CLP","value":0.345,"date":"2010-12-27T08:43:17.941Z","id":"4d1851a571ee9ef341000027"},{"cur":"HRK","value":0.345,"date":"2010-12-27T08:43:17.941Z","id":"4d1851a571ee9ef341000021"},{"cur":"COP","value":0.345,"date":"2010-12-27T08:43:17.941Z","id":"4d1851a571ee9ef341000025"},{"cur":"PHP","value":0.345,"date":"2010-12-27T08:43:17.941Z","id":"4d1851a571ee9ef341000024"},{"cur":"TRY","value":0.345,"date":"2010-12-27T08:43:17.941Z","id":"4d1851a571ee9ef341000023"},{"cur":"RUB","value":0.345,"date":"2010-12-27T08:43:17.941Z","id":"4d1851a571ee9ef341000022"},{"cur":"PLN","value":0.345,"date":"2010-12-27T08:43:17.941Z","id":"4d1851a571ee9ef34100001d"},{"cur":"ISK","value":0.345,"date":"2010-12-27T08:43:17.941Z","id":"4d1851a571ee9ef341000020"},{"cur":"SKK","value":0.345,"date":"2010-12-27T08:43:17.941Z","id":"4d1851a571ee9ef34100001f"},{"cur":"RON","value":0.345,"date":"2010-12-27T08:43:17.941Z","id":"4d1851a571ee9ef34100001e"},{"cur":"EEK","value":0.345,"date":"2010-12-27T08:43:17.941Z","id":"4d1851a571ee9ef341000019"},{"cur":"LVL","value":0.345,"date":"2010-12-27T08:43:17.941Z","id":"4d1851a571ee9ef34100001c"},{"cur":"LTL","value":0.345,"date":"2010-12-27T08:43:17.941Z","id":"4d1851a571ee9ef34100001b"},{"cur":"HUF","value":0.345,"date":"2010-12-27T08:43:17.941Z","id":"4d1851a571ee9ef34100001a"},{"cur":"BGN","value":0.345,"date":"2010-12-27T08:43:17.941Z","id":"4d1851a571ee9ef341000017"},{"cur":"CZK","value":0.345,"date":"2010-12-27T08:43:17.941Z","id":"4d1851a571ee9ef341000018"},{"cur":"ZAR","value":0.345,"date":"2010-12-27T08:43:17.941Z","id":"4d1851a571ee9ef341000012"},{"cur":"MXN","value":0.345,"date":"2010-12-27T08:43:17.941Z","id":"4d1851a571ee9ef341000016"},{"cur":"NOK","value":0.345,"date":"2010-12-27T08:43:17.941Z","id":"4d1851a571ee9ef341000015"},{"cur":"SEK","value":0.345,"date":"2010-12-27T08:43:17.941Z","id":"4d1851a571ee9ef341000014"},{"cur":"THB","value":0.345,"date":"2010-12-27T08:43:17.941Z","id":"4d1851a571ee9ef341000013"},{"cur":"MYR","value":0.345,"date":"2010-12-27T08:43:17.941Z","id":"4d1851a571ee9ef34100000e"},{"cur":"TWD","value":0.345,"date":"2010-12-27T08:43:17.941Z","id":"4d1851a571ee9ef341000011"},{"cur":"SGD","value":0.345,"date":"2010-12-27T08:43:17.941Z","id":"4d1851a571ee9ef341000010"},{"cur":"NZD","value":0.345,"date":"2010-12-27T08:43:17.941Z","id":"4d1851a571ee9ef34100000f"},{"cur":"INR","value":0.345,"date":"2010-12-27T08:43:17.941Z","id":"4d1851a571ee9ef34100000a"},{"cur":"LKR","value":0.345,"date":"2010-12-27T08:43:17.941Z","id":"4d1851a571ee9ef34100000d"},{"cur":"KRW","value":0.345,"date":"2010-12-27T08:43:17.941Z","id":"4d1851a571ee9ef34100000c"},{"cur":"JPY","value":0.345,"date":"2010-12-27T08:43:17.941Z","id":"4d1851a571ee9ef34100000b"},{"cur":"DKK","value":0.345,"date":"2010-12-27T08:43:17.941Z","id":"4d1851a571ee9ef341000008"},{"cur":"HKD","value":0.345,"date":"2010-12-27T08:43:17.941Z","id":"4d1851a571ee9ef341000009"},{"cur":"CNY","value":0.345,"date":"2010-12-27T08:43:17.941Z","id":"4d1851a571ee9ef341000007"},{"cur":"CHF","value":0.345,"date":"2010-12-27T08:43:17.941Z","id":"4d1851a571ee9ef341000006"},{"cur":"EUR","value":0.345,"date":"2010-12-27T08:43:17.941Z","id":"4d1851a571ee9ef341000001"},{"cur":"CAD","value":0.345,"date":"2010-12-27T08:43:17.941Z","id":"4d1851a571ee9ef341000005"},{"cur":"BRL","value":0.345,"date":"2010-12-27T08:43:17.941Z","id":"4d1851a571ee9ef341000004"},{"cur":"AUD","value":0.345,"date":"2010-12-27T08:43:17.941Z","id":"4d1851a571ee9ef341000003"},{"cur":"GBP","value":0.345,"date":"2010-12-27T08:43:17.941Z","id":"4d1851a571ee9ef341000002"},{"cur":"AUD","value":0.9963,"date":"2010-12-27T08:45:07.145Z","id":"4d18521371ee9ef34100003e"},{"cur":"USD","value":1,"date":"2010-12-27T08:45:07.145Z","id":"4d18521371ee9ef34100003b"},{"cur":"EUR","value":0.7606,"date":"2010-12-27T08:45:07.145Z","id":"4d18521371ee9ef34100003c"},{"cur":"GBP","value":0.6476,"date":"2010-12-27T08:45:07.145Z","id":"4d18521371ee9ef34100003d"},{"cur":"CHF","value":0.9589,"date":"2010-12-27T08:45:07.145Z","id":"4d18521371ee9ef341000041"},{"cur":"BRL","value":1.6909,"date":"2010-12-27T08:45:07.145Z","id":"4d18521371ee9ef34100003f"},{"cur":"CAD","value":1.0073,"date":"2010-12-27T08:45:07.145Z","id":"4d18521371ee9ef341000040"},{"cur":"INR","value":45.2183,"date":"2010-12-27T08:45:07.145Z","id":"4d18521371ee9ef341000045"},{"cur":"CNY","value":6.6298,"date":"2010-12-27T08:45:07.145Z","id":"4d18521371ee9ef341000042"},{"cur":"DKK","value":5.67,"date":"2010-12-27T08:45:07.145Z","id":"4d18521371ee9ef341000043"},{"cur":"HKD","value":7.7805,"date":"2010-12-27T08:45:07.145Z","id":"4d18521371ee9ef341000044"},{"cur":"KRW","value":1155.1561,"date":"2010-12-27T08:45:07.145Z","id":"4d18521371ee9ef341000047"},{"cur":"JPY","value":82.7518,"date":"2010-12-27T08:45:07.145Z","id":"4d18521371ee9ef341000046"},{"cur":"SGD","value":1.2982,"date":"2010-12-27T08:45:07.145Z","id":"4d18521371ee9ef34100004b"},{"cur":"LKR","value":111.1958,"date":"2010-12-27T08:45:07.145Z","id":"4d18521371ee9ef341000048"},{"cur":"MYR","value":3.0929,"date":"2010-12-27T08:45:07.145Z","id":"4d18521371ee9ef341000049"},{"cur":"NZD","value":1.3342,"date":"2010-12-27T08:45:07.145Z","id":"4d18521371ee9ef34100004a"},{"cur":"THB","value":30.1889,"date":"2010-12-27T08:45:07.145Z","id":"4d18521371ee9ef34100004e"},{"cur":"TWD","value":29.4889,"date":"2010-12-27T08:45:07.145Z","id":"4d18521371ee9ef34100004c"},{"cur":"ZAR","value":6.7403,"date":"2010-12-27T08:45:07.145Z","id":"4d18521371ee9ef34100004d"},{"cur":"MXN","value":12.3556,"date":"2010-12-27T08:45:07.145Z","id":"4d18521371ee9ef341000051"},{"cur":"SEK","value":6.8296,"date":"2010-12-27T08:45:07.145Z","id":"4d18521371ee9ef34100004f"},{"cur":"NOK","value":5.9687,"date":"2010-12-27T08:45:07.145Z","id":"4d18521371ee9ef341000050"},{"cur":"EEK","value":11.9014,"date":"2010-12-27T08:45:07.145Z","id":"4d18521371ee9ef341000054"},{"cur":"BGN","value":1.486,"date":"2010-12-27T08:45:07.145Z","id":"4d18521371ee9ef341000052"},{"cur":"CZK","value":19.3493,"date":"2010-12-27T08:45:07.145Z","id":"4d18521371ee9ef341000053"},{"cur":"LVL","value":0.5388,"date":"2010-12-27T08:45:07.145Z","id":"4d18521371ee9ef341000057"},{"cur":"HUF","value":211.592,"date":"2010-12-27T08:45:07.145Z","id":"4d18521371ee9ef341000055"},{"cur":"LTL","value":2.6258,"date":"2010-12-27T08:45:07.145Z","id":"4d18521371ee9ef341000056"},{"cur":"SKK","value":21.5722,"date":"2010-12-27T08:45:07.145Z","id":"4d18521371ee9ef34100005a"},{"cur":"PLN","value":3.0125,"date":"2010-12-27T08:45:07.145Z","id":"4d18521371ee9ef341000058"},{"cur":"RON","value":3.2617,"date":"2010-12-27T08:45:07.145Z","id":"4d18521371ee9ef341000059"},{"cur":"RUB","value":30.4474,"date":"2010-12-27T08:45:07.145Z","id":"4d18521371ee9ef34100005d"},{"cur":"ISK","value":117.1155,"date":"2010-12-27T08:45:07.145Z","id":"4d18521371ee9ef34100005b"},{"cur":"HRK","value":5.62,"date":"2010-12-27T08:45:07.145Z","id":"4d18521371ee9ef34100005c"},{"cur":"TRY","value":1.5472,"date":"2010-12-27T08:45:07.145Z","id":"4d18521371ee9ef34100005e"},{"cur":"PHP","value":43.9484,"date":"2010-12-27T08:45:07.145Z","id":"4d18521371ee9ef34100005f"},{"cur":"COP","value":1917.4271,"date":"2010-12-27T08:45:07.145Z","id":"4d18521371ee9ef341000060"},{"cur":"ARS","value":3.9723,"date":"2010-12-27T08:45:07.145Z","id":"4d18521371ee9ef341000061"},{"cur":"SVC","value":8.7472,"date":"2010-12-27T08:45:07.145Z","id":"4d18521371ee9ef341000063"},{"cur":"CLP","value":469.9322,"date":"2010-12-27T08:45:07.145Z","id":"4d18521371ee9ef341000062"}]
console.log course.length

process.exit 0

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

