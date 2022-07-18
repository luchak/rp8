-->8
-- ui

widget_defaults=parse[[{
 w=2,
 h=2,
 active=true,
 click_act=false,
 drag_amt=0
}]]

-- overlay is:
-- draw
-- input
-- row range
-- pixels behind (updates every frame)

function ui_new()
 local obj=parse[[{
  widgets={}
  sprites={}
  mtiles={}
  mx=0
  my=0
  hover_t=0
  help_on=false
  overlays={}
  page=1
  pages={}
  visible={}
 }]]
 -- focus
 -- hover
 -- overlay

 function obj:add_page(idx)
  self.pages[idx]={}
 end

 function obj:add_widget(w,page)
  w=merge(copy(widget_defaults),w)
  local widgets=self.widgets
  add(widgets,w)
  w.id,w.tx,w.ty,w.tiles=#widgets,w.x\4,w.y\4,{}
  local tile_base=w.tx+w.ty*32
  for dx=0,w.w-1 do
   for dy=0,w.h-1 do
    local tile=tile_base+dx+dy*32
    add(w.tiles,tile)
   end
  end
  if page then
   add(self.pages[page],w)
  end
  if page==self.page or not page then self:show_widget(w) end
 end

 function obj:set_page(p)
  if p==self.page then return end
  for w in all(self.pages[self.page]) do
   self:hide_widget(w)
  end
  for w in all(self.pages[p]) do
   self:show_widget(w)
  end
  self.page=p
 end

 function obj:show_widget(w)
  for tile in all(w.tiles) do self.mtiles[tile]=w end
  self.visible[w.id]=w
  -- force redraw
  self.sprites[w.id]=nil
 end

 function obj:hide_widget(w)
  for tile in all(w.tiles) do if self.mtiles[tile]==w then self.mtiles[tile]=nil end end
  self.visible[w.id]=nil
 end

 function obj:draw(state)
  -- restore screen from mouse
  local mx,my,off=self.mx,self.my,self.restore_offset
  if (off) memcpy(0x6000+off,0x9000+off,self.restore_size)

  palt(0,false)
  -- draw changed widgets
  for id,w in pairs(self.visible) do
   local ns=w.get_sprite(state)
   if ns!=self.sprites[id] or w==self.focus or w==self.old_focus then
    self.sprites[id]=ns
    local w,sp=self.widgets[id],self.sprites[id]
    local wx,wy=w.x,w.y
    -- see note 004
    if type(sp)=='number' then
     spr(sp,wx,wy)
    else
     local tw,text,bg,fg=w.w<<2,unpack_split(sp)
     text=tostr(text)
     rectfill(wx,wy,wx+tw-1,wy+7,bg)
     print(text,wx+tw-#text*4,wy+1,fg)
    end
   end
  end

  local f=self.focus
  palt(0,true)

  -- draw focus box
  if f then
   spr(1,f.x,f.y)
   sspr(32,0,4,8,f.x+f.w*4-4,f.y)
  end

  -- store rows behind mouse and draw mouse
  local tt_my=mid(0,my,122)
  local next_off=tt_my<<6
  memcpy(0x9000+next_off,0x6000+next_off,448)
  local hover=self.hover
  spr(15,mx,my)
  if show_help and self.hover_t>30 and hover and hover.active and hover.tt then
   local tt=hover.tt
   local xp=trn(mx<56,mx+7,mx-2-4*#tt)
   rectfill(xp,tt_my,xp+4*#tt,tt_my+6,1)
   print(tt,xp+1,tt_my+1,7)
  end
  self.restore_offset=next_off
  self.restore_size=448
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
  if (k=='\t') ui:set_page(3-ui.page)
  if (k=='l') state:toggle_loop()

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

  if new_focus then
   input+=trn(new_focus.drag_amt>0,stat(36),0)
   if (input!=0) new_focus:input(state,input)
  end
  if (self.hover==hover and click==0) self.hover_t+=1 else self.hover_t=0

  self.last_click,self.hover,self.last_my,self.focus,self.old_focus=click,hover,my,new_focus,focus
 end

 return obj
end

function syn_note_btn_new(x,y,syn,key,step,sp0,nt0,nmin,nmax)
 local offset=sp0-nt0
 return {
  x=x,y=y,drag_amt=0.05,tt='note (drag)',
  get_sprite=function(state)
   return offset+state:get_ui_pat(syn)[key][step]
  end,
  input=function(self,state,b)
   local n=state:get_ui_pat(syn)[key]
   n[step]=mid(nmin,nmax,n[step]+b)
  end
 }
end

function spin_btn_new(x,y,sprites,tt,get,set)
 local n=#sprites
 return {
  x=x,y=y,tt=tt,drag_amt=0.01,
  get_sprite=function(state)
   local val=get(state)
   return sprites[val>0 and val or #sprites]
  end,
  input=function(self,state,b)
   local sval=get(state)+b
   if self.wrap then
    if (sval>n) sval-=n
   else
    sval=mid(1,sval,n)
   end
   set(state,sval)
  end
 }
end

function step_btn_new(x,y,syn,step,sprites)
 -- last sprite is for current step
 local n=#sprites-1
 return {
  x=x,y=y,tt='step edit',click_act=true,
  get_sprite=function(state)
   if (state.playing and state:get_ptick(syn)==step) return sprites[n+1]
   local v=state:get_ui_pat(syn).st[step]
   return sprites[v-63]
  end,
  input=function(self,state,b)
   local st=state:get_ui_pat(syn).st
   st[step]=(st[step]+b-64+n)%n+64
  end
 }
end

function dial_new(x,y,s0,bins,param_idx,tt)
 local get,set=state_make_get_set_param(param_idx)
 bins-=0x0.0001
 return {
  x=x,y=y,tt=tt,drag_amt=0.33,
  get_sprite=function(state)
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
  get_sprite=function(state)
   return trn(get(state),s_on,s_off)
  end,
  input=function(self,state)
   set(state,not get(state))
  end
 }
end

function multitoggle_new(x,y,states,tt,get,set)
 return {
  x=x,y=y,click_act=true,tt=tt,
  get_sprite=function(state)
   return states[get(state)+1]
  end,
  input=function(self,state,b)
   set(state,(get(state)+b+#states)%#states)
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
  get_sprite=function(state)
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
  get_sprite=function(state)
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
  get_sprite=function(state)
   return tostr(get(state))..',0,15'
  end,
  input=function(self,state,b) input(state,b) end
 }
end

function wrap_override(w,s_override,get_not_override,override_active)
 local get_sprite=w.get_sprite
 w.get_sprite=function(state)
  if get_not_override(state) then
   w.active=true
   return get_sprite(state)
  else
   w.active=override_active
   return s_override
  end
 end
 return w
end

eval[[
(set pat_lens (pack))
(for 1 16 (fn (l)
 (add $pat_lens (cat $l ",0,14"))
))
]]

transport_number_new=eval[[(fn (x y w obj key tt input) (wrap_override
 (number_new $x $y $w $tt (take 1 (state_make_get_set $obj $key)) $input)
 "--,0,15"
 $state_is_song_mode
))]]

syn_ui_init=eval[[(fn (add_ui key base_idx yp)
(for 1 16 (fn (i)
 (let xp (* (~ $i 1) 8))
 (add_ui (syn_note_btn_new $xp (+ $yp 24) $key nt $i 64 0 0 36) 1)
 (add_ui (syn_note_btn_new $xp (+ $yp 24) $key dt $i 50 64 52 76) 2)
 (add_ui (step_btn_new $xp (+ $yp 16) $key $i (' (16 17 33 18 34 32))))
))
(add_ui (merge
 (spin_btn_new 32 $yp $pat_lens "pattern length" (state_make_get_set_pat_len $key))
 (' {w=2 drag_amt=0.03})
))
(add_ui (merge (push_new 24 $yp 26
 (fn (state b) (transpose_pat (@ $state pat_seqs $key) nt $b 0 36))
 "transpose (drag)"
) (' {click_act=false drag_amt=0.05})) 1)
(add_ui (merge (push_new 24 $yp 26
 (fn (state b) (transpose_pat (@ $state pat_seqs $key) dt $b 52 76))
 "transpose (drag)"
) (' {click_act=false drag_amt=0.05})) 2)
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
 (toggle_new 0 $yp 107 108 active
  (state_make_get_set_param_bool (+ $base_idx 3))
 )
)
(add_ui
 (spin_btn_new 0 (+ $yp 8) (' (248 249 250 251 252 253 254 255)) "bank select"
  (state_make_get_set (cat $key _bank))
 )
)
(for 1 6 (fn (i)
 (add_ui
  (pat_btn_new (+ (* $i 4) 5) (+ $yp 8) $key 6 $i 2 14 8 6)
 )
))
(foreach (' (
 {x=64,o=6,tt="tune"}
 {x=72,o=8,tt="osc 2 fine"}
 {x=80,o=9,tt="osc 2 mix"}
 {x=88,o=10,tt="filter cutoff"}
 {x=96,o=11,tt="filter resonance"}
 {x=104,o=12,tt="filter env amount"}
 {x=112,o=13,tt="filter env decay"}
 {x=120,o=14,tt="accent depth"}
 ))
 (fn (d) (add_ui
  (dial_new (@ $d x) $yp 160 29 (+ $base_idx (@ $d o)) (@ $d tt))
 ))
)
(add_ui
 (toggle_new 48 $yp 2 3 waveform (state_make_get_set_param_bool (+ $base_idx 5)))
)
(map 0 4 0 $yp 16 2)
)]]

drum_ui_init=eval[[(fn (add_ui)
(for 1 16 (fn (i)
 (let xp (* (~ $i 1) 8))
 (add_ui (step_btn_new $xp 120 dr $i (' (19 20 36 35))) 1)
 (add_ui (syn_note_btn_new $xp 120 dr dt $i 50 64 52 76) 2)
))
(add_ui (merge
 (spin_btn_new 0 96 $pat_lens "pattern length" (state_make_get_set_pat_len dr))
 (' {w=2 drag_amt=0.03})
))
(foreach
 (' (
  {k=bd,x=32,y=104,s=150,b=46,tt="bass drum"}
  {k=sd,x=32,y=112,s=152,b=49,tt="snare drum"}
  {k=hh,x=64,y=104,s=154,b=52,tt=hihat}
  {k=cy,x=64,y=112,s=156,b=55,tt=cymbal}
  {k=s1,x=96,y=104,s=158,b=58,tt=percussion}
  {k=s2,x=96,y=112,s=145,b=61,tt=sample}
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
 (' ({x=32,b=0,tt="bd/sd "} {x=64,b=2,tt="hh/cy "} {x=96,b=4,tt="pc/sp "}))
 (fn (c) (add_ui (multitoggle_new
  (@ $c x) 96 (' (101 102 103 104)) (cat (@ $c tt) "fx bypass") (state_make_get_set_param 45 (@ $c b) 2)
 )))
)
(add_ui (push_new
 8 104 11 (fn (state) (set copy_buf_drum (copy (@ $state pat_seqs dr)))) "copy pattern"
))
(add_ui (push_new
 16 104 10 (fn (state) (merge (@ $state pat_seqs dr) $copy_buf_drum)) "paste pattern"
))
(add_ui (toggle_new
 0 104 109 110 active (state_make_get_set_param_bool 42)
))
(add_ui (spin_btn_new
 0 112 (' (240 241 242 243 244 245 246 247)) "bank select" (state_make_get_set dr_bank)
))
(for 1 6 (fn (i) (add_ui
 (pat_btn_new (+ 5 (* $i 4)) 112 dr 6 $i 2 14 8 5)
)))
(map 0 8 0 96 16 4)
)]]

function no_uncommitted(s) return (not s.tl.has_override) or s.tl.rec end
function has_uncommitted(s) return not no_uncommitted(s) end
function get_page() return ui.page end
function set_page(_,p) ui:set_page(p) end

header_ui_init=eval[[(fn (add_ui)
(let hdial (fn (x y idx tt) (add_ui (dial_new $x $y 128 16 $idx $tt))))
(let song_only
 (fn (w s_not_song) (add_ui (wrap_override $w $s_not_song $state_is_song_mode false)))
)

(add_ui (toggle_new
 0 0 6 7 "play/pause" (take 1 (state_make_get_set playing)) (make_obj_cb toggle_playing)
))
(add_ui (toggle_new
 24 0 105 106 "pattern/song mode" $state_is_song_mode (make_obj_cb toggle_song_mode)
))
(song_only (wrap_override (toggle_new
 8 0 231 232 "record automation" (take 1 (state_make_get_set tl rec))
 (make_obj_cb toggle_rec)
) 196 $no_uncommitted true) 233)
(song_only (push_new 16 0 5 (fn (s)
 ((@ $s go_to_bar) $s
  (trn (gt (@ $s tl bar) (@ $s tl loop_start)) (@ $s tl loop_start) 1)
 )
) rewind) 5)

(add_ui (merge (spin_btn_new 96 0 (' (189 190)) "ui page" $get_page $set_page) (' {click_act=true drag_amt=0 wrap=true})))
(add_ui (push_new 0 8 201 (make_obj_cb copy_seq) "copy loop"))
(song_only (push_new 8 8 199 (make_obj_cb cut_seq) "cut loop") 198)
(add_ui (push_new 0 16 197 (make_obj_cb paste_seq) "fill loop"))
(song_only (push_new 8 16 203 (make_obj_cb insert_seq) "insert loop") 202)

(add_ui (wrap_override 
 (push_new 8 24 205 (make_obj_cb copy_overrides_to_loop) "commit changes")
 204 $has_uncommitted)
)
(add_ui (wrap_override 
 (push_new 0 24 207 (make_obj_cb clear_overrides) "clear changes")
 206 $has_uncommitted)
)

(foreach (' (
  (16 8 1 tempo)
  (32 8 3 level)
  (32 16 6 "compressor threshold")
  (16 16 2 shuffle)
  (32 24 5 "delay feedback")
  (48 16 66 "filter cutoff")
  (48 24 67 "filter resonance")
  (64 24 68 "filter wet/dry")
  (80 24 70 "filter env decay")
 )) (fn (s)
  (hdial (unpack $s))
 )
)
(let get_set_filt_pat (pack (state_make_get_set_param 69)))
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
 (toggle_new 64 16 234 235 "filter lp/bp" (state_make_get_set_param_bool 65 0))
 (' {click_act=false,drag_amt=0.01})
))
(add_ui (spin_btn_new
 48 8 (' ("--,0,15" "MA,0,15" "S1,0,15" "S2,0,15" "DR,0,15")) "filter source"
 (state_make_get_set_param 64)
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
