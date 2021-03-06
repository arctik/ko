'use strict'

#
# Request helpers
#

http = require 'http'
parseUrl = require('url').parse
formidable = require 'formidable'

http.IncomingMessage::parse = () ->

	# parse URL
	# N.B. we prohibit /../
	path = @url
	while lastPath isnt path
		lastPath = path
		path = path.replace /\/[^\/]*\/\.\.\//, '/'
	@location = parseUrl path, true

	# N.B. from now on querystring is stripped from the leading "?"
	@location.search = @location.search?.substring 1

	# real remote IP (e.g. if nginx or haproxy as a reverse-proxy is used)
	if @headers['x-forwarded-for']
		@socket.remoteAddress = @headers['x-forwarded-for']
		delete @headers['x-forwarded-for']

	# honor X-HTTP-Method-Override
	if @headers['x-http-method-override']
		@method = @headers['x-http-method-override'].toUpperCase()

	# parse URL parameters
	@params = @location.query or {}

	#
	headers = @headers
	method = @method = @method.toUpperCase()

	# set security flags
	@xhr = headers['x-requested-with'] is 'XMLHttpRequest'
	if not (@xhr or /application\/j/.test(headers.accept) or
			(method is 'POST' and headers.referer?.indexOf(headers.host + '/') > 0) or
			(method isnt 'GET' and method isnt 'POST'))
		@csrf = true

	# allow http-* URL params to override some request stuff
	for k, v of @params
		if k.toLowerCase().substring(0, 5) is 'http-'
			x = k.toLowerCase().substring(5)
			if x is 'method'
				@method = v.toUpperCase()
			else if x is 'accept' or x is 'content-type'
				@headers[x] = v.toLowerCase()
			# remove http-* params
			delete @params[k]

	##### honor X-Method
	####@method = @headers['x-method'].toUpperCase() if @headers['x-method']

	this

http.IncomingMessage::parseBody = () ->

	self = this
	self.params = {} # N.B. drop any parameter got from querystring
	# deserialize
	form = new formidable.IncomingForm()
	deferred = defer()
	form.uploadDir = 'upload'
	form.on 'file', (field, file) ->
		form.emit 'field', field, file
	form.on 'field', (field, value) ->
		#console.log 'FIELD', field, value
		if not self.params[field]
			self.params[field] = value
		else if self.params[field] not instanceof Array
			self.params[field] = [self.params[field], value]
		else
			self.params[field].push value
	form.on 'error', (err) ->
		#console.log 'TYPE?', err
		deferred.reject SyntaxError(err.message or err)
	form.on 'end', () ->
		# Backbone.emulateJSON compat:
		# if 'application/x-www-form-urlencoded[; foobar]' --> reparse 'model' key to be the final params
		if self.headers['content-type'].split(';')[0] is 'application/x-www-form-urlencoded'
			delete self.params._method
			#console.log 'BACKBONE?', self.params
			self.params = JSON.parse(self.params.model || '{}')
		deferred.resolve self
	form.parse self
	deferred.promise
