'use strict'

require.paths.unshift __dirname + '/lib/node'

# TODO: make 'development' come from environment
global.settings = require('./config').development
#Object.defineProperty global, 'settings',
#	get: () -> settings

fs = require 'fs'
Compose = require 'compose'

run = require('./server').run
Store = require('./store/store').Store

Model = (entity, store, overrides) ->
	Compose.create store, overrides

# expose enlisted model methods, bound to the model itself
Facet = (model, options, expose) ->
	options ?= {}
	facet = {}
	expose and expose.forEach (def) ->
		if def instanceof Array
			name = def[1]
			method = def[0]
		else
			name = def
			method = model[name]
		#
		fn = method
		# .add() honors schema, if any
		if name is 'add' and options.schema
			fn = (document) ->
				validation = validate document or {}, options.schema
				if not validation.valid
					return SyntaxError JSON.stringify validation.errors
				method.call this, document
		# .update() honors schema, if any
		else if name is 'update' and options.schema
			fn = (query, changes) ->
				console.log 'VALIDATE?', changes, options.schema
				validation = validatePart changes or {}, options.schema
				if not validation.valid
					return SyntaxError JSON.stringify validation.errors
				method.call this, query, changes
		#
		facet[name] = fn.bind model if fn
		#facet[name] = Compose.from(model, name).bind model
	Object.freeze Compose.create options, facet

# expose collection accessors plus enlisted model methods, bound to the model itself
PermissiveFacet = (model, options, expose...) ->
	Facet model, options, ['get', 'add', 'update', 'find', 'remove'].concat(expose or [])

# expose collection getters plus enlisted model methods, bound to the model itself
RestrictiveFacet = (model, options, expose...) ->
	Facet model, options, ['get', 'find'].concat(expose or [])

model = {}
facets = {}

######################################
################### User
######################################

encryptPassword = (password, salt) ->
	sha1(salt + password + settings.security.secret)

# given the user, return his capabilities
getUserLevel = (user) ->
	# settings.server.disabled disables guest or vanilla user interface
	# TODO: watchFile ./down to control settings.server.disabled
	if settings.server.disabled and not settings.security.roots[user.id]
		level = 'none'
	else if settings.security.bypass or settings.security.roots[user.id]
		level = 'root'
	else if user.id and user.type
		level = user.type
	else if user.id
		level = 'user'
	else
		level = 'public'
	level

# secure admin accounts
for k, v of settings.security.roots
	v.salt = nonce()
	v.password = encryptPassword v.password, v.salt

