(function() {
  'use strict';  var Compose, Facet, FacetForAdmin, FacetForAffiliate, FacetForGuest, FacetForMerchant, FacetForRoot, FacetForUser, Model, PermissiveFacet, RestrictiveFacet, Store, encryptPassword, facets, fs, getUserLevel, k, model, parseXmlFeed, run, v, _ref;
  var __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; }, __slice = Array.prototype.slice;
  require.paths.unshift(__dirname + '/lib/node');
  global.settings = require('./config').development;
  fs = require('fs');
  Compose = require('compose');
  run = require('./server').run;
  Store = require('./store/store').Store;
  Model = function(entity, store, overrides) {
    return Compose.create(store, overrides);
  };
  Facet = function(model, options, expose) {
    var facet;
    options != null ? options : options = {};
    facet = {};
    expose && expose.forEach(function(def) {
      var fn, method, name, schema;
      if (def instanceof Array) {
        name = def[1];
        method = def[0];
      } else {
        name = def;
        method = model[name];
      }
      fn = method;
      if (name === 'add' && options.schema) {
        schema = options.schema.put || options.schema;
        fn = function(document) {
          var validation;
          validation = validate(document || {}, schema);
          if (!validation.valid) {
            return SyntaxError(JSON.stringify(validation.errors));
          }
          return method.call(this, document);
        };
      } else if (name === 'update' && options.schema) {
        schema = options.schema.put || options.schema;
        fn = function(query, changes) {
          var validation;
          console.log('VALIDATE?', changes, schema);
          validation = validatePart(changes || {}, schema);
          if (!validation.valid) {
            return SyntaxError(JSON.stringify(validation.errors));
          }
          return method.call(this, query, changes);
        };
      } else if ((name === 'get' || name === 'find') && options.schema) {
        schema = options.schema.get || options.schema;
        fn = __bind(function(query) {
          return wait(method.call(this, query), function(result) {
            if (result instanceof Error) {
              return result;
            }
            console.log('DONTLETOUT?', query, schema);
            result.forEach(function(x) {
              return validateFilter(x, schema);
            });
            return result;
          });
        }, this);
      }
      if (fn) {
        return facet[name] = fn.bind(model);
      }
    });
    return Object.freeze(Compose.create(options, facet));
  };
  PermissiveFacet = function() {
    var expose, model, options;
    model = arguments[0], options = arguments[1], expose = 3 <= arguments.length ? __slice.call(arguments, 2) : [];
    return Facet(model, options, ['get', 'add', 'update', 'find', 'remove'].concat(expose || []));
  };
  RestrictiveFacet = function() {
    var expose, model, options;
    model = arguments[0], options = arguments[1], expose = 3 <= arguments.length ? __slice.call(arguments, 2) : [];
    return Facet(model, options, ['get', 'find'].concat(expose || []));
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
      return settings.security.roots[id] && U.clone(settings.security.roots[id]) || this.__proto__.get(id);
    },
    add: function(data) {
      data != null ? data : data = {};
      console.log('SIGNUP', data);
      return Step(this, [
        function() {
          return this.get(data.id);
        }, function(user) {
          var password, salt;
          if (user instanceof Error) {
            return user;
          }
          if (user) {
            return SyntaxError('Cannot create such user');
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
            name: data.name,
            email: data.email,
            regDate: Date.now(),
            type: data.type,
            active: data.active
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
      changes = U.veto(changes, ['password', 'salt']);
      return this.__proto__.update(query, changes);
    },
    login: function(data, context) {
      data != null ? data : data = {};
      return wait(this.get(data.user), __bind(function(user) {
        var session;
        if (!user) {
          if (data.user) {
            console.log('BAD');
            context.save(null);
            return false;
          } else {
            console.log('LOGOUT');
            context.save(null);
            return true;
          }
        } else {
          if (!user.password || !user.active) {
            console.log('INACTIVE');
            context.save(null);
            return false;
          } else if (user.password === encryptPassword(data.pass, user.salt)) {
            console.log('LOGIN');
            session = {
              id: nonce(),
              uid: user.id
            };
            if (data.remember) {
              session.expires = new Date(15 * 24 * 60 * 60 * 1000 + (new Date()).valueOf());
            }
            context.save(session);
            return session;
          } else {
            context.save(null);
            return false;
          }
        }
      }, this));
    },
    profile: function(changes, session, method) {
      var validation;
      if (method === 'GET') {
        return U.veto(session.user, ['password', 'salt']);
      }
      typeof data != "undefined" && data !== null ? data : data = {};
      console.log('PROFILECHANGE', changes);
      validation = validatePart(changes || {}, {
        properties: {
          id: {
            type: 'string',
            pattern: '[a-zA-Z0-9_]+'
          },
          name: {
            type: 'string'
          },
          email: {
            type: 'string',
            pattern: /^([\w\!\#$\%\&\'\*\+\-\/\=\?\^\`{\|\}\~]+\.)*[\w\!\#$\%\&\'\*\+\-\/\=\?\^\`{\|\}\~]+@((((([a-z0-9]{1}[a-z0-9\-]{0,62}[a-z0-9]{1})|[a-z])\.)+[a-z]{2,6})|(\d{1,3}\.){3}\d{1,3}(\:\d{1,5})?)$/i
          }
        }
      });
      if (!validation.valid) {
        return SyntaxError(JSON.stringify(validation.errors));
      }
      return this.update("id=" + session.user.id, changes);
    },
    passwd: function(data, session, method) {
      var changes;
      if (!(data.newPassword && data.newPassword === data.confirmPassword && session.user.password === encryptPassword(data.oldPassword, session.user.salt))) {
        return TypeError('Refuse to change the password');
      }
      changes = {};
      changes.salt = nonce();
      console.log('PASSWORD SET TO', data.newPassword);
      changes.password = encryptPassword(data.newPassword, changes.salt);
      return this.__proto__.update("id=" + session.user.id, changes);
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
      changes.type = void 0;
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
      changes.type = void 0;
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
  model.Role = Model('Role', Store('Role'), {});
  model.Group = Model('Group', Store('Group'), {});
  model.Session = Model('Session', Store('Session'), {
    lookup: function(req, res) {
      var sid;
      sid = req.getSecureCookie('sid');
      return Step({}, [
        function() {
          return model.Session.get(sid);
        }, function(session) {
          this.session = session || {};
          return model.User.get(this.session.uid);
        }, function(user) {
          var context, level;
          this.session.user = user || {};
          this.session.save = function(value) {
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
              model.Session.add(U.clone(value));
              return res.setSecureCookie('sid', sid, options);
            } else {
              model.Session.remove({
                id: sid
              });
              return res.clearCookie('sid', options);
            }
          };
          level = getUserLevel(this.session.user);
          if (!(level instanceof Array)) {
            level = [level];
          }
          context = Compose.create.apply(null, [{}].concat(level.map(function(x) {
            return facets[x];
          })));
          return Object.freeze(Compose.call(this.session, {
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
        now = Date.now();
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
    add: function(props) {
      props != null ? props : props = {};
      props.date = Date.now();
      return this.__proto__.add(props);
    },
    update: function(query, changes) {
      changes != null ? changes : changes = {};
      changes.date = Date.now();
      return this.__proto__.update(query, changes);
    },
    find: function(query) {
      return wait(this.__proto__.find(), function(result) {
        var found, latest;
        latest = U(result).chain().reduce(function(memo, item) {
          var id;
          id = item.cur;
          if (!memo[id] || item.date > memo[id].date) {
            memo[id] = item;
          }
          return memo;
        }, {}).toArray().value();
        found = U.query(latest, query);
        if (Query(query).normalize().pk) {
          found = found[0] || null;
        }
        return found;
      });
    }
  });
  model.Language = Model('Language', Store('Language', {
    properties: {
      name: String,
      localName: String
    }
  }));
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
  FacetForGuest = Compose.create({}, {
    find: function() {
      return 402;
    },
    home: function(data, session) {
      var k, s, v, _ref;
      s = {};
      _ref = session.context;
      for (k in _ref) {
        v = _ref[k];
        if (typeof v === 'function') {
          s[k] = true;
        } else {
          s[k] = {
            schema: v.schema,
            methods: {
              add: !!v.add,
              update: !!v.update,
              remove: !!v.remove
            }
          };
        }
      }
      return {
        user: U.veto(session.user, ['password', 'salt']),
        schema: s
      };
    },
    login: model.User.login.bind(model.User)
  });
  FacetForUser = Compose.create(FacetForGuest, {
    profile: model.User.profile.bind(model.User),
    passwd: model.User.passwd.bind(model.User),
    Course: RestrictiveFacet(model.Course, {
      schema: {
        properties: {
          cur: {
            type: 'string',
            pattern: '[A-Z]{3}'
          },
          value: {
            type: 'number'
          },
          date: {
            type: 'date'
          }
        }
      }
    })
  });
  FacetForRoot = Compose.create(FacetForUser, {
    Bar: PermissiveFacet(model.Bar, null, 'foos2'),
    Course: PermissiveFacet(model.Course, {
      schema: {
        properties: {
          cur: {
            type: 'string',
            pattern: '[A-Z]{3}'
          },
          value: {
            type: 'number'
          },
          date: {
            type: 'date'
          }
        }
      }
    }, 'fetch'),
    Affiliate: PermissiveFacet(model.Affiliate, {
      schema: {
        properties: {
          id: {
            type: 'string',
            pattern: '[a-zA-Z0-9_]+'
          },
          name: {
            type: 'string'
          },
          email: {
            type: 'string',
            pattern: /^([\w\!\#$\%\&\'\*\+\-\/\=\?\^\`{\|\}\~]+\.)*[\w\!\#$\%\&\'\*\+\-\/\=\?\^\`{\|\}\~]+@((((([a-z0-9]{1}[a-z0-9\-]{0,62}[a-z0-9]{1})|[a-z])\.)+[a-z]{2,6})|(\d{1,3}\.){3}\d{1,3}(\:\d{1,5})?)$/i
          },
          regDate: {
            type: 'date'
          },
          active: {
            type: 'boolean'
          }
        }
      }
    }),
    Merchant: PermissiveFacet(model.Merchant, {
      schema: {
        properties: {
          id: {
            type: 'string',
            pattern: '[a-zA-Z0-9_]+'
          },
          name: {
            type: 'string'
          },
          email: {
            type: 'string',
            pattern: /^([\w\!\#$\%\&\'\*\+\-\/\=\?\^\`{\|\}\~]+\.)*[\w\!\#$\%\&\'\*\+\-\/\=\?\^\`{\|\}\~]+@((((([a-z0-9]{1}[a-z0-9\-]{0,62}[a-z0-9]{1})|[a-z])\.)+[a-z]{2,6})|(\d{1,3}\.){3}\d{1,3}(\:\d{1,5})?)$/i
          },
          regDate: {
            type: 'date'
          },
          active: {
            type: 'boolean'
          }
        }
      }
    }),
    Admin: PermissiveFacet(model.Admin, {
      schema: {
        properties: {
          id: {
            type: 'string',
            pattern: '[a-zA-Z0-9_]+'
          },
          name: {
            type: 'string'
          },
          email: {
            type: 'string',
            pattern: /^([\w\!\#$\%\&\'\*\+\-\/\=\?\^\`{\|\}\~]+\.)*[\w\!\#$\%\&\'\*\+\-\/\=\?\^\`{\|\}\~]+@((((([a-z0-9]{1}[a-z0-9\-]{0,62}[a-z0-9]{1})|[a-z])\.)+[a-z]{2,6})|(\d{1,3}\.){3}\d{1,3}(\:\d{1,5})?)$/i
          },
          regDate: {
            type: 'date'
          },
          active: {
            type: 'boolean'
          }
        }
      }
    }),
    Role: PermissiveFacet(model.Role, {
      schema: {
        properties: {
          name: {
            type: 'string'
          },
          description: {
            type: 'string'
          },
          rights: {
            type: 'array',
            items: {
              type: 'object',
              properties: {
                entity: {
                  type: 'string',
                  "enum": U.keys(model)
                },
                access: {
                  type: 'integer',
                  "enum": [0, 1, 2, 3]
                }
              }
            }
          }
        }
      }
    }),
    Group: PermissiveFacet(model.Group, {
      schema: {
        properties: {
          name: {
            type: 'string'
          },
          description: {
            type: 'string'
          },
          roles: {
            type: 'array',
            items: {
              type: 'string',
              "enum": function() {
                return model.Role.find;
              }
            }
          }
        }
      }
    }),
    Language: PermissiveFacet(model.Language, {
      schema: {
        properties: {
          id: {
            type: 'string',
            pattern: '[a-zA-Z0-9_]+'
          },
          name: {
            type: 'string'
          },
          localName: {
            type: 'string'
          }
        }
      }
    })
  });
  FacetForAffiliate = Compose.create(FacetForUser, {
    Language: FacetForRoot.Language
  });
  FacetForMerchant = Compose.create(FacetForUser, {});
  FacetForAdmin = Compose.create(FacetForUser, {
    Course: FacetForRoot.Course,
    Affiliate: FacetForRoot.Affiliate,
    Merchant: FacetForRoot.Merchant,
    Admin: FacetForRoot.Admin,
    Role: FacetForRoot.Role,
    Group: FacetForRoot.Group,
    Language: FacetForRoot.Language
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
