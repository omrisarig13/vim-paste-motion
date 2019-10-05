" Functions {{{

" Internal Functions {{{

" Function s:IsAfter {{{
function! s:IsAfter( posA, posB )
    return (a:posA[1] > a:posB[1] || a:posA[1] == a:posB[1] && a:posA[2] > a:posB[2])
endfunction
" Function s:IsAfter }}}

" Function paste_motion#SetRegister {{{
function! paste_motion#SetRegister()
    let s:register = v:register
endfunction
" Function paste_motion#SetRegister }}}

" Function CorrectForRegtype {{{
function! s:CorrectForRegtype( type, register, regType, pasteText )
    if a:type ==# 'visual' && visualmode() ==# "\<C-v>" || a:type[0] ==# "\<C-v>"
        " Adaptations for blockwise replace.
        let l:pasteLnum = len(split(a:pasteText, "\n"))
        if a:regType ==# 'v' || a:regType ==# 'V' && l:pasteLnum == 1
            " If the register contains just a single line, temporarily duplicate
            " the line to match the height of the blockwise selection.
            let l:height = line("'>") - line("'<") + 1
            if l:height > 1
                call setreg(a:register, join(repeat(split(a:pasteText, "\n"), l:height), "\n"), "\<C-v>")
                return 1
            endif
        elseif a:regType ==# 'V' && l:pasteLnum > 1
            " If the register contains multiple lines, paste as blockwise.
            call setreg(a:register, '', "a\<C-v>")
            return 1
        endif
    elseif a:regType ==# 'V' && a:pasteText =~# '\n$'
        " Our custom operator is characterwise, even in the
        " paste_motionLine variant, in order to be able to replace less
        " than entire lines (i.e. characterwise yanks).
        " So there's a mismatch when the replacement text is a linewise yank,
        " and the replacement would put an additional newline to the end.
        " To fix that, we temporarily remove the trailing newline character from
        " the register contents and set the register type to characterwise yank.
        call setreg(a:register, strpart(a:pasteText, 0, len(a:pasteText) - 1), 'v')

        return 1
    endif

    return 0
endfunction
" Function CorrectForRegtype }}}

" Function paste_motion {{{
function! s:paste_motion( type )
    " With a put in visual mode, the selected text will be replaced with the
    " contents of the register. This works better than first deleting the
    " selection into the black-hole register and then doing the insert; as
    " "d" + "i/a" has issues at the end-of-the line (especially with blockwise
    " selections, where "v_o" can put the cursor at either end), and the "c"
    " commands has issues with multiple insertion on blockwise selection and
    " autoindenting.
    " With a put in visual mode, the previously selected text is put in the
    " unnamed register, so we need to save and restore that.
    let l:save_clipboard = &clipboard
    set clipboard= " Avoid clobbering the selection and clipboard registers.
    let l:save_reg = getreg('"')
    let l:save_regmode = getregtype('"')

    " Note: Must not use ""p; this somehow replaces the selection with itself?!
    let l:pasteRegister = (s:register ==# '"' ? '' : '"' . s:register)
    if s:register ==# '='
        " Cannot evaluate the expression register within a function; unscoped
        " variables do not refer to the global scope. Therefore, evaluation
        " happened earlier in the mappings.
        " To get the expression result into the buffer, we use the unnamed
        " register; this will be restored, anyway.
        call setreg('"', g:paste_motion#expr)
        call s:CorrectForRegtype(a:type, '"', getregtype('"'), g:paste_motion#expr)
        " Must not clean up the global temp variable to allow command
        " repetition.
        "unlet g:paste_motion#expr
        let l:pasteRegister = ''
    endif
    if a:type ==# 'visual'
        "****D echomsg '**** visual' string(getpos("'<")) string(getpos("'>")) string(l:pasteRegister)
        let l:previousLineNum = line("'>") - line("'<") + 1
        if &selection ==# 'exclusive' && getpos("'<") == getpos("'>")
            " In case of an empty selection, just paste before the cursor
            " position; reestablishing the empty selection would override
            " the current character, a peculiarity of how selections work.
            execute 'silent normal!' l:pasteRegister . 'P'
        else
            execute 'silent normal! gv' . l:pasteRegister . 'p'
        endif
    else
        "****D echomsg '**** operator' string(getpos("'[")) string(getpos("']")) string(l:pasteRegister)
        let l:previousLineNum = line("']") - line("'[") + 1
        if s:IsAfter(getpos("'["), getpos("']"))
            execute 'silent normal!' l:pasteRegister . 'P'
        else
            " Note: Need to use an "inclusive" selection to make `] include
            " the last moved-over character.
            let l:save_selection = &selection
            set selection=inclusive
            try
                execute 'silent normal! g`[' . (a:type ==# 'line' ? 'V' : 'v') . 'g`]' . l:pasteRegister . 'p'
            finally
                let &selection = l:save_selection
            endtry
        endif
    endif

    let l:newLineNum = line("']") - line("'[") + 1
    if l:previousLineNum >= &report || l:newLineNum >= &report
        echomsg printf('Replaced %d line%s', l:previousLineNum, (l:previousLineNum == 1 ? '' : 's')) .
                    \   (l:previousLineNum == l:newLineNum ? '' : printf(' with %d line%s', l:newLineNum, (l:newLineNum == 1 ? '' : 's')))
    endif
endfunction
" Function paste_motion }}}

" Function paste_motion#Operator {{{
function! paste_motion#Operator( type, ... )
    call s:paste_motion(a:type)

    if a:0
        if a:0 >= 2 && a:2
            silent! call repeat#set(a:1, s:count)
        else
            silent! call repeat#set(a:1)
        endif
    elseif s:register ==# '='
        " Employ repeat.vim to have the expression re-evaluated on repetition of
        " the operator-pending mapping.
        silent! call repeat#set("\<Plug>paste_motionExpressionSpecial")
    endif
    silent! call visualrepeat#set("\<Plug>paste_motionVisual")
endfunction
" Function paste_motion#Operator }}}

" Internal Functions }}}

" Exported Functions {{{

" Function paste_motion_operator#paste_motion_operator {{{
" @brief The actual motion of paste with a given motion.
" @return None
function! paste_motion#paste_motion_operator()
    call paste_motion#SetRegister()
    set opfunc=paste_motion#Operator

    let l:keys = 'g@'

    if ! &l:modifiable || &l:readonly
        " Probe for "Cannot make changes" error and readonly warning via a no-op
        " dummy modification.
        " In the case of a nomodifiable buffer, Vim will abort the normal mode
        " command chain, discard the g@, and thus not invoke the operatorfunc.
        let l:keys = ":call setline('.', getline('.'))\<CR>" . l:keys
    endif

    if v:register ==# '='
        " Must evaluate the expression register outside of a function.
        let l:keys = ":let g:paste_motion#expr = getreg('=')\<CR>" . l:keys
    endif

    return l:keys
endfunction
" Function paste_motion#paste_motion_operator }}}

" Exported Functions }}}

" Functions }}}

" Script Globals {{{


" Script Globals }}}
