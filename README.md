hikaru
======

A static site generator that generates routes based on directories naturally.
-----------------------------------------------------------------------------

- "This world won't need one more static site generator!"

- "But I need."

# Install

```
# npm i -g hikaru-coffee
```

# TODO List

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
- [X] RSS feed generating.
- [X] Porting theme ARIA.
- [X] Live reloading server.

# Example Dir Structure

```plain
hikura-site/
    |- srcs/ # source dir for user files
    |   |- images/
    |   |- css/
    |   |- js/
    |   |- index.md
    |   |- about/
    |   |   |- index.md
    |   |- tags/
    |   |   |- index.md
    |- docs/ # source will be render to here
    |   |- images/
    |   |   |- logo.png
    |   |- css/
    |   |   |- index.css
    |   |- js/
    |   |   |- index.js
    |   |- index.html
    |   |- index-2.html # page 2 of index
    |   |- index-3.html # page 3 of index
    |   |- about/
    |   |   |- index.html
    |   |- tags/
    |   |   |- index.html # layout: tags
    |   |   |- tag-1/
    |   |   |   |- index.html # automatically generated, layout: tag
    |   |   |   |- index-2.html # page 2 of tag-1
    |- themes/
    |   |- aria/
    |   |   |- srcs/ # this will be render to docs/
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
