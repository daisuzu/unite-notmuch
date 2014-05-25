let s:save_cpo = &cpo
set cpo&vim

let g:notmuch_cmd = get(g:, 'notmuch_cmd', 'notmuch')
let g:notmuch_boxes = get(g:, 'notmuch_boxes', [
            \   {'name': 'new'   , 'pattern': 'tag:inbox and tag:unread'},
            \   {'name': 'inbox' , 'pattern': 'tag:inbox and not tag:draft'},
            \   {'name': 'draft' , 'pattern': 'tag:inbox and tag:draft'},
            \ ])

function! notmuch#patterns()
    let patterns = {}
    for box in g:notmuch_boxes
        call extend(patterns, {box.name: box.pattern})
    endfor

    return patterns
endfunction

function! notmuch#json_decode(str)
    let str = s:wellformed_json_str(a:str)
    return s:get_json().decode(str)
endfunction

function! notmuch#datetime_from_unix_time(unix_time)
    return s:get_datetime().from_unix_time(a:unix_time)
endfunction

function! notmuch#parse_mail(mail)
    let output = []

    if !len(a:mail)
        return output
    endif

    let mail = a:mail[0]
    let thread = a:mail[1]

    call add(output, 'From: ' . mail.headers.From)
    call add(output, 'To: ' . get(mail.headers, 'To', ''))
    if exists('mail.headers.Cc')
        call add(output, 'Cc: ' . mail.headers.Cc)
    endif
    call add(output, 'Date: ' . mail.headers.Date)
    call add(output, 'Subject: ' . mail.headers.Subject)
    for body in mail.body
        if !exists('body.content')
            continue
        endif

        if type(body.content) == 1
            call extend(output, split(body.content, "\n"))
            continue
        endif

        for content in body.content
            if content['content-type'] == 'text/plain' &&
                        \ exists('content.content')
                call extend(output, split(content.content, "\n"))
            endif
        endfor
    endfor

    if len(thread)
        call add(output, '=========================')
        call extend(output, notmuch#parse_mail(thread[0]))
    endif
    return output
endfunction

function! notmuch#open_buffer(thread_id)
    call s:get_buffer().open(a:thread_id, {'opener': 'edit'})
    setlocal buftype=nofile
    setlocal syntax=mail
endfunction

function! notmuch#output_mail(output)
    % delete _
    call append(0, a:output)
    normal! gg
endfunction

function! notmuch#count(search_term)
    let cmd = join([g:notmuch_cmd, 'count', a:search_term], ' ')
    return s:notmuch_run(cmd)
endfunction

function! notmuch#search_cmd(search_term)
    return printf('%s %s %s %s',
                \   g:notmuch_cmd,
                \   'search',
                \   '--format=json',
                \   notmuch#patterns()[a:search_term],
                \ )
endfunction

function! notmuch#search_async(cmd)
    return vimproc#popen3(a:cmd)
endfunction

function! notmuch#show(search_term)
    let cmd = join([g:notmuch_cmd, 'show --format=json', a:search_term], ' ')
    return s:notmuch_run(cmd)
endfunction

function! notmuch#tag(search_term)
    let cmd = join([g:notmuch_cmd, 'tag', a:search_term], ' ')
    return s:notmuch_run(cmd)
endfunction

" vital.vim {{{
function! s:vital()
    if !exists('s:V')
        let s:V = vital#of('notmuch')
    endif
    return s:V
endfunction

function! s:get_process()
    if !exists('s:Process')
        let s:Process = s:vital().import('Process')
    endif
    return s:Process
endfunction

function! s:get_json()
    if !exists('s:JSON')
        let s:JSON = s:vital().import('Web.JSON')
    endif
    return s:JSON
endfunction

function! s:get_string()
    if !exists('s:String')
        let s:String = s:vital().import('Data.String')
    endif
    return s:String
endfunction

function! s:get_datetime()
    if !exists('s:DateTime')
        let s:DateTime = s:vital().import('DateTime')
    endif
    return s:DateTime
endfunction

function! s:get_buffermanager()
    if !exists('s:BufferManager')
        let s:BufferManager = s:vital().import('Vim.BufferManager')
    endif
    return s:BufferManager
endfunction

function! s:get_buffer()
    if !exists('s:Buffer')
        let s:Buffer = s:get_buffermanager().new()
    endif
    return s:Buffer
endfunction
" }}}

" internal functions {{{
function! s:wellformed_json_str(str)
    let str = a:str !~# '^[' ? '[' . a:str : a:str
    return str !~# ']$' ? str . ']' : str
endfunction

function! s:notmuch_run(cmd)
    return s:get_string().chomp(
                \ s:get_process().system(a:cmd))
endfunction
" }}}

let &cpo = s:save_cpo
unlet s:save_cpo

" vim: foldmethod=marker
