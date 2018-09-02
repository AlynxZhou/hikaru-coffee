fse = require("fs-extra")
path = require("path")

yaml = require("js-yaml")
nunjucks = require("nunjucks")
marked = require("marked")
stylus = require("stylus")
nib = require("nib")
coffee = require("coffeescript")

highlight = require("./highlight")
Logger = require("./logger")
Renderer = require("./renderer")
Generator = require("./generator")
Router = require("./router")

module.exports =
class Hikaru
  constructor: (debug = false) ->
    @debug = debug
    @logger = new Logger(@debug)
    @logger.info("Hikaru is starting...")
    process.on("exit", () =>
      @logger.info("Hikaru is stopping...")
    )

  init: (workDir = ".", configPath, srcDir, docDir, themeDir) =>
    @logger.info("Hikaru started initialization in `#{workDir}`.")
    return fse.mkdirp(workDir).then(() =>
      @logger.info("Hikaru created `#{workDir}/`.")
      return fse.mkdirp(srcDir or path.join(workDir, "src"))
    ).then(() =>
      @logger.info("Hikaru created `#{srcDir or path.join(workDir, "src")}/`.")
      return fse.copy(path.join(__dirname, "..", "dist", "config.yml"),
      configPath or path.join(workDir, "config.yml"))
    ).then(() =>
      @logger.info("Hikaru copyed `#{configPath or
      path.join(workDir, "config.yml")}`.")
      return fse.mkdirp(docDir or path.join(workDir, "doc"))
    ).then(() =>
      @logger.info("Hikaru created `#{docDir or path.join(workDir, "doc")}/`.")
      return fse.mkdirp(themeDir or path.join(workDir, "themes"))
    ).then(() =>
      @logger.info("Hikaru created `#{themeDir or
      path.join(workDir, "themes")}/`.")
      @logger.info("Hikaru finished initialization in `#{workDir}`.")
    ).catch(@logger.error)

  clean: (workDir = ".", configPath, docDir) =>
    @workDir = workDir
    configPath = configPath or path.join(@workDir, "config.yml")
    @siteConfig = yaml.safeLoad(fse.readFileSync(configPath, "utf8"))
    @docDir = docDir or path.join(@workDir, @siteConfig["docDir"]) or
    path.join(@workDir, "doc")
    fse.emptyDir(@docDir).then(() =>
      @logger.info("Hikaru cleaned `#{@docDir}/`.")
    ).catch(@logger.error)

  generate: (workDir = ".", configPath, srcDir, docDir, themeDir) =>
    @workDir = workDir
    configPath = configPath or path.join(@workDir, "config.yml")
    @siteConfig = yaml.safeLoad(fse.readFileSync(configPath, "utf8"))
    @srcDir = srcDir or path.join(@workDir, @siteConfig["srcDir"]) or
    path.join(@workDir, "src")
    @docDir = docDir or path.join(@workDir, @siteConfig["docDir"]) or
    path.join(@workDir, "doc")
    @themeDir = (if themeDir?
    then path.join(themeDir, "src")
    else path.join(@workDir, @siteConfig["themeDir"], "src") or
    path.join(@workDir, "themes", "aria", "src"))
    try
      @themeConfig = yaml.safeLoad(fse.readFileSync(path.join(@themeDir,
      "config.yml")))
    catch err
      if err["code"] is "ENOENT"
        @logger.info("Hikaru continues with a empty theme config...")
        @themeConfig = {}
    @renderer = new Renderer(@logger)
    @generator = new Generator(@logger)
    @router = new Router(@logger, @renderer, @generator,
    @srcDir, @docDir, @themeDir)
    @registerInternalRoutes()
    @registerInternalGenerators()
    @router.route()

  registerInternalRoutes: () =>
    templateDir = @themeDir
    njkConfig = Object.assign({"autoescape": false}, @siteConfig["nunjucks"])
    njkEnv = nunjucks.configure(templateDir, njkConfig)
    @router.register(".njk", (text, fullPath, ctx) ->
      # For template you must give a render function.
      template = nunjucks.compile(text, njkEnv, fullPath)
      njkRender = (ctx) ->
        return new Promise((resolve, reject) ->
          template.render(ctx, (err, res) ->
            if err
              return reject(err)
            return resolve(res)
          )
        )
      return njkRender
    )

    markedConfig = Object.assign({"gfm": true}, @siteConfig["marked"])
    renderer = new marked.Renderer()
    renderer.heading = (text, level) ->
      escaped = text.toLowerCase().replace(/[^\w]+/g, '-')
      return """
        <h#{level}>
          <a class="headerlink" href="##{escaped}" title="##{escaped}"></a>
          #{text}
        </h#{level}>
      """
    marked.setOptions({
      "langPrefix": "",
      "highlight": (code, lang) ->
        return highlight(code, {
          "lang": lang?.toLowerCase(),
          "hljs":  markedConfig["hljs"] or true,
          "gutter": markedConfig["gutter"] or true
        })
    })
    @router.register(".md", ".html", (text, fullPath, ctx) ->
      return marked(
        text, Object.assign({
          "renderer": renderer
        }, markedConfig)
      )
    )

    stylConfig = @siteConfig.stylus or {}
    @router.register(".styl", ".css", (text, fullPath, ctx) ->
      return new Promise((resolve, reject) =>
        stylus(text)
        .use(nib())
        .use((style) =>
          style.define("getSiteConfig", (data) =>
            return @siteConfig[data["val"]]
          )
        ).use((style) =>
          style.define("getThemeConfig", (data) =>
            return @themeConfig[data["val"]]
          )
        ).set("filename", fullPath)
        .set("sourcemap", stylConfig["sourcemap"])
        .set("compress", stylConfig["compress"])
        .set("include css", true)
        .render((err, res) ->
          if err
            return reject(err)
          return resolve(res)
        )
      )
    )
    # TODO: CoffeeScript render.
    @router.register(".coffee", ".js", (text, fullPath, ctx) ->)

  registerInternalGenerators: () =>
    @generator.register("index", (page, posts) =>
      posts.sort((a, b) ->
        return -(a["date"] - b["date"])
      )
      return paginate(page, posts, @siteConfig["perPage"])
    )

    @generator.register("archives", (page, posts) =>
      posts.sort((a, b) ->
        return -(a["date"] - b["date"])
      )
      return paginate(page, posts, @siteConfig["perPage"])
    )

    ###
    [
      {
        "name"：String,
        "posts": [Post],
        "subs": [
          {
            "name": String,
            "posts": [Post],
            "subs": []
          }
        ]
      }
    ]
    ###
    sortCategories = (category) ->
      category["posts"].sort((a, b) ->
        return -(a["date"] - b["date"])
      )
      category["subs"].sort((a, b) ->
        return a["name"].localeCompare(b["name"])
      )
      for sub in category["subs"]
        sortCategories(sub)
    paginateCategories = (category, page, parentPath) =>
      results = []
      p = Object.assign({}, page)
      p["layout"] = "category"
      p["docPath"] = path.join(parentPath, "#{category["name"]}", "index.html")
      p["title"] = "#{category["name"]}"
      results = results.concat(paginate(p, category["posts"],
      @siteConfig["perPage"]))
      for sub in category["subs"]
        results = results.concat(
          paginateCategories(
            sub, page, path.join(
              parentPath, "#{category["name"]}"
            )
          )
        )
      return results
    @generator.register("categories", (page, posts) ->
      categories = []
      for post in posts
        if not post["categories"]?
          continue
        subCategories = categories
        for cateName in post["categories"]
          found = false
          for category in subCategories
            if category["name"] is cateName
              found = true
              category["posts"].push(post)
              subCategories = category["subs"]
              break
          if not found
            newCate = {"name": cateName, "posts": [post], "subs": []}
            subCategories.push(newCate)
            subCategories = newCate["subs"]
      categories.sort((a, b) ->
        return a["name"].localeCompare(b["name"])
      )
      for sub in categories
        sortCategories(sub)
      results = []
      for sub in categories
        results = results.concat(paginateCategories(sub, page,
        path.dirname(page["docPath"])))
      results.push(Object.assign({"posts": categories}, page))
      return results
    )

    ###
    [
      {
        "name": String,
        "posts": [Post]
      }
    ]
    ###
    @generator.register("tags", (page, posts) =>
      tags = []
      for post in posts
        if not post["tags"]?
          continue
        for tagName in post["tags"]
          found = false
          for tag in tags
            if tag["name"] is tagName
              found = true
              tag["posts"].push(post)
              break
          if not found
            tags.push({"name": tagName, "posts": [post]})
      tags.sort((a, b) ->
        return a["name"].localeCompare(b["name"])
      )
      for tag in tags
        tag["posts"].sort((a, b) ->
          return -(a["date"] - b["date"])
        )
      results = []
      for tag in tags
        p = Object.assign({}, page)
        p["layout"] = "tag"
        p["docPath"] = path.join(path.dirname(page["docPath"]),
        "#{tag["name"]}", "index.html")
        p["title"] = "#{tag["name"]}"
        results = results.concat(paginate(p, tag["posts"],
        @siteConfig["perPage"]))
      results.push(Object.assign({"posts": tags}, page))
      return results
    )

paginate = (page, posts, perPage) ->
  if not perPage
    perPage = 10
  results = []
  perPagePosts = []
  for post in posts
    if perPagePosts.length is perPage
      results.push(Object.assign({"posts": perPagePosts}, page))
      perPagePosts = []
    perPagePosts.push(post)
  results.push(Object.assign({"posts": perPagePosts}, page))
  results[0]["pageArray"] = results
  results[0]["pageIndex"] = 1
  results[0]["docPath"] = page["docPath"]
  for i in [1...results.length]
    results[i]["pageArray"] = results
    results[i]["pageIndex"] = i + 1
    results[i]["docPath"] = path.join(path.dirname(page["docPath"]),
    "#{results[i]["pageIndex"]}.html")
  return results
