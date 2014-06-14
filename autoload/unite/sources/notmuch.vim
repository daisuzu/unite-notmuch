let s:save_cpo = &cpo
set cpo&vim

let s:source = {
            \   'name': 'notmuch',
            \   'hooks' : {},
            \ }

function! s:source.hooks.on_close(args, context) "{{{
    if has_key(a:context, 'source__proc')
        call a:context.source__proc.kill()
    endif
endfunction "}}}

function! s:source.gather_candidates(args, context) "{{{
    let box_name = get(a:args, 0, '')
    let a:context.source__pattern = get(notmuch#patterns(), box_name)

    let pattern = a:context.source__pattern
    if pattern == ''
        let a:context.is_async = 0
        return map(deepcopy(g:notmuch_boxes), '{
                    \   "word": v:val.name,
                    \   "abbr": v:val.name . " [ " . notmuch#count(v:val.pattern) . " ]",
                    \   "kind": "notmuch/folder",
                    \   "source__pattern": v:val.pattern,
                    \ }')
    endif

    let search_term = notmuch#patterns()[box_name]. get(a:context, 'source__search', '')
    let cmd = notmuch#search_cmd(search_term)
    call unite#print_source_message('Command-line: ' . cmd, self.name)

    let a:context.source__proc = notmuch#search_async(cmd)
    call a:context.source__proc.stdin.close()

    return []
endfunction "}}}

function! s:source.async_gather_candidates(args, context) "{{{
    if !has_key(a:context, 'source__proc')
        let a:context.is_async = 0
        call unite#print_source_message('Completed.', self.name)
        return []
    endif

    let stderr = a:context.source__proc.stderr
    if !stderr.eof
        " Print error.
        let errors = filter(stderr.read_lines(-1, 100),
                    \ "v:val !~ '^\\s*$'")
        if !empty(errors)
            call unite#print_source_error(errors, self.name)
        endif
    endif

    let stdout = a:context.source__proc.stdout
    if stdout.eof
        " Disable async.
        let a:context.is_async = 0
        call unite#print_source_message('Completed.', self.name)

        call a:context.source__proc.waitpid()
    endif

    let res = join(stdout.read_lines(-1, 100))
    if res == ''
        return []
    endif

    let json = notmuch#json_decode(res)
    return map(json, '{
                \   "word": v:val.subject,
                \   "abbr": notmuch#datetime_from_unix_time(v:val.timestamp).to_string() . " | " . v:val.subject,
                \   "kind": "notmuch/mail",
                \   "source__thread": v:val.thread,
                \ }')
endfunction "}}}

function! unite#sources#notmuch#define()
    if !notmuch#is_executable()
        return
    endif

    if !unite#util#has_vimproc()
        return
    endif

    return s:source
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo

" vim: foldmethod=marker
