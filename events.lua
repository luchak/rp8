-- see notes 001, 002

eval--[[language::loaf]][[
(set no_event_params (' {10=true,11=true,26=true,27=true,42=true,43=true}))
]]

function timeline_new(default_patch, savedata)
 local timeline=parse--[[language::loon]][[{
  bars={},
  overrides={},
  def_bar={t0=`(enc_bytes $default_patch),ev={}},
  rec=false,
  has_override=false,
  loop_start=1,
  loop_len=4,
  loop=true,
  bar=1
 }]]

 if (savedata) merge(timeline, savedata)

 function timeline:load_bar(patch,i)
  i=i or self.bar
  local bar_data=self.bars[i] or copy(self.def_bar)
  local op=self.overrides
  bar_data.t0..=sub(self.def_bar.t0,#bar_data.t0+1)
  self.bar_start=merge(dec_bytes(bar_data.t0),op)
  merge(patch,self.bar_start)
  if self.rec then
   bar_data.t0=enc_bytes(self.bar_start)
   for k,_ in pairs(op) do
    bar_data.ev[k]=nil
   end
   self.bars[i]=bar_data
  end

  self.bar_events=map_table(bar_data.ev,dec_bytes)
  self.bar=i
  self.tick=1
 end

 function timeline:next_tick(patch,load_bar)
  self.tick+=1
  local tick=self.tick
  local op=self.overrides
  if tick>16 then
   if self.loop and self.bar==self.loop_start+self.loop_len-1 then
    if (self.rec) self.overrides={}
    load_bar(self.loop_start)
   else
    load_bar(self.bar+1)
   end
   return
  end
  for k,v in pairs(self.bar_events) do
   patch[k]=v[tick]
  end
  merge(patch,op)
  local bar_events,bar_start=self.bar_events,self.bar_start
  if self.rec then
   for k,v in pairs(op) do
    if not no_event_params[k] then
     local ek,bsk=bar_events[k],bar_start[k]
     if v!=bsk then
      if not ek then
       ek={}
       for i=1,16 do
        ek[i]=bsk
       end
       bar_events[k]=ek
      end
      ek[tick]=v
     end
    end
   end
   if tick==16 then
    self:_finalize_bar()
   end
  end
 end

 function timeline:_finalize_bar()
  self.bars[self.bar]=self.bars[self.bar] or copy(self.def_bar)
  self.bars[self.bar].ev=map_table(self.bar_events,enc_bytes)
 end

 -- add to overrides
 -- events will be collected in tick/bar handlers
 function timeline:record_event(k,v)
  self.overrides[k]=v
  self.has_override=true
 end

 eval--[[language::loaf]][[(fn (timeline) (@= $timeline clear_overrides
 (fn (self) (@= $self overrides (pack)) (@= $self has_override false))
 ))]](timeline)

 function timeline:toggle_rec()
  local sr=self.rec
  if sr then
   if (self.has_override) self:_finalize_bar()
   self:clear_overrides()
  end
  self.rec=not sr
 end

 function timeline:cut_seq()
  local ls,ll=self.loop_start,self.loop_len
  local cut_end,c,nbs=ls+ll,self:copy_seq(),{}
  for i,b in pairs(self.bars) do
   if i>=ls then
    if i>=cut_end then
     nbs[i-ll]=b
    end
   else
    nbs[i]=b
   end
  end
  self.bars=nbs
  return c
 end

 function timeline:copy_seq()
  local c,bars={},self.bars
  for i=1,self.loop_len do
   local bar=i+self.loop_start-1
   c[i]=copy(bars[bar] or self.def_bar)
  end
  return c
 end

 function timeline:paste_seq(seq)
  local n=#seq
  for i=0,self.loop_len-1 do
   local bar=self.loop_start+i
   self.bars[bar]=copy(seq[i%n+1])
  end
 end

 function timeline:commit_overrides()
  local op=self.overrides
  for i=0,self.loop_len-1 do
   local bar_idx=self.loop_start+i
   local bar=self.bars[bar_idx] or copy(self.def_bar)
   bar.t0=enc_bytes(merge(dec_bytes(bar.t0),op))
   for k,_ in pairs(op) do
    bar.ev[k]=nil
   end
   self.bars[bar_idx]=bar
  end
  self:clear_overrides()
 end

 function timeline:insert_seq(seq)
  local bs,ls,ll,nbs=
   self.bars,
   self.loop_start,
   self.loop_len,
   {}
  for i,b in pairs(bs) do
   nbs[i>=ls and i+ll or i]=b
  end
  self.bars=nbs
  self:paste_seq(seq)
 end

 function timeline:get_serializable()
  local r={}
  for k in all(split'bars,def_bar,loop_start,loop_len,loop') do
   r[k]=self[k]
  end
  return r
 end

 return timeline
end
