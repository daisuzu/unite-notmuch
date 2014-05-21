let s:save_cpo = &cpo
set cpo&vim

let s:source = {
            \   'name': 'notmuch',
            \   'hooks' : {},
            \ }

function! s:source.hooks.on_init(args, context)
    if !len(a:args)
        let s:notmuch_folders = map(deepcopy(notmuch#folders()), '{
                    \   "word": v:val.name,
                    \   "abbr": v:val.name . " [ " . notmuch#count(v:val.pattern) . " ]",
                    \   "kind": "notmuch",
                    \   "source__pattern": v:val.pattern,
                    \ }')
    endif
endfunction

function! s:source.hooks.on_close(args, context)
    if has_key(a:context, 'source__proc')
        call a:context.source__proc.kill()
    endif
endfunction

function! s:source.gather_candidates(args, context)
    if !len(a:args)
        return s:notmuch_folders
    endif

    if a:args[0] == ''
        call unite#print_source_message('Canceled.', s:source.name)
        let a:context.is_async = 0
        return []
    endif

    if a:context.is_redraw
        let a:context.is_async = 1
    endif

    let cmd = notmuch#search_cmd(a:args[0])
    call unite#print_source_message('Command-line: ' . cmd, s:source.name)

    let a:context.source__proc = notmuch#search_async(cmd)

    return self.async_gather_candidates(a:args, a:context)
endfunction

function! s:source.async_gather_candidates(args, context)
    if !has_key(a:context, 'source__proc')
        let a:context.is_async = 0
        call unite#print_source_message('Completed.', s:source.name)
        return []
    endif

    let stderr = a:context.source__proc.stderr
    if !stderr.eof
        " Print error.
        let errors = filter(stderr.read_lines(-1, 100),
                    \ "v:val !~ '^\\s*$'")
        if !empty(errors)
            call unite#print_source_error(errors, s:source.name)
        endif
    endif

    let stdout = a:context.source__proc.stdout
    if stdout.eof
        " Disable async.
        let a:context.is_async = 0
        call unite#print_source_message('Completed.', s:source.name)

        call a:context.source__proc.waitpid()
   endif

    let res = join(stdout.read_lines(-1, 100))
    if res == ''
        return []
    endif
    if res !~# '^['
        let res = '[' . res
    endif
    if res !~# ']$'
        let res = res . ']'
    endif

    let json = notmuch#json_decode(res)
    return map(json, '{
                \   "word": v:val.subject,
                \   "abbr": notmuch#datetime_from_unix_time(v:val.timestamp).to_string() . " | " . v:val.subject,
                \   "kind": "notmuch",
                \   "source__thread": v:val.thread,
                \ }')
endfunction

function! unite#sources#notmuch#define()
    if !executable(notmuch#cmd())
        return
    endif

    if !unite#util#has_vimproc()
        return
    endif

    return s:source
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
