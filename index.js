(function() {
  'use strict';  var Compose, Facet, FacetForAdmin, FacetForAffiliate, FacetForGuest, FacetForMerchant, FacetForRoot, FacetForUser, Model, PermissiveFacet, RestrictiveFacet, Store, encryptPassword, facets, fs, getUserLevel, k, model, parseXmlFeed, run, v, _ref;
  var __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; };
  require.paths.unshift(__dirname + '/lib/node');
  global.settings = require('./config').development;
  fs = require('fs');
  Compose = require('compose');
  run = require('./server').run;
  Store = require('./store/store').Store;
  Model = function(entity, store, overrides) {
    return Compose.create(store, overrides);
  };
  Facet = function(model, expose) {
    var facet;
    facet = {};
    expose && expose.forEach(function(def) {
      var method, name;
      if (def instanceof Array) {
        name = def[1];
        method = def[0];
      } else {
        name = def;
        method = model[name];
      }
      if (method) {
        return facet[name] = method.bind(model);
      }
    });
    return Object.freeze(Compose.create({}, facet));
  };
  PermissiveFacet = function(model, expose) {
    return Facet(model, ['get', 'add', 'update', 'find', 'remove', 'eval'].concat(expose || []));
  };
  RestrictiveFacet = function(model, expose) {
    return Facet(model, ['get', 'find'].concat(expose || []));
  };
  model = {};
  facets = {};
  encryptPassword = function(password, salt) {
    return sha1(salt + password + settings.security.secret);
  };
  getUserLevel = function(user) {
    var level;
    if (settings.server.disabled && !settings.security.roots[user.id]) {
      level = 'none';
    } else if (settings.security.bypass || settings.security.roots[user.id]) {
      level = 'root';
    } else if (user.id && user.type) {
      level = user.type;
    } else if (user.id) {
      level = 'user';
    } else {
      level = 'public';
    }
    return level;
  };
  _ref = settings.security.roots;
  for (k in _ref) {
    v = _ref[k];
    v.salt = nonce();
    v.password = encryptPassword(v.password, v.salt);
  }
  model.User = Model('User', Store('User'), {
    get: function(id) {
      if (!id) {
        return null;
      }
      return settings.security.roots[id] || this.__proto__.get(id);
    },
    add: function(data) {
      data != null ? data : data = {};
      console.log('SIGNUP', data);
      return Step(this, [
        function() {
          return this.get(data.id);
        }, function(user) {
          var password, salt;
          if (user) {
            return SyntaxError('Already exists');
          }
          salt = nonce();
          if (!data.password) {
            data.password = nonce().substring(0, 7);
          }
          console.log('PASSWORD SET TO', data.password);
          password = encryptPassword(data.password, salt);
          return this.__proto__.add({
            id: data.id,
            password: password,
            salt: salt,
            email: data.email,
            regDate: Date.now(),
            type: data.type,
            active: true
          });
        }, function(user) {
          return user;
        }
      ]);
    },
    update: function(query, changes) {
      var id;
      if (!query) {
        return URIError('Please be more specific');
      }
      id = parseQuery(query).normalize().pk;
      if (changes.password !== void 0 && !id) {
        return URIError('Can not set passwords in bulk');
      }
      if (changes.password) {
        changes.salt = nonce();
        console.log('PASSWORD SET TO', changes.password);
        changes.password = encryptPassword(changes.password, changes.salt);
      }
      return this.__proto__.update(query, changes);
    },
    login: function(data, context) {
      data != null ? data : data = {};
      return wait(this.get(data.user), __bind(function(user) {
        var session;
        if (!user) {
          if (data.user) {
            context.save(null);
            return false;
          } else {
            context.save(null);
            return {
              user: {}
            };
          }
        } else {
          if (!user.password || !user.active) {
            context.save(null);
            return false;
          } else if (user.password === encryptPassword(data.pass, user.salt)) {
            session = {
              id: nonce(),
              user: {
                id: user.id,
                email: user.email,
                type: user.type
              }
            };
            if (data.remember) {
              session.expires = new Date(15 * 24 * 60 * 60 * 1000 + (new Date()).valueOf());
            }
            context.save(session);
            return {
              sid: session.id,
              user: session.user
            };
          } else {
            context.save(null);
            return false;
          }
        }
      }, this));
    },
    profile: function(data, session) {
      return this.__proto__.get(session.user.id);
    }
  });
  model.Affiliate = Compose.create(model.User, {
    add: function(data) {
      data != null ? data : data = {};
      data.type = 'affiliate';
      return this.__proto__.add(data);
    },
    find: function(query) {
      return this.__proto__.find(Query(query).eq('type', 'affiliate').ne('_deleted', true).select('-password', '-salt'));
    },
    update: function(query, changes) {
      return this.__proto__.update(Query(query).eq('type', 'affiliate'), changes);
    },
    remove: function(query) {
      var q;
      q = Query(query);
      if (!q.args.length) {
        throw TypeError('Please, be more specific');
      }
      return this.update(q.eq('type', 'affiliate'), {
        active: false,
        _deleted: true
      });
    }
  });
  model.Merchant = Compose.create(model.User, {
    add: function(data) {
      data != null ? data : data = {};
      data.type = 'merchant';
      return this.__proto__.add(data);
    },
    find: function(query) {
      return this.__proto__.find(Query(query).eq('type', 'merchant').ne('_deleted', true).select('-password', '-salt'));
    },
    update: function(query, changes) {
      return this.__proto__.update(Query(query).eq('type', 'merchant'), changes);
    },
    remove: function(query) {
      var q;
      q = Query(query);
      if (!q.args.length) {
        throw TypeError('Please, be more specific');
      }
      return this.update(q.eq('type', 'merchant'), {
        active: false,
        _deleted: true
      });
    }
  });
  model.Admin = Compose.create(model.User, {
    add: function(data) {
      data != null ? data : data = {};
      data.type = 'admin';
      return this.__proto__.add(data);
    },
    find: function(query) {
      return this.__proto__.find(Query(query).eq('type', 'admin').ne('_deleted', true).select('-password', '-salt'));
    },
    update: function(query, changes) {
      changes.type = void 0;
      return this.__proto__.update(Query(query).eq('type', 'admin'), changes);
    },
    remove: function(query) {
      var q;
      q = Query(query);
      if (!q.args.length) {
        throw TypeError('Please, be more specific');
      }
      return this.update(q.eq('type', 'admin'), {
        active: false,
        _deleted: true
      });
    }
  });
  model.Session = Model('Session', Store('Session'), {
    lookup: function(req, res) {
      var sid;
      sid = req.getSecureCookie('sid');
      return Step(this, [
        function() {
          return this.get(sid);
        }, function(session) {
          var context, level;
          session != null ? session : session = {
            user: {}
          };
          session.save = __bind(function(value) {
            var options;
            options = {
              path: '/',
              httpOnly: true
            };
            if (value) {
              sid = value.id;
              if (value.expires) {
                options.expires = value.expires;
              }
              this.add(U.clone(value));
              return res.setSecureCookie('sid', sid, options);
            } else {
              this.remove({
                id: sid
              });
              return res.clearCookie('sid', options);
            }
          }, this);
          level = getUserLevel(session.user);
          if (!(level instanceof Array)) {
            level = [level];
          }
          context = Compose.create.apply(null, [{}].concat(level.map(function(x) {
            return facets[x];
          })));
          console.log('EFFECTIVE FACET', level, context);
          return Object.freeze(Compose.call(session, {
            context: context
          }));
        }
      ]);
    }
  });
  parseXmlFeed = require('./server/remote').parseXmlFeed;
  model.Course = Model('Course', Store('Course'), {
    fetch: function() {
      var deferred;
      console.log('FETCHING');
      deferred = defer();
      wait(parseXmlFeed("http://xurrency.com/" + settings.defaults.currency + "/feed"), __bind(function(data) {
        var now, _ref;
        now = (new Date()).toISOString();
        this.add({
          cur: settings.defaults.currency.toUpperCase(),
          value: 1.0,
          date: now
        });
        if ((_ref = data.item) != null) {
          _ref.forEach(__bind(function(x) {
            return this.add({
              cur: x['dc:targetCurrency'],
              value: parseFloat(x['dc:value']['#']),
              date: now
            });
          }, this));
        }
        deferred.resolve(true);
        return console.log('FETCHED');
      }, this));
      return deferred.promise;
    },
    update: function(query, changes) {
      changes != null ? changes : changes = {};
      changes.date = Date.now();
      return this.__proto__.update(query, changes);
    },
    find0: function(query) {
      return this.__proto__.find(Query(query).eq('fresh', true));
    },
    find: function(query) {
      return wait(this.__proto__.find(query), __bind(function(result) {
        var a, now;
        now = Date.now();
        a = U(result).chain().reduce(function(memo, item) {
          var id;
          id = item.cur;
          if (!memo[id] || item.date > memo[id].date) {
            memo[id] = item;
          }
          return memo;
        }, {}).toArray().value();
        console.log(a);
        return a;
      }, this));
    }
  });
  model.Bar = Model('Bar', Store('Bar'), {
    find1: function(query) {
      console.log('FINDINTERCEPTED!');
      return this.__proto__.find((query || '') + '&a!=null');
    },
    find: Compose.around(function(base) {
      return function(query) {
        console.log('BEFOREFIND', arguments);
        return wait(base.call(this, (query || '') + '&a!=null'), function(result) {
          result.forEach(function(doc) {
            doc._version = 2;
            return doc = Object.veto(doc, ['id']);
          });
          console.log('AFTERFIND', result);
          return result;
        });
      };
    }),
    foos1: function() {
      return this.find("foo!=null");
    }
  });
  FacetForGuest = Compose.create({
    foo: 'bar'
  }, {
    find: function() {
      return 402;
    },
    home: function(data, session) {
      var k, s, v, _ref;
      s = {};
      _ref = session.context;
      for (k in _ref) {
        v = _ref[k];
        s[k] = typeof v;
      }
      return 'define(' + JSON.stringify({
        user: session.user,
        model: s
      }) + ');';
    },
    login: model.User.login.bind(model.User)
  });
  FacetForUser = Compose.create(FacetForGuest, {
    profile: model.User.profile.bind(model.User),
    Course: RestrictiveFacet(model.Course)
  });
  FacetForRoot = Compose.create(FacetForUser, {
    Bar: PermissiveFacet(model.Bar, ['foos2']),
    Course: PermissiveFacet(model.Course, ['fetch']),
    Affiliate: PermissiveFacet(model.Affiliate),
    Merchant: PermissiveFacet(model.Merchant),
    Admin: PermissiveFacet(model.Admin)
  });
  FacetForAffiliate = Compose.create(FacetForUser, {
    Affiliate: RestrictiveFacet(model.Affiliate)
  });
  FacetForMerchant = Compose.create(FacetForUser, {
    Merchant: RestrictiveFacet(model.Merchant)
  });
  FacetForAdmin = Compose.create(FacetForUser, {
    Bar: PermissiveFacet(model.Bar, ['foos2']),
    Course: PermissiveFacet(model.Course, ['fetch']),
    Affiliate: PermissiveFacet(model.Affiliate),
    Merchant: PermissiveFacet(model.Merchant),
    Admin: PermissiveFacet(model.Admin)
  });
  facets.public = FacetForGuest;
  facets.user = FacetForUser;
  facets.root = FacetForRoot;
  facets.affiliate = FacetForAffiliate;
  facets.merchant = FacetForMerchant;
  facets.admin = FacetForAdmin;
  global.model = model;
  global.facets = facets;
  wait(waitAllKeys(model), function() {
    var app;
    app = Compose.create(require('events').EventEmitter, {
      getSession: function(req, res) {
        return model.Session.lookup(req, res);
      }
    });
    return run(app);
  });
}).call(this);
