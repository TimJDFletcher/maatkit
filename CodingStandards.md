Coding standards provide consistently formatted source code that makes it easier to create commercial grade Perl programs that are easier to understand, modify, maintain and be used by others.  There are plenty standards available, but we believe the following standard is easy to implement.  With a properly configured editor, there’s no need for manual formatting of Perl code. Let your editor do the heavy lifting.

There are bad-good examples at the end of this wiki to drive home the points.

# The Dog Book #

The defacto standard for developing Perl programs is The Dog Book, formally, [Perl Best Practices by Damian Conway](http://oreilly.com/catalog/9780596001735/).  Maatkit coding standard implements as much of the Dog book as possible.  When you see us say stuff like "dog it", this is what we're referring to.

# Configuring VIM #

VIM can be configured as a Perl IDE by installing the perl-support plug-in. Perl-support can be found http://www.vim.org/scripts/script.php?script_id=556.

Here is a ~/.vimrc file from Baron Schwartz, the creator of Maatkit.  This file contains options to use 3 spaces for indentation (not tabs), and wrap lines at 80 columns wide.  The last 2 lines are to help make it easy to find syntax errors by typing `:make`.

```
set expandtab shiftwidth=3 tabstop=3 softtabstop=3
set smartindent
set tw=80
set makeprg=perl\ -c\ %
set errorformat=%m\ at\ %f\ line\ %l%.%#,%-G%.%#
```

Example .vimrc or .gvimrc file from another of the developers:

```
set autoindent                    "Preserve current indent on new lines
set textwidth=78                  "Wrap at this column
set backspace=indent,eol,start    "Make backspaces delete sensibly
 
set tabstop=3                     "Indentation levels every three columns
set expandtab                     "Convert all tabs typed to spaces
set shiftwidth=3                  "Indent/outdent by three columns
set shiftround                    "Indent/outdent to nearest tabstop
 
set matchpairs+=<:>               "Allow % to bounce between angles too

set iskeyword+=:                  "Perl double colons are valid part of
                                  "identifiers.

set lines=40
set columns=85
set number

set statusline=%<%f%h%m%r%=%{&ff}\ %l,%c%V\ %P

filetype plugin on

"reread .vimrc file after editing
autocmd BufWritePost $HOME/.vimrc source $HOME/.vimrc

" use visual bell instead of beeping
set vb

" incremental search
set incsearch

" syntax highlighting
set bg=light
syntax on

" autoindent
autocmd FileType perl set autoindent|set smartindent

" show matching brackets
autocmd FileType perl set showmatch

" check perl code with :make
"autocmd FileType perl set makeprg=perl\ -c\ %\ $*
"autocmd FileType perl set errorformat=%f:%l:%m
"autocmd FileType perl set autowrite

" dont use Q for Ex mode
map Q :q

" make tab in v mode ident code
vmap <tab> >gv
vmap <s-tab> <gv

" make tab in normal mode ident code
nmap <tab> I<tab><esc>
nmap <s-tab> ^i<bs><esc>

" paste mode - this will avoid unexpected effects when you
" cut or copy some text from one window and paste it in Vim.
set pastetoggle=<F11>

" Tlist Config
nnoremap <silent> <F8> :TlistToggle<CR>

" perltidy mappings
map <F2> <ESC>:%! perltidy<CR>
map <F3> <ESC>:'<,'>! perltidy<CR>

" Perl test files as Perl code
au BufRead,BufNewFile *.t set ft=perl

“perl-support plugin info
let g:Perl_AuthorName   = ''
let g:Perl_AutherRef    = ''
let g:Perl_Email        = ''
```

# Configuring Emacs #

**TODO** – I don’t use Emacs, if you do and could write up how to configure for the Maatkit standard, please email me: mark.schoonover@gmail.com

# Configuring Your\_favorite\_editor #

**TODO** - If you use an editor that’s not listed above, I’d like to hear from you. Since Maatkit runs on a wide range of operating systems, I’d like to document those editors that are popular on those systems. For example, Mac OSX.

# Tidying Up #

PerlTidy, http://perltidy.sourceforge.net/ is a tool to format Perl code.

Example .perltidyrc file:
```
-l=78   # Max line width is 78 cols
-i=3    # Indent level is 4 cols
-ci=3   # Continuation indent is 4 cols
-st     # Output to STDOUT
-se     # Errors to STDERR
-vt=2   # Maximal vertical tightness
-cti=0  # No extra indentation for closing brackets
-pt=1   # Medium parenthesis tightness
-bt=1   # Medium brace tightness
-sbt=1  # Medium square bracket tightness
-bbt=1  # Medium block brace tightness
-nsfs   # No space before semicolons
-nolq   # Don't outdent long quoted strings
-wbb="% + - * / x != == >= <= =~ !~ < > | & >= < = **= += *= &= <<= &&= -= /= |= >>= ||= .= %= ^= x="   
```

PerlTidy usually does a good job, but sometimes it's a little too strict.  Use your best judgment in accordance with the dog book.  Try for beautiful, sexy code.

# Templates #

Current code serves as templates.  The tools have a consistent layout, as described in the [Code Overview](http://code.google.com/p/maatkit/wiki/CodeOverview) wiki.  The modules are all roughly the same, too.  Even the tests are becoming uniform in their form and function.  So familiarize yourself with code like mk-query-digest and its modules and test.  Please try to mimic this style.

# Bad-Good Examples #

Such examples are plentiful in the dog book, but here are just a few to make the point in this wiki:

Bad:
```
if($foo) { print "ok\n"; } else { print "not ok\n"; }
```

Good:
```
if ( $foo ) {
   print "ok\n";
}
else {
   print "ok\n";
}
```

Bad:
```
$foo = ($val == 1 ? 'RED' : $val == 2 ? : 'BLUE' : 'GREEN');
```

Good:
```
$foo = $val == 1 ? 'RED'
     : $val == 2 ? 'BLUE'
     :             'GREEN';
```

Bad:
```
$query =~ s{(\bIN\s*\()([^\)]+)(?=\))}{$1 . __shorten($2)}gexsi;
```

Good:
```
$query =~ s{
   (\bIN\s*\()    # The opening of an IN list
   ([^\)]+)       # Contents of the list, assuming no item contains paren
   (?=\))         # Close of the list
}
{
   $1 . __shorten($2)
}gexsi;
```

# Next Steps #

If you've read this far you're probably determined to contribute code.  This wiki has been about writing sexy code (i.e. code formatting).  The next wiki, [Coding Conventions](http://code.google.com/p/maatkit/wiki/CodingConventions), is about sexy _and_ elegant code.  What fun!