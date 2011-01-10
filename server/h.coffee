'use strict';

#
# improve console.log
#
sys = require 'util'
inspect = require('eyes.js').inspector stream: null
oldConsoleLog = console.log
console.log = () ->
	for arg in arguments
		#sys.debug inspect arg
		oldConsoleLog inspect arg

#
# promises
#
promises = require 'promised-io/promise'
global.defer = promises.defer
global.waitNomatter = (promise, callback, errback) -> promises.when promise, callback, errback or callback
global.wait = promises.when
global.waitAll = promises.all
global.waitAllKeys = promises.allKeys
global.Step = require('promised-io/step').Step
global.p = (promise) -> wait promise, (x) -> console.dir x

#
# Object helpers
#
global.U = require 'underscore'

# U.drill({a:{b:{c:[0,2,4]}}},['a','b','c',2]) ---> 4
# U.drill({a:{b:{get:function(attr){return{c:[0,2,4]}[attr];}}}},['a','b','c',2]) ---> 4
U.mixin
	drill: (obj, path) ->
		_drill = (obj, path) ->
			return obj unless obj and path?
			if U.isArray path
				U.each path, (part) ->
					obj = obj and _drill obj, part
				obj
			else if typeof path is 'undefined'
				obj
			else
				attr = if U.isNumber path then path else decodeURIComponent path
				# FIXME: false .get() in models, .get() requires wait()
				#obj.get and obj.get(attr) or obj[attr]
				obj[attr]
		_drill obj, path
	# kick off properties mentioned in fields from obj
	veto: (obj, fields) ->
		for k in fields
			if typeof k is 'string'
				#delete o[k]
				obj[k] = undefined
			else if k instanceof Array
				k1 = k.shift()
				v1 = obj[k1]
				if v1 instanceof Array
					obj[k1] = v1.map (x) -> U.veto(x, if k.length > 1 then [k] else k)
				else if v1
					obj[k1] = U.veto(v1, if k.length > 1 then [k] else k)
		obj

#
# nonce
#
crypto = require 'crypto'
require('cookie').secret = settings.security.secret
rnd = () ->
	Math.random().toString().substring 2
global.nonce = () ->
	(Date.now() & 0x7fff).toString(36) + Math.floor(Math.random()*1e9).toString(36) + Math.floor(Math.random()*1e9).toString(36) + Math.floor(Math.random()*1e9).toString(36) #+ Math.floor(Math.random()*1e9).toString(36)
	#rnd() + rnd() + rnd() + rnd() + rnd() + rnd()
global.sha1 = (data, key) ->
	hmac = crypto.createHmac 'sha1', key
	hmac.update data
	hmac.digest 'hex'

#
# RQL
#

#global.drillDown = require('rql/js-array').evaluateProperty
global.parseQuery = require('rql/parser').parseGently
global.Query = require('rql/query').Query
global.filterArray = require('rql/js-array').executeQuery
U.mixin
	query: (arr, query, params) ->
		filterArray query, params or {}, arr

#
# Schema
#

J = require 'json-schema/lib/validate'

coerce = (instance, schema) ->
	t = schema.type
	if t is 'string'
		instance = instance ? ''+instance : '';
	else if t in ['number', 'integer']
		if not U.isNaN instance
			instance = +instance;
			instance = Math.floor instance if t is 'integer'
	else if t is 'boolean'
		# N.B. shouldn't 'false' coerce to false?
		instance = not not instance
	else if t is 'null'
		instance = null
	else if t is 'object'
		# can't really think of any sensible coercion to an object
	else if t is 'array'
		instance = U.toArray instance
		#instance = if instance instanceof Array then instance else if instance then [instance] else []
	else if t is 'date'
		date = new Date instance
		if not U.isNaN date.getTime()
			instance = date
	instance

# coercively validate instance
global.validate = (instance, schema) -> J._validate instance, schema, coerce: coerce
# coercively validate only properties that do exist in instance
global.validatePart = (instance, schema) -> J._validate instance, schema, existingOnly: true, coerce: coerce
# deletes properties not defined in the schema
global.validateFilter = (instance, schema) -> J._validate instance, schema, filter: true

############

global.timeout  = (time, next) -> setTimeout next, time
global.interval = (time, next) -> setInterval next, time
