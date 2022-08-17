-->8
-- utils

function log(...)
 for arg in all({...}) do
  printh(tostr(arg)..' \0','log')
 end
 printh('','log')
end

-- be careful, both t and f get evaluated
function trn(c,t,f)
 if (c) return t else return f
end

function copy(t)
 return merge({},t)
end

function merge(base,new)
 for k,v in pairs(new) do
  if type(v)=='table' then
   if type(base[k])=='table' then merge(base[k],v) else base[k]=copy(v) end
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
 if (type(a)=='number') return a
 return chr(unpack(a))
end

function dec_bytes(s)
 if (type(s)=='number') return s
 return {ord(s,1,#s)}
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

function stringify(v)
 local t=type(v)
 if t=='number' or t=='boolean' then return tostr(v)
 elseif t=='string' then
  local s='"'
  for i=1,#v do
   local c=sub(v,i,i)
   local o=ord(c)
   -- escape non-printables, ", and \
   if o<35 or o==92 or o>126 then s..='\\'..chr(48+(o>>4&0x0f),48+(o&0x0f)) else s..=c end
  end
  return s..'"'
 elseif t=='table' then
  local s='{'
  for vk,vv in pairs(v) do
   s..=vk..'='..stringify(vv)..','
  end
  return s..'}'
 else
  -- won't parse, but nice for debugging
  return t..'[?]'
 end
end

function mkmatch(s,inv)
 return function(c)
  for i=1,#s do
   if (c==sub(s,i,i)) return not inv
  end
  return inv
 end
end

is_num=mkmatch'0123456789.-'
is_id=mkmatch(' \r\n\t,)}',true)
is_sep=mkmatch' \r\n\t,'

function parse(s)
 local p=0

 local function read(d)
  p+=d or 1
  if p>0x6000 then
   s=sub(s,0x4001)
   p-=0x4000
  end
  return sub(s,p,p)
 end

 local function consume(test)
  local ss,c='',''
  repeat
   if (c=='\\') c=chr(ord(read())-48<<4 | ord(read())-48)
   ss..=c
   c=read()
  until not test(c)
  return ss
 end

 local function _parse()
  local c
  local function skip()
   repeat c=read() until not is_sep(c)
  end
  skip()
  if c=='"' then
   return consume(mkmatch('"',true))
  elseif is_num(c) then
   local n=c..consume(is_num)
   read(-1)
   return tonum(n)
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
    read(-1)
    local k=consume(mkmatch('=',true))
    t[tonum(k) or k]=_parse()
   until false
  elseif c=='`' then
   return _eval_scope({_parse()},{})
  else
   -- allow (most) bare strings
   local b=c..consume(is_id)
   read(-1)
   if (b=='true') return true
   if (b=='false') return false
   if (b=='nil') return nil
   return b
  end
 end

 return _parse()
end

nil_value = '__NIL_VALUE__'

function _eval_scope(ast,locals,start)
 local function eval_node(node)
  if sub(node,1,1)=='$' then
   local name=sub(node,2)
   local val=locals[name] or _ENV[name]
   if (val==nil_value) return nil else return val
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
     local val=args[k]
     if (val==nil) val=nil_value
     new_locals[v]=val
    end
    return _eval_scope(node,new_locals,3)
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

  local v1,v2,v3=unpack(vals)

  if cmd=='seq' then return vals[#vals]
  elseif cmd=='+' then return v1+v2
  elseif cmd=='*' then return v1*v2
  elseif cmd=='~' then return v1-v2
  elseif cmd=='not' then return not v1
  elseif cmd=='or' then return v1 or v2
  elseif cmd=='@' then if v3 then return v1[v2][v3] else return v1[v2] end
  elseif cmd=='@=' then v1[v2]=v3
  elseif cmd=='for' then for i=v1,v2 do v3(i) end
  elseif cmd=='set' then _ENV[v1]=v2
  elseif cmd=='let' then if v2==nil then locals[v1]=nil_value else locals[v1]=v2 end
  elseif cmd=='eq' then return v1==v2
  elseif cmd=='gt' then return v1>v2
  elseif cmd=='cat' then if v3 then return v1..v2..v3 else return v1..v2 end
  elseif cmd=='len' then return #v1
  else
   if type(cmd)=='string' then
    cmd=locals[cmd] or _ENV[cmd]
   end

   return cmd(unpack(vals))
  end
 end

 for i=start or 1,#ast-1 do eval_node(ast[i]) end
 return eval_node(ast[#ast])
end

function eval(src)
 local parsed=parse('(seq '..src..')')
 return _eval_scope(parsed,{})
end

function take(i,...)
 return pack(...)[i]
end

function pow3(x) return x*x*x end
function pow4(x) return pow3(x)*x end

eval--[[language::loaf]][[
(set make_obj_cb (fn (n) (fn (o) ((@ $o $n) $o))))
(set rep (fn (n x)
 (let a (pack))
 (for 1 $n (fn () (add $a $x)))
 $a
))
(set id (fn (x) $x))
(set mcall (fn (obj m) ((@ $obj $m) $obj)))
]]
