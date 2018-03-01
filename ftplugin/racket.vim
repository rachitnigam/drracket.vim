" A line/col entry is in the form 'line+col' where both 'line' and 'col'
" are numbers. Returns a tuple with 'line' and 'col'.
function! ParseLineCol(str)
  let l:res = split(a:str, '+')
  return map(l:res, "str2nr" . "(v:val)")
endfunction

" Given a '(a ...)' return a list with all elements [a, ...]
function! Elements(list_str)
  " Remove surrounding '( )
  let l:stripped = a:list_str[1:-2]
  return split(l:stripped, " ")
endfunction

" Generate a binding mapping from a string of the form `(("l+r" ...) ...)`
" where each internal `("l+r" ...) implies that each element maps to every
" other element in that list.
" Returns a dict from 'line+col' to [line, column] for all the bound instances.
function! GenerateDict(str)
  " Remove surrounding "( )"
  let l:stripped = a:str[2:-4]
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

let b:binding_dict = {}

" Lookup 'line+column' in binding_dict and highlight all visible
" elements.
" @param start_line the first visible line
" @param end_line the last visible line
" @param word the word under the cursor
" @param line starting line of the word
" @param column starting column of the word
function! GenerateHighlightRules(start_line, end_line, word, line, column)
  let l:key = string(a:line) . "+" . string(a:column)
  if has_key(b:binding_dict, l:key)
    let l:Filter_fun = {data -> data[0] >= a:start_line && data[0] <= a:end_line}
    let l:filtered_list = filter(b:binding_dict[l:key], "l:Filter_fun(v:val)")
    if len(l:filtered_list) >= 1
      let l:match_str = '2match MatchParen /\('
      for [line, column] in l:filtered_list[:-2]
        let l:match_str .= '\%' . string(line) . 'l\%' . string(column+1) . 'c\|'
      endfor
      let [l:lline, l:lcol] = l:filtered_list[-1]
      let l:match_str .= '\%' . string(l:lline) . 'l\%' . string(l:lcol+1) .'c\)\k\+/'
      return l:match_str
    else
      echo '[RacketServer]: No binding Information'
      return ""
    endif
  else
    return ""
  endif
endfunction

let s:UpdateBindingOpts = { 'shell': 'shell 1' }

" Binding data may come in chunks. Append the chunks into this array.
let s:bindingChunks = ['']

" On receiving stdout from the job, append it to the bindingChunks array
function s:UpdateBindingOpts.on_stdout(job_id, data, event) dict
  let s:bindingChunks[-1] .= a:data[0]
  call extend(s:bindingChunks, a:data[1:])
endfunction

function s:UpdateBindingOpts.on_stderr(job_id, data, event)
  echo 'an error occured from UpdateBinding'
endfunction

" Once all the data is received, update the bindings
function s:UpdateBindingOpts.on_exit(job_id, data, event)
  if a:data != 0
    echo 'an error occured from UpdateBinding'
  endif

  echo '[RacketServer]: Bindings updated'
  let b:binding_dict = GenerateDict(s:bindingChunks[0])
endfunction

" Get binding information from racket script
let s:racket_script = expand("<sfile>:p:h") . '/../racket/draw.rkt'
function! UpdateGetBindings()

  " Clear bindingChunks before the async job is invoked.
  let s:bindingChunks = ['']

  let job = jobstart(['racket', s:racket_script, expand('%:p')], s:UpdateBindingOpts)
endfunction

" This function is executed on cursor move and acts as the entrypoint for
" the rest of script.
function! HighlightBindings()
  2match none
  let l:cur_pos = getcurpos()
  let l:rule = GenerateHighlightRules(line('w0'), line('w$'), expand('<cword>'), l:cur_pos[1], l:cur_pos[2]-1)
  exe l:rule
endfunction

augroup HighlightingBinding
  autocmd!
  au CursorMoved <buffer> call HighlightBindings()
  au BufWritePost <buffer> call UpdateGetBindings()
augroup end
