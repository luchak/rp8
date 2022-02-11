--[[
 each chunk contains (1) a rollup of the current state at its start, and (2) an _unsorted_ array of events (conflict: later wins)
 when a chunk is loaded, we scan its whole list of events and stick them in a table indexed by tick.
 duplicates can be discovered at this time and eliminated (rule: last event wins)
 with 64 event types and k events per bar, a chunk size of n bars gets us a size-64 array every n bars, plus a size 2^ceil(log_2 kn) events list
 so that's 8*(64/n+2^ceil(log_2 kn)/n) -> (512+2^(3+ceil(log_2 k + log_2 n)))/n bytes per bar
]]

-- a bar is
-- snapshot: string
-- events: table<k=param_idx, v=event_string>
-- everything is passed in as a number array
-- a new bar is just an array of n_params numbers
-- an event is a (param, value) pair
function timeline_new(default_patch, savedata)
 local timeline={
  bars={},
  override_params={},
  default_bar={start=enc_byte_array(default_patch),events={}},
  recording=false,
  has_override=false,
  loop_start=1,
  loop_len=4,
  looping=true,
  bar=1
 }

 if (savedata) merge_tables(timeline, savedata)

 timeline.load_bar=function(self,patch,i)
  i=i or self.bar
  local bar_data=self.bars[i] or copy_table(self.default_bar)
  local op=self.override_params
  self.bar_start=merge_tables(dec_byte_array(bar_data.start),op)
  merge_tables(patch,self.bar_start)
  if self.recording then
   bar_data.start=enc_byte_array(self.bar_start)
   for k,_ in pairs(op) do
    bar_data.events[k]=nil
   end
   self.bars[i]=bar_data
  end

  self.bar_events=map_table(bar_data.events,dec_byte_array)
  self.bar=i
  self.tick=1
 end

 timeline.next_tick=function(self,patch,load_bar)
  self.tick+=1
  local tick=self.tick
  local op=self.override_params
  if tick>16 then
   if self.looping and self.bar==self.loop_start+self.loop_len-1 then
    load_bar(self.loop_start)
    if (self.recording) self.override_params={}
   else
    load_bar(self.bar+1)
   end
   return
  end
  for k,v in pairs(self.bar_events) do
   patch[k]=v[tick]
  end
  merge_tables(patch,op)
  local bars,bar,bar_events=self.bars,self.bar,self.bar_events
  if self.recording then
   for k,v in pairs(op) do
    local ek,bsk=bar_events[k],self.bar_start[k]
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
   if tick==16 then
    self:_finalize_bar()
   end
  end
 end

 timeline._finalize_bar=function(self)
  if (not self.bars[self.bar]) self.bars[self.bar]=copy_table(self.default_bar)
  assert(self.bar_start)
  assert(self.bar_events)
  self.bars[self.bar].events=map_table(self.bar_events,enc_byte_array)
 end

 -- add to overrides
 -- if recording, set in bar events
 timeline.record_event=function(self,k,v)
  self.override_params[k]=v
  self.has_override=true
 end

 timeline.toggle_recording=function(self)
  local sr=self.recording
  if sr then
   if (self.has_override) self:_finalize_bar()
   self.override_params={}
   self.has_override=false
  end
  self.recording=not sr
 end

 timeline.cut_seq=function(self)
  assert(not self.recording)
  local c=self:copy_seq(cut_start,cut_end)
  local nbs={}
  for i,b in pairs(self.bars) do
   if i>=cut_start then
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
   c[i]=copy_table(bars[bar] or self.default_bar)
  end
  log('copied',stringify(c))
  return c
 end

 timeline.paste_seq=function(self,seq)
  local n=#seq
  for i=0,self.loop_len-1 do
   local bar=self.loop_start+i
   self.bars[bar]=copy_table(seq[i%n+1])
  end
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
  log('nbs',stringify(self.bars))
  self:paste_seq(seq)
  log('post paste',stringify(self.bars))
 end

 timeline.get_serializable=function(self)
  return pick(self, parse[[{1="bars",2="default_bar",3="loop_start",4="loop_len",5="looping"}]])
 end

 return timeline
end
