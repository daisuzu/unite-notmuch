let s:save_cpo = &cpo
set cpo&vim

let s:kind = {
            \   'name': 'notmuch',
            \   'action_table': {},
            \   'default_action': 'open',
            \ }

let s:kind.action_table.open = {
            \ 'description' : 'open mail',
            \ 'is_selectable' : 0,
            \ }

function! s:kind.action_table.open.func(candidates)
    let thread_id = get(a:candidates, 'source__thread', -1)

    if thread_id == -1
        call unite#start_script([['notmuch', a:candidates.word]])
    else
        call notmuch#open_buffer(thread_id)

        let mail = notmuch#json_decode(
                    \   notmuch#show('thread:' . thread_id)
                    \ )[0][0]

        let output = notmuch#parse_mail(mail)
        call notmuch#output_mail(output)
    endif
endfunction

let s:kind.action_table.read= {
            \ 'description' : 'read mail',
            \ 'is_selectable' : 0,
            \ }

function! s:kind.action_table.read.func(candidates)
    let thread_id = get(a:candidates, 'source__thread', -1)

    if thread_id == -1
        let search_term = notmuch#patterns()[a:candidates.word]
    else
        let search_term = 'thread:' . thread_id
    endif

    let g:read_result = notmuch#tag('-unread ' . search_term)

endfunction

function! unite#kinds#notmuch#define()
    return s:kind
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
