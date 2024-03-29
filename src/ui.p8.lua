-->8
-- ui

function outline_text(s,x,y,c,o)
 color(o)
 print('\-f'..s..'\^g\-h'..s..'\^g\|f'..s..'\^g\|h'..s,x,y)
 print(s,x,y,c)
end

eval--[[language::loaf]][[
(set is_digit (mkmatch "0123456789"))
(set widget_defaults (' {
 w=2,
 h=2,
 active=true,
 click_act=false,
 drag_amt=0
}))
(set pat_lens (pack))
(set make_thin_ones (fn (s)
 (let s (tostr $s))
 (let r (pack ""))
 (for 1 (len $s) (fn (i)
  (if (== (@ $s $i) "1") (@= $r 1 (cat (@ $r 1) "|")) (@= $r 1 (cat (@ $r 1) (@ $s $i))))
 ))
 (@ $r 1)
))
(for 1 16 (fn (l)
 (add $pat_lens (cat (make_thin_ones $l) ",0,14"))
))
]]

-- overlay is:
-- draw
-- input
-- row range
-- pixels behind (updates every frame)

function ui_new()
 local obj=parse--[[language::loon]][[{
  widgets={}
  sprites={}
  mtiles={}
  mx=0
  my=0
  hover_t=0
  help_on=false
  page=1
  pages=({} {})
  visible={}
  ftoast_t=0
  toast_t=0
  click_t=0
  restores={}
  rp=36864
  grps={}
 }]]
 -- focus
 -- last_focus
 -- hover
 -- overlay

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
  if (page) add(self.pages[page],w)
  if w.grp then
   add(self.grps[w.grp],w)
  end
  if not page or self.page==page then self:show_widget(w) end
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
  for tile in all(w.tiles) do self.mtiles[tile]=nil end
  self.visible[w.id]=nil
  if (self.focus==w) self.focus=nil
 end

 local function save_band(screen)
  screen+=0x6000
  memcpy(obj.rp,screen,448)
  add(obj.restores,{screen,obj.rp,448},1)
  obj.rp+=448
 end

 function obj:draw()
  state:update_ui_vars()
  -- restore screen from mouse
  local mx,my=self.mx,self.my
  for r in all(self.restores) do
   memcpy(unpack(r))
  end
  self.rp=36864
  self.restores={}

  palt(0,false)

  local f=self.focus

  -- draw changed widgets
  for id,w in pairs(self.visible) do
   local ns=w:get_sprite()
   if ns!=self.sprites[id] or w==f or w==self.last_focus then
    self.sprites[id]=ns
    local sp=self.sprites[id]
    local wx,wy=w.x,w.y
    -- see note 004
    if type(sp)=='number' then
     spr(sp,wx,wy)
    else
     local tw,text,bg,fg,dx=w.w<<2,unpack_split(sp)
     text=tostr(text)
     rectfill(wx,wy,wx+tw-1,wy+7,bg)
     print(text,wx+tw-#text*4-(dx or 0),wy+1,fg)
    end
   end
  end

  palt(0,true)

  -- draw focus box
  if f then
   spr(1,f.x,f.y)
   sspr(32,0,4,8,f.x+f.w*4-4,f.y)
   self.last_focus=f
  end

  -- store rows behind toast and draw toast
  save_band(0xc0)
  if self.toast_t>0 then
   outline_text(self.toast,2,4,7,0)
   self.toast_t-=1
  end

  -- store rows behind mouse and draw mouse
  local tt_my=mid(my,121)
  local next_off,hover=tt_my<<6,self.hover
  save_band(next_off)
  spr(15,mx,my)
  if tooltips_enabled() and self.hover_t>30 and hover and hover.active and hover.tt then
   local xp=mx<56 and mx+7 or mx-2-4*#hover.tt
   outline_text(hover.tt,xp+1,tt_my+1,12,1)
  end

  -- store rows behind focus toast value and draw focus toast
  local focus_off=(f and f.y+9 or 0)<<6
  save_band(focus_off)
  if self.ftoast_w==f and self.ftoast_t>0 then
   outline_text(self.ftoast,mid(f.x-2,116),f.y+10,12,0)
   self.ftoast_t-=1
  end

 end

 function obj:update()
  state:update_ui_vars()
  if (display_mode!='ui') return
  local input,nav=0

  self.mx,self.my=mid(stat(32),127),mid(stat(33),127)
  local click,mx,my=stat(34),self.mx,self.my
  local hover=self.mtiles[mx\4 + (my\4)*32]

  local hotkey,shift=stat(30) and stat(31),stat(28,225) or stat(28,229)
  local hotkey_action=hotkey_map[ord(hotkey)]
  if (hotkey_action) hotkey_action()
  -- if this is positioned differently it causes a bug with focus on page switch
  local focus=self.focus
  if (focus and focus.on_num and is_digit(hotkey)) focus.on_num(tonum(hotkey))
  local new_focus=trn(focus and focus.active,focus,nil)

  local step=(shift and focus and focus.bigstep) or 1
  if (btnp(2)) input+=step
  if (btnp(3)) input-=step
  if (btnp(0)) nav=-2
  if (btnp(1)) nav=0

  if nav and focus and focus.grp then
   new_focus=self.grps[focus.grp][(focus.step+nav)%16+1]
  end

  if click>0 then
   if focus and click==self.last_click then
    local drag=stat(39)
    drag=drag==0 and (my-self.last_my)<<2 or drag
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
    if new_focus then
     if new_focus.click_act then
      input=click==1 and 1 or -1
     end
     if (self.click_t>0 and new_focus.doubleclick) new_focus.doubleclick()
    end
    self.click_t=12
   end
  else
   poke(0x5f2d,1)
  end

  self.click_t=max(self.click_t-1)

  if new_focus then
   input+=new_focus.drag_amt>0 and stat(36) or 0
   if (input!=0) new_focus:input(input)
  end
  if (self.hover==hover and click==0) self.hover_t+=1 else self.hover_t=0

  self.last_click,self.hover,self.last_my,self.focus=click,hover,my,new_focus
 end

 return obj
end

function note_btn_new(grp,x,y,syn,key,step,sp0,nt0,nmin,nmax)
 return merge(parse--[[language::loon]][[{drag_amt=0.05 tt=note bigstep=12}]], {
  grp=grp,step=step,x=x,y=y,
  get_sprite=function(self)
   return sp0-nt0+state.ui_pats[syn][key][step]
  end,
  input=function(self,b)
   local n=state.ui_pats[syn][key]
   n[step]=mid(nmin,nmax,n[step]+b)
  end
  })
end

function spin_btn_new(x,y,sprites,tt,get,set)
 local n=#sprites
 return {
  x=x,y=y,tt=tt,drag_amt=0.01,
  get_sprite=function(self)
   local val=get()
   return sprites[val>0 and val or n]
  end,
  input=function(self,b)
   local sval=get()+b
   if self.wrap then
    if sval>n then sval-=n end
   else
    sval=mid(1,sval,n)
   end
   set(sval)
  end
 }
end

function step_btn_new(grp,x,y,syn,step,sprites)
 -- last sprite is for current step
 local n=#sprites-1
 return {
  grp=grp,step=step,x=x,y=y,tt='step '..step,click_act=true,
  get_sprite=function(self)
   if (state.playing and state.ui_pticks[syn]==step) return sprites[n+1]
   local v=state.ui_pats[syn].st[step]
   return sprites[v-63]
  end,
  input=function(self,b)
   local st=state.ui_pats[syn].st
   st[step]=(st[step]+b-64)%n+64
  end,
  on_num=function(num)
   local st=state.ui_pats[syn].st
   st[step]=(num-65)%n+64
  end
 }
end

function dial_new(x,y,s0,bins,param_idx,tt)
 local get,set=state_make_get_set_param(param_idx)
 bins-=0x0.0001
 return {
  x=x,y=y,tt=tt,drag_amt=0.33,bigstep=16,param=param_idx,
  get_sprite=function(self)
   return s0+(get()>>7)*bins
  end,
  input=function(self,b)
   local val=mid(128,get()+b)
   local s=tostr(val)
   while (#s<3) s=' '..s
   set_ftoast(self,s)
   set(val)
  end,
  doubleclick=function()
   set(default_patch[param_idx])
  end
 }
end

function toggle_new(x,y,s_off,s_on,tt,get,set)
 return {
  x=x,y=y,click_act=true,tt=tt,
  get_sprite=function(self)
   return get() and s_on or s_off
  end,
  input=function(self)
   set(not get())
  end
 }
end

function multitoggle_new(x,y,states,tt,get,set)
 return {
  x=x,y=y,click_act=true,tt=tt,
  get_sprite=function(self)
   return states[get()+1]
  end,
  input=function(self,b)
   set((get()+b+#states)%#states)
  end
 }
end

function push_new(x,y,s,cb,tt)
 return {
  x=x,y=y,tt=tt,click_act=true,
  get_sprite=function()
   return s
  end,
  input=function(self,b)
   cb(b)
  end
 }
end

function radio_btn_new(x,y,val,s_off,s_on,tt,get,set)
 return {
  x=x,y=y,tt=tt,click_act=true,
  get_sprite=function(self)
   return get()==val and s_on or s_off
  end,
  input=function(self)
   set(val)
  end
 }
end

function pat_btn_new(x,y,syn,bank_size,pib,c_off,c_on,c_next,c_bg)
 local get_bank=state_make_get_set(syn..'_bank')
 local get_pat,set_pat=state_make_get_set_param(syn_base_idx[syn]+4)
 local ret_prefix=pib..','..c_bg..','
 return {
  x=x,y=y,tt='pattern select',w=1,click_act=true,
  get_sprite=function(self)
   local bank,pending=get_bank(),get_pat()
   local pat=state.pat_status[syn].idx
   local val=bank*bank_size-bank_size+pib
   local col=trn(pat==val,c_on,c_off)
   if (pending==val and pending!=pat) col=c_next
   return ret_prefix..col
  end,
  input=function(self)
   local bank=get_bank()
   local val=bank*bank_size-bank_size+pib
   set_pat(val)
  end
 }
end

function number_new(x,y,w,tt,get,input)
 return {
  x=x,y=y,w=w,drag_amt=0.05,tt=tt,
  get_sprite=function(self)
   return tostr(get())..',0,15'
  end,
  input=function(self,b) input(b) end
 }
end

function wrap_override(w,s_override,get_not_override,override_active)
 local get_sprite=w.get_sprite
 w.get_sprite=function(self)
  if get_not_override() then
   self.active=true
   return get_sprite(self)
  else
   self.active=override_active
   return s_override
  end
 end
 return w
end

function no_uncommitted() return (not state.tl.has_override) or state.tl.rec end
function has_uncommitted() return not no_uncommitted() end

eval--[[language::loaf]][[
(set set_page (fn (p) ((@ $ui set_page) $ui $p)))
(set get_page (fn () (@ $ui page)))

(set transport_number_new (fn (x y w obj key tt input) (wrap_override
 (number_new $x $y $w $tt (take 1 (state_make_get_set $obj $key)) $input)
 "--,0,15"
 $state_is_song_mode
)))

(set syn_ui_init (fn (add_ui key base_idx yp)
(@= (@ $ui grps) (cat sn1 $key) (pack))
(@= (@ $ui grps) (cat sn2 $key) (pack))
(@= (@ $ui grps) (cat sst $key) (pack))
(for 1 16 (fn (i)
 (let xp (* (~ $i 1) 8))
 (add_ui (note_btn_new (cat sn1 $key) $xp (+ $yp 24) $key nt $i 64 0 0 36) 1)
 (add_ui (note_btn_new (cat sn2 $key) $xp (+ $yp 24) $key dt $i 50 64 52 76) 2)
 (add_ui (step_btn_new (cat sst $key) $xp (+ $yp 16) $key $i (' (16 17 33 18 34 32))))
))
(add_ui (merge
 (spin_btn_new 24 $yp $pat_lens "pattern length" (state_make_get_set_pat_len $key))
 (' {w=2 drag_amt=0.03 bigstep=4})
))
(add_ui (merge (push_new 40 $yp 238
 (fn (b) (rotate_pat (@ $state pat_seqs $key) (' (st nt dt)) $b))
 "rotate"
) (' {click_act=false drag_amt=0.05 bigstep=4})))
(set randomize_pattern (fn (pat)
 (for 1 16 (fn (i)
  (if (> $change_step_prob (rnd)) (seq
   (let v 64)
   (if (> $step_prob (rnd)) (seq
    (let v 65)
    (if (> $yellow_prob (rnd)) (let v (+ $v 2)))
    (if (> $accent_prob (rnd)) (let v (+ $v 1)))
   ))
   (@= (@ $pat st) $i $v)
  ))
  (if (and (@ $pat nt) (> $change_note_prob (rnd)))
   (@= (@ $pat nt) $i (+ (rnd (@ $scale_notes $scale)) (* 12 (flr (rnd 3)))))
  )
 ))
))
(add_ui (push_new 40 (+ $yp 8) "?,6,5,2"
 (fn (b)
  (randomize_pattern (@ $state pat_seqs $key))
 )
 "randomize"
))
(add_ui (merge (push_new 32 $yp 26
 (fn (b) (transpose_pat (@ $state pat_seqs $key) nt $b 0 36))
 "transpose"
) (' {click_act=false drag_amt=0.05 bigstep=12})) 1)
(add_ui (merge (push_new 32 $yp 26
 (fn (b) (transpose_pat (@ $state pat_seqs $key) dt $b 52 76))
 "transpose"
) (' {click_act=false drag_amt=0.05 bigstep=12})) 2)
(add_ui
 (push_new 8 $yp 28
  (fn () (set copy_buf_syn (copy (@ $state pat_seqs $key))) (set_toast "synth pattern copied"))
  "copy pattern"
 )
)
(add_ui
 (push_new 16 $yp 27
  (fn () (if $copy_buf_syn (seq (merge (@ $state pat_seqs $key) $copy_buf_syn) (set_toast "synth pattern pasted"))))
  "paste pattern"
 )
)
(add_ui
 (toggle_new 0 $yp 107 108 on/off
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
 {x=64,o=6,tt="synth detune"}
 {x=72,o=8,tt="osc 2 fine"}
 {x=80,o=9,tt="osc mix"}
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
))

(set drum_ui_init (fn (add_ui)
(@= (@ $ui grps) drs (pack))
(@= (@ $ui grps) drn (pack))
(for 1 16 (fn (i)
 (let xp (* (~ $i 1) 8))
 (add_ui (step_btn_new drs $xp 120 dr $i (' (19 20 36 21 37 35))) 1)
 (add_ui (note_btn_new drn $xp 120 dr dt $i 50 64 52 76) 2)
))
(add_ui (merge (push_new 8 96 192 (fn ()) "") (' {active=false})) 1)
(add_ui (merge (push_new 16 96 239
 (fn (b) (rotate_pat (@ $state ui_pats dr) (' (st dt)) $b))
 "rotate pattern"
) (' {click_act=false drag_amt=0.05 bigstep=4})))
(add_ui (merge (push_new 8 96 111
 (fn (b) (transpose_pat (@ $state ui_pats dr) dt $b 52 76))
 transpose
) (' {click_act=false drag_amt=0.05 bigstep=12})) 2)
(add_ui (merge
 (spin_btn_new 0 96 $pat_lens "pattern length" (state_make_get_set_pat_len dr))
 (' {w=2 drag_amt=0.03 bigstep=4})
))
(foreach
 (' (
  {k=bd,x=32,y=104,s=150,b=46,tt="bass drum"}
  {k=sd,x=32,y=112,s=152,b=49,tt="snare drum"}
  {k=hh,x=64,y=104,s=154,b=52,tt=hihat}
  {k=cy,x=64,y=112,s=156,b=55,tt=cymbal}
  {k=pc,x=96,y=104,s=158,b=58,tt=percussion}
  {k=fm,x=96,y=112,s=145,b=61,tt="2-op fm"}
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
 (' ({x=32,b=0,tt="bd/sd "} {x=64,b=2,tt="hh/cy "} {x=96,b=4,tt="pc/fm "}))
 (fn (c)
 (add_ui (multitoggle_new
  (@ $c x) 96 (' (101 102 103 104)) (cat (@ $c tt) "fx bypass") (state_make_get_set_param 45 (@ $c b) 2)
 ))
 )
)
(add_ui (push_new
 8 104 11 (fn () (set copy_buf_drum (copy (@ $state pat_seqs dr))) (set_toast "drum pattern copied")) "copy pattern"
))
(add_ui (push_new
 16 104 10 (fn (b) (if $copy_buf_drum
  (if (> $b 0)
   (seq (merge (@ $state pat_seqs dr) $copy_buf_drum) (set_toast "drum pattern pasted"))
   (seq (merge (@ (@ $state pat_seqs dr) (@ $state drum_sel)) (@ $copy_buf_drum (@ $state drum_sel))) (set_toast "drum track pasted"))
  )
 )) "paste pattern"
))
(add_ui (push_new 24 104 "?,5,6,2"
 (fn (b)
  (randomize_pattern (@ $state ui_pats dr))
 )
 "randomize"
))
(add_ui (toggle_new
 0 104 109 110 on/off (state_make_get_set_param_bool 42)
))
(add_ui (spin_btn_new
 0 112 (' (240 241 242 243 244 245 246 247)) "bank select" (state_make_get_set dr_bank)
))
(for 1 6 (fn (i) (add_ui
 (pat_btn_new (+ 5 (* $i 4)) 112 dr 6 $i 2 14 8 5)
)))
(map 0 8 0 96 16 4)
))

(set next_page (fn () (set_page (~ 3 (@ $ui page)))))
(set rewind_t 0)
(set rewind (fn ()
 (go_to_bar
  (let r0 $rewind_t)
  (set rewind_t (time))
  (if (> (~ $rewind_t $r0) 0.2) (@ $state tl loop_start) 1)
 )
))

(set header_ui_init (fn (add_ui)
(let hdial (fn (x y idx tt) (add_ui (dial_new $x $y 128 16 $idx $tt))))
(let song_only
 (fn (w s_not_song) (add_ui (wrap_override $w $s_not_song $state_is_song_mode false)))
)

(add_ui (toggle_new
 0 0 6 7 "play/pause" (take 1 (state_make_get_set playing)) $toggle_playing
))
(add_ui (merge (spin_btn_new 24 0 (' (189 190)) "ui page" $get_page $set_page) (' {click_act=true drag_amt=0 wrap=true})))
(add_ui (toggle_new
 32 0 105 106 "pattern/song mode" $state_is_song_mode $toggle_song_mode
))
(song_only (wrap_override (toggle_new
 8 0 231 232 "record automation" (take 1 (state_make_get_set tl rec))
 $toggle_rec
) 196 $no_uncommitted true) 233)
(song_only (push_new 16 0 5 $rewind rewind) 5)

(add_ui (push_new 96 0 191 $enter_file "file menu"))
(add_ui (push_new 0 8 201 $copy_seq "copy loop"))
(song_only (push_new 8 8 199 $cut_seq "cut loop") 198)
(add_ui (push_new 0 16 197 (fn () (paste_seq false)) "fill loop"))
(song_only (push_new 8 16 203 $insert_seq "insert loop") 202)

(add_ui (wrap_override
 (push_new 8 24 205 $commit_overrides "commit overrides")
 204 $has_uncommitted)
)
(add_ui (wrap_override
 (push_new 0 24 207 $clear_overrides "clear overrides")
 206 $has_uncommitted)
)

(foreach (' (
  (32 8 3 level)
  (48 8 71 "overdrive shape")
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
  (fn (b)
   ((@ $get_set_filt_pat 2) (mid (+ ((@ $get_set_filt_pat 1)) $b) (len $svf_pats)))
  )
 )
 (' {drag_amt=0.02})
))
(let tempos (pack))
(for 60 188 (fn (t)
 (add $tempos (cat (make_thin_ones $t) ",0,15"))
))
(let get_set_tempo (pack (state_make_get_set_param 1)))
(add_ui (merge
 (spin_btn_new 16 8 $tempos "song tempo" (fn () (+ ((@ $get_set_tempo 1)) 1)) (fn (b) ((@ $get_set_tempo 2) (~ $b 1))))
 (' {w=3 drag_amt=0.2})
))
(let dts (pack))
(foreach (' ("" t d)) (fn (suffix)
 (for 1 16 (fn (dt)
  (if (== $suffix d) (let dt (~ $dt 1)))
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
 80 8 (' ("--,0,15" "MA,0,15" "S1,0,15" "S2,0,15" "DR,0,15")) "filter source"
 (state_make_get_set_param 64)
))

(foreach (' ({s=b0 y=8 tt="synth 1 "} {s=b1 y=16 tt="synth 2 "} {s=dr y=24 tt="drums "})) (fn (syn)
 (let base_idx (@ $syn_base_idx (@ $syn s)))
 (foreach (' ({i=0 x=104 tt=level} {i=1 x=112 tt=overdrive} {i=2 x=120 tt="delay send"})) (fn (par)
  (hdial (@ $par x) (@ $syn y) (+ $base_idx (@ $par i)) (cat (@ $syn tt) (@ $par tt)))
 ))
))

(add_ui (merge (transport_number_new 40 0 4 tl bar "song position" (fn (b)
 (go_to_bar (+ (@ $state tl bar) $b))
)) (' {bigstep=4})))

(song_only (toggle_new 56 0 193 194 "loop on/off" (state_make_get_set tl loop)) 195)

(set inc_loop_start (fn (d)
 (let tl (@ $state tl))
 (let ns (+ (@ $tl loop_start) $d))
 (@= $tl loop_start (mid 1 $ns 999))
 (@= $tl loop_len (mid 1 (@ $tl loop_len) (~ 1000 $ns)))
))

(add_ui (merge (transport_number_new 64 0 4 tl loop_start "loop start" $inc_loop_start) (' {bigstep=4})))

(let set_loop_len (fn (tl l)
  (@= $tl loop_len (mid 1 $l (~ 1000 (@ $tl loop_start))))
))

(let loop_len_ctrl
 (transport_number_new 84 0 3 tl loop_len "loop length" (fn (b)
  (let tl (@ $state tl))
  (set_loop_len $tl (+ (@ $tl loop_len) $b))
 ))
)

(@= $loop_len_ctrl on_num
 (fn (num) (set_loop_len (@ $state tl) (<< 1 $num)))
)

(@= $loop_len_ctrl bigstep 4)

(add_ui $loop_len_ctrl)

(map 0 0 0 0 16 4)
))

(set jump_to_banks (fn ()
  (foreach (' (b0 b1 dr)) (fn (syn)
   (let pat (@ $state patch (@ $pat_param_idx $syn)))
   (@= $state (cat $syn _bank) (+ (flr (* (~ $pat 1) 0.1667)) 1))
  ))
))
]]

-- due to how quoting/interpolation works, this needs to be parsed after prereqs have been defined
eval--[[language::loaf]][[
(set hotkey_map (' {
 8=`(id $rewind)
 9=`(id $next_page)
 32=`(id $toggle_playing)
 44=`(fn () (go_to_bar (~ (@ $state tl bar) 1)))
 46=`(fn () (go_to_bar (+ (@ $state tl bar) 1)))
 60=`(fn () (inc_loop_start (~ 0 (@ $state tl loop_len))))
 62=`(fn () (inc_loop_start (@ $state tl loop_len)))
 91=`(fn () (if (@ $ui focus) (paste_ctrl (@ $ui focus param))))
 93=`(fn () (paste_seq true))
 96=`(id $enter_config)
 98=`(id $copy_loop_begin)
 99=`(id $commit_overrides)
 101=`(fn () (if $audio_rec (stop_rec) (start_rec)))
 102=`(id $enter_file)
 103=`(id $jump_to_banks)
 104=`(id $enter_help)
 108=`(id $toggle_loop)
 109=`(id $toggle_song_mode)
 110=`(id $copy_loop_end)
 111=`(id $paste_state)
 112=`(fn () (poke 24368 1) (copy_state true))
 114=`(fn () (if (@ $state song_mode) (toggle_rec)))
 115=`(id $copy_state)
 116=`(id $toggle_tooltips)
 118=`(id $toggle_tooltips)
 120=`(id $clear_overrides)
}))
]]
