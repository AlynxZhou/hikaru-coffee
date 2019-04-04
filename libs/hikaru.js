// Generated by CoffeeScript 2.3.2
(function() {
  var Category, File, Generator, Hikaru, Logger, Processor, Promise, Renderer, Router, Site, Tag, Translator, URL, cheerio, colors, escapeHTML, fse, genToc, getPathFn, getURLFn, highlight, marked, matchFiles, nib, nunjucks, paginate, paginateCategories, path, removeControlChars, resolveHeaderIds, resolveImage, resolveLink, sortCategories, stylus, types, utils, yaml;

  fse = require("fs-extra");

  path = require("path");

  ({URL} = require("url"));

  cheerio = require("cheerio");

  colors = require("colors/safe");

  Promise = require("bluebird");

  yaml = require("js-yaml");

  nunjucks = require("nunjucks");

  marked = require("marked");

  stylus = require("stylus");

  nib = require("nib");

  Logger = require("./logger");

  Renderer = require("./renderer");

  Processor = require("./processor");

  Generator = require("./generator");

  Translator = require("./translator");

  Router = require("./router");

  types = require("./types");

  ({Site, File, Category, Tag} = types);

  utils = require("./utils");

  ({escapeHTML, matchFiles, removeControlChars, paginate, sortCategories, paginateCategories, getPathFn, getURLFn, resolveHeaderIds, resolveLink, resolveImage, genToc, highlight} = utils);

  Hikaru = class Hikaru {
    constructor(debug = false) {
      this.init = this.init.bind(this);
      this.clean = this.clean.bind(this);
      this.build = this.build.bind(this);
      this.serve = this.serve.bind(this);
      this.loadSite = this.loadSite.bind(this);
      this.loadModules = this.loadModules.bind(this);
      // Load local plugins for site.
      this.loadPlugins = this.loadPlugins.bind(this);
      // Load local scripts for site and theme.
      this.loadScripts = this.loadScripts.bind(this);
      this.registerInternalRenderers = this.registerInternalRenderers.bind(this);
      this.registerInternalProcessors = this.registerInternalProcessors.bind(this);
      this.registerInternalGenerators = this.registerInternalGenerators.bind(this);
      this.debug = debug;
      this.logger = new Logger(this.debug);
      this.logger.debug("Hikaru is starting...");
      this.types = types;
      this.utils = utils;
      process.on("exit", () => {
        return this.logger.debug("Hikaru is stopping...");
      });
      if (process.platform === "win32") {
        require("readline").createInterface({
          "input": process.stdin,
          "output": process.stdout
        }).on("SIGINT", function() {
          return process.emit("SIGINT");
        });
      }
      process.on("SIGINT", function() {
        return process.exit(0);
      });
    }

    init(workDir = ".", configPath) {
      return fse.mkdirp(workDir).then(() => {
        this.logger.debug(`Hikaru is copying \`${colors.cyan(configPath || path.join(workDir, "config.yml"))}\`...`);
        this.logger.debug(`Hikaru is copying \`${colors.cyan(path.join(workDir, "package.json"))}\`...`);
        this.logger.debug(`Hikaru is creating \`${colors.cyan(path.join(workDir, "srcs", path.sep))}\`...`);
        this.logger.debug(`Hikaru is creating \`${colors.cyan(path.join(workDir, "docs", path.sep))}\`...`);
        this.logger.debug(`Hikaru is creating \`${colors.cyan(path.join(workDir, "themes", path.sep))}\`...`);
        this.logger.debug(`Hikaru is creating \`${colors.cyan(path.join(workDir, "scripts", path.sep))}\`...`);
        fse.copy(path.join(__dirname, "..", "dist", "config.yml"), configPath || path.join(workDir, "config.yml"));
        fse.readFile(path.join(__dirname, "..", "dist", "package.json")).then(function(text) {
          var json;
          json = JSON.parse(text);
          // Set package name to site dir name.
          json["name"] = path.relative("..", ".");
          return fse.writeFile(path.join(workDir, "package.json"), JSON.stringify(json, null, "  "));
        });
        fse.mkdirp(path.join(workDir, "srcs")).then(() => {
          this.logger.debug(`Hikaru is copying \`${colors.cyan(path.join(workDir, "srcs", "index.md"))}\`...`);
          this.logger.debug(`Hikaru is copying \`${colors.cyan(path.join(workDir, "srcs", "archives", "index.md"))}\`...`);
          this.logger.debug(`Hikaru is copying \`${colors.cyan(path.join(workDir, "srcs", "categories", "index.md"))}\`...`);
          this.logger.debug(`Hikaru is copying \`${colors.cyan(path.join(workDir, "srcs", "tags", "index.md"))}\`...`);
          fse.copy(path.join(__dirname, "..", "dist", "index.md"), path.join(workDir, "srcs", "index.md"));
          fse.copy(path.join(__dirname, "..", "dist", "archives.md"), path.join(workDir, "srcs", "archives", "index.md"));
          fse.copy(path.join(__dirname, "..", "dist", "categories.md"), path.join(workDir, "srcs", "categories", "index.md"));
          return fse.copy(path.join(__dirname, "..", "dist", "tags.md"), path.join(workDir, "srcs", "tags", "index.md"));
        });
        fse.mkdirp(path.join(workDir, "docs"));
        fse.mkdirp(path.join(workDir, "themes"));
        return fse.mkdirp(path.join(workDir, "scripts"));
      }).catch((err) => {
        this.logger.warn("Hikaru catched some error during initializing!");
        return this.logger.error(err);
      });
    }

    clean(workDir = ".", configPath) {
      var siteConfig;
      configPath = configPath || path.join(workDir, "config.yml");
      siteConfig = yaml.safeLoad(fse.readFileSync(configPath, "utf8"));
      if ((siteConfig != null ? siteConfig["docDir"] : void 0) == null) {
        return;
      }
      return matchFiles("*", {
        "cwd": path.join(workDir, siteConfig["docDir"])
      }).then((res) => {
        return res.map((r) => {
          return fse.stat(path.join(workDir, siteConfig["docDir"], r)).then((stats) => {
            if (stats.isDirectory()) {
              this.logger.debug(`Hikaru is removing \`${colors.cyan(path.join(workDir, siteConfig["docDir"], r, path.sep))}\`...`);
            } else {
              this.logger.debug(`Hikaru is removing \`${colors.cyan(path.join(workDir, siteConfig["docDir"], r))}\`...`);
            }
            return fse.remove(path.join(workDir, siteConfig["docDir"], r));
          });
        });
      }).catch((err) => {
        this.logger.warn("Hikaru catched some error during cleaning!");
        return this.logger.error(err);
      });
    }

    async build(workDir = ".", configPath) {
      var err;
      this.loadSite(workDir, configPath);
      this.loadModules();
      this.loadPlugins();
      this.loadScripts();
      try {
        process.on("unhandledRejection", (err) => {
          this.logger.warn("Hikaru catched some error during generating!");
          this.logger.error(err);
          return this.logger.warn("Hikaru advise you to check generated files!");
        });
        return (await this.router.build());
      } catch (error) {
        err = error;
        this.logger.warn("Hikaru catched some error during generating!");
        this.logger.error(err);
        return this.logger.warn("Hikaru advise you to check generated files!");
      }
    }

    async serve(workDir = ".", configPath, ip, port) {
      var err;
      this.loadSite(workDir, configPath);
      this.loadModules();
      this.loadPlugins();
      this.loadScripts();
      try {
        process.on("unhandledRejection", (err) => {
          this.logger.warn("Hikaru catched some error during serving!");
          return this.logger.error(err);
        });
        return (await this.router.serve(ip || "localhost", Number.parseInt(port) || 2333));
      } catch (error) {
        err = error;
        this.logger.warn("Hikaru catched some error during serving!");
        return this.logger.error(err);
      }
    }

    loadSite(workDir, configPath) {
      var err;
      this.site = new Site(workDir);
      configPath = configPath || path.join(this.site["workDir"], "config.yml");
      try {
        this.site["siteConfig"] = yaml.safeLoad(fse.readFileSync(configPath, "utf8"));
      } catch (error) {
        err = error;
        this.logger.warn("Hikaru cannot find site config!");
        this.logger.error(err);
        process.exit(-1);
      }
      this.site["siteConfig"]["srcDir"] = path.join(this.site["workDir"], this.site["siteConfig"]["srcDir"] || "srcs");
      this.site["siteConfig"]["docDir"] = path.join(this.site["workDir"], this.site["siteConfig"]["docDir"] || "docs");
      this.site["siteConfig"]["themeDir"] = path.join(this.site["workDir"], "themes", this.site["siteConfig"]["themeDir"]);
      this.site["siteConfig"]["themeSrcDir"] = path.join(this.site["siteConfig"]["themeDir"], "srcs");
      this.site["siteConfig"]["categoryDir"] = this.site["siteConfig"]["categoryDir"] || "categories";
      this.site["siteConfig"]["tagDir"] = this.site["siteConfig"]["tagDir"] || "tags";
      try {
        this.site["themeConfig"] = yaml.safeLoad(fse.readFileSync(path.join(this.site["siteConfig"]["themeDir"], "config.yml")));
      } catch (error) {
        err = error;
        if (err["code"] === "ENOENT") {
          this.logger.warn("Hikaru continues with a empty theme config...");
          this.site["themeConfig"] = {};
        }
      }
      // For old plugins and will be removed.
      this.site["srcDir"] = this.site["siteConfig"]["srcDir"];
      this.site["docDir"] = this.site["siteConfig"]["docDir"];
      this.site["themeDir"] = this.site["siteConfig"]["themeDir"];
      this.site["themeSrcDir"] = this.site["siteConfig"]["themeSrcDir"];
      this.site["categoryDir"] = this.site["siteConfig"]["categoryDir"];
      return this.site["tagDir"] = this.site["siteConfig"]["tagDir"];
    }

    loadModules() {
      var defaultLanguage, err;
      this.renderer = new Renderer(this.logger, this.site["siteConfig"]["skipRender"]);
      this.processor = new Processor(this.logger);
      this.generator = new Generator(this.logger);
      this.translator = new Translator(this.logger);
      try {
        defaultLanguage = yaml.safeLoad(fse.readFileSync(path.join(this.site["siteConfig"]["themeDir"], "languages", "default.yml")));
        this.translator.register("default", defaultLanguage);
      } catch (error) {
        err = error;
        if (err["code"] === "ENOENT") {
          this.logger.warn("Hikaru cannot find default language file in your theme.");
        }
      }
      this.router = new Router(this.logger, this.renderer, this.processor, this.generator, this.translator, this.site);
      try {
        this.registerInternalRenderers();
        this.registerInternalProcessors();
        return this.registerInternalGenerators();
      } catch (error) {
        err = error;
        this.logger.warn("Hikaru cannot register internal functions!");
        this.logger.error(err);
        return process.exit(-2);
      }
    }

    async loadPlugins() {
      var modules, siteJsonPath;
      siteJsonPath = path.join(this.site["workDir"], "package.json");
      if (!fse.existsSync(siteJsonPath)) {
        return;
      }
      modules = JSON.parse((await fse.readFile(siteJsonPath)))["dependencies"];
      if (modules == null) {
        return;
      }
      return Object.keys(modules).filter(function(name) {
        return /^hikaru-/.test(name);
      }).map((name) => {
        this.logger.debug(`Hikaru is loading plugin \`${colors.cyan(name)}\`...`);
        return require(require.resolve(name, {
          "paths": [this.site["workDir"], ".", __dirname]
        }))(this);
      });
    }

    async loadScripts() {
      var scripts;
      scripts = ((await matchFiles(path.join("**", "*.js"), {
        "nodir": true,
        "cwd": path.join(this.site["workDir"], "scripts")
      }))).map((filename) => {
        return path.join(this.site["workDir"], "scripts", filename);
      }).concat(((await matchFiles(path.join("**", "*.js"), {
        "nodir": true,
        "cwd": path.join(this.site["siteConfig"]["themeDir"], "scripts")
      }))).map((filename) => {
        return path.join(this.site["siteConfig"]["themeDir"], "scripts", filename);
      }));
      return scripts.map((name) => {
        this.logger.debug(`Hikaru is loading script \`${colors.cyan(path.basename(name))}\`...`);
        return require(require.resolve(name, {
          "paths": [this.site["workDir"], ".", __dirname]
        }))(this);
      });
    }

    registerInternalRenderers() {
      var markedConfig, njkConfig, njkEnv, stylConfig;
      njkConfig = Object.assign({
        "autoescape": false,
        "noCache": true
      }, this.site["siteConfig"]["nunjucks"]);
      njkEnv = nunjucks.configure(this.site["siteConfig"]["themeSrcDir"], njkConfig);
      this.renderer.register([".njk", ".j2"], null, function(file, ctx) {
        var template;
        template = nunjucks.compile(file["text"], njkEnv, file["srcPath"]);
        // For template you must give a async render function as content.
        file["content"] = function(ctx) {
          return new Promise(function(resolve, reject) {
            return template.render(ctx, function(err, res) {
              if (err != null) {
                return reject(err);
              }
              return resolve(res);
            });
          });
        };
        return file;
      });
      this.renderer.register(".html", ".html", function(file, ctx) {
        file["content"] = file["text"];
        return file;
      });
      markedConfig = Object.assign({
        "gfm": true,
        "langPrefix": "",
        "highlight": (code, lang) => {
          return highlight(code, Object.assign({
            "lang": lang != null ? lang.toLowerCase() : void 0,
            "hljs": true,
            "gutter": true
          }, this.site["siteConfig"]["highlight"]));
        }
      }, this.site["siteConfig"]["marked"]);
      marked.setOptions(markedConfig);
      this.renderer.register(".md", ".html", function(file, ctx) {
        file["content"] = marked(file["text"]);
        return file;
      });
      stylConfig = this.site["siteConfig"]["stylus"] || {};
      return this.renderer.register(".styl", ".css", (file, ctx) => {
        return new Promise((resolve, reject) => {
          return stylus(file["text"]).use(nib()).use((style) => {
            return style.define("getSiteConfig", (file) => {
              var i, k, keys, len, res;
              keys = file["val"].toString().split(".");
              res = this.site["siteConfig"];
              for (i = 0, len = keys.length; i < len; i++) {
                k = keys[i];
                if (!(k in res)) {
                  return null;
                }
                res = res[k];
              }
              return res;
            });
          }).use((style) => {
            return style.define("getThemeConfig", (file) => {
              var i, k, keys, len, res;
              keys = file["val"].toString().split(".");
              res = this.site["themeConfig"];
              for (i = 0, len = keys.length; i < len; i++) {
                k = keys[i];
                if (!(k in res)) {
                  return null;
                }
                res = res[k];
              }
              return res;
            });
          }).set("filename", path.join(this.site["siteConfig"]["themeSrcDir"], file["srcPath"])).set("sourcemap", stylConfig["sourcemap"]).set("compress", stylConfig["compress"]).set("include css", true).render(function(err, res) {
            if (err != null) {
              return reject(err);
            }
            file["content"] = res;
            return resolve(file);
          });
        });
      });
    }

    registerInternalProcessors() {
      this.processor.register("index", (p, posts, ctx) => {
        var perPage;
        posts.sort(function(a, b) {
          return -(a["date"] - b["date"]);
        });
        if (this.site["siteConfig"]["perPage"] instanceof Object) {
          perPage = this.site["siteConfig"]["perPage"]["index"];
        } else {
          perPage = this.site["siteConfig"]["perPage"];
        }
        return paginate(p, posts, perPage, ctx);
      });
      this.processor.register("archives", (p, posts, ctx) => {
        var perPage;
        posts.sort(function(a, b) {
          return -(a["date"] - b["date"]);
        });
        if (this.site["siteConfig"]["perPage"] instanceof Object) {
          perPage = this.site["siteConfig"]["perPage"]["archives"];
        } else {
          perPage = this.site["siteConfig"]["perPage"];
        }
        return paginate(p, posts, perPage, ctx);
      });
      this.processor.register("categories", (p, posts, ctx) => {
        return Object.assign(new File(), p, ctx, {
          "categories": this.site["categories"]
        });
      });
      this.processor.register("tags", (p, posts, ctx) => {
        return Object.assign(new File(), p, ctx, {
          "tags": this.site["tags"]
        });
      });
      return this.processor.register(["post", "page"], (p, posts, ctx) => {
        var $, split, toc;
        $ = cheerio.load(p["content"]);
        resolveHeaderIds($);
        toc = genToc($);
        resolveLink($, this.site["siteConfig"]["baseURL"], this.site["siteConfig"]["rootDir"], p["docPath"]);
        resolveImage($, this.site["siteConfig"]["rootDir"], p["docPath"]);
        p["content"] = $("body").html();
        if (p["content"].indexOf("<!--more-->") !== -1) {
          split = p["content"].split("<!--more-->");
          p["excerpt"] = split[0];
          p["more"] = split[1];
          p["content"] = split.join("<a id=\"more\"></a>");
        }
        return Object.assign(new File(), p, ctx, {
          "toc": toc,
          "$": $
        });
      });
    }

    registerInternalGenerators() {
      this.generator.register("beforeProcessing", function(site) {
        var cateName, categories, categoriesLength, category, found, i, j, l, len, len1, len2, len3, len4, m, n, newCate, p, perPage, post, postCategories, ref, ref1, ref2, sub, subCategories;
        // Generate categories
        categories = [];
        categoriesLength = 0;
        ref = site["posts"];
        for (i = 0, len = ref.length; i < len; i++) {
          post = ref[i];
          if (post["frontMatter"]["categories"] == null) {
            continue;
          }
          postCategories = [];
          subCategories = categories;
          ref1 = post["frontMatter"]["categories"];
          for (j = 0, len1 = ref1.length; j < len1; j++) {
            cateName = ref1[j];
            found = false;
            for (l = 0, len2 = subCategories.length; l < len2; l++) {
              category = subCategories[l];
              if (category["name"] === cateName) {
                found = true;
                postCategories.push(category);
                category["posts"].push(post);
                subCategories = category["subs"];
                break;
              }
            }
            if (!found) {
              newCate = new Category(cateName, [post], []);
              ++categoriesLength;
              postCategories.push(newCate);
              subCategories.push(newCate);
              subCategories = newCate["subs"];
            }
          }
          post["categories"] = postCategories;
        }
        categories.sort(function(a, b) {
          return a["name"].localeCompare(b["name"]);
        });
        if (site["siteConfig"]["perPage"] instanceof Object) {
          perPage = site["siteConfig"]["perPage"]["category"];
        } else {
          perPage = site["siteConfig"]["perPage"];
        }
        for (m = 0, len3 = categories.length; m < len3; m++) {
          sub = categories[m];
          sortCategories(sub);
          ref2 = paginateCategories(sub, site["siteConfig"]["categoryDir"], perPage, site);
          for (n = 0, len4 = ref2.length; n < len4; n++) {
            p = ref2[n];
            site.put("pages", p);
          }
        }
        site["categories"] = categories;
        site["categoriesLength"] = categoriesLength;
        return site;
      });
      return this.generator.register("beforeProcessing", function(site) {
        var found, i, j, l, len, len1, len2, len3, len4, m, n, newTag, p, perPage, post, postTags, ref, ref1, ref2, sp, tag, tagName, tags, tagsLength;
        // Generate tags.
        tags = [];
        tagsLength = 0;
        ref = site["posts"];
        for (i = 0, len = ref.length; i < len; i++) {
          post = ref[i];
          if (post["frontMatter"]["tags"] == null) {
            continue;
          }
          postTags = [];
          ref1 = post["frontMatter"]["tags"];
          for (j = 0, len1 = ref1.length; j < len1; j++) {
            tagName = ref1[j];
            found = false;
            for (l = 0, len2 = tags.length; l < len2; l++) {
              tag = tags[l];
              if (tag["name"] === tagName) {
                found = true;
                postTags.push(tag);
                tag["posts"].push(post);
                break;
              }
            }
            if (!found) {
              newTag = new Tag(tagName, [post]);
              ++tagsLength;
              postTags.push(newTag);
              tags.push(newTag);
            }
          }
          post["tags"] = postTags;
        }
        tags.sort(function(a, b) {
          return a["name"].localeCompare(b["name"]);
        });
        if (site["siteConfig"]["perPage"] instanceof Object) {
          perPage = site["siteConfig"]["perPage"]["tag"];
        } else {
          perPage = site["siteConfig"]["perPage"];
        }
        for (m = 0, len3 = tags.length; m < len3; m++) {
          tag = tags[m];
          tag["posts"].sort(function(a, b) {
            return -(a["date"] - b["date"]);
          });
          sp = Object.assign(new File(site["siteConfig"]["docDir"]), {
            "layout": "tag",
            "docPath": path.join(site["siteConfig"]["tagDir"], `${tag["name"]}`, "index.html"),
            "title": "tag",
            "name": tag["name"].toString(),
            "comment": false,
            "reward": false
          });
          tag["docPath"] = sp["docPath"];
          ref2 = paginate(sp, tag["posts"], perPage);
          for (n = 0, len4 = ref2.length; n < len4; n++) {
            p = ref2[n];
            site.put("pages", p);
          }
        }
        site["tags"] = tags;
        site["tagsLength"] = tagsLength;
        return site;
      });
    }

  };

  module.exports = Hikaru;

}).call(this);
