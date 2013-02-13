# clayoven

An extremely simple website generator that operates on a very specific
kind of repository.  It only depends on slim (for rendering).  Posts
can optionally posted via email.

## Configuration

clayoven depends on slim:

    gem install slim

clayoven generates links with the assumption that the .html part is
implicit and unnecessary.  Use the following .htaccess file in your
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

## Repository format

* There are two kinds of pages: index pages and content pages.  Index
  pages are toplevel pages and (optionally) contain links to
  corresponding content pages.  To specify which pages should go under
  which "topic" (or index), content page filenames must look like
  `<topic>:<permalink>`.

* To generate HTML from the index and content files, the repository
  should contain `design/template.slim`.

* Both index and content pages conform to the same format.  The first
  line of file contains the title, followed by the body which is
  intended to be enclosed in a \<pre\> (you can change this in your
  template) pepper with [\d+] markers referring to links in the
  footer.  The footer should contain "[\d+]: \<link\>" lines.  The
  links will be turned into clickable links.

## Posting via email

clayoven includes clayovend, a daemon which constantly polls an IMAP
server for new emails.  Copy `imap-settings.template` to
`imap-settings.private` and configure.  The subject of the email
should be suffixed with "# \<permalink\>".

## Contributing

Open issues and send pull requests on GitHub.  You can optionally
email the author your patches, if you prefer that.
