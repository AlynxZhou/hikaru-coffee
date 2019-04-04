Types
=====

# TOC

- For Users
    - [Install](../user/install.md)
    - [Init](../user/init.md)
    - [Config](../user/config.md)
    - [Write](../user/write.md)
    - [Command](../user/command.md)
    - [Deploy](../user/deploy.md)
    - [Plugins and Scripts](../user/plugins-and-scripts.md)
- For Developers
    - [Lifecycle](../dev/lifecycle.md)
    - [Hikaru](../dev/hikaru.md)
    - [Types](../dev/types.md)
    - [Utils](../dev/utils.md)
    - [Extend](../dev/extend.md)
    - [Theme](../dev/theme.md)
This page contains types that Hikaru uses. Most of them are just class for plain object.

# `File`

`File` contains all properties that a file will have. Not all properties are available on all files.

## `docDir`

Where to output the file, it should be the site's `docDir`.

## `docPath`

Output file's path relative to `docDir`, which was determined by `Renderer`.

## `srcDir`

Where the file was read, it should be the site's `srcDir` or `themeSrcDir`.

## `srcPath`

Input file's path relative to `srcDir`.

## `createdTime`

File's created time from its front matter. Only available for posts and pages.

## `updatedTime`

File's updated time from its front matter or file system. Only available for posts and pages.

## `zone`

File's timezone from its front matter. Only available for posts and pages.

## `title`

File's title from its front matter. Only available for posts and pages.

## `layout`

File's layout from its front matter. Only available for posts and pages.

## `comment`

Option of whether a page can be commented from its front matter. Only available for posts and pages.

## `categories`

Post's categories from its front matter, it will be generated into `Category` array before processing. Only available for posts.

## `tags`

Post's tags from its front matter, it will be generated into `Tags` array before processing. Only available for posts.

## `raw`

File's raw content.

## `text`

File's text content.

- For pages and posts, it is **the content after YAML front matter**.
- For text assets and templates, it is just raw content.
- For binary assets it has no meaning.

## `content`

- For posts, pages and text assets, it's the **rendered text**.
- For templates, it should be **a compiled render function**.

## `type`

Whether file is a `asset`, `post`, `page`, `template` or `file`.

## `frontMatter`

The original parsed YAML front matter object. Only available for posts and pages.

## `excerpt`

Typically content before `<!--more-->` tag in post.

## `more`

Typically content after `<!--more-->` tag in post.

## `$`

Cheerio context for page content.

## `toc`

Toc for page content.

## `posts`

Attached posts for page.

## `pageArray`

The series of pages generated by `paginate` util function from a single page. Only available for pages.

## `pageIndex`

The index in the series of pages generated by `paginate` util function from a single page. **Begin from 0**. Only available for pages.

## `next`

Next post reference in date sequence. Only available for posts.

## `prev`

Previous post reference in date sequence. Only available for posts.

# `Category`

`Category` is a recursive data structure typecially because a category may have sub categories.

## `name`

Category's name to display.

## `posts`

All posts belong to this category.

## `subs`

An array of `Category`, which contains sub categories.

# `Tag`

`Tag` looks like `Category`, however it's not recursive.

## `name`

Tag's name to display.

## `posts`

All posts belong to this Tag.

# `Toc`

`Toc` is a recursive data structure typecially because a header may have sub haeders.

## `text`

Header's text to display.

## `name`

Header's tag name.

## `archor`

HTML archor for this header.

## `subs`

An array of `Toc`, which contains sub header.

# `Site`

Site's properties and methods.

## `workDir`

In which directory Hikaru works.

## `siteConfig`

From site's `config.yml` file but `srcDir`, `docDir`, `themeDir`, `themeSrcDir` are converted to full path relative to `workDir` for easier to use.

## `themeConfig`

From theme's `config.yml` file.

## `templates`

An object of theme's all templates, keys are layouts and values are `File`s.

## `assets`

Array of asset `File`s.

## `pages`

Array of page `File`s.

## `posts`

Array of post `File`s.

## `files`

Array of other site file `File`s.

## `categories`

Array of `Category`s, which contains all categories of site's posts. It is recursive, the top array only contains top-level categories and other's are in their `subs` array.

## `categoriesLength`

Because `Category` is recursive, `Site::categories.length` is only the number of top-level categories, this is **the number of all categories of site's posts**.

## `tags`

Array of `Tag`s, which contains all tags of site's posts.

## `tagsLength`

This is **the number of all tags of site's posts**, though `Tag` is not recursive.

## `put(key, file)`

A method to put file into the `Site[key]` array, this will compare `docPath` of argument and array elements, if there are same one, it will replace it instead of append to the array.

## `del(key, file)`

A method to delete file in the `Site[key]` array, this will compare `docPath` of argument and array elements, if there are same one, it will delete it from the array and return it.

## `raw()`

In fact all `Site`'s properties are inside a inner object `Site::_` and their getter and setter are wrapped, but sometime we need to pass the raw `Site::_` to templates, `Site::raw()` will return `Site::_`.

Prev Page: [Hikaru](hikaru.md)

Next Page: [Utils](utils.md)