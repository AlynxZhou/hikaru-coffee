fse = require("fs-extra")
path = require("path")
{URL} = require("url")
glob = require("glob")
cheerio = require("cheerio")
moment = require("moment")
colors = require("colors/safe")
Promise = require("bluebird")

yaml = require("js-yaml")
nunjucks = require("nunjucks")
marked = require("marked")
stylus = require("stylus")
nib = require("nib")
coffee = require("coffeescript")

highlight = require("./highlight")
Logger = require("./logger")
Renderer = require("./renderer")
Processer = require("./processer")
Generator = require("./generator")
Translator = require("./translator")
Router = require("./router")
{
  escapeHTML,
  removeControlChars,
  paginate,
  sortCategories,
  paginateCategories,
  getAbsPathFn,
  getUrlFn
} = require("./utils")

module.exports =
class Hikaru
  constructor: (debug = false) ->
    @debug = debug
    @logger = new Logger(@debug)
    @logger.debug("Hikaru is starting...")
    process.on("exit", () =>
      @logger.debug("Hikaru is stopping...")
    )

  init: (workDir = ".", configPath) =>
    return fse.mkdirp(workDir).then(() =>
      @logger.debug("Hikaru is copying `#{colors.cyan(
        configPath or path.join(workDir, "config.yml")
      )}`.")
      @logger.debug("Hikaru is creating `#{colors.cyan(
        path.join(workDir, "src", path.sep)
      )}`.")
      @logger.debug("Hikaru is creating `#{colors.cyan(path.join(
        workDir, "doc", path.sep
      ))}`.")
      @logger.debug("Hikaru is creating `#{colors.cyan(path.join(
        workDir, "themes", path.sep
      ))}`.")
      fse.copy(
        path.join(__dirname, "..", "dist", "config.yml"),
        configPath or path.join(workDir, "config.yml")
      )
      fse.mkdirp(path.join(workDir, "src")).then(() =>
        @logger.debug("Hikaru is copying `#{colors.cyan(path.join(
          workDir, "src", "archives", "index.md"
        ))}`.")
        @logger.debug("Hikaru is copying `#{colors.cyan(path.join(
          workDir, "src", "categories", "index.md"
        ))}`.")
        @logger.debug("Hikaru is copying `#{colors.cyan(path.join(
          workDir, "src", "tags", "index.md"
        ))}`.")
        fse.copy(
          path.join(__dirname, "..", "dist", "archives.md"),
          path.join(workDir, "src", "archives", "index.md")
        )
        fse.copy(
          path.join(__dirname, "..", "dist", "categories.md"),
          path.join(workDir, "src", "categories", "index.md")
        )
        fse.copy(
          path.join(__dirname, "..", "dist", "tags.md"),
          path.join(workDir, "src", "tags", "index.md")
        )
      )
      fse.mkdirp(path.join(workDir, "doc"))
      fse.mkdirp(path.join(workDir, "themes"))
    ).catch((err) =>
      @logger.warn("Hikaru catched some error during initializing!")
      @logger.error(err)
    )

  clean: (workDir = ".", configPath) =>
    configPath = configPath or path.join(workDir, "config.yml")
    siteConfig = yaml.safeLoad(fse.readFileSync(configPath, "utf8"))
    if not siteConfig?["docDir"]?
      return
    glob("*", {
      "cwd": path.join(workDir, siteConfig["docDir"])
    }, (err, res) =>
      if err
        return err
      return res.map((r) =>
        fse.stat(path.join(workDir, siteConfig["docDir"], r)).then((stats) =>
          if stats.isDirectory()
            @logger.debug("Hikaru is removing `#{colors.cyan(path.join(
              workDir, siteConfig["docDir"], r, path.sep
            ))}`.")
          else
            @logger.debug("Hikaru is removing `#{colors.cyan(path.join(
              workDir, siteConfig["docDir"], r
            ))}`.")
          return fse.remove(path.join(workDir, siteConfig["docDir"], r))
        ).catch((err) =>
          @logger.warn("Hikaru catched some error during cleaning!")
          @logger.error(err)
        )
      )
    )

  generate: (workDir = ".", configPath) =>
    @site = {
      "workDir": workDir,
      "siteConfig": {},
      "themeConfig": {},
      "templates": {},
      "assets": [],
      "pages": [],
      "posts": [],
      "data": [],
      "categories": [],
      # Flattend categories length.
      "categoriesLength": 0,
      "tags": [],
      # Flattend tags length.
      "tagsLength": 0
    }
    configPath = configPath or path.join(@site["workDir"], "config.yml")
    try
      @site["siteConfig"] = yaml.safeLoad(fse.readFileSync(configPath, "utf8"))
    catch err
      @logger.warn("Hikaru cannot find site config!")
      @logger.error(err)
      process.exit(-1)
    @site["srcDir"] = path.join(
      @site["workDir"], @site["siteConfig"]["srcDir"] or "srcs"
    )
    @site["docDir"] = path.join(
      @site["workDir"], @site["siteConfig"]["docDir"] or "docs"
    )
    @site["themeDir"] = path.join(
      @site["workDir"], "themes", @site["siteConfig"]["themeDir"]
    )
    @site["themeSrcDir"] = path.join(@site["themeDir"], "srcs")
    try
      @site["themeConfig"] = yaml.safeLoad(
        fse.readFileSync(path.join(@site["themeDir"], "config.yml"))
      )
    catch err
      if err["code"] is "ENOENT"
        @logger.warn("Hikaru continues with a empty theme config...")
    @site["categoryDir"] = @site["siteConfig"]["categoryDir"] or "categories"
    @site["tagDir"] = @site["siteConfig"]["tagDir"] or "tags"
    @renderer = new Renderer(@logger, @site["siteConfig"]["skipRender"])
    @processer = new Processer(@logger)
    @generator = new Generator(@logger)
    @translator = new Translator(@logger)
    try
      defaultLanguage = yaml.safeLoad(
        fse.readFileSync(
          path.join(@site["themeDir"], "languages", "default.yml")
        )
      )
      @translator.register("default", defaultLanguage)
    catch err
      if err["code"] is "ENOENT"
        @logger.warn("Hikaru cannot find default language file in your theme.")
    @router = new Router(
      @logger, @renderer, @processer, @generator, @translator, @site
    )
    try
      @registerInternalRenderers()
      @registerInternalProcessers()
      @registerInternalGenerators()
    catch err
      @logger.warn("Hikaru cannot register internal functions!")
      @logger.error(err)
      process.exit(-2)
    @router.route()

  registerInternalRenderers: () =>
    njkConfig = Object.assign(
      {"autoescape": false}, @site["siteConfig"]["nunjucks"]
    )
    njkEnv = nunjucks.configure(@site["themeSrcDir"], njkConfig)
    @renderer.register([".njk", ".j2"], null, (data, ctx) ->
      return new Promise((resolve, reject) ->
        try
          template = nunjucks.compile(data["text"], njkEnv, data["srcPath"])
          # For template you must give a render function.
          data["content"] = (ctx) ->
            return new Promise((resolve, reject) ->
              template.render(ctx, (err, res) ->
                if err
                  return reject(err)
                return resolve(res)
              )
            )
          return resolve(data)
        catch err
          return reject(err)
      )
    )

    markedConfig = Object.assign(
      {"gfm": true},
      @site["siteConfig"]["marked"]
    )
    headerIds = {}
    renderer = new marked.Renderer()
    renderer.heading = (text, level) ->
      escaped = escapeHTML(text)
      if headerIds[escaped]
        id = "#{escaped}-#{headerIds[escaped]++}"
      else
        id = escaped
        headerIds[escaped] = 1
      return "<h#{level} id=\"#{id}\">" +
      "<a class=\"headerlink\" href=\"##{id}\" title=\"#{escaped}\">" +
      "</a>" +
      "#{text}" +
      "</h#{level}>"
    marked.setOptions({
      "langPrefix": "",
      "highlight": (code, lang) ->
        return highlight(code, {
          "lang": lang?.toLowerCase(),
          "hljs":  markedConfig["hljs"] or true,
          "gutter": markedConfig["gutter"] or true
        })
    })
    @renderer.register(".md", ".html", (data, ctx) ->
      return new Promise((resolve, reject) ->
        try
          data["content"] = marked(
            data["text"],
            Object.assign({"renderer": renderer}, markedConfig)
          )
          headerIds = {}
          return resolve(data)
        catch err
          return reject(err)
      )
    )

    stylConfig = @site["siteConfig"]["stylus"] or {}
    @renderer.register(".styl", ".css", (data, ctx) =>
      return new Promise((resolve, reject) =>
        stylus(data["text"])
        .use(nib())
        .use((style) =>
          style.define("getSiteConfig", (data) =>
            keys = data["val"].toString().split(".")
            res = @site["siteConfig"]
            for k in keys
              if k not of res
                return null
              res = res[k]
            return res
          )
        ).use((style) =>
          style.define("getThemeConfig", (data) =>
            keys = data["val"].toString().split(".")
            res = @site["themeConfig"]
            for k in keys
              if k not of res
                return null
              res = res[k]
            return res
          )
        ).set("filename", path.join(@site["themeSrcDir"], data["srcPath"]))
        .set("sourcemap", stylConfig["sourcemap"])
        .set("compress", stylConfig["compress"])
        .set("include css", true)
        .render((err, res) ->
          if err
            return reject(err)
          data["content"] = res
          return resolve(data)
        )
      )
    )

    coffeeConfig = @site["siteConfig"]["coffee"] or {}
    @renderer.register(".coffee", ".js", (data, ctx) ->
      return new Promise((resolve, reject) ->
        try
          data["content"] = coffee.compile(data["text"], coffeeConfig)
          return resolve(data)
        catch err
          return reject(err)
      )
    )

  registerInternalProcessers: () =>
    @processer.register("index", (p, posts, ctx) =>
      return new Promise((resolve, reject) =>
        try
          posts.sort((a, b) ->
            return -(a["date"] - b["date"])
          )
          return resolve(paginate(
            p, posts, @site["siteConfig"]["perPage"], ctx
          ))
        catch err
          return reject(err)
      )
    )

    @processer.register("archives", (p, posts, ctx) =>
      return new Promise((resolve, reject) =>
        try
          posts.sort((a, b) ->
            return -(a["date"] - b["date"])
          )
          return resolve(paginate(
            p, posts, @site["siteConfig"]["perPage"], ctx
          ))
        catch err
          return reject(err)
      )
    )

    @processer.register("categories", (p, posts, ctx) ->
      return new Promise((resolve, reject) ->
        try
          return resolve(Object.assign({}, p, ctx, {
            "categories": ctx["site"]["categories"]
          }))
        catch err
          return reject(err)
      )
    )

    @processer.register("tags", (p, posts, ctx) ->
      return new Promise((resolve, reject) ->
        try
          return resolve(Object.assign({}, p, ctx, {
            "tags": ctx["site"]["tags"]
          }))
        catch err
          return reject(err)
      )
    )

    @processer.register(["post", "page"], (p, posts, ctx) =>
      return new Promise((resolve, reject) =>
        try
          $ = cheerio.load(p["content"])
          # TOC generate.
          hNames = ["h1", "h2", "h3", "h4", "h5", "h6"]
          headings = $(hNames.join(", "))
          toc = []
          for h in headings
            level = toc
            while level.length > 0 and
            hNames.indexOf(level[level.length - 1]["name"]) <
            hNames.indexOf(h["name"])
              level = level[level.length - 1]["subs"]
            level.push({
              "id": $(h).attr("id"),
              "name": h["name"]
              "text": $(h).text().trim(),
              "subs": []
            })
          # Replace relative path to absolute path.
          getUrl = getUrlFn(
            @site["siteConfig"]["baseUrl"], @site["siteConfig"]["rootDir"]
          )
          links = $("a")
          for a in links
            href = $(a).attr("href")
            if new URL(
              href, @site["siteConfig"]["baseUrl"]
            ).host isnt getUrl().host
              $(a).attr("target", "_blank")
            if href.startsWith("https://") or href.startsWith("http://") or
            href.startsWith("//") or href.startsWith("/") or
            href.startsWith("#")
              continue
            $(a).attr("href", path.posix.join(path.posix.sep,
            path.posix.dirname(p["docPath"]), href))
          imgs = $("img")
          for i in imgs
            src = $(i).attr("src")
            if src.startsWith("https://") or src.startsWith("http://") or
            src.startsWith("//") or src.startsWith("/") or
            src.startsWith("data:image")
              continue
            $(i).attr("src", path.posix.join(path.posix.sep,
            path.posix.dirname(p["docPath"]), src))
          p["content"] = $("body").html()
          if p["content"].indexOf("<!--more-->") isnt -1
            split = p["content"].split("<!--more-->")
            p["excerpt"] = split[0]
            p["more"] = split[1]
          return resolve(Object.assign({}, p, ctx, {"toc": toc, "$": $}))
        catch err
          return reject(err)
      )
    )

  registerInternalGenerators: () =>
    @generator.register("beforeProcessing", (site) ->
      # Generate categories
      return new Promise((resolve, reject) ->
        try
          categories = []
          categoriesLength = 0
          for post in site["posts"]
            if not post["categories"]?
              continue
            postCategories = []
            subCategories = categories
            for cateName in post["categories"]
              found = false
              for category in subCategories
                if category["name"] is cateName
                  found = true
                  postCategories.push(category)
                  category["posts"].push(post)
                  subCategories = category["subs"]
                  break
              if not found
                newCate = {"name": cateName, "posts": [post], "subs": []}
                ++categoriesLength
                postCategories.push(newCate)
                subCategories.push(newCate)
                subCategories = newCate["subs"]
            post["categories"] = postCategories
          categories.sort((a, b) ->
            return a["name"].localeCompare(b["name"])
          )
          for sub in categories
            sortCategories(sub)
            site["pages"] = site["pages"].concat(paginateCategories(
              sub,
              site["categoryDir"],
              site["siteConfig"]["perPage"]
            ))
          site["categories"] = categories
          site["categoriesLength"] = categoriesLength
          return resolve(site)
        catch err
          return reject(err)
      )
    )

    @generator.register("beforeProcessing", (site) ->
      # Generate tags.
      return new Promise((resolve, reject) ->
        try
          tags = []
          tagsLength = 0
          for post in site["posts"]
            if not post["tags"]?
              continue
            postTags = []
            for tagName in post["tags"]
              found = false
              for tag in tags
                if tag["name"] is tagName
                  found = true
                  postTags.push(tag)
                  tag["posts"].push(post)
                  break
              if not found
                newTag = {"name": tagName, "posts": [post]}
                ++tagsLength
                postTags.push(newTag)
                tags.push(newTag)
            post["tags"] = postTags
          tags.sort((a, b) ->
            return a["name"].localeCompare(b["name"])
          )
          for tag in tags
            tag["posts"].sort((a, b) ->
              return -(a["date"] - b["date"])
            )
            sp = {
              "layout": "tag",
              "docPath": path.join(
                site["tagDir"], "#{tag["name"]}", "index.html"
              ),
              "title": "tag",
              "name": tag["name"].toString()
            }
            tag["docPath"] = sp["docPath"]
            site["pages"] = site["pages"].concat(paginate(
              sp, tag["posts"], site["siteConfig"]["perPage"]
            ))
          site["tags"] = tags
          site["tagsLength"] = tagsLength
          return resolve(site)
        catch err
          return reject(err)
      )
    )

    @generator.register("afterProcessing", (site) ->
      return new Promise((resolve, reject) ->
        try
          if not site["siteConfig"]["search"]["enable"]
            return resolve(site)
          # Generate search index.
          search = []
          all = site["pages"].concat(site["posts"])
          getAbsPath = getAbsPathFn(site["siteConfig"]["rootDir"])
          for p in all
            search.push({
              "title": "#{p["title"]}",
              "url": getAbsPath(p["docPath"]),
              "content": p["text"]
            })
          site["data"].push({
            "docPath": site["siteConfig"]["search"]["path"] or "search.json",
            "content": JSON.stringify(search)
          })
          return resolve(site)
        catch err
          return reject(err)
      )
    )

    @generator.register("afterProcessing", (site) ->
      return new Promise((resolve, reject) ->
        try
          if not site["siteConfig"]["sitemap"]["enable"]
            return resolve(site)
          # Generate sitemap.
          tmpContent = fse.readFileSync(path.join(
            __dirname, "..", "dist", "sitemap.njk"
          ), "utf8")
          content = nunjucks.renderString(tmpContent, {
            "posts": site["posts"],
            "moment": moment,
            "getUrl": getUrlFn(site["siteConfig"]["baseUrl"],
            site["siteConfig"]["rootDir"]),
            "getAbsPath": getAbsPathFn(site["siteConfig"]["rootDir"])
          })
          site["data"].push({
            "docPath": site["siteConfig"]["sitemap"]["path"] or "sitemap.xml",
            "content": content
          })
          return resolve(site)
        catch err
          return reject(err)
      )
    )

    @generator.register("afterProcessing", (site) ->
      return new Promise((resolve, reject) ->
        try
          if not site["siteConfig"]["feed"]["enable"]
            return resolve(site)
          # Generate RSS feed.
          tmpContent = fse.readFileSync(path.join(
            __dirname, "..", "dist", "atom.njk"
          ), "utf8")
          content = nunjucks.renderString(tmpContent, {
            "siteConfig": site["siteConfig"],
            "themeConfig": site["themeConfig"],
            "posts": site["posts"],
            "moment": moment,
            "removeControlChars": removeControlChars,
            "getUrl": getUrlFn(site["siteConfig"]["baseUrl"],
            site["siteConfig"]["rootDir"]),
            "getAbsPath": getAbsPathFn(site["siteConfig"]["rootDir"])
          })
          site["data"].push({
            "docPath": site["siteConfig"]["feed"]["path"] or "atom.xml",
            "content": content
          })
          return resolve(site)
        catch err
          return reject(err)
      )
    )
