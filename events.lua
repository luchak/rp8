-- see notes 001, 002

no_event_params=parse[[{10=true,11=true,22=true,23=true,34=true,35=true}]]

function timeline_new(default_patch, savedata)
 local timeline={
  bars={},
  override_params={},
  def_bar={t0=enc_byte_array(default_patch),ev={}},
  recording=false,
  has_override=false,
  loop_start=1,
  loop_len=4,
  loop=true,
  bar=1
 }

 if (savedata) merge_tables(timeline, savedata)

 timeline.load_bar=function(self,patch,i)
  i=i or self.bar
  local bar_data=self.bars[i] or copy_table(self.def_bar)
  local op=self.override_params
  self.bar_start=merge_tables(dec_byte_array(bar_data.t0),op)
  merge_tables(patch,self.bar_start)
  if self.recording then
   bar_data.t0=enc_byte_array(self.bar_start)
   for k,_ in pairs(op) do
    bar_data.ev[k]=nil
   end
   self.bars[i]=bar_data
  end

  self.bar_events=map_table(bar_data.ev,dec_byte_array)
  self.bar=i
  self.tick=1
 end

 timeline.next_tick=function(self,patch,load_bar)
  self.tick+=1
  local tick=self.tick
  local op=self.override_params
  if tick>16 then
   if self.loop and self.bar==self.loop_start+self.loop_len-1 then
    if (self.recording) self.override_params={}
    load_bar(self.loop_start)
   else
    load_bar(self.bar+1)
   end
   return
  end
  for k,v in pairs(self.bar_events) do
   patch[k]=v[tick]
  end
  merge_tables(patch,op)
  local bars,bar,bar_events,bar_start=self.bars,self.bar,self.bar_events,self.bar_start
  if self.recording then
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

 timeline._finalize_bar=function(self)
  if (not self.bars[self.bar]) self.bars[self.bar]=copy_table(self.def_bar)
  self.bars[self.bar].ev=map_table(self.bar_events,enc_byte_array)
 end

 -- add to overrides
 -- adding to events will be handled in tick/bar handlers if required
 timeline.record_event=function(self,k,v)
  self.override_params[k]=v
  self.has_override=true
 end

 timeline.clear_overrides=function(self)
  self.override_params={}
  self.has_override=false
 end

 timeline.toggle_recording=function(self)
  local sr=self.recording
  if sr then
   if (self.has_override) self:_finalize_bar()
   self:clear_overrides()
  end
  self.recording=not sr
 end

 timeline.cut_seq=function(self)
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

 timeline.copy_seq=function(self)
  local c,bars={},self.bars
  for i=1,self.loop_len do
   local bar=i+self.loop_start-1
   c[i]=copy_table(bars[bar] or self.def_bar)
  end
  return c
 end

 timeline.paste_seq=function(self,seq)
  local n=#seq
  for i=0,self.loop_len-1 do
   local bar=self.loop_start+i
   self.bars[bar]=copy_table(seq[i%n+1])
  end
 end

 timeline.copy_overrides_to_loop=function(self)
  local op=self.override_params
  for i=0,self.loop_len-1 do
   local bar_idx=self.loop_start+i
   local bar=self.bars[bar_idx] or copy_table(self.def_bar)
   bar.t0=enc_byte_array(merge_tables(dec_byte_array(bar.t0),op))
   for k,_ in pairs(op) do
    bar.ev[k]=nil
   end
   self.bars[bar_idx]=bar
  end
  self:clear_overrides()
 end

 timeline.insert_seq=function(self,seq)
  local bs,ls,ll,nbs=
   self.bars,
   self.loop_start,
   self.loop_len,
   {}
  for i,b in pairs(bs) do
   if i>=ls then
    nbs[i+ll]=b
   else
    nbs[i]=b
   end
  end
  self.bars=nbs
  self:paste_seq(seq)
 end

 timeline.get_serializable=function(self)
  return pick(self, parse[[{1="bars",2="def_bar",3="loop_start",4="loop_len",5="loop"}]])
 end

 return timeline
end
