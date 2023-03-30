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
  if self.rec then
   for k,v in pairs(op) do
    if not no_event_params[k] then
     local ek,bsk=self.bar_events[k],self.bar_start[k]
     if v!=bsk then
      if not ek then
       ek={}
       for i=1,16 do
        ek[i]=bsk
       end
       self.bar_events[k]=ek
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

 eval--[[language::loaf]][[(fn (timeline)
  (@= $timeline clear_overrides
   (fn (self) (@= $self overrides (pack)) (@= $self has_override false))
  )

  (@= $timeline toggle_rec (fn (self)
   (if (@ $self rec) (seq
    (if (@ $self has_override) ((@ $self _finalize_bar) $self))
    ((@ $self clear_overrides) $self)
   ))
   (@= $self rec (not (@ $self rec)))
  ))
 )]](timeline)

 function timeline:cut_seq()
  local cut_end,c,nbs=self.loop_start+self.loop_len,self:copy_seq(),{}
  for i,b in pairs(self.bars) do
   if i>=self.loop_start then
    if i>=cut_end then
     nbs[i-self.loop_len]=b
    end
   else
    nbs[i]=b
   end
  end
  self.bars=nbs
  return c
 end

 function timeline:copy_seq()
  local c={}
  for i=1,self.loop_len do
   local bar=i+self.loop_start-1
   c[i]=copy(self.bars[bar] or self.def_bar)
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

 function timeline:paste_ctrls(seq,ctrls)
  local n=#seq
  for i=0,self.loop_len-1 do
   local bar_idx=self.loop_start+i
   local bar,src_bar=self.bars[bar_idx] or copy(self.def_bar),seq[i%n+1]
   local t0,src_t0=dec_bytes(bar.t0),dec_bytes(src_bar.t0)
   for ctrl in all(ctrls) do
    t0=merge(t0,{[ctrl]=src_t0[ctrl]})
    bar.ev[ctrl]=src_bar.ev[ctrl]
   end
   bar.t0=enc_bytes(t0)
   self.bars[bar_idx]=bar
  end
 end

 function timeline:commit_overrides()
  local ctrls={}
  for k,_ in pairs(self.overrides) do add(ctrls,k) end
  self:paste_ctrls({{t0=enc_bytes(merge(dec_bytes(self.def_bar.t0), self.overrides)), ev={}}}, ctrls)
  self:clear_overrides()
 end

 function timeline:insert_seq(seq)
  local nbs={}
  for i,b in pairs(self.bars) do
   nbs[i>=self.loop_start and i+self.loop_len or i]=b
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
