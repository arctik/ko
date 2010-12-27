'use strict'

Database = require('mongo').Database
ObjectID = require('mongo').ObjectID

#
# RQL
#
parseRQL = require('rql/parser').parseGently
Query = require('rql/query').Query

# valid funcs
valid_funcs = ['lt', 'lte', 'gt', 'gte', 'ne', 'in', 'nin', 'not', 'mod', 'all', 'size', 'exists', 'type', 'elemMatch']
# funcs which definitely require array arguments
requires_array = ['in', 'nin', 'all', 'mod']
# funcs acting as operators
valid_operators = ['or', 'and', 'not'] #, 'xor']

parse = (query) ->

	options = {}
	search = {}

	walk = (name, terms) ->
		search = {} # compiled search conditions
		# iterate over terms
		(terms or []).forEach (term) ->
			term ?= {}
			func = term.name
			args = term.args
			# ignore bad terms
			# N.B. this filters quirky terms such as for ?or(1,2) -- term here is a plain value
			return if not func or not args
			# http://www.mongodb.org/display/DOCS/Querying
			# nested terms? -> recurse
			if args[0] instanceof Query
				if 0 <= valid_operators.indexOf func
					search['$'+func] = walk func, args
				# N.B. here we encountered a custom function
				# ...
			# http://www.mongodb.org/display/DOCS/Advanced+Queries
			# structured query syntax
			else
				if func is 'le'
					func = 'lte'
				else if func is 'ge'
					func = 'gte'
				# args[0] is the name of the property
				key = args.shift()
				key = key.join('.') if key instanceof Array
				# the rest args are parameters to func()
				if 0 <= requires_array.indexOf func
					args = args[0]
				# match on regexp means equality
				else if func is 'match'
					func = 'eq'
					regex = new RegExp
					regex.compile.apply regex, args
					args = regex
				else
					# FIXME: do we really need to .join()?!
					args = if args.length is 1 then args[0] else args.join()
				# regexp inequality means negation of equality
				func = 'not' if func is 'ne' and args instanceof RegExp
				# valid functions are prepended with $
				func = '$'+func if 0 <= valid_funcs.indexOf func
				# $or requires an array of conditions
				if name is 'or'
					search = [] unless search instanceof Array
					x = {}
					x[if func is 'eq' then key else func] = args
					search.push x
				# other functions pack conditions into object
				else
					# several conditions on the same property are merged into the single object condition
					search[key] = {} if search[key] is undefined
					search[key][func] = args if search[key] instanceof Object and search[key] not instanceof Array
					# equality cancels all other conditions
					search[key] = args if func is 'eq'
		# TODO: add support for query expressions as Javascript
		# TODO: add support for server-side functions
		search

	# FIXME: parseRQL of normalized query should be idempotent!!!
	# TODO: more robustly determine already normal query!
	# TODO: RQL as executor: Query().le(a,1).fetch() <== real action
	query = parseRQL(query).normalize({primaryKey: '_id'}) unless query?.sortObj
	search = walk query.search.name, query.search.args
	options.sort = query.sortObj if query.sortObj
	options.fields = query.selectObj if query.selectObj
	if query.limit
		options.limit = query.limit[0]
		options.skip = query.limit[1]
	#console.log meta: options, search: search, terms: query
	meta: options, search: search, terms: query

#
# Storage
#
class Storage extends Database
	constructor: (url, options) ->
		options ?= {}
		options.hex ?= true
		super url, options
	add: (collection, document) ->
		document ?= {}
		if document.id
			document._id = document.id
			delete document.id
		deferred = defer()
		#console.log 'ADD?', document
		Storage.__super__.insert.call @, collection, document, (err, result) =>
			#console.log 'ADD!', arguments
			if err
				return deferred.reject SyntaxError 'Duplicated' if err.code is 11000
				return deferred.reject URIError err.message if err.code
			result.id = result._id
			delete result._id
			deferred.resolve result
		deferred.promise
	put: (collection, document) ->
		document ?= {}
		if document.id
			document._id = document.id
			delete document.id
		deferred = defer()
		#console.log 'UPDATE?', document
		# TODO: _deleted: true --> means remove?
		Storage.__super__.modify.call @, collection, {query: {_id: document._id}, update: document, new: true}, (err, result) =>
			#console.log 'UPDATE!', arguments
			return deferred.reject null if err
			result.id = result._id
			delete result._id
			deferred.resolve result
		deferred.promise
	remove: (collection, query) ->
		query = parse query
		deferred = defer()
		# fuser
		#console.log 'REM', query
		throw TypeError 'Use drop() instead to remove the whole collection' unless Object.keys(query.search).length
		super collection, query.search, (err, result) =>
			return deferred.reject URIError err.message if err
			deferred.resolve result
		deferred.promise
	drop: (collection) ->
		deferred = defer()
		super collection, (err, result) =>
			return deferred.reject URIError err.message if err
			deferred.resolve result
		deferred.promise
	find: (collection, query) ->
		#console.log 'FIND?', query
		query = parse query
		#console.log 'FIND!', query
		# limit the limit
		query.meta.limit = 1 if query.terms.pk
		#query.meta.limit = @limit if @limit < query.meta.limit
		deferred = defer()
		super collection, query.search, query.meta, (err, result) =>
			#console.log 'FOUND', arguments
			return deferred.reject URIError err.message if err
			result.forEach (doc) ->
				doc.id = doc._id
				delete doc._id
			if query.terms.pk
				result = result[0] or null
			#@emit 'find', result
			deferred.resolve result
		deferred.promise
	# TODO: findOne
	get: (collection, id) ->
		return null unless id
		@find collection, "id=#{id}"
	update: (collection, query, changes) ->
		changes ?= {}
		query = parse query
		search = query.search
		search.$atomic = 1
		deferred = defer()
		#console.log 'PATCH?', query, search, changes
		# FIXME: how to $unset?!
		# wrap changes into $set key
		unless changes.$set or changes.$unset
			changes = $set: changes
		#console.log 'PATCH???', changes
		super collection, search, changes, (err, result) =>
			#console.log 'PATCH!', arguments
			return deferred.reject URIError err.message if err
			deferred.resolve result
		deferred.promise
	eval: (code) ->
		deferred = defer()
		super code, (err, result) =>
			return deferred.reject URIError err.message if err
			deferred.resolve result
		deferred.promise

#########################################

db = new Storage settings.database.url

Store = (entity) ->
	find: db.find.bind db, entity
	add: db.add.bind db, entity
	update: db.update.bind db, entity
	remove: db.remove.bind db, entity
	get: db.get.bind db, entity
	put: db.put.bind db, entity
	drop: db.drop.bind db, entity
	eval: db.eval.bind db

module.exports =
	Store: Store
