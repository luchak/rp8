-->8
-- audio driver

sample_rate=5512.5
_dcf=0

function audio_update()
 if stat(108)<512 then
  local todo,buf,dcf=93,{},_dcf
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
   dcf+=(x-dcf)>>8
   x=mid(-1.5,(x-dcf)>>8,1.5)
   x-=0x0.25ee*x*x*x
   -- dither for nicer tails
   poke(0x42ff+i,flr(x*0x7f.5f80+0.375+(rnd()>>2)+128))
  end
  serial(0x808,0x4300,todo)
  _dcf=dcf
 end
end
