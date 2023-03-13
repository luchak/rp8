-- see notes 001, 002

eval--[[language::loaf]][[
(set no_event_params (' {10=true,11=true,26=true,27=true,42=true,43=true}))
(set has_event_params_list (pack))
(for 1 71 (fn (i)
 (if (@ $no_event_params $i) (id) (add $has_event_params_list $i))
))
]]

function timeline_new(default_patch, savedata)
 local timeline=parse--[[language::loon]][[{
  bars={},
  def_bar={t0=`(enc_bytes $default_patch),ev={}},
  loop_start=1,
  loop_len=4,
  loop=true,
  bar=1
 }]]

 if (savedata) merge(timeline, savedata)

 function timeline:load_bar(patch,i)
  i=i or self.bar
  local bar_data=self.bars[i] or copy(self.def_bar)
  bar_data.t0..=sub(self.def_bar.t0,#bar_data.t0+1)
  self.bar_start=merge(dec_bytes(bar_data.t0),op)
  merge(patch,self.bar_start)

  self.bar_events=map_table(bar_data.ev,dec_bytes)
  self.bar=i
  self.tick=1
 end

 function timeline:next_tick(patch,load_bar)
  self.tick+=1
  local tick=self.tick
  if tick>16 then
   if self.loop and self.bar==self.loop_start+self.loop_len-1 then
    load_bar(self.loop_start)
   else
    load_bar(self.bar+1)
   end
   return
  end
  for k,v in pairs(self.bar_events) do
   patch[k]=v[tick]
  end
 end

 return timeline
end
