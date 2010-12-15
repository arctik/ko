#!/usr/bin/env coffee

require './h'
Store = require('./store').Store

db = new Store 'Country', {name: 'test'}
#db = new Store 'Hit', {name: 'omega'}

facet = db.facet
	create: db.create
	top2: () ->
		@select 'foo/bar!=0&sort(-date)&limit(2)&select(foo/bar)'

db.on 'delete', (doc) -> console.log 'WORRRRRKKSSS!!!', doc

'''
console.log 'START', facet
Step facet, [
	() ->
		console.log 'FACET'
		@insert { name: 'Russia', date: Date(), foo: {bar: 1} }
	(res) ->
		console.log 'INSERTED', res
		@update { name: 'Russia!' }
	(res) ->
		console.log 'UPDATED', res
		#@select 'foo/bar!=0&sort(-date)&limit(5)&select(foo/bar)'
		@top2()
	(res) ->
		console.log 'FOUND', res
		@delete 'foo/bar!=0&sort(-date)&limit(5)&select(foo/bar)'
	(res) ->
		console.log 'DONE', res
		process.exit 0
]
'''

Step facet, [
	() ->
		db.remove()
	() ->
		console.log 'CREATING'
		@create { name: 'Russia', date: Date(), foo: {bar: 1} }
	(res) ->
		console.log 'CREATED', res
		res.save()
	(res) ->
		console.log 'SAVED', res
		res.save()
	(res) ->
		console.log 'DONE', res
		process.exit 0
]
