'use strict'
require.paths.unshift __dirname + '/lib/node'
sys = require 'util'
C = require 'compose'

p = C.create {foo: 'bar'},
	m1: () -> 'IAMM1P'

u = C.create p,
	m1: () -> 'IAMM1U'
	m2: () -> 'IAMM2U'

Facet = (model) ->
	f = {}
	['m1', 'm2'].forEach (m) ->
		#f[m] = C.from.call(model, m, m).bind(model)
		f[m] = model[m].bind model if model[m]
	f

Facet(u).m1()

stdin = process.openStdin()
stdin.on 'close', process.exit
repl = require('repl').start 'node>', stdin
repl.context.C = C
repl.context.Facet = Facet
repl.context.p = p
repl.context.u = u
