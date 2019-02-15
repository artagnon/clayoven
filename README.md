# clayoven

[![Code Climate](https://codeclimate.com/github/artagnon/clayoven.png)](https://codeclimate.com/github/artagnon/clayoven)

Modern website generator with a traditional design. Generates html from custom textual input, termed claytext, deriving certain elements from markdown. See [artagnon.com](https://artagnon.com) as an example.

At its core, clayoven is a paragraph-processor which intentionally avoids the complexity of a markdown-based generator like jekyll. All that claytext consists of is `PARAGRAPH_LINE_FILTERS`, which matches paragraphs where all lines begin with some regex, `PARAGRAPH_START_END_FILTERS` which matches paragraphs that start with some regex, and end with another regex. For things that involve using a regex to match text in the middle of a paragraph, [javascript](https://github.com/artagnon/artagnon.com/blob/master/design/claytext.js) is the hassle-free way of getting it done. The non-claytext part of clayoven is _cool_: when files are laid out in a certain way, and checked into git, clayoven automatically updates timestamps and sorts posts based on git-added date.

## Installation

The whole point of using clayoven is so you can hack on it: don't use gems. Just clone, and put `bin/clayoven` in `$PATH`.

## Usage

* Run `clayoven` on your website's repository to generate HTML files.
* Run `clayoven httpd` to preview your website locally.

## Pages

Every site needs a sidebar that allows the user to navigate through various sections: these are called Topics. Each topic has one Index Page (named `<topic>.index`; `<topic>` is the permalink), and several Content Pages (named `<topic>/<content>`, with the same permalink) corresponding to it. `index` is a special index page corresponding to the permalink `/`. Additionally, every repository should contain a `design/template.slim` to specify how to render content.

So, if you have these files:

    index
    blog.index
    blog/first
    blog/second
    colophon.index
    design/template.slim

clayoven automatically builds a sidebar with `index`, `blog` and `colophon`. In the page `/blog`, there will be links to the posts `/blog/first` and `/blog/second`.

Content pages are sorted based on the committer-timestamp of the commit that first introduced the file, reverse-chronologically. Index pages are sorted alphabetically, but for `index`.

## Configuration

On the first run, clayoven will create a `.clayoven/ignore` file in your repository. This is a gitignore-like file (but uses full regular expressions) specifying which files clayoven should ignore. Useful for your site's `README.md` and drafts.

## Slim template

Look at the [template](https://github.com/artagnon/artagnon.com/blob/master/design/template.slim) that artagnon.com uses.

## Hacking

Fork and customize as you please. Your testsuite is a clean `git diff`.

You may optionally contribute back changes if you think I will find it useful. Either use pull requests, or email me your patches.
