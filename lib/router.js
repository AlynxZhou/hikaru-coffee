// Generated by CoffeeScript 2.3.1
(function() {
  var Router, fm, fse, glob, path;

  fse = require("fs-extra");

  fm = require("front-matter");

  path = require("path");

  glob = require("glob");

  module.exports = Router = class Router {
    constructor(logger, renderer, generator, srcDir, docDir, themeDir) {
      this.route = this.route.bind(this);
      // fn: param text, fullPath, ctx, return Promise
      this.register = this.register.bind(this);
      this.getDocPath = this.getDocPath.bind(this);
      this.loadTemplates = this.loadTemplates.bind(this);
      this.renderTemplates = this.renderTemplates.bind(this);
      this.loadThemeAssets = this.loadThemeAssets.bind(this);
      this.renderThemeAssets = this.renderThemeAssets.bind(this);
      this.loadSrc = this.loadSrc.bind(this);
      this.renderPages = this.renderPages.bind(this);
      this.renderSrcAssets = this.renderSrcAssets.bind(this);
      this.logger = logger;
      this.renderer = renderer;
      this.generator = generator;
      this.srcDir = srcDir;
      this.docDir = docDir;
      this.themeDir = themeDir;
      this.store = {};
      this.templates = {};
      this.pages = [];
      this.posts = [];
      this.themeAssets = [];
      this.srcAssets = [];
    }

    route() {
      this.loadThemeAssets().then(() => {
        return this.renderThemeAssets();
      }).then(() => {
        var data, j, len, ref, results;
        ref = this.themeAssets;
        results = [];
        for (j = 0, len = ref.length; j < len; j++) {
          data = ref[j];
          results.push(((data) => {
            this.logger.debug(`Hikaru is saving \`${data["docPath"]}\`...`);
            if (data["content"] != null) {
              return fse.outputFile(path.join(this.docDir, data["docPath"]), data["content"]);
            } else {
              return fse.copy(path.join(this.themeDir, data["srcPath"]), path.join(this.docDir, data["docPath"]));
            }
          })(data));
        }
        return results;
      });
      return Promise.all([this.loadTemplates(), this.loadSrc()]).then(() => {
        this.renderSrcAssets().then(() => {
          var data, j, len, ref, results;
          ref = this.srcAssets;
          results = [];
          for (j = 0, len = ref.length; j < len; j++) {
            data = ref[j];
            results.push(((data) => {
              this.logger.debug(`Hikaru is saving \`${data["docPath"]}\`...`);
              if (data["content"] != null) {
                return fse.outputFile(path.join(this.docDir, data["docPath"]), data["content"]);
              } else {
                return fse.copy(path.join(this.srcDir, data["srcPath"]), path.join(this.docDir, data["docPath"]));
              }
            })(data));
          }
          return results;
        });
        return this.renderTemplates().then(() => {
          return this.renderPages();
        }).then(() => {
          var i, j, k, l, len, len1, page, ref, ref1, ref2, results;
          this.posts.sort(function(a, b) {
            return -(a["date"] - b["date"]);
          });
          for (i = j = 0, ref = this.posts.length; (0 <= ref ? j < ref : j > ref); i = 0 <= ref ? ++j : --j) {
            if (i > 0) {
              this.posts[i]["next"] = this.posts[i - 1];
            }
            if (i < this.posts.length - 1) {
              this.posts[i]["prev"] = this.posts[i + 1];
            }
          }
          ref1 = this.pages;
          for (k = 0, len = ref1.length; k < len; k++) {
            page = ref1[k];
            ((page) => {
              var pages;
              pages = this.generator.generate(page, this.posts);
              if (!(pages instanceof Array)) {
                pages = [pages];
              }
              return this.pages = this.pages.concat(pages);
            })(page);
          }
          ref2 = this.pages;
          results = [];
          for (l = 0, len1 = ref2.length; l < len1; l++) {
            page = ref2[l];
            results.push((async(page) => {
              var layout, res;
              // @template[layout]["content"] is a function receives ctx,
              // returns HTML.
              layout = page["layout"];
              if (!(layout in this.templates)) {
                layout = "page";
              }
              res = (await this.templates[layout]["content"](page));
              this.logger.debug(`Hikaru is saving \`${page["docPath"]}\`...`);
              return fse.outputFile(path.join(this.docDir, page["docPath"]), res);
            })(page));
          }
          return results;
        });
      });
    }

    register(srcExt, docExt, fn) {
      if (docExt instanceof Function) {
        fn = docExt;
        this.renderer.register(srcExt, fn);
        return;
      }
      this.renderer.register(srcExt, fn);
      return this.store[srcExt] = docExt;
    }

    matchFiles(pattern, options) {
      return new Promise(function(resolve, reject) {
        return glob(pattern, options, function(err, res) {
          if (err) {
            return reject(err);
          }
          return resolve(res);
        });
      });
    }

    getDocPath(data) {
      var basename, dirname, docExt, srcExt;
      srcExt = path.extname(data["srcPath"]);
      if (srcExt in this.store) {
        dirname = path.dirname(data["srcPath"]);
        basename = path.basename(data["srcPath"], srcExt);
        docExt = this.store[srcExt];
        return path.join(dirname, `${basename}${docExt}`);
      }
      return data["srcPath"];
    }

    async loadTemplates() {
      var filePath, j, len, promiseQueue, templateFiles;
      templateFiles = (await this.matchFiles("*.*", {
        "cwd": this.themeDir
      }));
      promiseQueue = [];
      for (j = 0, len = templateFiles.length; j < len; j++) {
        filePath = templateFiles[j];
        ((filePath) => {
          this.logger.debug(`Hikaru is loading \`${filePath}\`...`);
          return promiseQueue.push(fse.readFile(path.join(this.themeDir, filePath), "utf8").then((raw) => {
            var data;
            data = {
              "srcPath": filePath,
              "text": raw,
              "raw": raw
            };
            data["docPath"] = this.getDocPath(data);
            return this.templates[path.basename(filePath, path.extname(filePath))] = data;
          }));
        })(filePath);
      }
      return Promise.all(promiseQueue);
    }

    renderTemplates() {
      var data, key, promiseQueue, ref;
      promiseQueue = [];
      ref = this.templates;
      for (key in ref) {
        data = ref[key];
        ((data) => {
          this.logger.debug(`Hikaru is rendering \`${data["srcPath"]}\`...`);
          return promiseQueue.push(data["content"] = this.renderer.render(data["text"], path.join(this.themeDir, data["srcPath"])));
        })(data);
      }
      // Wait for all templates renderer finished.
      return Promise.all(promiseQueue);
    }

    async loadThemeAssets() {
      var filePath, j, len, promiseQueue, themeAssetFiles;
      themeAssetFiles = (await this.matchFiles(path.join("**", "*.*"), {
        "cwd": this.themeDir
      }));
      promiseQueue = [];
      for (j = 0, len = themeAssetFiles.length; j < len; j++) {
        filePath = themeAssetFiles[j];
        ((filePath) => {
          // Skip templates.
          if (path.dirname(filePath) === '.') {
            return;
          }
          this.logger.debug(`Hikaru is loading \`${filePath}\`...`);
          return promiseQueue.push(fse.readFile(path.join(this.themeDir, filePath), "utf8").then((raw) => {
            var data;
            data = {
              "srcPath": filePath,
              "text": raw,
              "raw": raw
            };
            data["docPath"] = this.getDocPath(data);
            return this.themeAssets.push(data);
          }));
        })(filePath);
      }
      return Promise.all(promiseQueue);
    }

    renderThemeAssets() {
      var data, j, len, promiseQueue, ref;
      promiseQueue = [];
      ref = this.themeAssets;
      for (j = 0, len = ref.length; j < len; j++) {
        data = ref[j];
        ((data) => {
          this.logger.debug(`Hikaru is rendering \`${data["srcPath"]}\`...`);
          return promiseQueue.push(data["content"] = this.renderer.render(data["text"], path.join(this.themeDir, data["srcPath"])));
        })(data);
      }
      return Promise.all(promiseQueue);
    }

    async loadSrc() {
      var filePath, j, len, promiseQueue, srcFiles;
      srcFiles = (await this.matchFiles(path.join("**", "*.*"), {
        "cwd": this.srcDir
      }));
      promiseQueue = [];
      for (j = 0, len = srcFiles.length; j < len; j++) {
        filePath = srcFiles[j];
        ((filePath) => {
          this.logger.debug(`Hikaru is loading \`${filePath}\`...`);
          return promiseQueue.push(fse.readFile(path.join(this.srcDir, filePath), "utf8").then((raw) => {
            var data, parsed;
            data = {
              "srcPath": filePath,
              "raw": raw
            };
            data["docPath"] = this.getDocPath(data);
            if (typeof raw === "string") {
              parsed = fm(raw);
              data["text"] = parsed["body"];
              if (parsed["frontmatter"] != null) {
                data = Object.assign(data, parsed["attributes"]);
              }
            }
            if (data["date"] != null) {
              data["date"] = new Date(data["date"]);
            }
            if (data["text"] !== (data["raw"] != null)) {
              this.pages.push(data);
              if (data["layout"] === "post") {
                return this.posts.push(data);
              }
            } else {
              return this.srcAssets.push(data);
            }
          }));
        })(filePath);
      }
      return Promise.all(promiseQueue);
    }

    renderPages() {
      var data, j, len, promiseQueue, ref;
      promiseQueue = [];
      ref = this.pages;
      for (j = 0, len = ref.length; j < len; j++) {
        data = ref[j];
        ((data) => {
          this.logger.debug(`Hikaru is rendering \`${data["srcPath"]}\`...`);
          return promiseQueue.push(data["content"] = this.renderer.render(data["text"], path.join(this.themeDir, data["srcPath"])));
        })(data);
      }
      return Promise.all(promiseQueue);
    }

    renderSrcAssets() {
      var data, j, len, promiseQueue, ref;
      promiseQueue = [];
      ref = this.srcAssets;
      for (j = 0, len = ref.length; j < len; j++) {
        data = ref[j];
        ((data) => {
          this.logger.debug(`Hikaru is rendering \`${data["srcPath"]}\`...`);
          return promiseQueue.push(data["content"] = this.renderer.render(data["text"], path.join(this.themeDir, data["srcPath"])));
        })(data);
      }
      return Promise.all(promiseQueue);
    }

  };

}).call(this);