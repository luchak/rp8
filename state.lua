-->8
-- state

n_off,n_on,n_ac,n_sl,n_ac_sl=unpack_split'64,65,66,67,68'

syn_base_idx=parse[[{b0=7,b1=23,dr=39,bd=46,sd=49,hh=52,cy=55,s1=58,s2=61}]]

pat_param_idx=parse[[{b0=11,b1=27,dr=43}]]

-- see note 003
default_patch=split'64,0,64,3,64,128,64,0,0,1,1,1,64,64,64,0,64,64,64,64,64,64,64,0,0,1,1,1,64,64,64,0,64,64,64,64,64,64,64,0,0,1,1,64,127,64,64,64,64,64,64,64,64,64,64,64,64,64,64,64,64,64,64,1,0,64,64,128,1,128'

syn_pat_template=parse[[{
 nt=`(rep 16 19)
 dt=`(rep 16 64)
 st=`(rep 16 64)
}]]

drum_pat_template=parse[[{
 bd={st=`(rep 16 64) dt=`(rep 16 64)}
 sd={st=`(rep 16 64) dt=`(rep 16 64)}
 hh={st=`(rep 16 64) dt=`(rep 16 64)}
 cy={st=`(rep 16 64) dt=`(rep 16 64)}
 s1={st=`(rep 16 64) dt=`(rep 16 64)}
 s2={st=`(rep 16 64) dt=`(rep 16 64)}
}]]

function state_new(savedata)
 local s=parse[[{
  pat_store={},
  tick=1,
  playing=false,
  base_note_len=750,
  note_len=750,
  drum_sel=bd,
  b0_bank=1,
  b1_bank=1,
  dr_bank=1,
  song_mode=false,
  samp=(0),
  patch={},
  pat_seqs={},
  pat_status={},
  tl=`(timeline_new $default_patch),
  pat_patch=`(copy $default_patch),
 }]]

 eval[[(fn (s dat)
 (if $dat ((fn ()
  (@= $s tl (timeline_new $default_patch (@ $dat tl)))
  (@= $s pat_patch (dec_bytes (@ $dat pat_patch)))
  (@= $s song_mode (@ $dat song_mode))
  (@= (@ $s pat_store) b0 (map_table (@ (@ $dat pat_store) b0) $dec_bytes 1))
  (@= (@ $s pat_store) b1 (map_table (@ (@ $dat pat_store) b1) $dec_bytes 1))
  (@= (@ $s pat_store) dr (map_table (@ (@ $dat pat_store) dr) $dec_bytes 2))
  (@= $s samp (dec_bytes (@ $dat samp)))
 )))
 )]](s,savedata)

 function _init_tick()
  local patch=s.patch
  local nl=sample_rate*(15/(60+patch[1]))
  local shuf_diff=nl*(patch[2]>>7)*(0.5-(s.tick&1))
  s.note_len,s.base_note_len=flr(0.5+nl+shuf_diff),nl
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
  local tl=self.tl
  if self.song_mode then
   tl:next_tick(self.patch,load_bar)
   self.bar,self.tick=tl.bar,tl.tick
  else
   self.tick+=1
   if (self.tick>16) load_bar()
  end
  _init_tick()
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
  self.song_mode=not self.song_mode
  self:stop_playing()
  load_bar()
 end

 function _sync_pats()
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
    if (syn=='b0' or syn=='b1') pat=copy(syn_pat_template) else pat=copy(drum_pat_template)
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

 function s:go_to_bar(bar)
  load_bar(mid(1,bar,999))
 end

 function s:get_ui_pat(syn)
  -- pats are aliased, always editing current
  return trn(syn=='dr',self.pat_seqs.dr[self.drum_sel],self.pat_seqs[syn])
 end

 function s:save()
  return 'rp80'..stringify({
   tl=self.tl:get_serializable(),
   song_mode=self.song_mode,
   pat_patch=enc_bytes(self.pat_patch),
   pat_store={
    b0=map_table(self.pat_store.b0,enc_bytes,1),
    b1=map_table(self.pat_store.b1,enc_bytes,1),
    dr=map_table(self.pat_store.dr,enc_bytes,2),
   },
   samp=enc_bytes(self.samp)
  })
 end

 function s:stop_playing()
  if (self.playing) self:toggle_playing()
 end

 function s:cut_seq()
  self:stop_playing()
  copy_buf_seq=self.tl:cut_seq()
  load_bar()
 end

 function s:copy_seq()
  if self.song_mode then
   copy_buf_seq=self.tl:copy_seq()
  else
   copy_buf_seq={{
    t0=enc_bytes(self.pat_patch),
    ev={}
   }}
  end
 end

 function s:paste_seq()
  if (not copy_buf_seq) return
  self:stop_playing()
  local n=#copy_buf_seq
  if self.song_mode then
   self.tl:paste_seq(copy_buf_seq)
  else
   self.pat_patch=dec_bytes(copy_buf_seq[1].t0)
  end
  load_bar()
 end

 function s:insert_seq()
  if (not copy_buf_seq) return
  self:stop_playing()
  self.tl:insert_seq(copy_buf_seq)
  load_bar()
 end

 function s:clear_overrides()
  self.tl:clear_overrides()
  if (not self.playing) self:load_bar()
 end

 function s:copy_overrides_to_loop()
  self.tl:copy_overrides_to_loop()
 end

 load_bar()
 return s
end

state_load=eval[[(fn (s)
 (if (eq (sub $s 1 4) rp80) (state_new (parse (sub $s 5))))
)]]

function transpose_pat(pat,key,d,vmin,vmax)
 for i=1,16 do
  pat[key][i]=mid(vmin,pat[key][i]+d,vmax)
 end
end

function state_make_get_set_param(idx,lsb,size)
 local lsb=lsb or 0
 local size=size or 8
 local mask=(1<<(lsb+size))-(1<<lsb)
 return
  function(state) return (state.patch[idx]&mask)>>lsb end,
  function(state,val)
   state._apply_diff(idx,((val<<lsb)&mask) | (state.patch[idx]&(~mask)))
  end
end

function state_make_get_set_param_bool(idx,bit)
 local mask=1<<(bit or 0)
 return
  function(state) return (state.patch[idx]&mask)>0 end,
  function(state,val) local old=state.patch[idx] state._apply_diff(idx,trn(val,old|mask,old&(~mask))) end
end

function state_make_get_set(a,b)
 return
  function(s) if b then return s[a][b] else return s[a] end end,
  function(s,v) if b then s[a][b]=v else s[a]=v end end
end

state_is_song_mode=function(state) return state.song_mode end

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
    self.root:update(b,p,p+n-1)
    _t+=n
    p+=n
    todo-=n
   end
   return p-1
  end
 }
end
