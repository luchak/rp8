function pf_make_r(s)
 local i=0
 local o=8
 local b
 local bit=function()
  if o>7 then
   o=0
   i+=1
   b=ord(s,i)
  end
  local r=(b>>o)&1
  o+=1
  return r
 end
 local num=function(n)
  local r=0
  for i=n-1,0,-1 do
   r|=bit()<<i
  end
  return r
 end
 return {
  bit=bit,
  num=num,
  gamma=function()
   local c=0
   while (bit()<1) c+=1
   return (1<<c) | num(c)
  end,
  done=function()
   return i>=#s
  end
 }
end

function pf_decompress_block(r)
 local s=''
 local mtf={}
 for j=1,256 do
  add(mtf,j-1)
 end
 while true do
  if r.bit()<1 then
   local p=((r.gamma()-1)<<3)|r.num(3)
   if (p==257) return s
   local v=deli(mtf,p)
   s..=chr(v)
   add(mtf,v,1)
  else
   local o=((r.gamma()-1)<<11)|r.num(11)
   local l=r.gamma()+2
   for _=1,l do
    s..=s[-o]
   end
  end
 end
end

function decompress(c)
 local r=pf_make_r(c)
 local s=''
 repeat
  local last=r.bit()>0
  s..=pf_decompress_block(r)
  if (last) return s
 until false
end