model.User = Model 'User', Store('User'),
	get: (id) ->
		return null unless id
		settings.security.roots[id] or @__proto__.get id
	add: (data) ->
		data ?= {}
		console.log 'SIGNUP', data
		Step @, [
			() ->
				@get data.id
			(user) ->
				#console.log 'USER', user
				return user if user instanceof Error
				return SyntaxError 'Cannot create such user' if user
				# TODO: password set, notify the user
				# TODO: notify only if added OK!
				# create salt, hash salty password
				salt = nonce()
				# generate random pass unless one is specified
				data.password = nonce().substring(0, 7) unless data.password
				console.log 'PASSWORD SET TO', data.password
				password = encryptPassword data.password, salt
				#console.log 'HERE', salt, password
				@__proto__.add
					id: data.id
					password: password
					salt: salt
					name: data.name
					email: data.email
					regDate: Date.now()
					type: data.type
					# TODO: activation!
					active: data.active
			(user) ->
				#console.log 'USER', user
				user
		]
	update: (query, changes) ->
		return URIError 'Please be more specific' unless query
		id = parseQuery(query).normalize().pk
		#return URIError 'Use signup to create new user' unless user.id
		changes = U.veto changes, ['password', 'salt']
		# TODO!!!: limit access rights in changes not higher than of current user
		@__proto__.update query, changes
	login: (data, context) ->
		#console.log 'LOGIN', arguments
		data ?= {}
		wait @get(data.user), (user) =>
			#console.log 'GOT?', user
			if not user
				if data.user
					# invalid user
					console.log 'BAD'
					context.save null
					false
				else
					# log out
					console.log 'LOGOUT'
					context.save null
					true
			else
				if not user.password or not user.active
					# not been activated
					console.log 'INACTIVE'
					context.save null
					false
				else if user.password is encryptPassword data.pass, user.salt
					# log in
					console.log 'LOGIN'
					session =
						id: nonce()
						uid: user.id
					session.expires = new Date(15*24*60*60*1000 + (new Date()).valueOf()) if data.remember
					context.save session
					session
				else
					context.save null
					false
	profile: (changes, session, method) ->
		if method is 'GET'
			return U.veto session.user, ['password', 'salt']
		data ?= {}
		console.log 'PROFILECHANGE', changes
		# N.B. have to manually validate here
		# FIXME: BADBADBAD to double schema here
		validation = validatePart changes or {},
			properties:
				id:
					type: 'string'
					pattern: '[a-zA-Z0-9_]+'
				name:
					type: 'string'
				email:
					type: 'string'
					pattern: /^([\w\!\#$\%\&\'\*\+\-\/\=\?\^\`{\|\}\~]+\.)*[\w\!\#$\%\&\'\*\+\-\/\=\?\^\`{\|\}\~]+@((((([a-z0-9]{1}[a-z0-9\-]{0,62}[a-z0-9]{1})|[a-z])\.)+[a-z]{2,6})|(\d{1,3}\.){3}\d{1,3}(\:\d{1,5})?)$/i
		if not validation.valid
			return SyntaxError JSON.stringify validation.errors
		@update "id=#{session.user.id}", changes
	passwd: (data, session, method) ->
		return TypeError 'Refuse to change the password' unless data.newPassword and data.newPassword is data.confirmPassword and session.user.password is encryptPassword data.oldPassword, session.user.salt
		# TODO: password changed, notify the user
		# TODO: notify only if changed OK!
		# create salt, hash salty password
		changes = {}
		changes.salt = nonce()
		console.log 'PASSWORD SET TO', data.newPassword
		changes.password = encryptPassword data.newPassword, changes.salt
		@__proto__.update "id=#{session.user.id}", changes

model.Affiliate = Compose.create model.User, {
	add: (data) ->
		data ?= {}
		data.type = 'affiliate'
		@__proto__.add data
	find: (query) ->
		@__proto__.find Query(query).eq('type', 'affiliate').ne('_deleted', true).select('-password', '-salt')
	update: (query, changes) ->
		# veto some changes
		changes.type = undefined
		@__proto__.update Query(query).eq('type', 'affiliate'), changes
	remove: (query) ->
		q = Query(query)
		throw TypeError 'Please, be more specific' unless q.args.length
		@update q.eq('type', 'affiliate'), active: false, _deleted: true
}

model.Merchant = Compose.create model.User, {
	add: (data) ->
		data ?= {}
		data.type = 'merchant'
		@__proto__.add data
	find: (query) ->
		@__proto__.find Query(query).eq('type', 'merchant').ne('_deleted', true).select('-password', '-salt')
	update: (query, changes) ->
		# veto some changes
		changes.type = undefined
		@__proto__.update Query(query).eq('type', 'merchant'), changes
	remove: (query) ->
		q = Query(query)
		throw TypeError 'Please, be more specific' unless q.args.length
		@update q.eq('type', 'merchant'), active: false, _deleted: true
}

model.Admin = Compose.create model.User, {
	add: (data) ->
		data ?= {}
		data.type = 'admin'
		@__proto__.add data
	find: (query) ->
		@__proto__.find Query(query).eq('type', 'admin').ne('_deleted', true).select('-password', '-salt')
	update: (query, changes) ->
		# veto some changes
		changes.type = undefined
		@__proto__.update Query(query).eq('type', 'admin'), changes
	remove: (query) ->
		q = Query(query)
		throw TypeError 'Please, be more specific' unless q.args.length
		@update q.eq('type', 'admin'), active: false, _deleted: true
}

model.Role = Model 'Role', Store('Role'), {
}

model.Group = Model 'Group', Store('Group'), {
}

model.Session = Model 'Session', Store('Session'),
	# look for a saved session, attach .save() helper
	lookup: (req, res) ->
		sid = req.getSecureCookie 'sid'
		Step {}, [
			() ->
				#console.log "GET FOR SID #{sid}"
				model.Session.get sid
			(session) ->
				#console.log "GOT FOR SID #{sid}", session
				@session = session or {}
				model.User.get @session.uid
			(user) ->
				#console.log "GOT USER", user
				@session.user = user or {}
				#console.log "SESSIN!#{sid}", @session
				@session.save = (value) ->
					#console.log 'SESSOUT' + sid, value
					options = path: '/', httpOnly: true
					if value
						# store new session and set the cookie
						sid = value.id
						options.expires = value.expires if value.expires
						#console.log 'MAKESESS', value
						# N.B. we don't wait here, so value will be spoiled id -> _id
						model.Session.add U.clone value
						res.setSecureCookie 'sid', sid, options
					else
						# remove the session and the cookie
						#console.log 'REMOVESESS', @
						model.Session.remove id: sid
						res.clearCookie 'sid', options
				level = getUserLevel @session.user
				#context = facets[level] or {}
				level = [level] unless level instanceof Array
				context = Compose.create.apply null, [{}].concat(level.map (x) -> facets[x])
				#console.log 'EFFECTIVE FACET', level, context
				Object.freeze Compose.call @session, context: context
		]

######################################
################### Misc
######################################

parseXmlFeed = require('./server/remote').parseXmlFeed
model.Course = Model 'Course', Store('Course'),
	fetch: () ->
		console.log 'FETCHING'
		deferred = defer()
		wait parseXmlFeed("http://xurrency.com/#{settings.defaults.currency}/feed"), (data) =>
			now = Date.now()
			@add cur: settings.defaults.currency.toUpperCase(), value: 1.0, date: now
			data.item?.forEach (x) =>
				@add cur: x['dc:targetCurrency'], value: parseFloat(x['dc:value']['#']), date: now
			deferred.resolve true
			console.log 'FETCHED'
			#delay 3000, model.Course.fetch.bind(model.Course)
		deferred.promise
	add: (props) ->
		props ?= {}
		props.date = Date.now()
		@__proto__.add props
	update: (query, changes) ->
		changes ?= {}
		changes.date = Date.now()
		@__proto__.update query, changes
	find: (query) ->
		wait @__proto__.find(), (result) ->
			#console.log 'R', result
			latest = U(result).chain().reduce((memo, item) ->
				id = item.cur
				memo[id] = item if not memo[id] or item.date > memo[id].date
				memo
			, {}).toArray().value()
			found = U.query latest, query
			found = found[0] or null if Query(query).normalize().pk
			found

model.Language = Model 'Language', Store('Language', {
	properties:
		name: String
		localName: String
})

######################################
################### Tests
######################################

model.Bar = Model 'Bar', Store('Bar'),
	find1: (query) ->
		console.log 'FINDINTERCEPTED!'
		# TODO: sugar?
		@__proto__.find (query or '') + '&a!=null'
	find: Compose.around (base) ->
		(query) ->
			console.log 'BEFOREFIND', arguments
			wait base.call(@, (query or '') + '&a!=null'), (result) ->
				result.forEach (doc) ->
					doc._version = 2
					doc = Object.veto doc, ['id']
				console.log 'AFTERFIND', result
				result
	#find: Compose.before (query) ->
	#	console.log 'BEFOREFIND', arguments
	#	[(query or '') + '&a!=null']
	#find: Compose.after (promise) ->
	#	console.log 'AFTERFIND', arguments
	#	promise
	foos1: () -> @find "foo!=null"

######################################
################### FACETS
######################################

FacetForGuest = Compose.create {}, {
	find: () -> 402
	home: (data, session) ->
		#s = {}
		#for k, v of session
		#	s[k] = v?.schema?.get?._value or v?.schema?._value or {id: k, properties: {}, type: 'object'}
		#	s[k].id ?= k
		#s = _.keys session.context
		s = {}
		for k, v of session.context
			if typeof v is 'function'
				s[k] = true
			else
				s[k] =
					schema: v.schema
					methods:
						add: not not v.add
						update: not not v.update
						remove: not not v.remove
		#s = session.context
		user: U.veto(session.user, ['password', 'salt']), schema: s
	login: model.User.login.bind model.User
}

FacetForUser = Compose.create FacetForGuest, {
	profile: model.User.profile.bind model.User
	passwd: model.User.passwd.bind model.User
	Course: RestrictiveFacet model.Course,
		schema:
			properties:
				cur:
					type: 'string'
					pattern: '[A-Z]{3}'
				value:
					type: 'number'
				date:
					type: 'date'
}

# root -- hardcoded DB owner
FacetForRoot = Compose.create FacetForUser, {
	Bar: PermissiveFacet model.Bar, null, 'foos2'
	Course: PermissiveFacet model.Course,
		schema:
			properties:
				cur:
					type: 'string'
					pattern: '[A-Z]{3}'
				value:
					type: 'number'
				date:
					type: 'date'
	, 'fetch'
	Affiliate: PermissiveFacet model.Affiliate,
		schema:
			properties:
				id:
					type: 'string'
					pattern: '[a-zA-Z0-9_]+'
				name:
					type: 'string'
				email:
					type: 'string'
					pattern: /^([\w\!\#$\%\&\'\*\+\-\/\=\?\^\`{\|\}\~]+\.)*[\w\!\#$\%\&\'\*\+\-\/\=\?\^\`{\|\}\~]+@((((([a-z0-9]{1}[a-z0-9\-]{0,62}[a-z0-9]{1})|[a-z])\.)+[a-z]{2,6})|(\d{1,3}\.){3}\d{1,3}(\:\d{1,5})?)$/i
				regDate:
					type: 'date'
				active:
					type: 'boolean'
	Merchant: PermissiveFacet model.Merchant,
		schema:
			properties:
				id:
					type: 'string'
					pattern: '[a-zA-Z0-9_]+'
				name:
					type: 'string'
				email:
					type: 'string'
					pattern: /^([\w\!\#$\%\&\'\*\+\-\/\=\?\^\`{\|\}\~]+\.)*[\w\!\#$\%\&\'\*\+\-\/\=\?\^\`{\|\}\~]+@((((([a-z0-9]{1}[a-z0-9\-]{0,62}[a-z0-9]{1})|[a-z])\.)+[a-z]{2,6})|(\d{1,3}\.){3}\d{1,3}(\:\d{1,5})?)$/i
				regDate:
					type: 'date'
				active:
					type: 'boolean'
	Admin: PermissiveFacet model.Admin,
		schema:
			properties:
				id:
					type: 'string'
					pattern: '[a-zA-Z0-9_]+'
				name:
					type: 'string'
				email:
					type: 'string'
					pattern: /^([\w\!\#$\%\&\'\*\+\-\/\=\?\^\`{\|\}\~]+\.)*[\w\!\#$\%\&\'\*\+\-\/\=\?\^\`{\|\}\~]+@((((([a-z0-9]{1}[a-z0-9\-]{0,62}[a-z0-9]{1})|[a-z])\.)+[a-z]{2,6})|(\d{1,3}\.){3}\d{1,3}(\:\d{1,5})?)$/i
				regDate:
					type: 'date'
				active:
					type: 'boolean'
	Role: PermissiveFacet model.Role,
		schema:
			properties:
				name:
					type: 'string'
				description:
					type: 'string'
				rights:
					type: 'array'
					items:
						type: 'object'
						properties:
							entity:
								type: 'string'
								enum: U.keys model
							access:
								type: 'integer'
								enum: [0, 1, 2, 3]
	Group: PermissiveFacet model.Group,
		schema:
			properties:
				name:
					type: 'string'
				description:
					type: 'string'
				roles:
					type: 'array'
					items:
						type: 'string'
						enum: () -> model.Role.find
	Language: PermissiveFacet model.Language,
		schema:
			properties:
				id:
					type: 'string'
					pattern: '[a-zA-Z0-9_]+'
				name:
					type: 'string'
				localName:
					type: 'string'
}

FacetForAffiliate = Compose.create FacetForUser, {
	Language: FacetForRoot.Language
}

FacetForMerchant = Compose.create FacetForUser, {
}

# admin -- powerful user
FacetForAdmin = Compose.create FacetForUser, {
	Course: FacetForRoot.Course
	Affiliate: FacetForRoot.Affiliate
	Merchant: FacetForRoot.Merchant
	Admin: FacetForRoot.Admin
	Role: FacetForRoot.Role
	Group: FacetForRoot.Group
	Language: FacetForRoot.Language
}

facets.public = FacetForGuest
facets.user = FacetForUser
facets.root = FacetForRoot

facets.affiliate = FacetForAffiliate
facets.merchant = FacetForMerchant
facets.admin = FacetForAdmin

# TODO: remove from global
global.model = model
global.facets = facets

############################

wait waitAllKeys(model), () ->

	# define the application
	app = Compose.create require('events').EventEmitter, {
		getSession: (req, res) -> model.Session.lookup(req, res)
		#handler: handler
	}

	# run the application
	run app

# fetch the freshest Courses
#timeout 1000, facets.admin.Course.fetch
