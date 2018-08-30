#!/usr/bin/env coffee
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

class Hikaru
  constructor: () ->
    @config = yaml.safeLoad(fse.readFileSync("config.yml", "utf8"))
    @logger = new Logger(false)
    @logger.info("Starting")
    @renderer = new Renderer(@logger)
    @router = new Router(@logger, @renderer, "src", "doc",
    path.join("themes", @config["theme"]))
    @registerRenderer()

  registerRenderer: () =>
    templateDir = path.join("themes", @config["theme"], "src")
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

  main: () =>
    @router.route()

# TODO: Arguments dealing.

new Hikaru().main()
