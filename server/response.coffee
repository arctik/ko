'use strict'

#
# Response additions
#

fs = require 'fs'
http = require 'http'
lookupMimeType = require('mime').lookup

http.ServerResponse::send = (body, headers, status) ->

	#console.log 'RESPONSE', body
	# allow status as second arg
	if typeof headers is 'number'
		status = headers
		headers = null
	# defaults
	headers ?= {}
	@headers ?= {}
	# determine content type
	if body instanceof Error
		if body instanceof URIError
			status = 400
			body = body.message
		else if body instanceof TypeError
			body = 403
		else if body instanceof SyntaxError
			status = 406
			body = body.message
		#else if body instanceof RangeError
		#	body = 405
		else
			status = body.status or 500
			# 500 means server internal failure
			if status is 500
				body = process.errorHandler body
			delete body.stack
			delete body.message
			delete body.status
	else if body is true
		body = 204
	else if body is false
		body = 406
	else if body is null
		body = 404
	if not body
		status ?= 204
	else if (t = typeof body) is 'number'
		status = body
		if body < 300
			@contentType '.json' unless @headers['content-type']
			body = '{}'
		else
			@contentType '.txt' unless @headers['content-type']
			body = http.STATUS_CODES[status]
	else if t is 'string'
		@contentType '.html' unless @headers['content-type']
	else if t is 'object' or body instanceof Array
		if body.body or body.headers or body.status
			@headers = body.headers if body.headers
			status = body.status if body.status
			body = body.body or ''
			return @send body, status
		else if body instanceof Buffer
			@contentType '.bin' unless @headers['content-type']
		else
			if not @headers['content-type']
				@contentType '.json'
				try
					if body instanceof Array and body.totalCount
						@headers['content-range'] = 'items=' + body.start + '-' + body.end + '/' + body.totalCount
					#console.log body
					body = JSON.stringify body
				catch err
					console.log err
					body = 'HZ' #sys.inspect body
			else
				mime = @headers['content-type']
				body = serialize body, mime
	else if typeof body is 'function'
		@contentType '.js' unless @headers['content-type']
		body = body.toString()
	else
		console.log 'BODY!!!', t, body
		# populate content-length:
		@headers['content-length'] = (if body instanceof Buffer then body.length else Buffer.byteLength body) unless @headers['content-length']

	# merge headers passed
	for k, v of headers
		@headers[k] = v

	# respond
	@writeHead status or 200, @headers
	# TODO: serializer!
	@end body

http.ServerResponse::contentType = (type) ->
	@headers['content-type'] = lookupMimeType type

http.ServerResponse::redirect = (url, status) ->
	@send '', {location: url}, status or 302

# TODO: make use of node-static!
http.ServerResponse::sendfile = (file) ->
	self = this
	fs.readFile file, (err, buf) ->
		#dir 'FS', file, err
		if err
			self.send (if err.errno is process.ENOENT or err.errno is process.EISDIR then 404 else 500)
		else
			self.contentType file
			self.send buf

http.ServerResponse::attachment = (filename) ->
	@headers['content-disposition'] = if filename then 'attachment; filename="' + path.basename(filename) + '"' else 'attachment'
	this

http.ServerResponse::download = (file, filename) ->
	@attachment(filename or file).sendfile file
