'use strict'
require.paths.unshift __dirname + '/lib/node'
global.settings = require('./config').development
require './server/h'
#sys = require 'util'
#J = require 'json-schema'

obj =
	a: '1'
	b: 'false'
	c:
		['2', 1, false]
		#a: '2'
		#b: ['2', 1, false]
	t: '2010'
	e: 'bar'

schema =
	properties:
		a:
			type: 'number'
		b:
			type: 'boolean'
		c:
			type: 'array'
			items:
				type: 'integer'
		d:
			type: 'any', optional: true
		t:
			type: 'date'
	#additionalProperties: false

console.log validatePart obj, schema
console.log obj
