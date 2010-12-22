'use strict'

require.paths.unshift __dirname + '/lib/node'

# TODO: make 'development' come from environment
settings = require('./config').development
Object.defineProperty global, 'settings',
	get: () -> settings

fs = require 'fs'

run = require('./server').run
Model = require('./store/store').Model
Compose = require 'compose'

PermissiveFacet = (model, methods...) ->
	r =
		find: model.find?.bind model
		get: model.get?.bind model
		add: model.add?.bind model
		save: model.save?.bind model
		remove: model.remove?.bind model
	methods.forEach (m) ->
		r[m] = model[m]?.bind model
	r

RestrictiveFacet = (model, methods...) ->
	r =
		find: model.find?.bind model
		get: model.get?.bind model

facets =
	public: {}
	user: {}
	admin: {}

model = {}

model.Bar = Model 'Bar',
	find1: (query) ->
		console.log 'FINDINTERCEPTED!'
		# TODO: sugar?
		@__proto__.find (query or '') + '&a!=null'
	#find: Compose.around (base) ->
	#	(query) ->
	#		console.log 'BEFOREFIND', arguments
	#		r = base.call @, (query or '') + '&a!=null'
	#		console.log 'AFTERFIND', r
	#		r
	find: Compose.before (query) ->
		console.log 'BEFOREFIND', arguments
		[(query or '') + '&a!=null']
	foos1: () -> @find "foo!=null"

#model.Bar1 = Compose

encryptPassword: (password, salt) ->
	sha1(salt + password + settings.security.secret)

model.User = Model 'User',
	get: (id) ->
		return null unless id
		wait @__proto__.get(id), (user) ->
			if not user
				user = settings.security.admins[id] or null
			user
	signup: (data, method, context) ->
		return null unless method is 'POST'
		data ?= {}
		wait @add({id: data.user, password: data.pass, email: 'foo@bar.baz', active: true}), (user) =>
			console.log 'USER', user
			user
	login: (data, method, context) ->
		return null unless method is 'POST'
		#console.log 'LOGIN', arguments
		data ?= {}
		wait @get(data.user), (user) =>
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
				else if user.password is data.pass # is encryptPassword data.pass, user.salt
					# log in
					#console.log 'LOGIN'
					session =
						id: nonce()
						user: user
					session.expires = new Date(15*24*60*60*1000 + (new Date()).valueOf()) if data.remember
					context.save session
					sid: session.id, user: {id: user.id, email: user.email}
				else
					context.save null
					false

model.Session = Model 'Session'

model.Course = require('./store/remote')()

class WebRootPublic
	find: () ->
		console.log 'ROOTQUERIED'
		return true
		templates = []
		# TODO: make async?
		# TODO: employ View Store?
		fs.readdirSync(settings.server.views).forEach (filename) ->
			return unless filename.match /\.html$/
			return if filename is 'index.html'
			data = fs.readFileSync "#{settings.server.views}/#{filename}", 'utf8'
			name = filename.replace '.html', ''
			templates.push "<script id=\"tmpl_#{name}\" type=\"text/x-jquery-tmpl\">#{data}</script>"
		index = fs.readFileSync "#{settings.server.views}/index.html", 'utf8'
		text = index.replace '[[[@@@]]]', templates.join ''
		# atomically form index.html
		if not settings.debug
			fs.writeFileSync "#{settings.server.static.dir}/index.html~", text
			fs.renameSync "#{settings.server.static.dir}/index.html~", "#{settings.server.static.dir}/index.html"
		text
	home: (data, method, context) ->
		user = Object.clone context.user
		delete user.salt
		delete user.password
		s = {}
		for k, v of context
			s[k] = v?.schema?.get?._value or v?.schema?._value or {id: k, properties: {}, type: 'object'}
			s[k].id ?= k
		s = Object.keys context
		#user: user, model: s
		# JSONP answer for RequireJS
		'define('+JSON.stringify(user: user, model: s)+');'
	signup: model.User.signup.bind model.User
	login: model.User.login.bind model.User
	false: () ->
		r = {}
		for k, v of model.User.prototype #__proto__
			r[k] = v.toString()
		r
	test: () -> model.Bar.find {pass: {$ne: '124'}}

class WebRootUser extends WebRootPublic

class WebRootAdmin extends WebRootUser
	Foo: model.Foo
	Bar: PermissiveFacet model.Bar, 'foos1'
	Course: PermissiveFacet model.Course, 'find', 'get'

facets.public = new WebRootPublic()
facets.user = new WebRootUser()
facets.admin = new WebRootAdmin()

# TODO: remove from global
global.model = model
global.facets = facets


############################

wait waitAllKeys(model), (_facets) ->
	# run
	app = Object.create require('events').EventEmitter.prototype,
		getUserLevel:
			value: (user) ->
				# settings.server.disabled disables guest or vanilla user interface
				# TODO: watchFile ./down to control settings.server.disabled
				if settings.server.disabled and not settings.security.admins[user.id]
					level = 'none'
				else if settings.security.bypass or settings.security.admins[user.id]
					level = 'admin'
				else if user.id
					level = 'user'
				else
					level = 'public'
				level
		getModel:
			value: (user) ->
				level = @getUserLevel user
				context = facets[level] or {}
				# TODO: more advanced separation
				context
		getSession:
			value: (req, res) ->
				# TODO: unclosure to be in Session prototype?
				sid = req.getSecureCookie 'sid'
				wait model.Session.get(sid), (session) =>
					session ?= id: sid, user: {}
					#console.log 'SESSIN!' + sid, session
					Object.defineProperties session,
						save:
							value: (value) ->
								#console.log 'SESSOUT' + sid, value
								options = {path: '/', httpOnly: true}
								if value
									# user logged in --> store new session and set the cookie
									sid = value.id
									options.expires = value.expires if value.expires
									#console.log 'MAKESESS', value
									model.Session.add value
									res.setSecureCookie 'sid', sid, options
								else
									# user logged out --> remove the session and the cookie
									#console.log 'REMOVESESS'
									model.Session.remove id: sid
									res.clearCookie 'sid', options
						context:
							get: () ->
								level = app.getUserLevel session.user
								'''
				if user.write
					admin = facets.admin
					#for k in user.write.split /\W+/
					for k in user.write
						context[k].schemaPut = admin[k].schemaPut if admin[k].schemaPut
						context[k].put = admin[k].put if admin[k].put
						context[k].delete = admin[k].delete if admin[k].delete
								'''
								#console.log 'SSSS', level, facets[level]
								context = facets[level] or {}
		#handler: handler
	run app
