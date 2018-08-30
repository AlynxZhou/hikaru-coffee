"use strict"

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

  clean: (workDir = ".") ->

  generate: (workDir = ".", configPath, srcDir, docDir, themeDir) =>
    @workDir = workDir
    configPath = configPath or path.join(@workDir, "config.yml")
    @config = yaml.safeLoad(fse.readFileSync(configPath, "utf8"))
    @srcDir = srcDir or path.join(@workDir, @config["srcDir"]) or
    path.join(@workDir, "src")
    @docDir = docDir or path.join(@workDir, @config["docDir"]) or
    path.join(@workDir, "doc")
    @themeDir = (if themeDir?
    then path.join(themeDir, "src")
    else path.join(@workDir, @config["themeDir"], "src") or
    path.join(@workDir, "themes", "aria", "src"))
    @renderer = new Renderer(@logger)
    @router = new Router(@logger, @renderer, @srcDir, @docDir, @themeDir)
    @registerRenderer()

  registerRenderer: () =>
    templateDir = path.join(@themeDir)
    njkConfig = Object.assign({"autoescape": false}, @config["nunjucks"])
    njkEnv = nunjucks.configure(templateDir, njkConfig)
    @renderer.register(".njk", ".njk", (data, ctx) =>
      return new Promise((resolve, reject) =>
        try
          resolve(nunjucks.compile(data["text"], njkEnv,
          path.join(@config["theme"], data["srcPath"])))
        catch err
          reject(err)
      )
    )

    markedConfig = Object.assign({"gfm": true} or @config["marked"])
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
          "lang": lang,
          "hljs":  markedConfig["hljs"] or true,
          "gutter": markedConfig["gutter"] or true
        })
    })
    @renderer.register(".md", ".html", (data, ctx) ->
      return new Promise((resolve, reject) ->
        data["html"] = marked(data["text"],
        Object.assign({"renderer": renderer}, markedConfig))
        ctx["layout"].render({
          "page": {"content": data["html"]},
          "title": data["frontMatter"]?["title"]
        }, (err, res) ->
          if err
            return reject(err)
          return resolve(res)
        )
      )
    )

    stylConfig = @config.stylus or {}
    @renderer.register(".styl", ".css", (data, ctx) ->
      return new Promise((resolve, reject) =>
        stylus(data["text"])
        .use(nib())
        .use((style) =>
          style.define("getConfig", (data) =>
            return @config[data["val"]]
          )
        ).set("filename", data["srcPath"])
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
    @renderer.register(".coffee", ".js", (data, ctx) ->)
