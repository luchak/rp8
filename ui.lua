-->8
-- ui

widget_defaults=parse[[{
 w=2,
 h=2,
 active=true,
 click_act=false,
 drag_amt=0
}]]

function ui_new()
 local obj=parse[[{
  widgets={},
  sprites={},
  dirty={},
  mtiles={},
  mx=0,
  my=0,
  hover_t=0,
  help_on=false
 }]]
 -- focus
 -- hover

 function obj:add_widget(w)
  w=merge(copy(widget_defaults),w)
  local widgets=self.widgets
  add(widgets,w)
  w.id,w.tx,w.ty=#widgets,w.x\4,w.y\4
  local tile=w.tx+w.ty*32
  for dx=0,w.w-1 do
   for dy=0,w.h-1 do
    self.mtiles[tile+dx+dy*32]=w
   end
  end
 end

 function obj:draw(state)
  -- restore screen from mouse
  local mx,my,off=self.mx,self.my,self.mouse_restore_offset
  if (off) memcpy(0x6000+off,0x9000+off,448)

  -- draw changed widgets
  for id,w in pairs(self.widgets) do
   local ns=w:get_sprite(state)
   if ns!=self.sprites[id] then
    self.sprites[id],self.dirty[id]=ns,true
   end
  end
  palt(0,false)
  for id,_ in pairs(self.dirty) do
   local w,sp=self.widgets[id],self.sprites[id]
   local wx,wy=w.x,w.y
   -- see note 004
   if type(sp)=='number' then
    spr(self.sprites[id],wx,wy,1,1)
   else
    local tw,text,bg,fg=w.w*4,unpack_split(sp)
    text=tostr(text)
    rectfill(wx,wy,wx+tw-1,wy+7,bg)
    print(text,wx+tw-#text*4,wy+1,fg)
   end
  end
  self.dirty={}

  local f=self.focus
  palt(0,true)

  -- draw focus box
  if f then
   spr(1,f.x,f.y,1,1)
   sspr(32,0,4,8,f.x+f.w*4-4,f.y)
  end

  -- store rows behind mouse and draw mouse
  local next_off=mid(0,my,122)<<6
  memcpy(0x9000+next_off,0x6000+next_off,448)
  local hover=self.hover
  spr(15,mx,my)
  if show_help and self.hover_t>30 and hover and hover.active and hover.tt then
   local tt=hover.tt
   local xp=trn(mx<56,mx+7,mx-2-4*#tt)
   rectfill(xp,my,xp+4*#tt,my+6,1)
   print(tt,xp+1,my+1,7)
  end
  self.mouse_restore_offset=next_off
 end

 function obj:update(state)
  local input=0
  if (btnp(2)) input+=1
  if (btnp(3)) input-=1

  self.mx,self.my,click=stat(32),stat(33),stat(34)
  local mx,my,k=self.mx,self.my
  local hover=self.mtiles[mx\4 + (my\4)*32]

  if (stat(30)) k=stat(31)
  if (k=='h') toggle_help()
  if (k==' ') state:toggle_playing()

  local focus=self.focus
  local new_focus=self.focus

  if click>0 then
   if focus and click==self.last_click then
    local drag=stat(39)
    drag=trn(drag==0,(my-self.last_my)<<2,drag)
    self.drag_dist+=drag
    local diff=flr(focus.drag_amt*(self.last_drag-self.drag_dist)+0.5)
    if diff!=0 then
     input=diff
     self.last_drag=self.drag_dist
    end
   else
    poke(0x5f2d,5)
    self.click_x,self.click_y,self.drag_dist,self.last_drag=mx,my,0,0
    new_focus=trn(hover and hover.active,hover,nil)
    if (new_focus and new_focus.click_act) input=trn(click==1,1,-1)
   end
  else
   poke(0x5f2d,1)
  end

  if new_focus!=focus then
   if (focus) self.dirty[focus.id]=true
   if (new_focus) self.dirty[new_focus.id]=true
   focus=new_focus
  end

  if focus then
   input+=trn(focus.drag_amt>0,stat(36),0)
   if (input!=0) focus:input(state,input)
  end
  if (self.hover==hover and click==0) self.hover_t+=1 else self.hover_t=0

  self.last_click,self.hover,self.last_my,self.focus=click,hover,my,focus
 end

 return obj
end

function syn_note_btn_new(x,y,syn,step)
 return {
  x=x,y=y,drag_amt=0.05,tt='note (drag)',
  get_sprite=function(self,state)
   return 64+state.pat_seqs[syn].nt[step]
  end,
  input=function(self,state,b)
   local n=state.pat_seqs[syn].nt
   n[step]=mid(0,36,n[step]+b)
  end
 }
end

function spin_btn_new(x,y,sprites,tt,get,set)
 local n=#sprites
 return {
  x=x,y=y,tt=tt,drag_amt=0.01,
  get_sprite=function(self,state)
   return sprites[get(state)]
  end,
  input=function(self,state,b)
   local sval=get(state)
   set(state,mid(1,get(state)+b,n))
  end
 }
end

function step_btn_new(x,y,syn,step,sprites)
 -- last sprite is for current step
 local n=#sprites-1
 return {
  x=x,y=y,tt='step edit',click_act=true,
  get_sprite=function(self,state)
   if (state.playing and state.tick==step) return sprites[n+1]
   local v=state:get_pat_steps(syn)[step]
   return sprites[v-63]
  end,
  input=function(self,state,b)
   local st=state:get_pat_steps(syn)
   st[step]=(st[step]+b-64+n)%n+64
  end
 }
end

function dial_new(x,y,s0,bins,param_idx,tt)
 local get,set=state_make_get_set_param(param_idx)
 bins-=0x0.0001
 return {
  x=x,y=y,tt=tt,drag_amt=0.33,
  get_sprite=function(self,state)
   return s0+(get(state)>>7)*bins
  end,
  input=function(self,state,b)
   local x=mid(0,128,get(state)+b)
   set(state,x)
  end
 }
end

function toggle_new(x,y,s_off,s_on,tt,get,set)
 return {
  x=x,y=y,click_act=true,tt=tt,
  get_sprite=function(self,state)
   return trn(get(state),s_on,s_off)
  end,
  input=function(self,state)
   set(state,not get(state))
  end
 }
end

function push_new(x,y,s,cb,tt)
 return {
  x=x,y=y,tt=tt,click_act=true,
  get_sprite=function()
   return s
  end,
  input=function(self,state,b)
   cb(state,b)
  end
 }
end

function radio_btn_new(x,y,val,s_off,s_on,tt,get,set)
 return {
  x=x,y=y,tt=tt,click_act=true,
  get_sprite=function(self,state)
   return trn(get(state)==val,s_on,s_off)
  end,
  input=function(self,state)
   set(state,val)
  end
 }
end

function pat_btn_new(x,y,syn,bank_size,pib,c_off,c_on,c_next,c_bg)
 local get_bank=state_make_get_set(syn..'_bank')
 local get_pat,set_pat=state_make_get_set_param(syn_base_idx[syn]+4)
 local ret_prefix=pib..','..c_bg..','
 return {
  x=x,y=y,tt='pattern select',w=1,click_act=true,
  get_sprite=function(self,state)
   local bank,pending=get_bank(state),get_pat(state)
   local pat=state.pat_status[syn].idx
   local val=bank*bank_size-bank_size+pib
   local col=trn(pat==val,c_on,c_off)
   if (pending==val and pending!=pat) col=c_next
   return ret_prefix..col
  end,
  input=function(self,state)
   local bank=get_bank(state)
   local val=bank*bank_size-bank_size+pib
   set_pat(state,val)
  end
 }
end

function number_new(x,y,w,tt,get,input)
 return {
  x=x,y=y,w=w,drag_amt=0.05,tt=tt,
  get_sprite=function(self,state)
   return tostr(get(state))..',0,15'
  end,
  input=function(self,state,b) input(state,b) end
 }
end

function wrap_override(w,s_override,get_not_override,active)
 local get_sprite=w.get_sprite
 w.get_sprite=function(self,state)
  if get_not_override(state) then
   self.active=true
   return get_sprite(self,state)
  else
   self.active=active
   return s_override
  end
 end
 return w
end

transport_number_new=eval[[(fn (x y w obj key tt input) (wrap_override
 (number_new $x $y $w $tt (take 1 (state_make_get_set $obj $key)) $input)
 "--,0,15"
 $state_is_song_mode
))]]

syn_ui_init=eval[[(fn (add_ui key base_idx yp)
(for 1 16 (fn (i)
 (let xp (* (~ $i 1) 8)),
 (add_ui (syn_note_btn_new $xp (+ $yp 24) $key $i)),
 (add_ui (step_btn_new $xp (+ $yp 16) $key $i (' (16 17 33 18 34 32)))),
))
(add_ui (merge (push_new 24 $yp 26
 (fn (state b) (transpose_pat (@ $state pat_seqs $key) $b))
 "transpose (drag)"
) (' {click_act=false drag_amt=0.05})))
(add_ui
 (push_new 8 $yp 28
  (fn (state) (set copy_buf_syn (copy (@ $state pat_seqs $key))))
  "copy pattern"
 )
)
(add_ui
 (push_new 16 $yp 27
  (fn (state) (if $copy_buf_syn (merge (@ $state pat_seqs $key) $copy_buf_syn) nil))
  "paste pattern"
 )
)
(add_ui
 (toggle_new 0 $yp 186 187 active
  (state_make_get_set_param_bool (+ $base_idx 3))
 )
)
(add_ui
 (spin_btn_new 0 (+ $yp 8) (' (162 163 164 165)) "bank select"
  (state_make_get_set (cat $key _bank))
 )
)
(for 1 6 (fn (i)
 (add_ui
  (pat_btn_new (+ (* $i 4) 5) (+ $yp 8) $key 6 $i 2 14 8 6)
 )
))
(foreach (' (
 {x=40,o=6,tt="tune"}
 {x=56,o=7,tt="filter cutoff"}
 {x=72,o=8,tt="filter resonance"}
 {x=88,o=9,tt="filter env amount"}
 {x=104,o=10,tt="filter env decay"}
 {x=120,o=11,tt="accent depth"}
 ))
 (fn (d) (add_ui
  (dial_new (@ $d x) $yp 43 21 (+ $base_idx (@ $d o)) (@ $d tt))
 ))
)
(add_ui
 (toggle_new 32 $yp 2 3 waveform (state_make_get_set_param_bool (+ $base_idx 5)))
)
(map 0 4 0 $yp 16 2)
)]]

drum_ui_init=eval[[(fn (add_ui)
(for 1 16 (fn (i) (add_ui
 (step_btn_new (* (~ $i 1) 8) 120 dr $i (' (19 20 36 35)))
)))
(foreach
 (' (
  {k=bd,x=32,y=104,s=150,b=38,tt="bass drum"}
  {k=sd,x=32,y=112,s=152,b=41,tt="snare drum"}
  {k=hh,x=64,y=104,s=154,b=44,tt=hihat}
  {k=cy,x=64,y=112,s=156,b=47,tt=cymbal}
  {k=pc,x=96,y=104,s=158,b=50,tt=percussion}
  {k=sp,x=96,y=112,s=174,b=53,tt=sample}
 ))
 (fn (d)
  (add_ui (radio_btn_new (@ $d x) (@ $d y) (@ $d k) (@ $d s) (+ 1 (@ $d s)) (@ $d tt) (state_make_get_set drum_sel)))
  (foreach
   (' ({x=8,o=2,tt=level} {x=16,o=0,tt=tune} {x=24,o=1,tt=decay}))
   (fn (c) (add_ui
    (dial_new (+ (@ $d x) (@ $c x)) (@ $d y) 112 16 (+ (@ $d b) (@ $c o)) (cat (cat (@ $d k) " ") (@ $c tt)))
   ))
  )
 )
)
(foreach
 (' ({x=32,b=0,tt="bd/sd "} {x=64,b=1,tt="hh/cy "} {x=96,b=2,tt="pc/sp "}))
 (fn (c) (add_ui (toggle_new
  (@ $c x) 96 170 171 (cat (@ $c tt) "fx bypass") (state_make_get_set_param_bool 37 (@ $c b))
 )))
)
(add_ui (push_new
 8 104 11 (fn (state) (set copy_buf_drum (copy (@ $state pat_seqs dr)))) "copy pattern"
))
(add_ui (push_new
 16 104 10 (fn (state) (merge (@ $state pat_seqs dr) $copy_buf_drum)) "paste pattern"
))
(add_ui (toggle_new
 0 104 188 189 active (state_make_get_set_param_bool 34)
))
(add_ui (spin_btn_new
 0 112 (' (166 167 168 169)) "bank select" (state_make_get_set dr_bank)
))
(for 1 6 (fn (i) (add_ui
 (pat_btn_new (+ 5 (* $i 4)) 112 dr 6 $i 2 14 8 5)
)))
(map 0 8 0 96 16 4)
)]]

function rec_not_yellow(s) return (not s.tl.has_override) or s.tl.rec end

header_ui_init=eval[[(fn (add_ui)
(let hdial (fn (x y idx tt) (add_ui (dial_new $x $y 128 16 $idx $tt))))
(let song_only
 (fn (w s_not_song) (add_ui (wrap_override $w $s_not_song $state_is_song_mode false)))
)

(add_ui (toggle_new
 0 0 6 7 "play/pause" (take 1 (state_make_get_set playing)) (make_obj_cb toggle_playing)
))
(add_ui (toggle_new
 24 0 172 173 "pattern/song mode" $state_is_song_mode (make_obj_cb toggle_song_mode)
))
(song_only (wrap_override (toggle_new
 8 0 231 232 "record automation" (take 1 (state_make_get_set tl rec))
 (make_obj_cb toggle_rec)
) 239 $rec_not_yellow true) 233)
(song_only (push_new 16 0 5 (fn (s)
 ((@ $s go_to_bar) $s
  (trn (gt (@ $s tl bar) (@ $s tl loop_start)) (@ $s tl loop_start) 1)
 )
) rewind) 5)

(add_ui (push_new 0 8 242 (make_obj_cb copy_seq) "copy loop"))
(song_only (push_new 8 8 241 (make_obj_cb cut_seq) "cut loop") 199)
(add_ui (push_new 0 16 247 (make_obj_cb paste_seq) "fill loop"))
(song_only (push_new 8 16 243 (make_obj_cb insert_seq) "insert loop") 201)
(song_only
 (push_new 8 24 246 (make_obj_cb copy_overrides_to_loop) "commit changes")
204)

(foreach (' (
  (16 8 1 tempo)
  (32 8 3 level)
  (32 16 6 "compressor threshold")
  (16 16 2 shuffle)
  (32 24 5 "delay feedback")
  (48 16 57 "filter cutoff")
  (48 24 58 "filter resonance")
  (64 24 59 "filter wet/dry")
  (80 24 61 "filter env decay")
 )) (fn (s)
  (hdial (unpack $s))
 )
)
(let get_set_filt_pat (pack (state_make_get_set_param 60)))
(add_ui (merge
 (number_new 80 16 2 "filter pattern" (@ $get_set_filt_pat 1)
  (fn (s b)
   ((@ $get_set_filt_pat 2) $s (mid 1 (+ ((@ $get_set_filt_pat 1) $s) $b) (len $svf_pats)))
  )
 )
 (' {drag_amt=0.02})
))
(let dts (pack))
(foreach (' ("" t d)) (fn (suffix)
 (for 1 16 (fn (dt)
  (if (eq $suffix d) (let dt (~ $dt 1)))
  (add $dts (cat (cat $dt $suffix) ",0,15"))
 ))
))
(add_ui (merge
 (spin_btn_new 16 24 $dts "delay time" (state_make_get_set_param 4))
 (' {w=3})
))
(add_ui (merge
 (toggle_new 64 16 234 235 "filter lp/bp" (state_make_get_set_param_bool 56 0))
 (' {click_act=false,drag_amt=0.01})
))
(add_ui (spin_btn_new
 64 8 (' ("--,0,15" "MA,0,15" "S1,0,15" "S2,0,15" "DR,0,15")) "filter source"
 (state_make_get_set_param 56 1)
))

(foreach (' ({s=b0 y=8 tt="synth 1 "} {s=b1 y=16 tt="synth 2 "} {s=dr y=24 tt="drums "})) (fn (syn)
 (let base_idx (@ $syn_base_idx (@ $syn s)))
 (foreach (' ({i=0 x=104 tt=level} {i=1 x=112 tt=overdrive} {i=2 x=120 tt="delay send"})) (fn (par)
  (hdial (@ $par x) (@ $syn y) (+ $base_idx (@ $par i)) (cat (@ $syn tt) (@ $par tt)))
 ))
))

(add_ui (transport_number_new 32 0 4 tl bar "song position" (fn (s b)
 ((@ $s go_to_bar) $s (+ (@ $state tl bar) $b))
)))

(song_only (toggle_new 56 0 193 194 "loop on/off" (state_make_get_set tl loop)) 195)

(add_ui (transport_number_new 64 0 4 tl loop_start "loop start" (fn (s b)
 (let tl (@ $s tl))
 (let ns (+ (@ $tl loop_start) $b))
 (@= $tl loop_start (mid 1 $ns 999))
 (@= $tl loop_len (mid 1 (@ $tl loop_len) (~ 1000 $ns)))
)))

(add_ui (transport_number_new 84 0 3 tl loop_len "loop length" (fn (s b)
 (let tl (@ $s tl))
 (@= $tl loop_len (mid 1 (+ (@ $tl loop_len) $b) (~ 1000 (@ $tl loop_start))))
)))

(map 0 0 0 0 16 4)
)]]
