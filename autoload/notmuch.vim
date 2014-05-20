let s:save_cpo = &cpo
set cpo&vim

let s:V = vital#of('notmuch')
let s:JSON = s:V.import('Web.JSON')
let s:DateTime = s:V.import('DateTime')
let s:BufferManager = s:V.import('Vim.BufferManager')
let s:buffer = s:BufferManager.new()

let g:notmuch_cmd = get(g:, 'notmuch_cmd', 'notmuch')
let g:notmuch_boxes = get(g:, 'notmuch_boxes', [
            \   {'name': 'new'   , 'pattern': 'tag:inbox and tag:unread'},
            \   {'name': 'inbox' , 'pattern': 'tag:inbox and not tag:draft'},
            \   {'name': 'draft' , 'pattern': 'tag:inbox and tag:draft'},
            \ ])

function! notmuch#cmd()
    return g:notmuch_cmd
endfunction

function! notmuch#folders()
    return g:notmuch_boxes
endfunction

function! notmuch#patterns()
    let patterns = {}
    for box in g:notmuch_boxes
        call extend(patterns, {box.name: box.pattern})
    endfor

    return patterns
endfunction

function! notmuch#json_decode(str)
    return s:JSON.decode(a:str)
endfunction

function! notmuch#datetime_from_unix_time(unix_time)
    return s:DateTime.from_unix_time(a:unix_time)
endfunction

function! notmuch#open_buffer(thread_id)
    call s:buffer.open(a:thread_id, {'opener': 'edit'})
    setlocal buftype=nofile
    setlocal syntax=mail
endfunction

function! notmuch#output_mail(output)
    % delete _
    call append(0, a:output)
    normal! gg
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

function! notmuch#count(search_term)
    return vimproc#popen3([g:notmuch_cmd,
                \ 'count', a:search_term]).stdout.read_line()
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

function! notmuch#search(search_term)
    return vimproc#popen3([g:notmuch_cmd,
                \ 'search', '--format=json', a:search_term]).stdout.read()
endfunction

function! notmuch#show(search_term)
    return vimproc#popen3([g:notmuch_cmd,
                \ 'show', '--format=json', a:search_term]).stdout.read_line()
endfunction

function! notmuch#tag(search_term)
    let cmd = join([g:notmuch_cmd, 'tag', a:search_term], ' ')
    return vimproc#popen3(cmd)
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
