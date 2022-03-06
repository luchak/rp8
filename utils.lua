-->8
-- utils

function log(...)
 local s=''
 for arg in all({...}) do
  s..=tostr(arg)..' '
 end
 printh(s,'log')
end

function pick(t,keys)
 local r={}
 for k in all(keys) do
  r[k]=t[k]
 end
 return r
end

function die(msg)
 assert(false,msg)
end

function copy_table(t)
 return merge_tables({},t)
end

function merge_tables(base,new)
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

function stringify(v)
 local t=type(v)
 if t=='number' or t=='boolean' then
  return tostr(v)
 elseif t=='string' then
  local s='"'
  for i=1,#v do
   local c=sub(v,i,i)
   local o=ord(c)
   -- escape control chars, ", and \
   if o<16 or o==34 or o==92 then
    s..='\\'..chr(o+35)
   else
    s..=c
   end
  end
  s..='"'
  return s
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

function parse(s)
 local p=0
 local reader=function(inc)
  p+=inc or 1
  if p>0x6000 then
   s=sub(s,0x4001)
   p-=0x4000
  end
  return sub(s,p,p)
 end
 return _parse(reader)
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
   if c=='\\' then
    s..=chr(ord(input())-35)
   else
    s..=c
   end
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

-- todo: i think the base case can be inlined and this function can do both?
function map_table_deep(a,f,d)
 if (d==0) return map_table(a,f)
 return map_table(a,function(v) return map_table_deep(v,f,d-1) end)
end

function map_table(a,f)
 local r={}
 for k,v in pairs(a) do
  r[k]=f(v)
 end
 return r
end

function unpack_patch(patch,first,last)
 local r,idx={},1
 for i=first,last do
  -- shift back to 0-1 range
  r[idx]=patch[i]>>7
  idx+=1
 end
 return unpack(r)
end

