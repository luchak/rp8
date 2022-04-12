-->8
-- utils

function log(...)
 local s=''
 for arg in all({...}) do
  s..=tostr(arg)..' '
 end
 printh(s,'log')
end

function trn(c,t,f)
 if (c) return t else return f
end

function copy(t)
 return merge({},t)
end

function merge(base,new)
 for k,v in pairs(new) do
  if type(v)=='table' then
   local bk=base[k]
   if type(bk)=='table' then merge(bk,v) else base[k]=copy(v) end
  else
   base[k]=v
  end
 end
 return base
end

function unpack_split(s)
 return unpack(split(s))
end

function enc_bytes(a)
 return chr(unpack(a))
end

function dec_bytes(s)
 local a={}
 for i=1,#s do a[i]=ord(s,i) end
 return a
end

function map_table(a,f,d)
 if (d or 0)==0 then
  local r={}
  for k,v in pairs(a) do r[k]=f(v) end
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

function stringify(v)
 local t=type(v)
 if t=='number' or t=='boolean' then return tostr(v)
 elseif t=='string' then
  local s='"'
  for i=1,#v do
   local c=sub(v,i,i)
   local o=ord(c)
   -- escape control chars, ", and \
   if o<16 or o==34 or o==92 then s..='\\'..chr(o+35) else s..=c end
  end
  return s..'"'
 elseif t=='table' then
  local s='{'
  for k,v in pairs(v) do
   s..=k..'='..stringify(v)..','
  end
  return s..'}'
 else
  return t..'[?]'
 end
end

function is_num(c)
 return (c>='0' and c<='9') or c=='.' or c=='-'
end

function is_id(c)
 return not (is_sep(c) or c=='}' or c==')' or  c=='')
end

function is_sep(c)
 return c==' ' or c=='\n' or c=='\t' or c==','
end

function consume(r,test,c)
 local s=''
 c=c or ''
 repeat
  if (c=='\\') c=chr(ord(r())-35)
  s..=c
  c=r()
 until not test(c)
 return s
end

function parse(s)
 local p=0
 local read=function(d)
  p+=d or 1
  if p>0x6000 then
   s=sub(s,0x4001)
   p-=0x4000
  end
  return sub(s,p,p)
 end

 local function _parse()
  local c
  local function skip()
   repeat c=read() until not is_sep(c)
  end
  skip()
  if c=='"' then
   return consume(read,function (c) return c!='"' end)
  elseif is_num(c) then
   local s=consume(read,is_num,c)
   read(-1)
   return tonum(s)
  elseif c=='(' then
   local t={}
   repeat
    skip()
    if (c==')') return t
    read(-1)
    add(t,_parse())
   until false
  elseif c=='{' then
   local t={}
   repeat
    skip()
    if (c=='}') return t
    local k=consume(read,function (c) return c!='=' end,c)
    k=tonum(k) or k
    t[k]=_parse()
   until false
  elseif c=='`' then
   return _eval_scope(_parse(),{})
  else
   -- allow (most) bare strings
   local s=consume(read,is_id,c)
   read(-1)
   if (s=='true') return true
   if (s=='false') return false
   if (s=='nil') return nil
   return s
  end
 end

 return _parse()
end

function eq(a1,a2) return a1==a2 end
function gt(a1,a2) return a1>a2 end
function cat(a1,a2) return a1..a2 end

function _eval_scope(ast,locals)
 local builtins={
  ['+']=function(a1,a2) return a1+a2 end,
  ['*']=function(a1,a2) return a1*a2 end,
  ['not']=function(a1) return not a1 end,
  ['or']=function(a1,a2) return a1 or a2 end,
  ['@']=function(a1,a2,a3) if a3 then return a1[a2][a3] else return a1[a2] end end,
  ['@=']=function(a1,a2,a3) a1[a2]=a3 end,
  ['for']=function(a1,a2,a3) for i=a1,a2 do a3(i) end end,
  set=function(a1,a2) _ENV[a1]=a2 end,
  let=function(a1,a2) locals[a1]=a2 end,
 }

 local function lookup(s)
  return locals[s] or _ENV[s] or builtins[s]
 end
 local function eval_node(node)
  if sub(node,1,1)=='$' then
   return lookup(sub(node,2))
  end

  if (type(node)!='table') return node

  local cmd,a1,a2,a3=unpack(node)

  if cmd=='\'' then
   return a1
  elseif cmd=='if' then
   if (eval_node(a1)) return eval_node(a2) else return eval_node(a3)
  elseif cmd=='fn' then
   return function(...)
    local args,new_locals={...},{}
    for k,v in pairs(locals) do
     new_locals[k]=v
    end
    for k,v in ipairs(a1) do
     new_locals[v]=args[k]
    end
    return _eval_scope(a2,new_locals)
   end
  end

  cmd=eval_node(cmd)
  local vals={}
  for i=2,#node do
   local ret={eval_node(node[i])}
   for rv in all(ret) do
    add(vals,rv)
   end
  end

  if type(cmd)=='string' then
   cmd=lookup(cmd)
  end

  if type(cmd)=='function' then
   return cmd(unpack(vals))
  else
   return vals[#vals]
  end
 end

 return eval_node(ast)
end

function eval(src)
 return _eval_scope(parse(src),{})
end

function take(i,...)
 return pack(...)[i]
end

eval[[(
(set make_obj_cb (fn (n) (fn (o) ((@ $o $n) $o))))
(set rep (fn (n x) (
 (let a (pack))
 (for 1 $n (fn () (add $a $x)))
 $a
)))
)]]

