'use strict'

sys = require 'util'
spawn = require('child_process').spawn
net = require 'net'
netBinding = process.binding 'net'
fs = require 'fs'
http = require 'http'
crypto = require 'crypto'
events = require 'events'

# merge helpers
require './h'

# improve http.IncomingMessage
require './request'
# improve http.ServerResponse
require './response'

# connect to frontend db
redis = require 'redis'
db = redis.createClient()

createFarm = (options, handler) ->

	# options
	options ?= {}
	options.port ?= 80

	#
	node = new process.EventEmitter()

	# setup server
	server = http.createServer()

	# SSL?
	if options.sslKey
		credentials = crypto.createCredentials
			key: fs.readFileSync options.sslKey, 'utf8'
			cert: fs.readFileSync options.sslCert, 'utf8'
			#ca: options.sslCACerts.map (fname) -> fs.readFileSync fname, 'utf8'
		server.setSecure credentials
	server.on 'request', handler

	# websocket?
	if options.websocket
		#ws = require('ws-server').createServer debug: true, server: server
		ws = require('socket.io').listen server, flashPolicyServer: false
		ws.on 'connection', (client) ->
			client.broadcast JSON.stringify channel: 'bcast', client: client.sessionId, message: 'IAMIN'
			client.on 'disconnect', () ->
				ws.broadcast JSON.stringify channel: 'bcast', client: client.sessionId, message: 'IAMOUT'
			client.on 'message', (message) ->
				#console.log 'MESSAGE', message
				client.broadcast JSON.stringify channel: 'bcast', client: client.sessionId, message: message
		# broadcast to clients what is published to 'bcast' channel
		dbPubSub = redis.createClient()
		dbPubSub.on 'message', (channel, message) ->
			ws.broadcast JSON.stringify channel: channel, message: message.toString('utf8')
		dbPubSub.subscribe 'bcast'

	# worker branch
	if process.env._WID_

		Object.defineProperty node, 'id', value: process.env._WID_

		# obtain the master socket from the master and listen to it
		comm = new net.Stream 0, 'unix'
		data = {}
		comm.on 'data', (message) ->
			# get config from master
			data = JSON.parse message
			Object.defineProperty data, 'wid', value: node.id, enumerable: true
		comm.on 'fd', (fd) ->
			server.listenFD fd, 'tcp4'
			console.log "WORKER #{node.id} started"
		comm.resume()

	# master branch
	else

		Object.defineProperty node, 'id', value: 'master'
		Object.defineProperty node, 'isMaster', value: true

		# bind master socket
		socket = netBinding.socket 'tcp4'
		netBinding.bind socket, options.port
		netBinding.listen socket, options.connections or 128
		# attach the server if no workers needed
		server.listenFD socket, 'tcp4' unless options.workers

		# drop privileges
		try
			process.setuid options.uid if options.uid
			process.setgid options.gid if options.gid
		catch err
			console.log 'Sorry, failed to drop privileges'

		# allow to override workers arguments
		args = options.argv or process.argv
		# copy environment
		# TODO: extend?
		env = {}
		for k, v of process.env
			env[k] = v
		for k, v of options.env or {}
			env[k] = v

		# array of listening processes
		workers = []

		# create workers
		createWorker = (id) ->
			env._WID_ = id
			[outfd, infd] = netBinding.socketpair()
			# spawn worker process
			worker = spawn args[0], args.slice(1), env, [infd, 1, 2]
			# establish communication channel to the worker
			worker.comm = new net.Stream outfd, 'unix'
			# init respawning
			worker.on 'exit', () ->
				workers[id] = undefined
				createWorker id
			# we can pass some config to worker
			conf = {}
			# pass worker master socket
			worker.comm.write JSON.stringify(conf), 'ascii', socket
			# put worker to the slot
			workers[id] = worker

		createWorker id for id in [0...options.workers]

		# handle signals
		'SIGINT|SIGTERM|SIGKILL|SIGQUIT|SIGHUP|exit'.split('|').forEach (signal) ->
			process.on signal, () ->
				workers.forEach (worker) ->
					try
						worker.kill()
					catch e
						worker.emit 'exit'
				# we use SIGHUP to restart the workers
				process.exit() unless signal is 'exit' or signal is 'SIGHUP'

		# report usage
		if not options.quiet
			console.log "#{options.workers} worker(s) running at http" +
				(if options.sslKey then 's' else '') + "://*:#{options.port}/. Use CTRL+C to stop."

		# start REPL
		if options.repl
			stdin = process.openStdin()
			stdin.on 'close', process.exit
			repl = require('repl').start 'node>', stdin
			#repl.context.require = require
			#repl.context.app = app

	process.errorHandler = (err) ->
		# err could be: number, string, instanceof Error, simple object
		# TODO: store exception state under filesystem and emit issue ticket
		#text = '' #err.message or err
		logText = err.stack if err.stack
		sys.debug logText
		text = err.stack if err.stack and settings.debug
		text or 500

	process.on 'uncaughtException', (err) ->
		# http://www.debuggable.com/posts/node-js-dealing-with-uncaught-exceptions:4c933d54-1428-443c-928d-4e1ecbdd56cb
		console.log 'Caught exception: ' + err.stack
		# respawn workers
		process.kill process.pid, 'SIGHUP'

	# return
	node

