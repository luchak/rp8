-->8
-- utils

function log(...)
 local s=''
 for arg in all({...}) do
  s..=tostr(arg)..' '
 end
 printh(s,'log')
end

function copy(t)
 return merge({},t)
end

function merge(base,new)
 if (not new) return base
 for k,v in pairs(new) do
  if type(v)=='table' then
   local bk=base[k]
   if type(bk)=='table' then
    merge(bk,v)
   else
    base[k]=copy(v)
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
  return '[?]'
 end
end

function parse(s)
 local p=0
 local reader=function(d)
  p+=d or 1
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

function is_sep(c)
 return c==' ' or c=='\n' or c=='\t' or c==','
end

function consume(r,test,s)
 s=s or ''
 repeat
  local c=r()
  if (not test(c)) return s
  if (c=='\\') c=chr(ord(r())-35)
  s..=c
 until false
end

-- make sure to always use
-- " (not ') when hand serializing
function _parse(input)
 local c
 repeat
  c=input()
 until not is_sep(c)
 if c=='"' then
  return consume(input,function (c) return c!='"' end)
 elseif c=='-' or is_digit(c) then
  local s=consume(input,is_digit,c)
  input(-1)
  return tonum(s)
 elseif c=='{' then
  local t={}
  repeat
   repeat
    c=input()
   until not is_sep(c)
   if (c=='}') return t
   local k=consume(input,function (c) return c!='=' end,c)
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
  assert(nil,'cannot parse, c="'..c..'"')
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

function map_table(a,f,d)
 d=d or 0
 if d==0 then
  local r={}
  for k,v in pairs(a) do
   r[k]=f(v)
  end
  return r
 end
 return map_table(a,function(v) return map_table(v,f,d-1) end)
end

function unpack_patch(patch,first,last)
 local r={}
 for i=first,last do
  -- shift to 0-1 range
  add(r,patch[i]>>7)
 end
 return unpack(r)
end

function pow3(x) return x*x*x end
function pow4(x) return pow3(x)*x end
