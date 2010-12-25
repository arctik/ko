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
Facet = (model, expose) ->
	facet = {}
	expose and expose.forEach (def) ->
		if def instanceof Array
			name = def[1]
			method = def[0]
		else
			name = def
			method = model[name]
		facet[name] = method.bind model if method
		#facet[name] = Compose.from(model, name).bind model
	Object.freeze Compose.create {}, facet

# expose collection accessors plus enlisted model methods, bound to the model itself
PermissiveFacet = (model, expose) ->
	Facet model, ['get', 'add', 'update', 'find', 'patch', 'remove'].concat(expose or [])

# expose collection getters plus enlisted model methods, bound to the model itself
RestrictiveFacet = (model, expose) ->
	Facet model, ['get', 'find'].concat(expose or [])

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
	patch: (query, changes) ->
		return URIError 'Please be more specific' unless query
		id = parseQuery(query).normalize().pk
		return URIError 'Can not set passwords in bulk' if changes.password isnt undefined and not id
		#return URIError 'Use signup to create new user' unless user.id
		if changes.password
			# TODO: password changed, notify the user
			# TODO: notify only if changed OK!
			# create salt, hash salty password
			changes.salt = nonce()
			console.log 'PASSWORD SET TO', changes.password
			changes.password = encryptPassword changes.password, changes.salt
		# TODO: limit access rights in changes not higher than of current user
		@__proto__.patch query, changes
	login: (data, context) ->
		#console.log 'LOGIN', arguments
		data ?= {}
		wait @get(data.user), (user) =>
			#console.log 'GOT?', user
			if not user
				if data.user
					# invalid user
					#console.log 'BAD'
					context.save null
					false
				else
					# log out
					#console.log 'LOGOUT'
					context.save null
					user: {}
			else
				if not user.password or not user.active
					# not been activated
					#console.log 'INACTIVE'
					context.save null
					false
				else if user.password is encryptPassword data.pass, user.salt
					# log in
					#console.log 'LOGIN'
					session =
						id: nonce()
						user:
							id: user.id
							email: user.email
							type: user.type
					session.expires = new Date(15*24*60*60*1000 + (new Date()).valueOf()) if data.remember
					context.save session
					sid: session.id, user: session.user
				else
					context.save null
					false
	signup: (data) ->
		data ?= {}
		#console.log 'SIGNUP', data
		Step @, [
			() ->
				@get data.user
			(user) ->
				return SyntaxError 'Already exists' if user
				# TODO: password set, notify the user
				# TODO: notify only if added OK!
				# create salt, hash salty password
				salt = nonce()
				console.log 'PASSWORD SET TO', data.pass
				password = encryptPassword data.pass, salt
				#console.log 'HERE', salt, password
				# TODO: activation!
				@__proto__.add
					id: data.user
					password: password
					salt: salt
					email: data.email
					regDate: Date.now()
					type: data.type
					active: true
			(user) ->
				#console.log 'USER', user
				user
		]
	profile: (data, session) ->
		@__proto__.get session.user.id

model.Affiliate = Compose.create model.User, {
	add: (data) ->
		data ?= {}
		data.type = 'affiliate'
		@signup data
	find: (query) ->
		@__proto__.find Query(query).eq('type', 'affiliate').ne('_deleted', true).select('-password', '-salt')
	patch: (query, changes) ->
		# TODO: veto some changes
		@__proto__.patch Query(query).eq('type', 'affiliate'), changes
	remove: (query) ->
		q = Query(query)
		throw TypeError 'Please, be more specific' unless q.args.length
		@patch q.eq('type', 'affiliate'), active: false, _deleted: true
}

model.Merchant = Compose.create model.User, {
	add: (data) ->
		data ?= {}
		data.type = 'merchant'
		@signup data
	find: (query) ->
		@__proto__.find Query(query).eq('type', 'merchant').ne('_deleted', true).select('-password', '-salt')
	patch: (query, changes) ->
		# TODO: veto some changes
		@__proto__.patch Query(query).eq('type', 'merchant'), changes
	remove: (query) ->
		q = Query(query)
		throw TypeError 'Please, be more specific' unless q.args.length
		@patch q.eq('type', 'merchant'), active: false, _deleted: true
}

