" A line/col entry is in the form 'line+col' where both 'line' and 'col'
" are numbers. Returns a tuple with 'line' and 'col'.
function! ParseLineCol(str)
  let l:res = split(a:str, '+')
  return map(l:res, "str2nr" . "(v:val)")
endfunction

" Given a '(a ...)' return a list with all elements [a, ...]
function! Elements(list_str)
  " Remove surrounding ( )
  let l:stripped = a:list_str[1:-2]
  return split(l:stripped, " ")
endfunction

" Generate a binding mapping from a string of the form `(("l+r" ...) ...)`
" where each internal `("l+r" ...) implies that each element maps to every
" other element in that list.
" Returns a dict from 'line+col' to [line, column] for all the bound instances.
function! GenerateDict(str)
  " Remove surrounding ( )
  let l:stripped = a:str[1:-2]
  let l:lst = []
  call substitute(l:stripped, '([^()]*)', '\=add(l:lst, submatch(0))', 'g')

  let l:dict = {}
  for l in l:lst
    " The first element in the list is the binder
    let l:elems = Elements(l)
    let l:parsed = map(Elements(l), "ParseLineCol(v:val)")
    for e in elems
      let l:dict[e] = l:parsed
    endfor
  endfor

  return l:dict
endfunction

let b:current_binding_dict = GenerateDict("((1+6 4+3 7+3 3+1 6+1) (3+9 4+5 4+7) (6+9 7+5 7+7))")

" Lookup 'line+column' in current_binding_dict and highlight all visible
" elements.
" @param start_line the first visible line
" @param end_line the last visible line
" @param word the word under the cursor
" @param line starting line of the word
" @param column starting column of the word
function! GenerateHighlightRules(start_line, end_line, word, line, column)
  let l:key = string(a:line) . "+" . string(a:column)
  if has_key(b:current_binding_dict, l:key)
    let l:Filter_fun = {data -> data[0] >= a:start_line && data[0] <= a:end_line}
    let l:filtered_list = filter(b:current_binding_dict[l:key], "l:Filter_fun(v:val)")
    let l:match_str = '2match MatchParen /\('
    for [line, column] in l:filtered_list[:-2]
      let l:match_str .= '\%' . string(line) . 'l\%' . string(column+1) . 'c\|'
    endfor
    let [l:lline, l:lcol] = l:filtered_list[-1]
    let l:match_str .= '\%' . string(l:lline) . 'l\%' . string(l:lcol+1).'c\)\k\+/'
    return l:match_str
  else
    return ""
  endif
endfunction

" This function is executed on cursor move and ties.
function! HighlightBindings()
  2match none
  let l:cur_pos = getcurpos()
  let l:rule = GenerateHighlightRules(line('w0'), line('w$'), expand('<cword>'), l:cur_pos[1], l:cur_pos[2]-1)
  exe l:rule
endfunction

function! Simple()
  echo 'called'
endfunction

augroup HighlightingBinding
  " this one is which you're most likely to use?
  autocmd!
  autocmd CursorMoved,CursorMovedI <buffer> call HighlightBindings()
augroup end
