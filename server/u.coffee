'use strict'

fs = require 'fs'

# Stolen from connect utils
# Works like find on unix.  Does a recursive readdir and filters by pattern.
exports.find = find = (root, pattern, cb) ->

	rfind = (root, callback) ->
		fs.readdir root, (err, files) ->
			return callback err if err
			results = []
			counter = 0
			console.log 'ROOT', files
			files.forEach (file) ->
				counter++
				checkCounter = () ->
					counter--
					callback null, results if counter is 0
				file = root + '/' + file
				fs.stat file, (err, stat) ->
					return callback err if err
					if stat.isDirectory()
						rfind file, (err, files) ->
							return callback err if err
							results.push.apply results, files
							checkCounter()
						#checkCounter()
						#return
					if pattern.test file
						stat.path = file
						results.push stat
					checkCounter()

	rfind root, (err, files) ->
		return cb err if err
		cb null, files.map (file) ->
			file.path = file.path.substr root.length
			file

#
# string formatting
#
# Stolen from akidee/extensions.js
`
function str_repeat(i, m) {
	for (var o = []; m > 0; o[--m] = i);
	return o.join('');
}

function sprintf() {
	var i = 0, a, f = arguments[i++], o = [], m, p, c, x, s = '';
	while (f) {
		if (m = /^[^\x25]+/.exec(f)) {
			o.push(m[0]);
		}
		else if (m = /^\x25{2}/.exec(f)) {
			o.push('%');
		}
		else if (m = /^\x25(?:(\d+)\$)?(\+)?(0|'[^$])?(-)?(\d+)?(?:\.(\d+))?([b-fosuxX])/.exec(f)) {
			if (((a = arguments[m[1] || i++]) == null) || (a == undefined)) {
				throw('Too few arguments.');
			}
			if (/[^s]/.test(m[7]) && (typeof(a) != 'number')) {
				throw('Expecting number but found ' + typeof(a));
			}
			switch (m[7]) {
				case 'b': a = a.toString(2); break;
				case 'c': a = String.fromCharCode(a); break;
				case 'd': a = parseInt(a); break;
				case 'e': a = m[6] ? a.toExponential(m[6]) : a.toExponential(); break;
				case 'f': a = m[6] ? parseFloat(a).toFixed(m[6]) : parseFloat(a); break;
				case 'o': a = a.toString(8); break;
				case 's': a = ((a = String(a)) && m[6] ? a.substring(0, m[6]) : a); break;
				case 'u': a = Math.abs(a); break;
				case 'x': a = a.toString(16); break;
				case 'X': a = a.toString(16).toUpperCase(); break;
			}
			a = (/[def]/.test(m[7]) && m[2] && a >= 0 ? '+'+ a : a);
			c = m[3] ? m[3] == '0' ? '0' : m[3].charAt(1) : ' ';
			x = m[5] - String(a).length - s.length;
			p = m[5] ? str_repeat(c, x) : '';
			o.push(s + (m[4] ? a + p : p + a));
		}
		else {
			throw('Invalid format string: ' + f);
		}
		f = f.substring(m[0].length);
	}
	return o.join('');
}
`
exports.sprintf = sprintf

#
# captcha
#
exports.checkCaptcha = (data) ->
	# FIXME: pubkeys
	return null
	x = {
		remoteip: data.remoteip
		challenge: data.recaptcha_challenge_field
		response: data.recaptcha_response_field
	}
	Recaptcha = require('recaptcha').Recaptcha
	recaptcha = new Recaptcha settings.security.recaptcha.pubkey, settings.security.recaptcha.privkey, x
	recaptcha.verify (err) ->
		if err
			callback CustomError 403, {errors: [{path: ['captcha'], name: err or 'captcha', message: ''}]}
		else
			callback()






#
# mail
#
Mail = require('mail').Mail
# FIXME: should be protected operation
exports.sendmail = sendmail = (body, subject, to) ->
	console.log 'MAIL: ', body
	#settings = exports.settings.mail
	mail = Mail settings
	#deferred = defer()
	mail.message({
		from: settings.from,
		to: to or settings.support,
		subject: subject or 'Ping'
	}).body(body or 'Pong').send (err) ->
		#console.log 'MAILERR', err
		#return deferred.reject err if err
		#deferred.resolve err or ''
	#deferred.promise

# remote store helper
exports.GET = (uri, options) ->
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

#
# get remote user info
#
#maxmind = require 'node-maxmind'
#geo = new maxmind.DB()
#geo.opendb 'GeoLiteCity.dat'
useragent = require 'useragent'
exports.getRemoteUserInfo = (ip, headers) ->
	agent = headers['user-agent'] or ''
	return {
		ip: ip
		geo: {foo: 'bar'} #geo.record_by_addr ip
		agent: useragent.parser agent
		browser: useragent.browser agent
		nls: headers['accept-language']?.replace(/[,;].*$/, '').toLowerCase() or 'en-us'
	}

exports.MongoStore = require './mongo'
exports.RedisStore = require './redis'
exports.FileSystemStore = require './filesystem'
exports.RemoteStore = require './remote'
# default store
exports.Store = exports.MongoStore
#exports.Store = exports.RedisStore

exports.ValidatingModel = (model, schema) ->

	if modelGet = model.get
		model.get = (id) ->
			# allow drill-down
			path = String(id).split '.'
			id = path.shift()
			# cache schema keys
			schema = overrides.schema.get
			validProps = schema.properties if schema
			# get the doc
			wait modelGet(id), (doc) ->
				if doc
					# kick off unwanted fields
					if validProps
						for k, v of doc
							delete doc[k] unless validProps[k]
					# drill-down
					for prop in path
						p = decodeURIComponent prop
						break unless doc
						doc = doc[p]
						# resolve $ref
						if doc?.$ref
							# TODO: get global rest() and call it
							doc = this.rest?.apply this, ['GET', doc.$ref]
				doc

	if storeQuery = facet.query
		facet.query = (query) ->
			# cache schema keys
			schema = overrides.schema.query or overrides.schema.get
			validProps = schema.properties if schema
			# get the docs
			wait storeQuery(query), (docs) ->
				# kick off unwanted fields
				if validProps
					result.forEach (doc) ->
						for k, v of doc
							delete doc[k] unless validProps[k]
				docs

	if modelPut = facet.put
		facet.put = (object, directives) ->
			# cache schema keys
			schema = overrides.schema.put
			validProps = schema.properties if schema
			# validate the object
			# put the object
			modelPut object, directives

	Object.freeze facet
