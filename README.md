Hikaru
======

A static site generator that generates routes based on directories naturally.
-----------------------------------------------------------------------------

# Deprecated

This project is deprecated! I am maintaining a JavaScript refacted Hikaru at <https://github.com/AlynxZhou/hikaru>.

[![npm](https://img.shields.io/npm/v/hikaru-coffee.svg?style=for-the-badge)](https://www.npmjs.com/package/hikaru-coffee)
[![npm](https://img.shields.io/npm/dt/hikaru-coffee.svg?style=for-the-badge)](https://www.npmjs.com/package/hikaru-coffee)
[![GitHub](https://img.shields.io/github/license/AlynxZhou/hikaru.svg?style=for-the-badge)](https://github.com/AlynxZhou/hikaru/blob/master/LICENSE)

# Install

Hikaru is a command line program (not a module) and you can install it from NPM:

```
# npm i -g hikaru-coffee
```

# Setup site

```
$ hikaru i hikaru-site
$ cd hikaru-site
$ npm install
```

# Install theme

## Clone theme

Using `hikaru-theme-aria` as example:

```
$ git clone https://github.com/AlynxZhou/hikaru-theme-aria.git themes/aria
```

Or if you want commit the whole site you can use submodule:

```
$ git submodule add https://github.com/AlynxZhou/hikaru-theme-aria.git themes/aria
```

## Edit site config

```
$ $EDITOR siteConfig.yml
```

Set `themeDir` to `aria`

```yaml
themeDir: aria
```

**Don't forget to edit your theme config as its README file.**

# Create src file

## Edit file

```
$ $EDITOR srcs/my-first-post.md
```

## Add front matter

```yaml
---
title: My First Post
date: 2018-08-08 09:27:00
layout: post
---
```

## Add content

```markdown
Some content...

<!--more-->

# This is my first post!
```

# Start live server

```
$ hikaru s
```

# Build static files

```
$ hikaru b
```

# More

Docs: [Here](docs/en/index.md)(Needs to update)

Default theme ARIA: [hikaru-theme-aria](https://github.com/AlynxZhou/hikaru-theme-aria/)

My blog built with Hikaru and ARIA: [喵's StackHarbor](https://sh.alynx.moe/)

# License

[Apache-2.0](LICENSE)

