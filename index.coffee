'use strict'

require.paths.unshift __dirname + '/lib/node'

#require 'underscore'

# TODO: make 'development' come from environment
settings = require('./config').development
Object.defineProperty global, 'settings',
	get: () -> settings

fs = require 'fs'

run = require('./server').run
Store = require('./store/store').Store

facets =
	public: {}
	user: {}
	admin: {}

model = {}

class Facet
	constructor: (@store) ->

model.Foo = new Store 'Foo'

class BarModel extends Store
	constructor: () -> super 'Bar'
	#remove: null # BAD: also internally disabled
	top2: () -> @find 'foo/bar!=0&sort(-date)&limit(2)&select(foo/bar)'

model.Bar = new BarModel

encryptPassword: (password, salt) ->
	sha1(salt + password + settings.security.secret)

class UserModel extends Store
	constructor: () ->
		super 'User'
	findById: (id) ->
		# FIXME: undefined strikes bson?!
		return null unless id
		wait UserModel.__super__.findById.call(@, id), (user) ->
			if not user
				user = settings.security.admins[id] or null
			user
	login: (data, method, context) ->
		return null unless method is 'POST'
		#console.log 'LOGIN', arguments
		data ?= {}
		wait @findById(data.user), (user) =>
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
					true
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
						_id: nonce()
						user: user
					session.expires = new Date(15*24*60*60*1000 + (new Date()).valueOf()) if data.remember
					context.save session
					sid: session._id
				else
					context.save null
					false
	prototype:
		ppp: () -> if 1 is 0 then false else true

model.User = new UserModel

class SessionModel extends Store
	constructor: () ->
		super 'Session'

model.Session = new SessionModel
#model.Session = new Store('Session')

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
	Bar: model.Bar.permissiveFacet ['top2']

facets.public = new WebRootPublic()
facets.user = new WebRootUser()
facets.admin = new WebRootAdmin()

global.model = model
global.facets = facets

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
				sid = req.getSecureCookie 'sid'
				wait model.Session.findById(sid), (session) =>
					session ?= _id: sid, user: {}
					#console.log 'SESSIN!' + sid, session
					Object.defineProperties session,
						save:
							value: (value) ->
								#console.log 'SESSOUT' + sid, value
								options = {path: '/', httpOnly: true}
								if not sid and value
									# user logged in --> store new session and set the cookie
									sid = value._id
									options.expires = value.expires if value.expires
									#console.log 'MAKESESS', value
									model.Session.insert value
									res.setSecureCookie 'sid', sid, options
								else if sid and not value
									# user logged out --> remove the session and the cookie
									#console.log 'REMOVESESS'
									model.Session.remove _id: sid
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
