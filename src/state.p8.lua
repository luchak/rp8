-->8
-- state

--lint: copy_buf_seq

-- see note 003
eval--[[language::loaf]][[
(set default_patch (' (64 0 64 3 64 128 64 0 0 1 1 1 64 64 64 0 64 64 64 64 64 64 64 0 0 1 1 1 64 64 64 0 64 64 64 64 64 64 64 0 0 1 1 64 127 64 64 64 64 64 64 64 64 64 64 64 64 64 64 64 64 64 64 1 0 128 64 0 0 64 0)))
(set syn_base_idx (' {b0=7,b1=23,dr=39,bd=46,sd=49,hh=52,cy=55,pc=58,fm=61}))
(set pat_param_idx (' {b0=11,b1=27,dr=43}))
(set syn_pat_template (' {
 nt=`(rep 16 19)
 st=`(rep 16 64)
 dt=`(rep 16 64)
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
 return note==66 or note==68,note>=67
end

function _init_tick()
 local nl=5512.5*(15/(60+state.patch[1]))
 local shuf_diff=nl*(state.patch[2]>>7)*(0.5-(state.tick&1))
 state.note_len,state.base_note_len=flr(0.5+nl+shuf_diff),nl
 local gtick=state.tick+state.bar*16-17
 state.ptick.b0=gtick%(state.pat_seqs.b0.l or 16)+1
 state.ptick.b1=gtick%(state.pat_seqs.b1.l or 16)+1
 for k,p in pairs(state.pat_seqs.dr) do
  state.ptick[k]=gtick%(p.l or 16)+1
 end
end

function _sync_pats()
 local ps,patch=state.pat_store,state.patch
 for syn,param_idx in pairs(pat_param_idx) do
  local syn_pats=ps[syn]
  if not syn_pats then
   syn_pats={}
   state.pat_store[syn]=syn_pats
  end
  local pat_idx=patch[param_idx]
  local pat=syn_pats[pat_idx]
  if not pat then
   pat=(syn=='b0' or syn=='b1') and copy(syn_pat_template) or copy(drum_pat_template)
   syn_pats[pat_idx]=pat
  end
  state.pat_seqs[syn]=pat
 end
 for group,idx in pairs(pat_param_idx) do
  state.pat_status[group]={
   on=patch[idx-1]>0,
   idx=patch[idx],
  }
 end
end

load_bar=function(i)
 local tl=state.tl
 if state.song_mode then
  tl:load_bar(state.patch,i)
  state.tick,state.bar=tl.tick,tl.bar
 else
  state.patch=copy(state.pat_patch)
  state.tick,state.bar=1,1
 end
 _sync_pats()
 _init_tick()
end


function state_new(savedata)
 local s=parse--[[language::loon]][[{
  name="new song",
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

 eval--[[language::loaf]][[(fn (st dat)
 (if $dat ((fn ()
  (@= $st name (or (@ $dat name) (@ $st name)))
  (@= $st tl (timeline_new $default_patch (@ $dat tl)))
  (@= $st pat_patch (dec_bytes (@ $dat pat_patch)))
  (@= $st song_mode (@ $dat song_mode))
  (@= (@ $st pat_store) b0 (map_table (@ $dat pat_store b0) $dec_bytes 1))
  (@= (@ $st pat_store) b1 (map_table (@ $dat pat_store b1) $dec_bytes 1))
  (@= (@ $st pat_store) dr (map_table (@ $dat pat_store dr) $dec_bytes 2))
 )))
 (set_song_name (@ $st name))
 )]](s,savedata)

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

 state=s
 load_bar()
end

eval--[[language::loaf]][[
(set toggle_loop
 (fn () (@= (@ $state tl) loop (not (@ $state tl loop))))
)
(set toggle_rec
 (fn () (log a) ((@ $state tl toggle_rec) (@ $state tl)))
)
(set toggle_song_mode
 (fn ()
  (if (@ $state song_mode) ((@ $state tl clear_overrides) (@ $state tl)))
  (@= $state song_mode (not (@ $state song_mode)))
  (if (@ $state playing) (toggle_playing))
  (load_bar)
 )
)
(set go_to_bar
 (fn (bar)
  (load_bar ($mid 1 $bar 999))
 )
)
(set cut_seq
 (fn ()
  (set_toast "loop cut")
  (set copy_buf_seq ((@ $state tl cut_seq) (@ $state tl)))
  (if (not (@ $state playing)) (load_bar))
 )
)
(set copy_seq
 (fn ()
  (if (@ $state song_mode)
   (seq
    (set_toast "loop copied")
    (set copy_buf_seq ((@ $state tl copy_seq) (@ $state tl)))
   )
   (seq
    (set_toast "pattern copied")
    (let copy_bar (tab))
    (@= $copy_bar t0 (enc_bytes (@ $state pat_patch)))
    (@= $copy_bar ev (tab))
    (set copy_buf_seq (tab))
    (add $copy_buf_seq $copy_bar)
   )
  )
 )
)
(set copy_loop_begin
 (fn ()
  (if (@ $state song_mode)
   (seq
    (set_toast "loop beginning copied")
    (let tl (@ $state tl))
    (set copy_buf_seq ((@ $tl copy_step) $tl (@ $tl loop_start) 1))
   )
  )
 )
)
(set copy_loop_end
 (fn ()
  (if (@ $state song_mode)
   (seq
    (set_toast "loop end copied")
    (let tl (@ $state tl))
    (set copy_buf_seq ((@ $tl copy_step) $tl (~ (+ (@ $tl loop_start) (@ $tl loop_len)) 1) 16))
   )
  )
 )
)
(set paste_seq
 (fn (exclude_pats)
  (if $copy_buf_seq (seq
   (if (@ $state song_mode)
    (seq
     (set_toast "loop pasted")
     (if $exclude_pats
      ((@ $state tl paste_ctrls) (@ $state tl) $copy_buf_seq $has_event_params_list)
      ((@ $state tl paste_seq) (@ $state tl) $copy_buf_seq)
     )
    )
    (seq
     (set_toast "pattern pasted")
     (@= $state pat_patch (dec_bytes (@ $copy_buf_seq 1 t0)))
    )
   )
   (if (not (@ $state playing)) (load_bar))
  ))
 )
)
(set paste_ctrl
 (fn (ctrl)
  (if (and (and (@ $state song_mode) $copy_buf_seq) $ctrl) (seq
   (set_toast "loop pasted (ctrl only)")
   ((@ $state tl paste_ctrls) (@ $state tl) $copy_buf_seq (pack $ctrl))
   (if (not (@ $state playing)) (load_bar))
  ))
 )
)
(set insert_seq
 (fn ()
  (if $copy_buf_seq (seq
   (set_toast "loop inserted")
   ((@ $state tl insert_seq) (@ $state tl) $copy_buf_seq)
   (if (not (@ $state playing)) (load_bar))
  ))
 )
)
(set clear_overrides
 (fn ()
  (set_toast "overrides cleared")
  ((@ $state tl clear_overrides) (@ $state tl))
  (if (not (@ $state playing)) (load_bar))
 )
)
(set commit_overrides
 (fn ()
  (set_toast "overrides committed")
  ((@ $state tl commit_overrides) (@ $state tl))
 )
)
(set state_load (fn (st)
 (if (== (sub $st 1 4) rp80) (seq (state_new (parse (sub $st 5))) true) false)
))
]]



function toggle_playing()
 local tl=state.tl
 if state.playing then
  if (tl.rec) tl:toggle_rec()
  tl:clear_overrides()
 end
 state.playing=not state.playing
 load_bar()
 seq_helper:reset()
end


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
  function() return (state.patch[idx]&mask)>>lsb end,
  function(val)
   state._apply_diff(idx,((val<<lsb)&mask) | (state.patch[idx]&(~mask)))
  end
end

function state_make_get_set_param_bool(idx,bit)
 local get,set=state_make_get_set_param(idx,bit or 0,1)
 return
  function() return get()>0 end,
  function(val) set(val and 1 or 0) end
end

function state_make_get_set(a,b)
 if b then return
  function() return state[a][b] end,
  function(v) state[a][b]=v end
 else return
  function() return state[a] end,
  function(v) state[a]=v end
 end
end

function state_make_get_set_pat_len(syn)
 return
  function() return state.ui_pats[syn].l or 16 end,
  function(l) state.ui_pats[syn].l=l end
end

state_is_song_mode=function() return state.song_mode end

--taf=0.75

-- splits blocks for sample-accurate note triggering
function seq_helper_new(root,note_fn)
 local _t,_cost=0x7fff,3
 return {
  root=root,
  reset=function() _t=state.note_len note_fn() end,
  run=function(self,b,todo)
   local p=1
   while todo>0 do
    if _t>=state.note_len then
     if (todo<_cost) break
     _t=0
     note_fn()
     if (state.playing) state:next_tick()
     todo-=_cost
    end
    local n=min(state.note_len-_t,todo)
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
