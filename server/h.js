(function() {
  'use strict';  var crypto, http, inspect, oldConsoleLog, promises, rnd, sys;
  var __indexOf = Array.prototype.indexOf || function(item) {
    for (var i = 0, l = this.length; i < l; i++) {
      if (this[i] === item) return i;
    }
    return -1;
  };
  sys = require('util');
  inspect = require('eyes.js').inspector({
    stream: null
  });
  oldConsoleLog = console.log;
  console.log = function() {
    var arg, _i, _len, _results;
    _results = [];
    for (_i = 0, _len = arguments.length; _i < _len; _i++) {
      arg = arguments[_i];
      _results.push(oldConsoleLog(inspect(arg)));
    }
    return _results;
  };
  promises = require('promised-io/promise');
  global.defer = promises.defer;
  global.waitNomatter = function(promise, callback, errback) {
    return promises.when(promise, callback, errback || callback);
  };
  global.wait = promises.when;
  global.waitAll = promises.all;
  global.waitAllKeys = promises.allKeys;
  global.p = function(promise) {
    return wait(promise, function(x) {
      return console.dir(x);
    });
  };
  global.Step = function(context, steps) {
    var next;
    next = function() {
      var fn, result;
      if (!steps.length) {
        return arguments[0];
      }
      fn = steps.shift();
      try {
        result = fn.apply(context, arguments);
        if (result !== void 0) {
          result = wait(result, next, next);
        }
      } catch (err) {
        next(err);
      }
      return result;
    };
    return next();
  };
  global._ = require('underscore');
  Object.apply = function(o, props) {
    var k, prop, v, x;
    x = Object.create(o);
    for (k in props) {
      v = props[k];
      prop = (v != null ? v.value : void 0) ? v : {
        value: v,
        enumerable: true
      };
      Object.defineProperty(x, k, prop);
    }
    return x;
  };
  Object.clone = function(o) {
    var n, pName, props, _i, _len;
    n = Object.create(Object.getPrototypeOf(o));
    props = Object.getOwnPropertyNames(o);
    for (_i = 0, _len = props.length; _i < _len; _i++) {
      pName = props[_i];
      Object.defineProperty(n, pName, Object.getOwnPropertyDescriptor(o, pName));
    }
    return n;
  };
  Object.veto = function(o, fields) {
    var k, k1, v1, _i, _len;
    for (_i = 0, _len = fields.length; _i < _len; _i++) {
      k = fields[_i];
      if (typeof k === 'string') {
        delete o[k];
      } else if (k instanceof Array) {
        k1 = k.shift();
        v1 = o[k1];
        if (v1 instanceof Array) {
          o[k1] = v1.map(function(x) {
            return Object.veto(x, k.length > 1 ? [k] : k);
          });
        } else if (v1) {
          o[k1] = Object.veto(v1, k.length > 1 ? [k] : k);
        }
      }
    }
    return o;
  };
  Object.copy = function(source, target, overwrite) {
    return Object.getOwnPropertyNames(source).forEach(function(name) {
      var descriptor;
      if (__indexOf.call(target, name) >= 0) {
        return;
      }
      descriptor = Object.getOwnPropertyDescriptor(source, name);
      return Object.defineProperty(target, name, descriptor);
    });
  };
  Object.deepCopy = function(source, target, overwrite) {
    var k, v;
    for (k in source) {
      v = source[k];
      if (typeof v === 'object' && typeof target[k] === 'object') {
        Object.deepCopy(v, target[k], overwrite);
      } else if (overwrite || !target.hasOwnProperty(k)) {
        target[k] = v;
      }
    }
    return target;
  };
  crypto = require('crypto');
  require('cookie').secret = settings.security.secret;
  rnd = function() {
    return Math.random().toString().substring(2);
  };
  global.nonce = function() {
    return (Date.now() & 0x7fff).toString(36) + Math.floor(Math.random() * 1e9).toString(36) + Math.floor(Math.random() * 1e9).toString(36) + Math.floor(Math.random() * 1e9).toString(36);
  };
  global.sha1 = function(data, key) {
    var hmac;
    hmac = crypto.createHmac('sha1', key);
    hmac.update(data);
    return hmac.digest('hex');
  };
  http = require('http');
  global.CustomError = function(message, props) {
    var err, status;
    if (typeof message === 'number') {
      status = message;
      message = http.STATUS_CODES[message];
    } else if (typeof props === 'number') {
      status = props;
    }
    err = new Error(message);
    Object.deepCopy(props, err);
    err.status = status;
    return err;
  };
  global.parseQuery = require('rql/parser').parseGently;
  global.filterArray = require('rql/js-array').executeQuery;
  _.mixin({
    query: function(arr, query, params) {
      return filterArray(query, params || {}, arr);
    }
  });
  Object.drillDown = function(o, property) {
    if (property instanceof Array) {
      property.forEach(function(part) {
        if (part) {
          return o = o && o[decodeURIComponent(part)];
        }
      });
      return o;
    } else if (typeof property === 'undefined') {
      return o;
    } else {
      return o[decodeURIComponent(property)];
    }
  };
}).call(this);
