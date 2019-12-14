# clayoven ![logo](clayoven.png)

[![Code Climate](https://codeclimate.com/github/artagnon/clayoven.png)](https://codeclimate.com/github/artagnon/clayoven)

clayoven is an minimalist website generator with a carefully curated set of features. It has been built at a glacial pace, over a period of [seven years](https://github.com/artagnon/clayoven/commit/d4d40161e9f76dbe74078c669de9af698cf621d6), as [my website](https://artagnon.com) content expanded. The source files are written in "claytext", a custom minimalist format for elegance and speed.

## The claytext processor, briefly

Here's an excerpt of claytext, illustrating the main features.

```
claytext demo

(Posts here have been ressurrected from several years ago)

<<
rM-reading.jpg
rM-writing.jpg
>>

I have written a lot of [code](https://github.com/artagnon) in the past.

# Functors

For a fixed field $K$, consider the functors

$$
\begin{xy}
\xymatrix{
\textbf{Set}\ar@<.5ex>[r]^V & \textbf{Vct}_K\ar@<.5ex>[l]^U
}
\end{xy}
$$

--

[[
void assignHeads(std::vector<Statement*> branchHeads,
                 std::vector<Statement*> headsToStaggerWith,
                 Statement* nestWithin, Statement* toEnclose);
]]

(ii) Every element of $A$ is either unit or nilpotent.
(iii) $A/\mathfrak{N}$ is a field.

1. The Merge dominates the Split, in which case, the Merge dominates everything lying on the outEdges of the Split leading to the Merge
2. The Split dominates the Merge, in which case, the Split dominates everything on its outEdges leading to the Merge.

[^1]: Hat tip to [Sanjoy](http://playingwithpointers.com) for pointing out the fifth case.
[^2]: You might want to merge loops that share a header in a post-pass.
```

## The site-generation engine, briefly

All site content is split up into "topics", to put in the sidebar, each of which can either serve as an index to a collection of ContentPages (as a bunch of `.clay` files in a subdirectory with the name "#{topic}/"), or a single IndexPage (named `#{topic}.index.clay`). `index.clay` is special-cased to serve as the root of the site.

So, if you have these files:

    index.clay
    design/template.slim
    blog.index.clay
    blog/first.clay
    blog/second.clay
    colophon.index.clay

clayoven automatically builds a sidebar with `index`, `blog` and `colophon`; the IndexPages. In the page `/blog`, there will be links to the posts `/blog/first` and `/blog/second`, the ContentPages, with the headings appearing in the index pages. If there are ContentPages for a topic, the IndexPage simply serves to give a small introduction, with links to articles appearing thereafter.

The site-generation engine works closely with git; it incrementally builds only pages that changed, according to git. It also pulls out the created-timestamp (`authdate`) and last-modified-timestamp (`pubdate`) from the git information, respecting moves. As long as there is a significant correlation between old content and new content, authdate is calculated on the old content; content matters, not files.

## Usage

Install the `slim` and `sitemap_generator` gems. For the initial setup, you need to have two files in your website's repository: an `index.clay` and a `design/template.slim`; [here's](https://github.com/artagnon/artagnon.com/blob/master/design/template.slim) the one that artagnon.com uses. Running clayoven would produce `index.html`.

- Run `clayoven` on your website's repository to generate HTML files incrementally based on the current git index.
- Run `clayoven aggressive` to regenerate the entire site along with a `sitemap.xml`. You can run this occassionally, when you create new pages.
- Run `clayoven httpd` to preview your website locally.

## Configuration

`.clayoven/hidden` is a gitignore-like file that uses regular expressions to match IndexFiles that should be built, but not displayed in the sidebar. You could use it for your 404 page.

## Workflow and vscode integration

Getting some syntax highlighting in `.clay` files in vscode is pretty simple: you simply have to tell it to associate the extension with the `latex` mode. A build-on-save is also pretty easy to set up: write a custom build task, and use the

## Appendix: Details of the claytext processor

The claytext processor is, at its core, a paragraph-processor; all content must be split up into paragraphs, decorated with optional first-and-last-line-markers. The markers '<< ... >>', '$$ ... $$', and '[[ ... ]]' should be clear from the example; the marker tokens must be in lines of their own. The first paragraph is optionally a header, and uses the markers '( ... )' to disambiguate. The last paragraph is an optional footer, prefixed with "[^\d+]: " lines to disambiguate. The '#' prefix for a paragraph is for subheadings, and only one level of subheading is allowed. In paragraph with lists, each line must begin with the numeral or roman numeral, as shown. The format is strict, and doesn't like files with paragraphs wrapped using hard line breaks, for instance.

`PARAGRAPH_LINE_FILTERS` matches paragraphs where all lines begin with some regex, and `PARAGRAPH_START_END_FILTERS` match paragraphs that start and end with the specified tokens. For things that involve using a regex to match text in the middle of a paragraph link the markdown-style link in the example, [javascript](https://github.com/artagnon/artagnon.com/blob/master/design/claytext.js) is the hassle-free way of getting it done.

## Appendix: Details of the site-generation engine

Content pages are sorted based on the committer-timestamp of the commit that first introduced the file, reverse-chronologically. Index pages are sorted alphabetically, but for `index`.

## Tips

- Check in the generated html to the site's repository, so that eyeballing `git diff` can serve as a testing mechanism.
- If you accidentally commit `.clay` files before running clayoven, running it afterward will do nothing, since it will see a clean git index; you'll need to run the aggressive version. This kind of situation doesn't occur in the first place, if you follow the [Workflow guidelines](/README.md#workflow-and-vscode-integration) outlined above.
- Importing historical content is easy; a `git commit --date="#{historical_date}"` would give the post an appropriate authdate that will be respected in the sorting-order.

## Appendix: Some planned features

- A vscode extension that does better syntax highlighting.
- A linguist definition, if there are enough users.
