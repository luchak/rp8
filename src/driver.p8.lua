-->8
-- audio driver

_dcf=0

function audio_update()
 if stat(108)<768 then
  local todo,buf,dcf,lfsr=94,{},_dcf,_lfsr
  if audio_root then
   todo=audio_root:run(buf,todo)
  else
   for i=1,todo do
    buf[i]=0
   end
  end
  for i=1,todo do
   -- dc filter and soft clipping
   local x=buf[i]<<8
   x=(x-dcf)>>8
   dcf+=x
   local m=x>>31
   x=x^^m<1.5 and x or 1.5^^m
   x-=0x0.25ee*x*x*x
   lfsr=lfsr~(lfsr*0x70.00f)
   -- dither for nicer tails
   poke(0x42ff+i,(x*0x7f.5f80+(lfsr&0x0.3fff)+128.375)&-1)
  end
  serial(0x808,0x4300,todo)
  _dcf,_lfsr=dcf,lfsr
 end
end
