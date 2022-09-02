-->8
-- state

--lint: copy_buf_seq

-- see note 003
eval--[[language::loaf]][[
(set n_off 64)
(set n_on 65)
(set n_ac 66)
(set n_sl 67)
(set n_ac_sl 68)
(set default_patch (' (64 0 64 3 64 128 64 0 0 1 1 1 64 64 64 0 64 64 64 64 64 64 64 0 0 1 1 1 64 64 64 0 64 64 64 64 64 64 64 0 0 1 1 64 127 64 64 64 64 64 64 64 64 64 64 64 64 64 64 64 64 64 64 1 0 128 64 0 1 64 0)))
(set syn_base_idx (' {b0=7,b1=23,dr=39,bd=46,sd=49,hh=52,cy=55,pc=58,fm=61}))
(set pat_param_idx (' {b0=11,b1=27,dr=43}))
(set syn_pat_template (' {
 nt=`(rep 16 19)
 dt=`(rep 16 64)
 st=`(rep 16 64)
 l=16
}))
(set drum_pat_template (' {
 bd={st=`(rep 16 64) dt=`(rep 16 64) l=16}
 sd={st=`(rep 16 64) dt=`(rep 16 64) l=16}
 hh={st=`(rep 16 64) dt=`(rep 16 64) l=16}
 cy={st=`(rep 16 64) dt=`(rep 16 64) l=16}
 pc={st=`(rep 16 64) dt=`(rep 16 64) l=16}
 fm={st=`(rep 16 64) dt=`(rep 16 64) l=16}
}))
]]

function get_ac_mode(note)
 return note==n_ac or note==n_ac_sl,note>=n_sl
end

function state_new(savedata)
 local s=parse--[[language::loon]][[{
  name="new_rp8_song",
  pat_store={},
  tick=1,
  ptick={},
  playing=false,
  base_note_len=750,
  note_len=750,
  drum_sel=bd,
  b0_bank=1,
  b1_bank=1,
  dr_bank=1,
  song_mode=false,
  patch={},
  pat_seqs={},
  pat_status={},
  tl=`(timeline_new $default_patch),
  pat_patch=`(copy $default_patch),
 }]]

 eval--[[language::loaf]][[(fn (s dat)
 (if $dat ((fn ()
  (@= $s name (or (@ $dat name) (@ $s name)))
  (@= $s tl (timeline_new $default_patch (@ $dat tl)))
  (@= $s pat_patch (dec_bytes (@ $dat pat_patch)))
  (@= $s song_mode (@ $dat song_mode))
  (@= (@ $s pat_store) b0 (map_table (@ (@ $dat pat_store) b0) $dec_bytes 1))
  (@= (@ $s pat_store) b1 (map_table (@ (@ $dat pat_store) b1) $dec_bytes 1))
  (@= (@ $s pat_store) dr (map_table (@ (@ $dat pat_store) dr) $dec_bytes 2))
 )))
 (set_song_name (@ $s name))
 )]](s,savedata)

 local function _init_tick()
  local patch=s.patch
  local nl=5512.5*(15/(60+patch[1]))
  local shuf_diff=nl*(patch[2]>>7)*(0.5-(s.tick&1))
  s.note_len,s.base_note_len=flr(0.5+nl+shuf_diff),nl
  local gtick=s.tick+s.bar*16-17
  s.ptick.b0=gtick%(s.pat_seqs.b0.l or 16)+1
  s.ptick.b1=gtick%(s.pat_seqs.b1.l or 16)+1
  for k,p in pairs(s.pat_seqs.dr) do
   s.ptick[k]=gtick%(p.l or 16)+1
  end
 end

 local function _sync_pats()
  local ps,patch=s.pat_store,s.patch
  for syn,param_idx in pairs(pat_param_idx) do
   local syn_pats=ps[syn]
   if not syn_pats then
    syn_pats={}
    s.pat_store[syn]=syn_pats
   end
   local pat_idx=patch[param_idx]
   local pat=syn_pats[pat_idx]
   if not pat then
    pat=(syn=='b0' or syn=='b1') and copy(syn_pat_template) or copy(drum_pat_template)
    syn_pats[pat_idx]=pat
   end
   s.pat_seqs[syn]=pat
  end
  for group,idx in pairs(pat_param_idx) do
   s.pat_status[group]={
    on=patch[idx-1]>0,
    idx=patch[idx],
   }
  end
 end


 function s:load_bar(i)
  local tl=self.tl
  if self.song_mode then
   self.tl:load_bar(self.patch,i)
   self.tick,self.bar=tl.tick,tl.bar
  else
   self.patch=copy(self.pat_patch)
   self.tick,self.bar=1,1
  end
  _sync_pats()
  _init_tick()
 end
 local load_bar=function(i) s:load_bar(i) end

 s._apply_diff=function(k,v)
  s.patch[k]=v
  if s.song_mode then
   s.tl:record_event(k,v)
  else
   s.pat_patch[k]=v
  end
  if (not s.playing) load_bar()
 end

 function s:next_tick()
  local before,tl=self.tick,self.tl
  if self.song_mode then
   tl:next_tick(self.patch,load_bar)
   self.bar,self.tick=tl.bar,tl.tick
  else
   self.tick+=1
   if (self.tick>16) load_bar()
  end
  if (self.tick>before) _init_tick()
 end

 function s:toggle_playing()
  local tl=self.tl
  if self.playing then
   if (tl.rec) tl:toggle_rec()
   tl:clear_overrides()
  else
   seq_helper:reset()
  end
  load_bar()
  self.playing=not self.playing
 end

 function s:toggle_loop()
  self.tl.loop=not self.tl.loop
 end

 function s:toggle_rec()
  self.tl:toggle_rec()
 end

 function s:toggle_song_mode()
  if (self.song_mode) self.tl:clear_overrides()
  self.song_mode=not self.song_mode
  self:stop_playing()
  load_bar()
 end

 function s:go_to_bar(bar)
  load_bar(mid(1,bar,999))
 end

 function s:update_ui_vars()
  -- pats are aliased, always editing current
  self.ui_pats={
   b0=self.pat_seqs.b0,b1=self.pat_seqs.b1,dr=self.pat_seqs.dr[self.drum_sel]
  }
  self.ui_pticks={
   b0=self.ptick.b0,b1=self.ptick.b1,dr=self.ptick[self.drum_sel]
  }
 end

 function s:save()
  return 'rp80'..stringify({
   name=self.name,
   tl=self.tl:get_serializable(),
   song_mode=self.song_mode,
   pat_patch=enc_bytes(self.pat_patch),
   pat_store={
    b0=map_table(self.pat_store.b0,enc_bytes,1),
    b1=map_table(self.pat_store.b1,enc_bytes,1),
    dr=map_table(self.pat_store.dr,enc_bytes,2),
   }
  })
 end

 function s:stop_playing()
  if (self.playing) self:toggle_playing()
 end

 function s:cut_seq()
  set_toast("loop cut")
  self:stop_playing()
  copy_buf_seq=self.tl:cut_seq()
  load_bar()
 end

 function s:copy_seq()
  if self.song_mode then
   set_toast("loop copied")
   copy_buf_seq=self.tl:copy_seq()
  else
   set_toast("pattern copied")
   copy_buf_seq={{
    t0=enc_bytes(self.pat_patch),
    ev={}
   }}
  end
 end

 function s:paste_seq()
  if (not copy_buf_seq) return
  self:stop_playing()
  if self.song_mode then
   set_toast("loop pasted")
   self.tl:paste_seq(copy_buf_seq)
  else
   set_toast("pattern pasted")
   self.pat_patch=dec_bytes(copy_buf_seq[1].t0)
  end
  load_bar()
 end

 function s:insert_seq()
  if (not copy_buf_seq) return
  set_toast("loop inserted")
  self:stop_playing()
  self.tl:insert_seq(copy_buf_seq)
  load_bar()
 end

 function s:clear_overrides()
  set_toast("overrides cleared")
  self.tl:clear_overrides()
  if (not self.playing) self:load_bar()
 end

 function s:commit_overrides()
  set_toast("overrides committed")
  self.tl:commit_overrides()
 end

 load_bar()
 return s
end

state_load=eval--[[language::loaf]][[(fn (s)
 (if (eq (sub $s 1 4) rp80) (state_new (parse (sub $s 5))))
)]]

function transpose_pat(pat,key,d,vmin,vmax)
 for i=1,16 do
  pat[key][i]=mid(vmin,pat[key][i]+d,vmax)
 end
end

function rotate_pat(pat,keys,d)
 local pc=copy(pat)
 for key in all(keys) do
  for i=1,16 do
   pat[key][i]=pc[key][(i-d-1)%16+1]
  end
 end
end

function state_make_get_set_param(idx,lsb,size)
 lsb=lsb or 0
 size=size or 8
 local mask=(1<<(lsb+size))-(1<<lsb)
 return
  function(state) return (state.patch[idx]&mask)>>lsb end,
  function(state,val)
   state._apply_diff(idx,((val<<lsb)&mask) | (state.patch[idx]&(~mask)))
  end
end

function state_make_get_set_param_bool(idx,bit)
 local get,set=state_make_get_set_param(idx,bit or 0,1)
 return
  function(state) return get(state)>0 end,
  function(state,val) set(state, val and 1 or 0) end
end

function state_make_get_set(a,b)
 if b then return
  function(s) return s[a][b] end,
  function(s,v) s[a][b]=v end
 else return
  function(s) return s[a] end,
  function(s,v) s[a]=v end
 end
end

function state_make_get_set_pat_len(syn)
 return
  function(s) return s.ui_pats[syn].l or 16 end,
  function(s,l) s.ui_pats[syn].l=l end
end

state_is_song_mode=function(state) return state.song_mode end

--taf=0.75

-- splits blocks for sample-accurate note triggering
function seq_helper_new(state,root,note_fn)
 local _t,_cost=state.note_len,3
 return {
  state=state,
  root=root,
  reset=function(self) _t=self.state.note_len end,
  run=function(self,b,todo)
   local p=1
   while todo>0 do
    if _t>=self.state.note_len then
     if (todo<_cost) break
     _t=0
     note_fn()
     todo-=_cost
    end
    local n=min(self.state.note_len-_t,todo)
    --local t0=stat(1)
    self.root:update(b,p,p+n-1)
    --local t_audio=(stat(1)-t0)*94/n
    --if (n>50) taf+=0.01*(t_audio-taf) log('tps', taf)
    _t+=n
    p+=n
    todo-=n
   end
   return p-1
  end
 }
end