model.Admin = Compose.create model.User, {
	add: (data) ->
		data ?= {}
		data.type = 'admin'
		@signup data
	find: (query) ->
		@__proto__.find Query(query).eq('type', 'admin').ne('_deleted', true).select('-password', '-salt')
	patch: (query, changes) ->
		# TODO: veto some changes
		@__proto__.patch Query(query).eq('type', 'admin'), changes
	remove: (query) ->
		q = Query(query)
		throw TypeError 'Please, be more specific' unless q.args.length
		@patch q.eq('type', 'admin'), active: false, _deleted: true
}

model.Session = Model 'Session', Store('Session'),
	# look for a saved session, attach .save() if found
	lookup: (req, res) ->
		sid = req.getSecureCookie 'sid'
		Step @, [
			() ->
				@get sid
			(session) ->
				session ?= user: {}
				#console.log 'SESSIN!' + sid, session
				session.save = (value) =>
					#console.log 'SESSOUT' + sid, value
					options = {path: '/', httpOnly: true}
					if value
						# store new session and set the cookie
						sid = value.id
						options.expires = value.expires if value.expires
						#console.log 'MAKESESS', value
						# N.B. we don't wait here, so value will be spoiled id -> _id
						@add U.clone value
						res.setSecureCookie 'sid', sid, options
					else
						# remove the session and the cookie
						#console.log 'REMOVESESS', @
						@remove id: sid
						res.clearCookie 'sid', options
				level = getUserLevel session.user
				#context = facets[level] or {}
				level = [level] unless level instanceof Array
				context = Compose.create.apply null, [{}].concat(level.map (x) -> facets[x])
				console.log 'EFFECTIVE FACET', level, context
				Object.freeze Compose.call session, context: context
				#session
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
			# archive previous data
			wait @patch('', $unset: {fresh: 1}), () =>
				# push fresh data
				now = Date.now()
				@add cur: settings.defaults.currency.toUpperCase(), value: 1.0, date: now, fresh: true
				data.item?.forEach (x) =>
					@add cur: x['dc:targetCurrency'], value: parseFloat(x['dc:value']['#']), date: now, fresh: true
				deferred.resolve true
				console.log 'FETCHED'
				#delay 3000, model.Course.fetch.bind(model.Course)
		deferred.promise
	find: (query) ->
		@__proto__.find Query(query).eq('fresh', true)

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

FacetForGuest = Compose.create {foo: 'bar'}, {
	find: () -> 402
	home: (data, session) ->
		#s = {}
		#for k, v of session
		#	s[k] = v?.schema?.get?._value or v?.schema?._value or {id: k, properties: {}, type: 'object'}
		#	s[k].id ?= k
		#s = _.keys session.context
		s = {}
		for k, v of session.context
			s[k] = typeof v
		#s = session.context
		# JSONP answer for RequireJS
		'define('+JSON.stringify(user: session.user, model: s)+');'
	login: model.User.login.bind model.User
	signup: model.User.signup.bind model.User
}

FacetForUser = Compose.create FacetForGuest, {
	signup: null
	profile: model.User.profile.bind model.User
	Course: RestrictiveFacet model.Course
}

FacetForRoot = Compose.create FacetForUser, {
	Bar: PermissiveFacet model.Bar, ['foos2']
	Course: PermissiveFacet model.Course, ['fetch']
	Affiliate: PermissiveFacet model.Affiliate
	Merchant: PermissiveFacet model.Merchant
	Admin: PermissiveFacet model.Admin
}

FacetForAffiliate = Compose.create FacetForUser, {
	Affiliate: RestrictiveFacet model.Affiliate
}

FacetForMerchant = Compose.create FacetForUser, {
	Merchant: RestrictiveFacet model.Merchant
}

FacetForAdmin = Compose.create FacetForUser, {
	Bar: PermissiveFacet model.Bar, ['foos2']
	Course: PermissiveFacet model.Course, ['fetch']
	Affiliate: PermissiveFacet model.Affiliate
	Merchant: PermissiveFacet model.Merchant
	Admin: PermissiveFacet model.Admin
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
	global.app = app = Compose.create require('events').EventEmitter, {
		getSession: (req, res) -> model.Session.lookup(req, res)
		#handler: handler
	}

	# run the application
	run app

# fetch the freshest Courses
#timeout 1000, facets.admin.Course.fetch