handlerFactory = (app, before, after) ->

	# setup static file server, if any
	if settings.server.static
		staticFileServer = new (require('static/node-static').Server)( settings.server.static.dir, cache: settings.server.static.ttl )

	# faceted handler
	faceted = (req, res) ->

		#console.log "REQ: #{req.method} #{req.url}", req.params
		wid = process.env._WID_

		# process request
		Step {foo:'bar'}, [
			() ->
				# get session
				app.getSession req, res
			(session) ->
				console.log "REQUEST: #{req.method} #{req.url}", req.location, req.params
				# run REST handler
				method = req.method
				path = req.location.pathname
				search = req.location.search or ''
				data = req.params
				# REST handler
				# find the method handler by descending into model own properties
				parts = path.substring(1).split '/'
				model = U.drill session.context, parts
				# bail out unless the handler is determined
				unless model or search
					return null if parts.length isnt 2
					# /Foo/bar --> try to mangle to /Foo?id=bar
					model = U.drill session.context, [parts[0]]
					#console.log 'PARTS', parts, model
					return null unless model
					search = 'id=' + parts[1]
				# parse query
				# N.B. sometimes we want to pass bulk parameters, say ids to DELETE
				#   we may do it as follows: POST /Foo?in(id,$1) x-http-method-override: delete {queryParameters: [[id1,id2,...]]}
				# N.B. sometimes we want to both pass bulk parameters and some data, say ids and props to POST
				#   we may do it as follows: POST /Foo?in(id,$1) {queryParameters: [[id1,id2,...]], data: props}
				if data.queryParameters
					# FIXME: detect when we want to convert parameters
					queryParameters = data.queryParameters #.map (param) -> RQL.converters.default param
					data = data.data or {}
				query = parseQuery search, queryParameters
				#console.log 'QUERY', query
				return URIError query.error if query.error
				# determine handler parameters
				# N.B. we rely on exceptions being catched
				console.log 'MODEL', model
				if typeof model is 'function'
					# TODO: elaborate on method and data
					# FIXME: move to POST handler?
					# FIXME: passing context is good?
					#console.log 'DIRECTCALL', model, this
					model data, method, session
				else if method is 'GET'
					model.find query
				else if method is 'PUT'
					model.save data
				# TODO: parser stucks here!
				else if method is 'DELETE'
					model.remove query
				else if method is 'POST'
					# RPC?
					if data.id and data.method and data.params
						# FIXME: ignore if data.id was already seen
						model[data.method] data.params
					# copy properties?
					else if search
						delete data.id # id is constant!
						model.patch query, data
					# mimic PUT
					else
						model.save data
				else
					return 405 # ReferenceError?
			(response) ->
				console.log "RESPONSE for #{req.url}", arguments
				# send the response
				res.send response
				# handle post-process
				after response if after
				# full stop here
				undefined
			(err) ->
				# here we get if an exception is thrown in previous step
				# FIXME: we should res.send() something
				console.log 'SHOULD NOT HAVE BEEN HERE!', err
				res.send err
		]

	# setup request handler
	handler = (req, res) ->

		# parse the request, leave body alone
		req.parse()

		# allow application to hook some high-load routes
		# the function should return a truthy value to indicate no further processing is needed
		if typeof before is 'function'
			return if before req, res, db

		# serve static files
		# no static file? -> invoke dynamic handler
		if staticFileServer and req.method is 'GET'
			staticFileServer.serve req, res, (err, data) ->
				#console.log "STATIC: #{req.url} == ", err
				faceted req, res if err?.status is 404
		else
			# N.B. damn! if we put this after nextTick() is fired (say, in a callback), we loose data events and thus data
			wait req.parseBody(),
				(parsed) ->
					faceted parsed, res
				(err) ->
					res.send err

	# return
	handler

#
# spawn the farm
#
module.exports.run = (app) ->
	#console.log 'APP', app, facets
	createFarm settings.server, handlerFactory app, app.handler
