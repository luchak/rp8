-->8
-- utils

function pick(t,keys)
 local r={}
 for k in all(keys) do
  r[k]=t[k]
 end
 return r
end

function pick_prefix(t,prefix,suffixes)
 local r={}
 for s in all(suffixes) do
  r[s]=t[prefix..'_'..s]
 end
 return r
end

function die(msg)
 assert(false,msg)
end

function copy_table(t)
 return merge_tables({},t)
end

function merge_tables(base,new,do_copy)
 if (do_copy) base=copy_table(base)
 if (not new) return base
 for k,v in pairs(new) do
  if type(v)=='table' then
   local bk=base[k]
   if type(bk)=='table' then
    merge_tables(bk,v)
   else
    base[k]=copy_table(v)
   end
  else
   base[k]=v
  end
 end
 return base
end

function is_empty(t)
 for _ in pairs(t) do
  return false
 end
 return true
end

function diff_tables(base,diff)
 if (not (diff and base)) return
 for k,v in pairs(base) do
  local dk=diff[k]
  if type(v)=='table' and type(dk)=='table' then
   diff_tables(v,dk)
   if (is_empty(v)) base[k]=nil
  elseif dk then
   base[k]=nil
  end
 end
end

function stringify(v)
 local t=type(v)
 if t=='number' or t=='boolean' then
  return tostr(v)
 elseif t=='string' then
  return '"'..v..'"'
 elseif t=='table' then
  local s='{'
  for k,v in pairs(v) do
   s..=k..'='..stringify(v)..','
  end
  return s..'}'
 else
  die'unsupported type in stringify'
 end
end

function make_reader(s)
 local p,n=0,#s
 return function(inc)
  p+=inc or 1
  if (p>n) return ''
  return sub(s,p,p)
 end
end

function parse(s)
 return _parse(make_reader(s))
end

function is_digit(c)
 return (c>='0' and c<='9') or c=='.'
end

function is_whitespace(c)
 return c==' ' or c=='\n' or c=='\t'
end

-- this is super fragile
-- can easily hang the program!
-- make sure to always use
-- double quotes in serialized
-- data, single quotes will hang
function _parse(input)
 local c
 repeat
  c=input()
 until not is_whitespace(c)
 if c=='"' then
  local s=''
  repeat
   c=input()
   if (c=='"') return s
   s..=c
  until false
 elseif c=='-' or is_digit(c) then
  local s=c
  repeat
   c=input()
   local d=is_digit(c)
   if (d) s..=c
  until not d
  input(-1)
  return tonum(s)
 elseif c=='{' then
  local t={}
  repeat
   c=input()
   while is_whitespace(c) or c==',' do
    c=input()
   end
   if (c=='}') return t
   local k=c
   repeat
    c=input()
    if (c=='=') break
    k..=c
   until false
   k=tonum(k) or k
   t[k]=_parse(input)
  until false
 elseif c=='t' then
  input(3)
  return true
 elseif c=='f' then
  input(4)
  return false
 else
  die('cannot parse, c="'..c..'"')
 end
end

function unpack_split(s)
 return unpack(split(s))
end

function trn(c,t,f)
 return (c and t) or f
end

function enc_byte_array(a)
 return chr(unpack(a))
end

function dec_byte_array(s)
 local a={}
 for i=1,#s do
  a[i]=ord(s,i)
 end
 return a
end

function map_table(a,f)
 local r={}
 for k,v in pairs(a) do
  r[k]=f(v)
 end
 return r
end
