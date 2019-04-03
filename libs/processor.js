// Generated by CoffeeScript 2.3.2
(function() {
  var Category, File, Processor, Promise, Site, Tag, colors;

  colors = require("colors/safe");

  Promise = require("bluebird");

  ({Site, File, Category, Tag} = require("./types"));

  Processor = class Processor {
    constructor(logger) {
      // fn: param p, posts, ctx, return Promise
      this.register = this.register.bind(this);
      this.process = this.process.bind(this);
      this.logger = logger;
      this._ = {};
    }

    register(layout, fn) {
      var i, l, len;
      if (!(fn instanceof Function)) {
        throw new TypeError("fn must be a Function!");
        return;
      }
      if (layout instanceof Array) {
        for (i = 0, len = layout.length; i < len; i++) {
          l = layout[i];
          if (!(l in this._)) {
            this._[l] = [];
          }
          this._[l].push(fn);
        }
        return;
      }
      if (!(layout in this._)) {
        this._[layout] = [];
      }
      return this._[layout].push(fn);
    }

    async process(p, posts, ctx) {
      var fn, i, len, ref, results;
      this.logger.debug(`Hikaru is processing \`${colors.cyan(p["docPath"])}\`...`);
      if (p["layout"] in this._) {
        results = [];
        ref = this._[p["layout"]];
        for (i = 0, len = ref.length; i < len; i++) {
          fn = ref[i];
          p = (await fn(p, posts, ctx));
        }
        return p;
      }
      return Object.assign(new File(), p, ctx);
    }

  };

  module.exports = Processor;

}).call(this);
