Hikaru
======

A static site generator that generates routes based on directories naturally.
-----------------------------------------------------------------------------

# NOT FINISHED YET, JUST IMPLEMENTED VERY SIMPLE FUNCTIONS.

# Refactor

Router:

    - Load each post then compile template and cache and render then call generator then save.
    - Load each asset then render then save.
    - Load each page then compile template and cache and render then call generator then save.
    - Make custom site variables before pages and posts are generated.

Renderer: Register srcExt, docExt and fn, render data and return a promise of data.

Generator: Receive page(data), posts and ctx then return a promise of data.

# List

- [X] Dir based router.
- [X] Marked Markdown renderer.
- [X] Stylus CSS renderer.
- [X] Nunjucks template renderer.
- [X] Highlight.js code highlight.
- [X] Async loading, rendering and saving file.
- [X] Pagination for index, archives, categories (different category pages) and tags (different tag pages).
- [X] Archives info for templating.
- [X] Categories info for templating.
- [X] Tags info for templating.
- [X] Cheerio-based toc generating.
- [X] Cheerio-based path converting (relative to absolute).
- [X] Date operations in templates.
- [X] sprintf-js based multi-languages support.
- [X] Local search JSON gengrating.
- [ ] RSS feed generating.
- [X] Porting theme ARIA.
- [ ] File watch and live reload server.

# Dir Structure

```plain
hikura-site/
    |- src/ # source dir for user files
    |   |- images/
    |   |- css/
    |   |- js/
    |   |- index.md
    |   |- about/
    |   |   |- index.md
    |   |- tags/
    |   |   |- index.md
    |- doc/ # source will be render to here
    |   |- images/
    |   |   |- logo.png
    |   |- css/
    |   |   |- index.css
    |   |- js/
    |   |   |- index.js
    |   |- index.html
    |   |- 2.html # page 2 of index
    |   |- 3.html # page 3 of index
    |   |- about/
    |   |   |- index.html
    |   |- tags/
    |   |   |- index.html # layout: tags
    |   |   |- tag-1/
    |   |   |   |- index.html # automatically generated, layout: tag
    |   |   |   |- 2.html # page 2 of tag-1
    |- themes/
    |   |- aria/
    |   |   |- src/ # this will be render to doc/
    |   |   |   |- layout.njk # templates
    |   |   |   |- index.njk
    |   |   |   |- tags.njk
    |   |   |   |- tag.njk
    |   |   |   |- page.njk # if no layout specific, fallback to this
    |   |   |   |- css/
    |   |   |   |   |- index.styl
    |   |   |   |- js/
    |   |   |   |   |- index.js
    |   |   |   |- images/
    |   |   |   |   |- logo.png
    |   |- README.md
```
