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
					regex = new RegExp()
					regex.compile.apply(regex, args)
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
# Store
#
class Store extends Database
	constructor: (@collection, options) ->
		options ?= {}
		options.hex ?= true
		super options.name or 'test', options
		#@options.host.replace /^mongodb:\/\/([^\/]+)/ # TODO
	insert: (document) ->
		document ?= {}
		if document.id
			document._id = document.id
			delete document.id
		deferred = defer()
		#console.log 'INSERT?', document
		super @collection, document, (err, result) =>
			#console.log 'INSERT!', arguments
			return deferred.reject URIError err.message if err
			result.id = result._id
			delete result._id
			@emit 'insert', result
			deferred.resolve result
		deferred.promise
	update: (document) ->
		document ?= {}
		if document.id
			document._id = document.id
			delete document.id
		deferred = defer()
		#console.log 'UPDATE?', document
		# TODO: _deleted: true --> means remove!
		Store.__super__.modify.call @, @collection, query: {_id: document._id}, update: document, new: true, (err, result) =>
			#console.log 'UPDATE!', arguments
			return deferred.reject null if err
			result.id = result._id
			delete result._id
			@emit 'update', result
			deferred.resolve result
		deferred.promise
	save: (document) ->
		document ?= {}
		if not document.id
			# TODO: fill with defaults first?
			@insert document
		else
			@update document
	mupdate: (changes, query) ->
		changes ?= {}
		@validateOnPut changes, true
		query = parse(query).search
		query.$atomic = 1
		deferred = defer()
		#console.log 'MUPDATE?!', query, changes
		# FIXME: how to $unset?!
		Store.__super__.update.call @, @collection, query, changes, (err, result) =>
			return deferred.reject URIError err.message if err
			@emit 'mupdate', result
			deferred.resolve result
		deferred.promise
	remove: (query) ->
		query = parse query
		deferred = defer()
		# fuser
		console.log 'REM', query
		throw TypeError() unless Object.keys(query.search).length
		super @collection, query.search, (err, result) =>
			return deferred.reject URIError err.message if err
			@emit 'remove', result
			deferred.resolve result
		deferred.promise
	find: (query) ->
		#console.log 'FIND?', query
		query = parse query
		#console.log 'FIND!', query
		# limit the limit
		query.meta.limit = 1 if query.terms.pk
		query.meta.limit = @limit if @limit < query.meta.limit
		deferred = defer()
		super @collection, query.search, query.meta, (err, result) =>
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
	findById: (id) ->
		return null unless id
		@find "id=#{id}"
	stream: (query) ->
		query = parse query
		# limit the limit
		query.meta.limit = @limit if @limit < query.meta.limit
		query.meta.stream = true
		deferred = defer()
		# TODO: return forEachable -- a commonjs-utils lazy array?
		super @collection, query.search, query.meta, (err, doc) ->
			if err then deferred.reject err else deferred.resolve doc
		deferred.promise
	mapReduce: (map, reduce) ->
		deferred = defer()
		super @collection, map, reduce, (err, result) ->
			if err then deferred.reject URIError err.message else deferred.resolve result
		deferred.promise
	#
	# get a frozen set of allowed methods to give safely to the consumer
	#
	# e.g.
	#
	#	facet = db.facet
	#		insert: db.insert
	#		top2: () ->
	#			@select 'foo/bar!=0&sort(-date)&limit(2)&select(foo/bar)'
	#
	# if consumer has `facet` he can insert new documents or fetch top two
	#	 documents which have foo.bar non-zero sorted by date desc
	#	 and _no more_
	#
	facet: (exportedMethods) ->
		Object.freeze Object.proxy @, exportedMethods
	# allow CRUD plus exportedMethods
	permissiveFacet: (exportedMethods) ->
		#@facet insert: true, find: true, update: true, remove: true
		#@facet ['insert', 'find', 'update', 'remove'] #.concat arguments
		@facet ['find', 'save', 'remove', 'mupdate'] #.concat arguments
	# allow only read plus exportedMethods
	restrictiveFacet: (exportedMethods) ->
		#@facet find: true
		@facet ['find'] #.concat arguments
	# get a Document
	load: (id) ->
		wait @findById(id), (properties) =>
			@create properties
	# create a new Document
	create: (properties) ->
		doc = new Document properties
		store = @
		#Object.defineProperties doc,
		#	collection:
		#		value: @restrictiveFacet()
		_.mixin doc,
			collection: @restrictiveFacet()
		doc
	# validate a Document
	validateOnGet: (document) -> document
	validateOnPut: (document, partial) -> document


class Document
	constructor: (properties) ->
		properties ?= {}
		Object.defineProperty @, '_props',
			value: properties
	get: (name) ->
		@_props[name]
	set: (changes, options) ->
		now = @_props
		changed = false
		for prop, val of changes or {}
			unless _.isEqual now[prop], val
				now[prop] = val
				changed = true
				#if not options.silent
				#	@emit 'change:' + attr, @, val, options
		#if not options.silent and changed
		#	@change options
		@

	beforeSave: () ->
		@_props._version = if not @_props._version then 1 else @_props._version + 1
		@
	afterSave: () -> @
	beforeRemove: () -> @
	afterRemove: () -> @

'''
		@vetoRead = options.veto?.read or {}
		@vetoWrite = options.veto?.write or {}
	veto: (document, op) ->
		if op is 'read'
			document = Object.veto Object.clone(document), @vetoRead
		else if op is 'write'
			document = Object.veto Object.clone(document), @vetoWrite
'''

'''
	return new DbCommand(db, @name + ".$cmd", 16, 0, -1, options, null);
'''

class Queue extends Store
	constructor: (@collection, options) ->
		super @collection, options
		options ?= {}
		options =
			create: @collection
			capped: true
			max: options.max or 2
		@command 'create', options, (error, document) ->
			if document and document.errmsg
				if document.errmsg isnt 'collection already exists'
					error = { code: document.code, message: document.errmsg }
					throw error
		@timeout = options.timeout or 3000
	publish: (message) ->
		@insert message: message
	subscribe: (callback) ->
		self = @
		# get id of the latest document
		wait @find("sort(-$natural)&limit(1)"), (latest) ->
			latest = latest[0]?._id or ''
			fetch = () ->
				#console.log 'LATEST', latest
				# get document with id > latest and don't close the connection
				Store.__super__.find.call self, self.collection, {_id: {$gt: latest}}, {tailable: true}, (err, docs) ->
					#console.log 'ERR', err, docs, self.connections.length
					return if err
					docs.forEach (doc) ->
						latest = doc._id
						callback doc #.message
					if docs.length
						process.nextTick fetch
					else
						setTimeout fetch, self.timeout
			fetch()

module.exports =
	Database: Database
	Store: Store
	Document: Document
	Queue: Queue

