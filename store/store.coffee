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
class Store000000000000000000 extends Database
	constructor: (options) ->
		options ?= {}
		options.hex ?= true
		super options.name or 'test', options
		#@options.host.replace /^mongodb:\/\/([^\/]+)/ # TODO
	insert: (collection, document) ->
		document ?= {}
		if document.id
			document._id = document.id
			delete document.id
		deferred = defer()
		#console.log 'INSERT?', document
		super collection, document, (err, result) =>
			#console.log 'INSERT!', arguments
			return deferred.reject URIError err.message if err
			result.id = result._id
			delete result._id
			deferred.resolve result
		deferred.promise
	update: (collection, document) ->
		document ?= {}
		if document.id
			document._id = document.id
			delete document.id
		deferred = defer()
		#console.log 'UPDATE?', document
		# TODO: _deleted: true --> means remove!
		Store.__super__.modify.call @, collection, {query: {_id: document._id}, update: document, new: true}, (err, result) =>
			#console.log 'UPDATE!', arguments
			return deferred.reject null if err
			result.id = result._id
			delete result._id
			deferred.resolve result
		deferred.promise
	save: (collection, document) ->
		document ?= {}
		if not document.id
			# TODO: fill with defaults first?
			@insert collection, document
		else
			@update collection, document
	remove: (collection, query) ->
		query = parse query
		deferred = defer()
		# fuser
		#console.log 'REM', query
		throw TypeError 'Refused to remove the whole collection' unless Object.keys(query.search).length
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
		query.meta.limit = @limit if @limit < query.meta.limit
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
	findById: (collection, id) ->
		return null unless id
		@find collection, "id=#{id}"
	patch: (collection, changes, query) ->
		changes ?= {}
		query = parse(query).search
		query.$atomic = 1
		deferred = defer()
		#console.log 'MUPDATE?!', query, changes
		# FIXME: how to $unset?!
		Store.__super__.update.call @, collection, query, changes, (err, result) =>
			return deferred.reject URIError err.message if err
			deferred.resolve result
		deferred.promise

#########################################

class Store extends Database
	constructor: (options) ->
		options ?= {}
		options.hex ?= true
		super options.name or 'test', options
		#@options.host.replace /^mongodb:\/\/([^\/]+)/ # TODO
	insert: (collection, document, next) ->
		document ?= {}
		if document.id
			document._id = document.id
			delete document.id
		console.log 'INSERT?', collection, document
		super collection, document, (err, result) =>
			console.log 'INSERT!', arguments
			return next URIError err.message if err
			result.id = result._id
			delete result._id
			next null, result
	update: (collection, document, next) ->
		document ?= {}
		id = document.id
		delete document.id
		console.log 'UPDATE?', collection, document
		super collection, {_id: id}, {$set: document}, (err, result) =>
			console.log 'UPDATE!', arguments
			next null, null
	save: (collection, document, next) ->
		document ?= {}
		if not document.id
			# TODO: fill with defaults first?
			@insert collection, document, next
		else
			@update collection, document, next
	remove: (collection, query, next) ->
		query = parse query
		console.log 'REMOVE', collection, query
		# fuser
		return next TypeError 'Refused to remove the whole collection' unless Object.keys(query.search).length
		super collection, query.search, (err, result) =>
			return next URIError err.message if err
			next null, result
	find: (collection, query, next) ->
		#console.log 'FIND?', query
		query = parse query
		#console.log 'FIND!', query
		# limit the limit
		query.meta.limit = 1 if query.terms.pk
		query.meta.limit = @limit if @limit < query.meta.limit
		super collection, query.search, query.meta, (err, result) =>
			#console.log 'FOUND', arguments
			return next URIError err.message if err
			result.forEach (doc) ->
				doc.id = doc._id
				delete doc._id
			if query.terms.pk
				result = result[0] or null
			next null, result
	findById: (collection, id, next) ->
		return next null, null unless id
		@find collection, "id=#{id}", next
	patch: (collection, changes, query, next) ->
		changes ?= {}
		query = parse(query).search
		query.$atomic = 1
		#console.log 'MUPDATE?!', query, changes
		# FIXME: how to $unset?!
		Store.__super__.update.call @, collection, query, changes, (err, result) =>
			return next URIError err.message if err
			next null, result

db = new Store000000000000000000

class Stor
	constructor: (entity) ->
		@find = db.find.bind db, entity
		@findById = db.findById.bind db, entity
		@insert = db.insert.bind db, entity
		@update = db.update.bind db, entity
		@save = db.save.bind db, entity
		@remove = db.remove.bind db, entity
		@drop = db.drop.bind db, entity

class Collection
	constructor: (@name) ->
		Object.defineProperty @, 'db',
			value: Object.freeze
				find: db.find.bind db, @name
				findById: db.findById.bind db, @name
				insert: db.insert.bind db, @name
				update: db.update.bind db, @name
				save: db.save.bind db, @name
				remove: db.remove.bind db, @name
				drop: db.drop.bind db, @name
		@docs = []
	#create: (props) ->
	#	@set props
	get: (id) ->
		wait @db.findById(id), (doc) =>
			console.log 'LOADEDONE!', doc
			new Document doc, name: @name
		@
	find: (query) ->
		wait @db.find(query), (docs) =>
			console.log 'LOADED!', docs
			@set docs
		@
	set: (docs) ->
		@docs = []
		docs.forEach (doc) =>
			@docs.push new Document doc, name: @name
		#@emit 'change', @
		@

class Document
	constructor: (@props, options) ->
		options ?= {}
		options.name ?= 'Foo'
		Object.defineProperty @, 'db',
			value: Object.freeze
				find: db.find.bind db, options.name
				findById: db.findById.bind db, options.name
				insert: db.insert.bind db, options.name
				update: db.update.bind db, options.name
				save: db.save.bind db, options.name
				remove: db.remove.bind db, options.name
		# TODO: defaults
		@props ?= {}
	set: (props) ->
		return @ unless props
		now = @props
		changed = false
		# TODO:
		# return false unless validation
		for k, v of props
			unless _.isEqual now[k], v
				now[k] = v
				changed = true
				#@emit "change:#{k}", v if changed
		#@emit 'change', @ if changed
		@
	save: (props) ->
		if @set props
			console.log 'SAVE?', @props
			@db.save _.clone(@props), (err, doc) =>
				console.log 'SAVED!', arguments
				@set doc
		@
	destroy: () ->
		if @props.id
			@db.remove "id=#{@props.id}", (err, doc) =>
				console.log 'REMOVED!', arguments
		@

module.exports =
	Database: Database
	Store: Store
	Stor: Stor
	Collection: Collection
	Document: Document
