#
# Read-Only external store
#

http = require 'http'
parseUrl = require('url').parse

# remote store helper
GET = (uri, options) ->
	deferred = defer()
	request = parseUrl uri
	protocol = request.protocol
	port = request.port
	host = request.host or '127.0.0.1'
	if proxy = process.env.http_proxy
		proxy = parseUrl proxy
		protocol = proxy.protocol
		port = proxy.port
		host = proxy.hostname
	secure = 0 <= protocol.indexOf 's'
	client = http.createClient port or (if secure then 443 else 80), host, secure
	req = client.request false or 'GET', uri, {
		host: request.hostname
		'cache-control': 'no-cache'
		'user-agent': 'Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1; SV1; GTB6.5; .NET CLR 1.1.4322; .NET CLR 2.0.50727)'
	}
	req.end()
	req.on 'response', (res) ->
		res.setEncoding 'utf8'
		body = []
		res.on 'error', (err) -> deferred.reject err
		res.on 'data', (chunk) -> body.push chunk
		res.on 'end', () -> deferred.resolve body.join ''
	deferred.promise

XML2JS = require 'xml2js'
parseXmlFeed = (uri, callback) ->
	wait GET(uri), (data) ->
		deferred = defer()
		#console.log data
		parser = new XML2JS.Parser()
		parser.on 'end', (result) ->
			deferred.resolve if typeof callback is 'function' then callback result else result
		parser.parseString data
		deferred.promise

module.exports = (options) ->

	options ?= {}
	options.collection ?= 'foo'
	options.ttl = Infinity
	options.hardLimit ?= settings.database.hardLimit or 500

	_cache = undefined

	# TODO: generalize
	fetch = (callback) ->
		_cache = {}
		deferred = defer()
		wait parseXmlFeed("http://xurrency.com/#{settings.defaults.currency}/feed"), (data) ->
			_cache[settings.defaults.currency.toUpperCase()] = 1
			data.item?.forEach (x) ->
				_cache[x['dc:targetCurrency']] = parseFloat x['dc:value']['#']
			# TODO: push it to other nodes, if any!
			# TODO: spawn a reaper once a options.ttl milliseconds. Ensure we are not in the middle of find/findById
			deferred.resolve _cache
		deferred.promise

	store =

		find: (query) ->
			filter = () ->
				# TODO: move to RQL: filtering a hash
				arr = []
				for k, v of _cache
					arr.push id: k, value: v
				#console.log 'RQRY', query
				# FIXME: ?sum(value) returns a number, which is treated as status code!
				x = filterArray query, {}, arr
				#console.log 'RESULT', x, x.totalCount, arr
				x
			if _cache
				filter()
			else
				wait fetch(), () -> store.find query

		findById: (id) ->
			if _cache
				if _cache[id]
					{id: id, value: _cache[id]}
				else
					null
			else
				wait fetch(), () -> store.findById id

	Object.freeze store
