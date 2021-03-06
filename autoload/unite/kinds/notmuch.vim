let s:save_cpo = &cpo
set cpo&vim

" notmuch/folder {{{
let s:kind_folder = {
            \   'name': 'notmuch/folder',
            \   'action_table': {},
            \   'default_action': 'open',
            \ }

let s:kind_folder.action_table.open = {
            \ 'description' : 'open folder',
            \ 'is_selectable' : 0,
            \ 'is_quit' : 1,
            \ 'is_start' : 1,
            \ }
function! s:kind_folder.action_table.open.func(candidate) "{{{
    call unite#start_temporary([['notmuch', a:candidate.word]], {'resume': 0})
endfunction "}}}

let s:kind_folder.action_table.read= {
            \ 'description' : 'read folder',
            \ 'is_selectable' : 1,
            \ }
function! s:kind_folder.action_table.read.func(candidates) "{{{
    let search_term = join(map(deepcopy(a:candidates),
                \ '"\"" . notmuch#patterns()[v:val.word] . "\""'), ' or ')
    call notmuch#tag('-unread ' . search_term)
endfunction "}}}

let s:kind_folder.action_table.unread= {
            \ 'description' : 'unread folder',
            \ 'is_selectable' : 1,
            \ }
function! s:kind_folder.action_table.unread.func(candidates) "{{{
    let search_term = join(map(deepcopy(a:candidates),
                \ '"\"" . notmuch#patterns()[v:val.word] . "\""'), ' or ')
    call notmuch#tag('+unread ' . search_term)
endfunction "}}}

let s:kind_folder.action_table.search= {
            \ 'description' : 'search folder',
            \ 'is_selectable' : 0,
            \ 'is_quit' : 1,
            \ 'is_start' : 1,
            \ }
function! s:kind_folder.action_table.search.func(candidate) "{{{
    let context = unite#get_context()
    let context.resume = 0
    let pattern = input('Input search-term:')

    if len(pattern)
        let context.source__search = ' and ' . pattern
    endif
    call unite#start_script([['notmuch', a:candidate.word]], context)
endfunction "}}}
"}}}

" notmuch/mail {{{
let s:kind_mail = {
            \   'name': 'notmuch/mail',
            \   'action_table': {},
            \   'default_action': 'open',
            \   'parents': ['openable'],
            \ }

let s:kind_mail.action_table.open = {
            \ 'description' : 'open mail',
            \ 'is_selectable' : 0,
            \ }
function! s:kind_mail.action_table.open.func(candidate) "{{{
    let thread_id = get(a:candidate, 'source__thread', -1)
    if thread_id == -1
        return
    endif

    call notmuch#open_buffer(thread_id)

    let mail = notmuch#json_decode(
                \   notmuch#show('thread:' . thread_id)
                \ )[0]

    let output = notmuch#parse_mail(mail)
    call notmuch#output_mail(output)
endfunction "}}}

let s:kind_mail.action_table.read= {
            \ 'description' : 'read mail',
            \ 'is_selectable' : 1,
            \ }
function! s:kind_mail.action_table.read.func(candidates) "{{{
    let search_term = join(map(deepcopy(a:candidates),
                \ '"\"thread:" . v:val.source__thread . "\""'), ' or ')
    call notmuch#tag('-unread ' . search_term)
endfunction "}}}

let s:kind_mail.action_table.unread= {
            \ 'description' : 'unread mail',
            \ 'is_selectable' : 1,
            \ }
function! s:kind_mail.action_table.unread.func(candidates) "{{{
    let search_term = join(map(deepcopy(a:candidates),
                \ '"\"thread:" . v:val.source__thread . "\""'), ' or ')
    call notmuch#tag('+unread ' . search_term)
endfunction "}}}

let s:kind_mail.action_table.preview = {
            \ 'description' : 'preview mail',
            \ 'is_quit' : 0,
            \ }
function! s:kind_mail.action_table.preview.func(candidates) "{{{
    let thread_id = get(a:candidates, 'source__thread', -1)
    if thread_id == -1
        return
    endif

    noautocmd silent execute 'pedit!' thread_id
    wincmd P

    let mail = notmuch#json_decode(
                \   notmuch#show('thread:' . thread_id)
                \ )[0][0]

    let output = notmuch#parse_mail(mail)
    call notmuch#output_mail(output)
    setlocal nomodified
    setlocal nobuflisted
    wincmd p
endfunction "}}}
"}}}

function! unite#kinds#notmuch#define()
    return [s:kind_folder, s:kind_mail]
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo

" vim: foldmethod=marker
