# clayoven

Modern website generator with a traditional design. Generates html
files from a git repository; files are written in claytext.  Pages can
optionally be posted via email.

## Configuration

clayoven depends on Git, Ruby 1.9.3 and [Slim](http://slim-lang.com).

    gem install slim

It generates links with the assumption that the .html part is implicit
and unnecessary.  Use the following `.htaccess` file in your
repository root:

    Options +FollowSymLinks -MultiViews
    DirectorySlash Off
    
    RewriteEngine On
    
    RewriteCond %{SCRIPT_FILENAME}/ -d
    RewriteCond %{SCRIPT_FILENAME}.html !-f
    RewriteRule [^/]$ %{REQUEST_URI}/ [R=301,L]
    
    RewriteCond %{ENV:REDIRECT_STATUS} ^$
    RewriteRule ^(.+)\.html$ /$1 [R=301,L]
    
    RewriteCond %{SCRIPT_FILENAME}.html -f
    RewriteRule [^/]$ %{REQUEST_URI}.html [QSA,L]

## Usage

Simply run `clayoven` on your website's repository.  A small HTTP
server is also included for previewing your website locally; start
with `clayoven httpd`.

## Repository format

There are two kinds of pages: index pages and content pages.  Index
pages are toplevel pages and (optionally) contain links to
corresponding content pages.  To specify which pages should go under
which "topic" (or index), content page filenames must look like
`<topic>:<permalink>`.  Topic page filenames must look like
`<topic>.index`.  A special index page called `index` will serve as
the homepage.  Additionally, the repository should contain a
`design/template.slim`.

Content pages are sorted based on the timestamp of the commit that
first introduced the file, reverse-chronologically.  This means that
updating a page (and checking in the changes) will not break the sort
order.

## Using slim and claytext

claytext is the markup engine that processes all your files, and
passes structured information to the slim template.  However, no
special effort is required to mark up the text that you write.  The
first line of file should contain the title, followed by the body
peppered with [\d+] markers referring to links in the footer.  The
footer should contain "[\d+]: \<link\>" lines, which will be turned
into clickable links.  For a full example, see
[artagnon.com/claytext](http://artagnon.com/claytext).


The simplest possible slim template that will work with clayoven is:

    doctype html
    html
      head
        title #{permalink}
      body
        h1 #{title}
	pre #{body}

However, this does not make use of the structured information that
claytext offers.  For a full example, look at the
[template](https://github.com/artagnon/artagnon.com/blob/master/design/template.slim)
that artagnon.com uses.

## Posting via email

clayoven includes imapd, a daemon which constantly polls an IMAP
server for new emails.  This is currently incomplete.

## Contributing

Open issues and send pull requests on GitHub.  You can optionally
email the author your patches, if you prefer that.
