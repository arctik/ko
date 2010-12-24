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
global._ = require 'underscore'

Object.apply = (o, props) ->
	x = Object.create o
	for k, v of props
		prop = if v?.value then v else value: v, enumerable: true
		Object.defineProperty x, k, prop
	x

# TODO: use _
# shallow copy
Object.clone = (o) ->
	n = Object.create Object.getPrototypeOf o
	props = Object.getOwnPropertyNames o
	for pName in props
		Object.defineProperty n, pName, Object.getOwnPropertyDescriptor(o, pName)
	n

# kick off properties mentioned in fields from object o
Object.veto = (o, fields) ->
	for k in fields
		if typeof k is 'string'
			delete o[k]
		else if k instanceof Array
			k1 = k.shift()
			v1 = o[k1]
			if v1 instanceof Array
				o[k1] = v1.map (x) -> Object.veto(x, if k.length > 1 then [k] else k)
			else if v1
				o[k1] = Object.veto(v1, if k.length > 1 then [k] else k)
	o
	#Object.freeze o

# shallow copy
Object.copy = (source, target, overwrite) ->
	Object.getOwnPropertyNames(source).forEach (name) ->
		return if name in target
		descriptor = Object.getOwnPropertyDescriptor source, name
		Object.defineProperty target, name, descriptor

# deep copy
Object.deepCopy = (source, target, overwrite) ->
	for k, v of source
		if typeof v is 'object' and typeof target[k] is 'object'
			Object.deepCopy v, target[k], overwrite
		else if overwrite or not target.hasOwnProperty k
			target[k] = v
	target

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
# custom errors generator
#
http = require 'http'
global.CustomError = (message, props) ->
	if typeof message is 'number'
		status = message
		message = http.STATUS_CODES[message]
	else if typeof props is 'number'
		status = props
	err = new Error message
	Object.deepCopy props, err
	err.status = status
	#console.log 'ERRGEN', err
	err



############

#global.drillDown = require('rql/js-array').evaluateProperty
global.parseQuery = require('rql/parser').parseGently
global.Query = require('rql/query').Query
global.filterArray = require('rql/js-array').executeQuery
_.mixin
	query: (arr, query, params) ->
		filterArray query, params or {}, arr

Object.drillDown = (o, property) ->
	if property instanceof Array
		property.forEach (part) ->
			if part
				o = o and o[decodeURIComponent part]
		o
	else if typeof property is 'undefined'
		o
	else
		o[decodeURIComponent property]

############
