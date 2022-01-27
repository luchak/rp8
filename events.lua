local function event_enc(t,k,v)
 return t | (k>>>8) | (v>>>16)
end

local function event_dec(e)
 return e&0xffff,(e&0x0.ff)<<8,(e&0x0.00ff)<<16
end

function enc_byte_array(a)
 local adjusted={}
 for i=1,#a do
  adjusted[i]=a[i]+40
 end
 return chr(unpack(adjusted))
end

function dec_byte_array(s)
 local a={}
 for i=1,#s do
  a[i]=ord(s,i)-40
 end
 return a
end

function map(a,f)
 local r={}
 for k,v in pairs(a) do
  r[k]=f(v)
 end
 return r
end

function copy_table(t)
 return merge_tables({},t)
end

function merge_tables(base,new,do_copy)
 if (do_copy) base=copy_table(base)
 if (not new) return base
 for k,v in pairs(new) do
  if type(v)=='table' then
   local bk=base[k]
   if type(bk)=='table' then
    merge_tables(bk,v)
   else
    base[k]=copy_table(v)
   end
  else
   base[k]=v
  end
 end
 return base
end


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
function timeline_new(default_start)
 local timeline={
  bars={},
  override_params={},
  default_start=enc_byte_array(default_start),
  recording=false,
  has_override=false
 }

 timeline.load_bar=function(self,i)
  local bar_data=self.bars[i] or {
   start=self.default_start,
   events={}
  }
  local op=self.override_params
  self.bar_start=merge_tables(dec_byte_array(bar_data.start),op)
  if self.recording then
   bar_data.start=enc_byte_array(self.bar_start)
   for k,_ in pairs(self.override_params) do
    bar_data.events[k]=nil
   end
   self.bars[i]=bar_data
  end

  self.bar_events=map(bar_data.events,dec_byte_array)
  self.state=copy_table(self.bar_start)
  self.bar=1
  self.tick=1
 end

 timeline.next_tick=function(self,i,next_bar)
  self.tick+=1
  local tick=self.tick
  local op=self.override_params
  if (tick>16) return self:load_bar(next_bar)
  for k,v in pairs(self.bar_events) do
   self.state[k]=v[tick]
  end
  merge_tables(self.state,op)
  local bars,bar,bar_events=self.bars,self.bar,self.bar_events
  if self.recording then
   for k,v in pairs(op) do
    local ek=bar_events[k]
    if not ek then
     local s=self.bar_start[k]
     ek={}
     for i=1,16 do
      ek[i]=s
     end
     bar_events[k]=ek
    end
    ek[tick]=v
   end
   if tick==16 then
    self:_finalize_bar()
   end
  end
 end

 timeline._finalize_bar=function(self)
  print('finalize bar '..self.bar)
  assert(self.bars[self.bar])
  assert(self.bar_start)
  assert(self.bar_events)
  self.bars[self.bar].events=map(self.bar_events,enc_byte_array)
 end

 -- add to overrides
 -- if recording, set in bar events
 timeline.record_event=function(self,k,v)
  self.override_params[k]=v
 end

 timeline.toggle_recording=function(self)
  if self.recording then
   if (self.has_override) self:_finalize_bar()
   self.override_params={}
   self.has_override=false
  end
  self.recording=not self.recording
 end

 return timeline
end
