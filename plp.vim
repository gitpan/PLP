" Vim syntax file
" Language:	PLP (Perl in HTML)
" Maintainer:	Juerd <juerd@juerd.nl>
" Last Change:	2002 May 19
" Cloned From:	aspperl.vim

" Add to filetype.vim the following line (without quote sign):
" au BufNewFile,BufRead *.plp setf plp

" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded
if version < 600
  syntax clear
elseif exists("b:current_syntax")
  finish
endif

if !exists("main_syntax")
  let main_syntax = 'perlscript'
endif

if version < 600
  so <sfile>:p:h/html.vim
  syn include @PLPPerlScript <sfile>:p:h/perl.vim
else
  runtime! syntax/html.vim
  unlet b:current_syntax
  syn include @PLPPerlScript syntax/perl.vim
endif

syn cluster htmlPreproc add=PLPPerlScriptInsideHtmlTags

syn region  PLPPerlScriptInsideHtmlTags keepend matchgroup=Delimiter start=+<:=\=+ end=+:>+ contains=@PLPPerlScript

syn cluster htmlPreproc add=PLPIncludeTag

syn region  PLPIncludeTag keepend matchgroup=Delimiter start=+<(+ end=+)>+ contains=@PLPIncludeFilename

let b:current_syntax = "plp"
