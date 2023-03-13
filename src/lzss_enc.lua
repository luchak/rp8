function pf_make_w()
 local i=0
 local b=0
 local s=''
 local bit=function(x)
  b|=x<<i
  i+=1
  if i>7 then
   i=0
   s..=chr(b)
   b=0
  end
 end
 local num=function(x,n)
  for i=n-1,0,-1 do
   bit((x>>i)&1)
  end
 end
 return {
  bit=bit,
  num=num,
  gamma=function(x)
   local p=2
   local c=1
   while (p<=x) p<<=1 bit(0) c+=1
   num(x,c)
  end,
  done=function()
   if i!=0 then
    s..=chr(b)
   end
   return s
  end
 }
end

function pf_compress_block(s,w)
 local pre={}
 local i=1
 local mtf={}
 for j=1,256 do
  add(mtf,j-1)
 end
 while s[i] do
  local key=sub(s,i,i+2)
  local starts=pre[key] or {}
  pre[key]=starts
  local o,l
  for sp in all(starts) do
   for j=0,1027 do
    if s[i+j]!=s[sp+j%(i-sp)] then
     if j>(l or 3) then
      l=j-1
      o=i-sp
     end
     break
    end
   end
  end
  if o then
   w.bit(1)
   w.gamma(o\2048+1)
   w.num(o&2047,11)
   w.gamma(l-2)
  else
   w.bit(0)
   local j=1
   local v=ord(s[i])
   while (mtf[j]!=v) j+=1
   w.gamma(j\8+1)
   w.num(j&7,3)
   deli(mtf,j)
   add(mtf,v,1)
  end

  for j=1,l or 1 do
   add(starts,i,1)
   i+=1
  end
 end
 w.bit(0)
 w.gamma(33)
 w.num(1,3)
end

function compress(s)
 local w=pf_make_w()
 while s[1] do
  local next_s=sub(s,32767)
  w.bit(next_s[1] and 0 or 1)
  pf_compress_block(sub(s,1,32766),w)
  s=next_s
 end
 return w.done()
end

