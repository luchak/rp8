pico-8 cartridge // http://www.pico-8.com
version 35
__lua__
-- rp-8
-- by luchak

semitone=2^(1/12)

-- give audio time to settle
-- before starting synthesis
function audio_wait(frames)
 pause_frames=frames
 audio_root_obj=nil
end
audio_wait(6)

function copy_state()
 audio_wait(2)
 printh(state:save(),'@clip')
end

function paste_state()
 audio_wait(2)
 local pd=stat(4)
 if pd!='' then
  state=state_load(pd) or state
  seq_helper.state=state
 end
end

show_help=true
function toggle_help()
 show_help=not show_help
 menuitem(4,trn(show_help,'hide tooltips','show tooltips'),toggle_help)
end

audio_rec=false
function start_rec()
 audio_rec=true
 menuitem(3,'stop export',stop_rec)
 extcmd'audio_rec'
end

function stop_rec()
 if (audio_rec) extcmd'audio_end'
 menuitem(3,'start export',start_rec)
end

function _init()
 cls()

 -- no output lpf
 poke(0x5f36,@0x5f36^^0x20)
 -- yes mouse
 poke(0x5f2d,0x1)
 -- faster repeat
 poke(0x5f5c,5)
 poke(0x5f5d,1)

 ui,state=ui_new(),state_new()
 function add_to_ui(w) ui:add_widget(w) end

 header_ui_init(add_to_ui)
 pbl_ui_init(add_to_ui,unpack_split'b0,7,32')
 pbl_ui_init(add_to_ui,unpack_split'b1,19,64')
 pirc_ui_init(add_to_ui)

 local pbl0,pbl1=synth_new(7),synth_new(19)
 local drums={
  sweep_new(unpack_split'38,0.092,0.0126,0.12,0.7,0.7,0.4'),
  snare_new(),
  hh_cy_new(unpack_split'44,1,0.8,0.75,0.35,-1,2'),
  hh_cy_new(unpack_split'47,1.3,0.5,0.5,0.18,0.3,0.8'),
  sweep_new(unpack_split'50,0.12,0.06,0.2,1,0.85,0.6'),
  sample_new(53)
 }
 local kick,snare,hh,cy,perc,sp=unpack(drums)
 local drum_mixer=submixer_new(drums)
 local delay=delay_new()
 local svf=svf_new()
 local drum_keys=split'bd,sd,hh,cy,pc,sp'

 mixer=mixer_new(
  {
   b0={obj=pbl0,lev=0.5,od=0.0,fx=0},
   b1={obj=pbl1,lev=0.5,od=0.5,fx=0},
   dr={obj=drum_mixer,lev=0.5,od=0.5,fx=0},
  },
  delay,
  svf,
  1.0
 )
 comp=comp_new(mixer,unpack_split'0.5,4,0.05,0.002')

 local mixer_params=parse[[{
  b0={s=7,e=9,lev=8},
  b1={s=19,e=21,lev=8},
  dr={s=31,e=33,lev=16},
 }]]
 seq_helper=seq_helper_new(
  state,comp,function()
   local patch,pseq,pstat=
    state.patch,
    state.pat_seqs,
    state.pat_status
   if (not state.playing) return
   local now,nl,bar=state.tick,state.base_note_len,state.bar
   if (pstat.b0.on) pbl0:note(pseq.b0,patch,now,nl)
   if (pstat.b1.on) pbl1:note(pseq.b1,patch,now,nl)
   if pstat.dr.on then
    local dseq=pseq.dr
    for idx,drum in ipairs(drums) do
     drum:note(dseq[drum_keys[idx]],patch,now)
    end
   end
   drum_mixer:note(patch)
   mixer:note(patch)
   svf:note(patch,bar,now)

   local mix_lev,dl_t,dl_fb,comp_thresh=unpack_patch(patch,3,6)
   mixer.lev=pow3(mix_lev)*8

   dl_t=(dl_t<<7)
   if dl_t>32 then
    dl_t=(dl_t-33)+0.5
   elseif dl_t>16 then
    dl_t=(dl_t-16)*0.66667
   end
   delay.l=dl_t*nl
   delay.fb=sqrt(dl_fb)*0.95

   comp.thresh=0.05+0.95*pow3(comp_thresh)

   for key,src in pairs(mixer_params) do
    local msk=mixer.srcs[key]
    local lev,od,fx=unpack_patch(patch,src.s,src.e)
    msk.lev,msk.od,msk.fx=src.lev*pow3(lev),od,pow3(fx)
   end

   state:next_tick()
  end
 )

 menuitem(1, 'save to clip', copy_state)
 menuitem(2, 'load from clip', paste_state)
 stop_rec()
 toggle_help()

 log'init complete'
end

function _update60()
 if stat(120) then
  local s={}
  state.samp=s
  local nread=0
  while stat(120) do
   local n=serial(0x800,0x5100,0x800)
   for i=0x5100,0x50ff+n do
    if nread<0x7fff then
     add(s,@i)
     nread+=1
    end
   end
  end
  audio_wait(10)
 end

 audio_update()
 if pause_frames<=0 then
  ui:update(state)
  audio_root_obj=seq_helper
 else
  pause_frames-=1
 end
end

function _draw()
 ui:draw(state)
 palt(0,false)
end

#include utils.lua

-->8
-- audio driver

_schunk=100
_bufpadding=2*_schunk
sample_rate=5512.5
_audio_dcf=0

function audio_update()
 if stat(108)<stat(109)+_bufpadding then
  local dcf=_audio_dcf
  local buf={}
  if audio_root_obj then
   audio_root_obj:update(buf,1,_schunk)
  else
   for i=1,_schunk do
    buf[i]=0
   end
  end
  for i=1,_schunk do
   -- dc filter plus soft clipping
   local x=buf[i]<<8
   dcf+=(x-dcf)>>8
   x-=dcf
   x=mid(-1,x>>8,1)
   x-=0.148148*x*x*x
   -- add dither for nicer tails
   poke(0x42ff+i,flr((x<<7)+0.375+(rnd()>>2))+128)
  end
  serial(0x808,0x4300,_schunk)
  _audio_dcf=dcf
 end
end
-->8
-- audio gen

function synth_new(base)
 local obj,_op,_odp,_todp,_todpr,_fc,_fr,_os,_env,_acc,
       _detune,_fc,_f1,_f2,_f3,_f4,_fosc,_ffb,_me,_med,
       _ae,_aed,_nt,_nl={},
       unpack_split'0,0.001,0.001,0.999,0.5,3.6,4,0.5,0.5,1,0,0,0,0,0,0,0,0,0.99,0,0.997,900'
 local _mr,_ar,_gate,_saw,_ac,_sl,_lsl=parse[[{
  1=false,2=false,3=false,4=false,5=false,6=false,7=false
 }]]

 function obj:note(pat,patch,step,note_len)
  local patstep,saw,tun,cut,res,env,dec,acc=pat.st[step],unpack_patch(patch,base+5,base+11)

  _fc=(100/sample_rate)*(2^(4*cut))/_os
  _fr=res*4.9+0.1
  _env=env*env+0.1
  _acc=acc*1.9+0.1
  _saw=saw>0
  local pd=dec-1
  if (patstep==n_ac or patstep==n_ac_sl) pd=-0.99
  _med=0.999-0.01*pow4(pd)
  _nt,_nl=0,note_len
  _lsl=_sl
  _gate=false
  _detune=semitone^(flr(24*(tun-0.5)+0.5))
  _ac=patstep==n_ac or patstep==n_ac_sl
  _sl=patstep==n_sl or patstep==n_ac_sl
  if (patstep==n_off) return

  _gate=true
  local f=55*(semitone^(pat.nt[step]+3))
  --ordered for safety
  _todp=(f/_os)/(sample_rate>>16)

  if (_ac) _env+=acc
  if _lsl then
   _todpr=0.015
  else
   _todpr=0.995
   _mr=true
  end

  _nt=0
 end

 function obj:update(b,first,last)
  local odp,op,detune,todp,todpr=_odp,_op,_detune,_todp,_todpr
  local f1,f2,f3,f4=_f1,_f2,_f3,_f4
  local fr,fcb,os=_fr,_fc,_os
  local ae,aed,me,med,mr=_ae,_aed,_me,_med,_mr
  local env,saw,lev,acc=_env,_saw,_lev,_acc
  local gate,nt,nl,sl,ac=_gate,_nt,_nl,_sl,_ac
  local fosc,ffb=_fosc,_ffb
  for i=first,last do
   local fc=min(0.4/os,fcb+((me*env)>>4))
   -- janky dewarping
   -- scaling constant is 0.75*2*pi because???
   fc=4.71*fc/(1+fc)
   local fc1=(0.6+fc)>>1
   if gate then
    ae+=(1-ae)>>2
    if ((nt>(nl>>1) and not sl) or nt>nl) gate=false
   else
    ae*=aed
   end
   if mr then
    me+=(1-me)>>2
    mr=not (me>0.99)
   else
    me*=med
   end
   odp+=todpr*(todp-odp)
   local dodp=odp*detune
   _nt+=1
   for j=1,os do
    local osc=op>>15
    if not saw then
     osc=0.5+((osc&0x8000)>>15)
    end
    fosc+=(osc-fosc)>>5
    osc-=fosc
    ffb+=(f4-ffb)>>5
    local x=osc-fr*(f4-ffb-osc)
    local xc=mid(-1,x,1)
    x=xc+(x-xc)*0.9840

    f1+=(x-f1)*fc1
    f2+=(f1-f2)*fc
    f3+=(f2-f3)*fc
    f4+=(f3-f4)*fc

    op+=dodp
   end
   local out=(f4*ae)>>2
   if (ac) out+=acc*me*out
   b[i]=out
  end
  _op,_odp,_gate=op,odp,gate
  _f1,_f2,_f3,_f4,_fosc,_ffb=f1,f2,f3,f4,fosc,ffb
  _me,_ae,_mr=me,ae,mr
 end

 return obj
end

function sweep_new(base,_dp0,_dp1,ae_ratio,boost,te_base,te_scale)
 local obj,_op,_dp,_ae,_aemax,_aed,_ted,_detune=
  {},unpack_split'0,6553.6,0,0.6,0.995,0.05,1'

 function obj:note(pat,patch,step)
  local s=pat[step]
  local tun,dec,lev=unpack_patch(patch,base,base+2)
  if s!=d_off then
   -- TODO: param updates should be reflected on every step?
   _detune=2^(1.5*tun-0.75)
   _op,_dp=0,(_dp0<<16)*_detune
   _ae=lev*lev*boost*trn(s==d_ac,1.5,0.6)
   _aemax=0.5*_ae
   _ted=0.5*pow4(te_base-te_scale*dec)
   _aed=1-ae_ratio*_ted
  end
 end

 function obj:subupdate(b,first,last)
  local op,dp,dp1,ae,aed,ted=_op,_dp,(_dp1<<16)*_detune,_ae,_aed,_ted
  local aemax=_aemax
  for i=first,last do
   op+=dp
   dp+=ted*(dp1-dp)
   ae*=aed
   b[i]+=min(ae,aemax)*sin(0.5+(op>>16))
  end
  _op,_dp,_ae=op,dp,ae
 end

 return obj
end

function snare_new()
 local obj,_dp0,_dp1,_op,_dp,_aes,_aen,_detune,_aesd,_aend,_aemax=
  {},unpack_split'0.08,0.042,0,0.05,0,0,10,0.99,0.996,0.4'

 function obj:note(pat,patch,step)
  local s=pat[step]
  local tun,dec,lev=unpack_patch(patch,41,43)
  if s!=d_off then
   _detune=2^(2*tun-1)
   _op,_dp=0,_dp0*_detune
   _aes,_aen=0.7,0.4
   if (s==d_ac) _aes,_aen=1.5,0.85
   local lev2,aeo=lev*lev,(tun-0.5)*0.2
   _aes-=aeo
   _aen+=aeo
   _aes*=lev2
   _aen*=lev2
   _aemax=_aes*0.5
   local pd4=pow4(0.65-0.25*dec)
   _aesd=1-0.1*pd4
   _aend=1-0.04*pd4
  end
 end

 function obj:subupdate(b,first,last)
  local op,dp,dp1=_op,_dp,_dp1*_detune
  local aes,aen,aesd,aend=_aes,_aen,_aesd,_aend
  local aemax=_aemax
  for i=first,last do
   op+=dp
   dp+=(dp1-dp)>>7
   aes*=aesd
   aen*=aend
   if (op>=1) op-=2
   b[i]+=(min(aemax,aes)*sin(op)+aen*(2*rnd()-1))*0.3
  end
  _dp,_op,_aes,_aen=dp,op,aes,aen
 end

 return obj
end

function hh_cy_new(base,_nlev,_tlev,dbase,dscale,tbase,tscale)
 local obj,_ae,_f1,_f2,_op1,_odp1,_op2,_odp2,_op3,_odp3,_op4,_odp4,_aed,_detune=
  {},unpack_split'0,0,0,0,14745.6,0,17039.36,0,15400.96,0,15892.48,0.995,1'

 function obj:note(pat,patch,step)
  local s=pat[step]
  local tun,dec,lev=unpack_patch(patch,base,base+2)
  if s!=d_off then
   _op,_dp=0,_dp0
   _ae=lev*lev*trn(s==d_ac,2.0,0.8)

   _detune=2^(tbase+tscale*tun)
   local pd=(dbase-dscale*dec)

   _aed=1-0.04*pow4(pd)
  end
 end

 function obj:subupdate(b,first,last)
  local ae,f1,f2,aed,tlev,nlev=_ae,_f1,_f2,_aed,_tlev,_nlev
  local op1,op2,op3,op4,detune=_op1,_op2,_op3,_op4,_detune
  local odp1,odp2,odp3,odp4=_odp1*detune,_odp2*detune,_odp3*detune,_odp4*detune

  for i=first,last do
   local osc=1.0
   osc+=(op1&0x8000)>>16
   osc+=(op2&0x8000)>>16
   osc+=(op3&0x8000)>>16
   osc+=(op4&0x8000)>>16

   local r=nlev*(rnd()-0.5)+tlev*osc
   f1+=0.8*(r-f1)
   f2+=0.8*(f1-f2)
   ae*=aed
   b[i]+=ae*((r-f2)>>1)
   op1+=odp1
   op2+=odp2
   op3+=odp3
   op4+=odp4
  end
  _ae,_f1,_f2=ae,f1,f2
  _op1,_op2,_op3,_op4=op1,op2,op3,op4
 end

 return obj
end

function sample_new(base)
 local obj,_pos,_detune,_dec,_amp={},unpack_split'1,0,0,1,0.99,0.5'

 function obj:note(pat,patch,step)
  local s=pat[step]
  local tun,dec,lev=unpack_patch(patch,base,base+2)
  _dec=1-(0.2*(1-dec)^2)
  _detune=2^(flr((tun-0.5)*24+0.5)/12)
  if s!=d_off then
   _pos=1
   _amp=lev*lev*trn(s==d_ac,1,0.5)
  end
 end

 function obj:subupdate(b,first,last)
  local pos,samp=_pos,state.samp
  if (pos<0) return
  local amp,dec,detune,n=_amp,_dec,_detune,#samp
  for i=first,last do
   if (pos>=n) pos=-1 break
   local pi=pos&0xffff.0000
   local po,s0,s1=pos-pi,samp[pi],samp[pi+1]
   local val=s0+po*(s1-s0)

   b[i]+=amp*((val>>7)-1)
   if (pi&0xff==0) amp*=dec
   pos+=detune
  end
  _pos,_amp=pos,amp
 end

 return obj
end
-->8
-- audio fx

function delay_new()
 local obj,_dl,_p,_f1={l=20,fb=0},{},1,0

 for i=1,0x7fff do
  _dl[i]=0
 end

 function obj:update(b,first,last)
  local dl,l,fb,p,f1=_dl,self.l,self.fb,_p,_f1
  for i=first,last do
   local x,y=b[i],dl[p]
   if (abs(y)<0x0.0100) y=0
   b[i]=y
   y=x+fb*y
   f1+=(y-f1)>>4
   dl[p]=y-(f1>>2)
   p+=1
   if (p>l) p=1
  end
  _p,_f1=p,f1
 end

 return obj
end


dr_src_fx_masks=parse[[{1=1,2=1,3=2,4=2,5=4,6=4}]]
function submixer_new(srcs)
 return {
  srcs=srcs,
  fx=127,
  note=function(self,patch) self.fx=patch[37] end,
  update=function(self,b,first,last,bypass)
   for i=first,last do
    b[i]=0
    bypass[i]=0
   end

   for i,src in ipairs(self.srcs) do
    if (self.fx&dr_src_fx_masks[i]>0) src:subupdate(b,first,last) else src:subupdate(bypass,first,last)
   end
  end
 }
end

filtmap=parse[[{b0=3,b1=4,dr=5}]]
function mixer_new(srcs,fx,filt,lev)
 return {
  srcs=srcs,lev=lev,tmp={},bypass={},fxbuf={},filtsrc=1,
  note=function(self,state)
   self.filtsrc=flr(state[56]>>1)
  end,
  update=function(self,b,first,last)
   local fxbuf,tmp,bypass,lev,filtsrc=self.fxbuf,self.tmp,self.bypass,self.lev,self.filtsrc
   for i=first,last do
    b[i],fxbuf[i]=0,0
   end

   for k,src in pairs(self.srcs) do
    local slev,od,fx=src.lev,src.od*src.od,src.fx
    src.obj:update(tmp,first,last,bypass)
    local odf=0.3+31.7*od
    local odfi=(1+3*od)/odf
    for i=first,last do
     local x=mid(-1,tmp[i]*odf,1)
     tmp[i]=slev*odfi*(x-0.148148*x*x*x)
    end
    if (filtmap[k]==filtsrc) filt:update(tmp,first,last)
    for i=first,last do
     local x=tmp[i]
     b[i]+=x*lev
     fxbuf[i]+=x*fx
    end
   end

   fx:update(fxbuf,first,last)
   local drlev=self.srcs.dr.lev
   for i=first,last do
    b[i]+=(fxbuf[i]+bypass[i]*drlev)*lev
   end
   if (filtsrc==2) filt:update(b,first,last)
  end
 }
end

function comp_new(src,thresh,ratio,_att,_rel)
 return {
  src=src,
  thresh=thresh,
  ratio=ratio,
  env=0,
  update=function(self,b,first,last)
   self.src:update(b,first,last)
   local env,att,rel=self.env,_att,_rel
   local thresh,ratio=self.thresh,1/self.ratio
   -- makeup targets 0.6
   local makeup=max(1,0.6/((0.6-thresh)*ratio+thresh))
   for i=first,last do
    local x=abs(b[i])
    local c
    if (x>env) c=att else c=rel
    env+=c*(x-env)
    local g,te=makeup,thresh/env
    if (env>thresh) g*=te+ratio*(1-te)
    b[i]*=g
   end
   self.env=env
  end
 }
end

svf_pats=parse[[{
 1="@///////////////",
 2="@///////",
 3="@///",
 4="@/",
 5="@",
 6="@//@//@//@//@//@",
 7="//@//@////@//@//",
 8="/123456789:;<=>@",
 9="8899::;;<<==>>@@",
 10="8/9/:/;/</=/>/@/",
 11="@/>/=/</;/:/9/8/",
 12="==/3@@:/23@114:;92>:5<:27<@//;>8;3;43;64</;883=4:",
 13=">/3/7/</=/8/5/>/2/@/5/4/2/>/3/@/7/3/3/;/</6/2/;/7/",
 14="@;:=<@:=;8@;<>>@8@<999;8=<==:99:=<8:=:=<;8<<@8=<8",
 15=";/=/>/@/;/:/9/;/@/;/=/</@/@/</</>/</;/:/@/</;/</@/",
 16="@//",
 17="@////",
 18="@//////",
 19="@//:/",
 20="////////@///////",
 21="////@///",
 22="//@/",
 23="/@",
 24=":///@/////:/@///",
}]]

-- heavily inspired by
-- https://github.com/JordanTHarris/VAStateVariableFilter
function svf_new()
 local _z1,_z2,_rc,_gc,_wet,_fe,_bp,_dec=unpack_split'0,0,0.1,0.2,1,1,0,1'
 return {
  note=function(self,patch,bar,tick)
   local r,bp,gc,dec
   bp,gc,r,self.wet,_,dec=unpack_patch(patch,56,61)
   _rc=1-r*0.96
   local svf_pat=svf_pats[patch[60]]
   local pat_val=ord(svf_pat,(bar*16+tick-17)%#svf_pat+1)-48
   if (pat_val>=0) _fe=pat_val>>4
   _dec=1-(pow3(1-dec)>>7)
   _bp=(bp&0x0.02>0 and 1) or 0
   _gc=gc*gc+0x0.02
  end,
  update=function(self,b,first,last)
   local z1,z2,rc,gc_base,wet,fe,is_bp,dec=_z1,_z2,_rc,_gc,_wet,_fe,_bp,_dec
   for i=first,last do
    gc=min(gc_base*fe,1)
    local rrpg=2*rc+gc
    local hpn,inp=1/gc+rrpg,b[i]
    local hpgc=(inp-rrpg*z1-z2)/hpn
    local bp=hpgc+z1
    local lp=bp*gc+z2
    z1,z2=hpgc+bp,bp*gc+lp

    -- 2x oversample
    hpgc=(inp-rrpg*z1-z2)/hpn
    bp=hpgc+z1
    lp=bp*gc+z2
    z1,z2=hpgc+bp,bp*gc+lp

    -- rc*bp is 1/2 of unity gain bp
    b[i]=inp+wet*(lp+is_bp*(rc*bp+bp-lp)-inp)
    fe*=dec
   end
   _z1,_z2,_fe=z1,z2,fe
  end
 }
end

#include events.lua

-->8
-- state

n_off,n_on,n_ac,n_sl,n_ac_sl,d_off,d_on,d_ac=unpack_split'64,65,66,67,68,64,65,66'

syn_base_idx=parse[[{b0=7,b1=19,dr=31,bd=38,sd=41,hh=44,cy=47,pc=50,sp=53}]]

pat_param_idx=parse[[{b0=11,b1=23,dr=35}]]

-- see note 003
default_patch=split'64,0,64,3,64,128,64,0,0,1,1,1,64,64,64,64,64,64,64,0,0,1,1,1,64,64,64,64,64,64,64,0,0,1,1,64,127,64,64,64,64,64,64,64,64,64,64,64,64,64,64,64,64,64,64,2,64,64,128,1,128'

pbl_pat_template=parse[[{
 nt={1=19,2=19,3=19,4=19,5=19,6=19,7=19,8=19,9=19,10=19,11=19,12=19,13=19,14=19,15=19,16=19},
 st={1=64,2=64,3=64,4=64,5=64,6=64,7=64,8=64,9=64,10=64,11=64,12=64,13=64,14=64,15=64,16=64},
}]]

drum_pat_template=parse[[{
 bd={1=64,2=64,3=64,4=64,5=64,6=64,7=64,8=64,9=64,10=64,11=64,12=64,13=64,14=64,15=64,16=64},
 sd={1=64,2=64,3=64,4=64,5=64,6=64,7=64,8=64,9=64,10=64,11=64,12=64,13=64,14=64,15=64,16=64},
 hh={1=64,2=64,3=64,4=64,5=64,6=64,7=64,8=64,9=64,10=64,11=64,12=64,13=64,14=64,15=64,16=64},
 cy={1=64,2=64,3=64,4=64,5=64,6=64,7=64,8=64,9=64,10=64,11=64,12=64,13=64,14=64,15=64,16=64},
 pc={1=64,2=64,3=64,4=64,5=64,6=64,7=64,8=64,9=64,10=64,11=64,12=64,13=64,14=64,15=64,16=64},
 sp={1=64,2=64,3=64,4=64,5=64,6=64,7=64,8=64,9=64,10=64,11=64,12=64,13=64,14=64,15=64,16=64},
}]]

function state_new(savedata)
 local s=parse[[{
  pat_store={},
  tick=1,
  playing=false,
  base_note_len=750,
  note_len=750,
  drum_sel="bd",
  b0_bank=1,
  b1_bank=1,
  dr_bank=1,
  song_mode=false,
  samp={1=0}
 }]]

 s.tl=timeline_new(default_patch)
 s.pat_patch=copy(default_patch)
 s.patch={}
 s.pat_seqs={}
 s.pat_status={}
 if savedata then
  s.tl=timeline_new(default_patch,savedata.tl)
  s.pat_patch=dec_bytes(savedata.pat_patch)
  s.song_mode=savedata.song_mode
  s.pat_store=map_table(savedata.pat_store,dec_bytes,2)
  s.samp=dec_bytes(savedata.samp)
 end

 function s:_init_tick()
  local patch=self.patch
  local nl=sample_rate*(15/(60+patch[1]))
  local shuf_diff=nl*(patch[2]>>7)*(0.5-(self.tick&1))
  self.note_len,self.base_note_len=flr(0.5+nl+shuf_diff),nl
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
  self:_sync_pats()
  self:_init_tick()
 end
 local load_bar=function(i) s:load_bar(i) end

 function s:_apply_diff(k,v)
  self.patch[k]=v
  if self.song_mode then
   self.tl:record_event(k,v)
  else
   self.pat_patch[k]=v
  end
  if (not self.playing) load_bar()
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
  self:_init_tick()
 end

 function s:toggle_playing()
  local tl=self.tl
  if self.playing then
   if (tl.rec) tl:toggle_rec()
   tl:clear_overrides()
  end
  load_bar()
  self.playing=not self.playing
 end

 function s:toggle_rec()
  self.tl:toggle_rec()
 end

 function s:toggle_song_mode()
  self.song_mode=not self.song_mode
  self:stop_playing()
  load_bar()
 end

 function s:_sync_pats()
  local ps,patch=self.pat_store,self.patch
  for syn,param_idx in pairs(pat_param_idx) do
   local syn_pats=ps[syn]
   if not syn_pats then
    syn_pats={}
    self.pat_store[syn]=syn_pats
   end
   local pat_idx=patch[param_idx]
   local pat=syn_pats[pat_idx]
   if not pat then
    if (syn=='b0' or syn=='b1') pat=copy(pbl_pat_template) else pat=copy(drum_pat_template)
    syn_pats[pat_idx]=pat
   end
   self.pat_seqs[syn]=pat
  end
  for group,idx in pairs(pat_param_idx) do
   self.pat_status[group]={
    on=patch[idx-1]>0,
    idx=patch[idx],
   }
  end
 end

 function s:go_to_bar(bar)
  load_bar(mid(1,bar,999))
 end

 function s:get_pat_steps(syn)
  -- assume pats are aliased, always editing current
  return trn(syn=='dr',self.pat_seqs.dr[self.drum_sel],self.pat_seqs[syn].st)
 end

 function s:save()
  return 'rp80'..stringify({
   tl=self.tl:get_serializable(),
   song_mode=self.song_mode,
   pat_patch=enc_bytes(self.pat_patch),
   pat_store=map_table(self.pat_store,enc_bytes,2),
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

 load_bar()
 return s
end

function state_load(str)
 if (sub(str,1,4)!='rp80') return nil
 return state_new(parse(sub(str,5)))
end

function transpose_pat(pat,d)
 for i=1,16 do
  pat.nt[i]=mid(0,pat.nt[i]+d,36)
 end
end

function state_make_get_set_param(idx,shift)
 local shift=shift or 0
 local mask=(1<<shift)-1
 return
  function(state) return (state.patch[idx]>>shift)&0xffff.0000 end,
  function(state,val)
   state:_apply_diff(idx,val<<shift | (state.patch[idx]&mask))
  end
end

function state_make_get_set_param_bool(idx,bit)
 local mask=1<<(bit or 0)
 return
  function(state) return (state.patch[idx]&mask)>0 end,
  function(state,val) local old=state.patch[idx] state:_apply_diff(idx,trn(val,old|mask,old&(~mask))) end
end

function state_make_get_set(a,b)
 return
  function(s) if b then return s[a][b] else return s[a] end end,
  function(s,v) if b then s[a][b]=v else s[a]=v end end
end

state_is_song_mode=function(state) return state.song_mode end

-- passthrough audio processor
-- that splits blocks to allow
-- for sample-accurate note
-- triggering
function seq_helper_new(state,root,note_fn)
 return {
  state=state,
  root=root,
  t=state.note_len,
  update=function(self,b,first,last)
   local p=first
   while p<=last do
    if self.t>=self.state.note_len then
     self.t=0
     note_fn()
    end
    local n=min(self.state.note_len-self.t,last-p+1)
    self.root:update(b,p,p+n-1)
    self.t+=n
    p+=n
   end
   if (not self.state.playing) self.t=0
  end
 }
end
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
  mouse_tiles={},
  mx=0,
  my=0,
  hover_frames=0,
  help_on=false
 }]]
 -- obj.focus
 -- obj.hover

 function obj:add_widget(w)
  w=merge(copy(widget_defaults),w)
  local widgets=self.widgets
  add(widgets,w)
  w.id,w.tx,w.ty=#widgets,w.x\4,w.y\4
  local tile=w.tx+w.ty*32
  for dx=0,w.w-1 do
   for dy=0,w.h-1 do
    self.mouse_tiles[tile+dx+dy*32]=w
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

  -- draw focus indicator
  if f then
   spr(1,f.x,f.y,1,1)
   sspr(32,0,4,8,f.x+f.w*4-4,f.y)
  end

  -- store rows behind mouse and draw mouse
  local next_off=mid(0,my,122)<<6
  memcpy(0x9000+next_off,0x6000+next_off,448)
  local hover=self.hover
  spr(15,mx,my)
  if show_help and self.hover_frames>30 and hover and hover.active and hover.tt then
   local tt=hover.tt
   local xp=trn(mx<56,mx+7,mx-2-4*#tt)
   rectfill(xp,my,xp+4*#tt,my+6,1)
   print(tt,xp+1,my+1,7)
  end
  self.mouse_restore_offset=next_off
 end

 function obj:update(state)
  local input=0
  if (btnp(5)) input+=1
  if (btnp(4)) input-=1

  self.mx,self.my,click=stat(32),stat(33),stat(34)
  local mx,my,k=self.mx,self.my
  local hover=self.mouse_tiles[mx\4 + (my\4)*32]

  if (stat(30)) k=stat(31)
  if (k=='h') toggle_help()

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
    poke(0x5f2d, 0x5)
    self.click_x,self.click_y,self.drag_dist,self.last_drag=mx,my,0,0
    new_focus=trn(hover and hover.active,hover,nil)
    if (new_focus and new_focus.click_act) input=trn(click==1,1,-1)
   end
  else
   poke(0x5f2d, 0x1)
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
  if (self.hover==hover and click==0) self.hover_frames+=1 else self.hover_frames=0

  self.last_click,self.hover,self.last_my,self.focus=click,hover,my,focus
 end

 return obj
end

function pbl_note_btn_new(x,y,syn,step)
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
 -- last sprite is for the current step
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

function momentary_new(x,y,s,cb,tt)
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

function wrap_override(w,s_override,get_not_override,override_active)
 local get_sprite=w.get_sprite
 w.get_sprite=function(self,state)
  if get_not_override(state) then
   self.active=true
   return get_sprite(self,state)
  else
   self.active=override_active
   return s_override
  end
 end
 return w
end

function transport_number_new(x,y,w,obj,key,tt,input)
 return wrap_override(
  number_new(x,y,w,tt,state_make_get_set(obj,key),input),
  '--,0,15',
  state_is_song_mode
 )
end

function pbl_ui_init(add_to_ui,key,base_idx,yp)
 for i=1,16 do
  local xp=i*8-8
  add_to_ui(
   pbl_note_btn_new(xp,yp+24,key,i)
  )
  add_to_ui(
   step_btn_new(xp,yp+16,key,i,split'16,17,33,18,34,32')
  )
 end

 local transpose_btn = momentary_new(24,yp,26,function(state,b)
  transpose_pat(state.pat_seqs[key],b)
 end,'transpose (drag)')
 transpose_btn.click_act=false
 transpose_btn.drag_amt=0.05
 add_to_ui(transpose_btn)

 add_to_ui(
  momentary_new(8,yp,28,function(state,b)
   copy_buf_pbl=copy(state.pat_seqs[key])
  end,'copy pattern')
 )
 add_to_ui(
  momentary_new(16,yp,27,function(state,b)
   local v=copy_buf_pbl
   if (v) merge(state.pat_seqs[key],v)
  end,'paste pattern')
 )
 add_to_ui(
  toggle_new(0,yp,186,187,'active',state_make_get_set_param_bool(base_idx+3))
 )
 add_to_ui(
  spin_btn_new(0,yp+8,split'162,163,164,165','bank select',state_make_get_set(key..'_bank'))
 )
 for i=1,6 do
  add_to_ui(
   pat_btn_new(5+i*4,yp+8,key,6,i,unpack_split'2,14,8,6')
  )
 end

 for d in all(parse[[{
  1={x=40,o=6,tt="tune"},
  2={x=56,o=7,tt="filter cutoff"},
  3={x=72,o=8,tt="filter resonance"},
  4={x=88,o=9,tt="filter env amount"},
  5={x=104,o=10,tt="filter env decay"},
  6={x=120,o=11,tt="accent depth"},
 }]]) do
  add_to_ui(
   dial_new(
    d.x,yp,43,21,base_idx+d.o,d.tt
   )
  )
 end

 add_to_ui(
  toggle_new(32,yp,2,3,'waveform',state_make_get_set_param_bool(base_idx+5))
 )

 map(0,4,0,yp,16,2)
end


function pirc_ui_init(add_to_ui)
 for i=1,16 do
  add_to_ui(
   step_btn_new(i*8-8,120,'dr',i,split'19,20,36,35')
  )
 end
 for k,d in pairs(parse[[{
  bd={x=32,y=104,s=150,b=38,tt="bass drum"},
  sd={x=32,y=112,s=152,b=41,tt="snare drum"},
  hh={x=64,y=104,s=154,b=44,tt="hihat"},
  cy={x=64,y=112,s=156,b=47,tt="cymbal"},
  pc={x=96,y=104,s=158,b=50,tt="percussion"},
  sp={x=96,y=112,s=174,b=53,tt="sample"}
 }]]) do
  add_to_ui(
   radio_btn_new(d.x,d.y,k,d.s,d.s+1,d.tt,state_make_get_set'drum_sel')
  )
  -- lev,tun,dec
  for dial in all(parse[[{1={x=8,o=2,tt="level"},2={x=16,o=0,tt="tune"},3={x=24,o=1,tt="decay"}}]]) do
   add_to_ui(
    dial_new(d.x+dial.x,d.y,112,16,d.b+dial.o,k..' '..dial.tt)
   )
  end
 end

 for fx in all(parse[[{1={x=32,b=0,tt="bd/sd "},2={x=64,b=1,tt="hh/cy "},3={x=96,b=2,tt="pc/sp "}}]]) do
  add_to_ui(
   toggle_new(fx.x,96,170,171,fx.tt..'fx bypass',state_make_get_set_param_bool(37,fx.b))
  )
 end

 add_to_ui(
  momentary_new(8,104,11,function(state,b)
   copy_buf_pirc=copy(state.pat_seqs['dr'])
  end, 'copy pattern')
 )
 add_to_ui(
  momentary_new(16,104,10,function(state,b)
   merge(state.pat_seqs['dr'],copy_buf_pirc)
  end, 'paste pattern')
 )

 add_to_ui(
  toggle_new(0,104,188,189,'active',state_make_get_set_param_bool(34))
 )

 add_to_ui(
  spin_btn_new(0,112,split'166,167,168,169','bank select',state_make_get_set('dr_bank'))
 )
 for i=1,6 do
  add_to_ui(
   pat_btn_new(5+i*4,112,'dr',6,i,unpack_split'2,14,8,5')
  )
 end

 map(unpack_split'0,8,0,96,16,4')
end

function header_ui_init(add_to_ui)
 local function hdial(x,y,idx,tt)
  add_to_ui(
   dial_new(x,y,128,16,idx,tt)
  )
 end

 local function song_only(w,s_not_song)
  add_to_ui(
   wrap_override(w,s_not_song,state_is_song_mode,false)
  )
 end

 add_to_ui(
  toggle_new(
   0,0,6,7,
   'play/pause',
   state_make_get_set'playing',
   function(s) s:toggle_playing() end
  )
 )
 add_to_ui(
  toggle_new(
   24,0,172,173,
   'pattern/song mode',
   state_is_song_mode,
   function(s) s:toggle_song_mode() end
  )
 )
 song_only(
  wrap_override(
   toggle_new(
    8,0,231,232,
    'record automation',
    state_make_get_set('tl','rec'),
    function(s) s:toggle_rec() end
   ),
   239,
   function(s) return (not s.tl.has_override) or s.tl.rec end,
   true
  ),
  233
 )
 song_only(
  momentary_new(
   16,0,5,
   function()
    state:go_to_bar(
     trn(
      state.tl.bar>state.tl.loop_start,
      state.tl.loop_start,
      1
     )
    )
   end,
   'rewind'
  ),
  5
 )

 add_to_ui(momentary_new(
  0,8,242,
  function(s)
   s:copy_seq()
  end,
  'copy loop'
 ))
 song_only(momentary_new(
  8,8,241,
  function(s)
   s:cut_seq()
  end,
  'cut loop'
 ),199)
 add_to_ui(momentary_new(
  0,16,247,
  function(s)
   s:paste_seq()
  end,
  'fill loop'
 ))
 song_only(momentary_new(
  8,16,243,
  function(s)
   s:insert_seq()
  end,
  'insert loop'
 ),201)
 song_only(momentary_new(
  8,24,246,
  function(s)
   s.tl:copy_overrides_to_loop()
  end,
  'commit touched controls'
 ),204)

 for s in all(parse[[{
  1="16,8,1,tempo",
  2="32,8,3,level",
  3="32,16,6,compressor threshold",
  4="16,16,2,shuffle",
  5="32,24,5,delay feedback",
  6="48,16,57,filter cutoff",
  7="48,24,58,filter resonance",
  8="64,24,59,filter wet/dry",
  9="80,24,61,filter env decay",
 }]]) do
  hdial(unpack_split(s))
 end
 local get_filt_pat,set_filt_pat=state_make_get_set_param(60)
 local filt_pat_ctl=number_new(80,16,2,'filter pattern',get_filt_pat,function(state,b)
   set_filt_pat(state,mid(1,get_filt_pat(state)+b,#svf_pats))
  end)
 filt_pat_ctl.drag_amt=0.02
 add_to_ui(filt_pat_ctl)

 local dts={}
 for suffix in all(split(',t,d')) do
  for dt in all(split('1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16')) do
   if (suffix=='d') dt-=1
   add(dts,dt..suffix..',0,15')
  end
 end
 local dt_spin_btn=spin_btn_new(16,24,dts,'delay time',state_make_get_set_param(4))
 dt_spin_btn.w=3
 add_to_ui(dt_spin_btn)

 local filt_toggle=toggle_new(64,16,234,235,'filter lp/bp',state_make_get_set_param_bool(56,0))
 filt_toggle.click_act=false
 filt_toggle.drag_amt=0.01
 add_to_ui(filt_toggle)
 add_to_ui(
  spin_btn_new(64,8,parse[[{1="--,0,15",2="MA,0,15",3="S1,0,15",4="S2,0,15",5="DR,0,15"}]],'filter source',state_make_get_set_param(56,1))
 )

 for syn,sd in pairs(parse[[{b0={y=8,tt="synth 1 "},b1={y=16,tt="synth 2 "},dr={y=24, tt="drums "}}]]) do
  local base_idx=syn_base_idx[syn]
  for idx,cd in pairs(parse[[{0={x=104,tt="level"},1={x=112,tt="overdrive"},2={x=120,tt="delay send"}}]]) do
   hdial(cd.x,sd.y,base_idx+idx,sd.tt..cd.tt)
  end
 end
 add_to_ui(
  transport_number_new(32,0,4,'tl','bar','song position',
   function(state,b)
    state:go_to_bar(state.tl.bar+b)
   end
  )
 )
 song_only(
  toggle_new(56,0,193,194,'loop on/off',state_make_get_set('tl','loop')),
  195
 )
 add_to_ui(
  transport_number_new(64,0,4,'tl','loop_start','loop start',
   function(state,b)
    local tl=state.tl
    local ns=tl.loop_start+b
    tl.loop_start=mid(1,ns,999)
    tl.loop_len=mid(1,tl.loop_len,1000-ns)
   end
  )
 )
 add_to_ui(
  transport_number_new(84,0,3,'tl','loop_len','loop length',
   function(state,b)
    local tl=state.tl
    tl.loop_len=mid(1,tl.loop_len+b,1000-tl.loop_start)
   end
  )
 )

 map(unpack_split'0,0,0,0,16,4')
end

__gfx__
0000000000000000666666666666666600cc000000000000000000000000000000000000000000005555555555555555000000050d0000006666666607000000
00000000000000006557000660005576000c0000006000606000f0f0b000606000000000000000005555555556666555000000001dd000006666666617700000
0070070000000000655500066000555600000000006005505600f0f03b00606000000000000000005556655556556555000000051ddd00006666666617770000
0007700000000000666666666666666600000000005055505560909033b0505000000000fff0fff05566665556566665000000001dddd0006666666617777000
000770000000000065556656655566560000000000505550555090903330505000000000000000005565565556565565000000051dd100006666666617710000
00700700000000006565655665656556000000000050055055009090330050500000000000000000556556555666556500000000011000006666666601100000
00000000c00000006565555665655556000000000050005050009090300050500000000000000000556556555556556500000005000000006666666600000000
00000000cc0000006666666666666666000000000000000000000000000000000000000000000000556666555556666500000000000000006666066600000000
66000006660000066600000655000005550000055500000500000000000000000000000000000000666666666666666666666666666666666666666666666660
60666670606666706066667050555560505555605055556000056000000000000000000000000000666566666666666665555666666666666666666666666666
06666667066666670666666705555556055555560555555600555600006606600066066006600660665556666665566665665666666666666666666666666666
06655766066228660664496605566755055228550554495500555500060000600600000606060606666566666655556665655556666666660666666606666666
06655566066222660664446605566655055222550554445500055000000600600006060006060660666666666656656665656656666666660666666606666666
06666666066666660666666605555555055555550555555500000000066006660660066606600606665556666656656665556656666666660666666606666666
06666666066666660666666605555555055555550555555500000000000000000000000000000000666666666656656666656656666666666666666666666666
00666660006666600066666000555550005555500055555000000000000000000000000000000000666666666655556666655556666666666666666666666666
66000006660000066600000655000005550000055500000500000000000000050000000000000000660060006660006666600066666000666660006666600066
6066667060666670606666705055556050555560505555600003b000000006000006600000000000606060006606770666067706660677066606770666067706
06666667066666670666666705555556055555560555555600333b00000600650006060006606600606060006066667060666670606666706066667060666670
06633b6606688e6606699a6605533b5505588e5505599a5500333300060060600006600060606060660066600666666606666666066666660666666606666666
06633366066888660669996605533355055888550559995500033000060060650006060060606060006060000666666606666666066666660656666606066666
06666666066666660666666605555555055555550555555500000000000600600066060066006600006660000666666606566666060666660656666606666666
06666666066666660666666605555555055555550555555500000000000006050066000000000000000060006060666060656660606666606066666060566660
00666660006666600066666000555550005555500055555000000000000000000000000000000000006600006605560666055606660556066605560666055606
66600066666000666660006666600066666000666660006666600066666000666660006666600066666000666660006666600066666000666660006666600066
66067706660677066606770666067706660677066606770666067706660677066606770666067706660677066606770666067706660677066606770666067706
60666670606666706065667060606670606556706066067060665570606660706066657060666670606666706066667060666670606666706066667060666670
06566666060666660656666606666666066666660666666606666666066666660666665606666607066666560666666606666666066666660666666606666666
06566666066666660666666606666666066666660666666606666666066666660666666606666666066666560666660606666656066666660666666606666666
06666666066666660666666606666666066666660666666606666666066666660666666606666666066666660666666606666656066666060666665606666666
60566660605666606056666060566660605666606056666060566660605666606056666060566660605666606056666060566660605666606056656060566060
66055606660556066605560666055606660556066605560666055606660556066605560666055606660556066605560666055606660556066605560666055606
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
05665555056656560665555506655656066655550666555506665656056655550566565606665555066656560666555505665555056656560665555506655656
06555555065556660656555506565666065555550655555506555666065555550655566606565555065656660656555506555555065556660656555506565666
06555555065556660656555506565666066555550665555506655666065555550655566606665555066656660665555506555555065556660656555506565666
06555555065556560656555506565656065555550655555506555656065655550656565606565555065656560656555506555555065556560656555506565656
05665555056655550666555506665555066655550655555506555555066655550666555506565555065655550666555505665555056655550666555506665555
05555555055555550555555505555555055555550555555505555555055555550555555505555555055555550555555505555565055555650555556505555565
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
06665555066655550666565605665555056656560666555506665656066655550566555505665656066555550665565606665555066655550666565605665555
06555555065555550655566606555555065556660656555506565666065655550655555506555666065655550656566606555555065555550655566606555555
06655555066555550665566606555555065556660666555506665666066555550655555506555666065655550656566606655555066555550665566606555555
06555555065555550655565606565555065656560656555506565656065655550655555506555656065655550656565606555555065555550655565606565555
06665555065555550655555506665555066655550656555506565555066655550566555505665555066655550666555506665555065555550655555506665555
05555565055555650555556505555565055555650555556505555565055555650555565605555656055556560555565605555656055556560555565605555656
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
05665656066655550666565606665555056655550000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
06555666065655550656566606565555065555550000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
06555666066655550666566606655555065555550000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
06565656065655550656565606565555065555550000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
06665555065655550656555506665555056655550000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
05555656055556560555565605555656055556660000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55000055550000555500005555000055550000555500005555800055550800555500805555000855550000555500005555000055550000555500005555000055
50000005500000055000000550000005500000055800000550000005500000055000000550000005500000855000000550000005500000055000000550000005
50000005500000055000000550000005580000055000000550000005500000055000000550000005500000055000008550000005500000055000000550000005
50000005500000055000000558000005500000055000000550000005500000055000000550000005500000055000000550000085500000055000000550000005
50000005500000055800000550000005500000055000000550000005500000055000000550000005500000055000000550000005500000855000000550000005
55280055558000555500005555000055550000555500005555000055550000555500005555000055550000555500005555000055550000555500085555008255
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00555500005555000055550000555500005555000055550000755500005755000055750000555700005555000055550000555500005555000055550000555500
05555550055555500555555005555550055555500755555005555550055555500555555005555550055555700555555005555550055555500555555005555550
05555550055555500555555005555550075555500555555005555550055555500555555005555550055555500555557005555550055555500555555005555550
05555550055555500555555007555550055555500555555005555550055555500555555005555550055555500555555005555570055555500555555005555550
05555550055555500755555005555550055555500555555005555550055555500555555005555550055555500555555005555550055555700555555005555550
00675500007555000055550000555500005555000055550000555500005555000055550000555500005555000055550000555500005555000055570000557600
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
55555555055555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555577555577555775555555555555555555555556556655665500550055566566555005005565656565050505055665656550050505566556655005500
55505555560655560656005555666555556655555555655656665606577057705600560650775770565656565757575756005666507757075606560050775077
55505555565656565656555555565665556565565565565656065656577757575056565657505757566656665707570756555006575557775666565557075755
55505555566050566056555555565656556565655565565656665660570757575660566050075707560656065777577750665660570050075600506657775700
55505555560556560656555555565656556655665555655650005005577757755005500557755775505050505757575755005005557757755055550057555577
55505555565556565650665555555555555555555555556555555555555555555555555555555555555555555555555555555555555555555555555555555555
55505555505550505055005555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55505555555555556666666666666666666666666666666655555555555555555555555555555555555555555555555500000000000000005555555555555555
55505555555555556676655566766555667666556666655655755666557556665575556655555665556665555566655500000000000000005566556655005500
5550555555555555677765656777656567776566666665655777565657775656577756555555565655665555556655550ff00099099000ff5600560650775077
5550555555555555666665556666655666666566666665655555566655555665555556555555565655655288556558ee090f0400040909005056566657505707
55505555555555556666656566666565666665666666656555555656577756565777565557775656555552285555588e09900004044000095660560050075777
55505555555555556666656567776555677766556777655655555656557556665575556655755665556562225565688809000440040009905005505557755755
55505555555555556666666666766666667666666676666655555555555555555555555555555555555655555556555500000000000000005555555555555555
55505555555555556666666666666666666666666666666655555555555555555555555555555555556565555565655500000000000000005555555555555555
5550555500cc00000000000000000000000000000000000000000000000000000000000000222200066666660666666655555555555555555555555500000000
55505555000c00000000000000000000000000000000000000000000000000000022220002888820666666666666666655555555555555555555555500000000
55505555000c0000000000000000000000000000000000000000000000aaaa0009aaaa9009aaaa90666286666668e666555285555558e5555556655500000000
555055550000000000000000000000000000000000000000009999000099990000999900009999006622286666888e665522285555888e555565656600000000
555055550000000000000000000000000000000000bbbb0003bbbb3003bbbb3003bbbb3003bbbb30662222666688886655222255558888555566656500000000
55505555c00000000000000000000000003333000033330000333300003333000033330000333300666226666668866655522555555885555565656600000000
55555555c0000000000000000033330003bbbb3003bbbb3003bbbb3003bbbb3003bbbb3003bbbb30666666666666666655555555555555555555555500000000
55555555cc0000000000000000000000000000000000000000000000000000000000000000000000666666666666666655555555555555555555555500000000
000000000000090000000f0000000600000000050000000050050050555055555555000005000505000000000000000000000555000000000000000000000000
057500000000490000009f0000005600057500000050000005050500505050505005000000505000055555000055555000005505000000000000000000000000
0777000000044490000999f000055560077700050555000000000000555055555055550000050005550005500050005000005005000000000000000000000000
00000000040044090900990f05005506000000000000000055000550005050005050050055505550050005005555500000050550000000000000000000000000
07770000040004040900090905000505077700050555000000000000000500055550050000505005055555000555000000005005000000000000000000000000
05750000040000040900000905000005057500000050000005050500005050000050050000505000500000500050000005555500000000000000000000000000
00000000004444400099999000555550000000050000000050050050005050050055550055505555055555000000000050555005000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000050050000000000000000000000000000
00000000000000000000000000000000666000666666666666600066666666666660006666666666666000666666666666600066666666666660006666666666
5750eee05750eee057500ee00000ee00666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
7770e0e07770e0e07770e0000000e0e0555656565566666665565656555666655665556655666655565566565666665566555665566665566556655666666666
0000eee00000ee000000e0000000e0e0656656565656666656665656656666656565566566666655665656565666665656556656666656565666566666666666
0000e0e00000e0e00000e0000000e0e0656656565656666656665656656666655665666665666656665656565666665656566656666655565666566666666666
0000e0e07770eee077700ee07770ee00656665565656666665566556656666656566556556666665565656656666665566655665566656566556655666666666
00000000575000005750000057500000666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
00000000000000000000000000000000666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
06606600666066006600666066606660000000006600666500000005000000000000000000000000000000000000000000000000665666660000000000000000
600060606600606060606600666006000000000060606600000000000000000000000000000000000ffff000000f000000000600655666660000000000000000
00606600600066006600600060600600666066006060600506606665000280000008e0000005600000000f0000f0f00000060060555556660000000000049000
660060606000606060600660606066606660606066000660606006000022280000888e000055560000000f0000f0f0000600606065566566fff0fff000444900
00066000000600000006600000606000606060600006600566600605002222000088880000555500000000f000f0f00006006060665665560000000000444400
00600000006060000060000000060000606066000060000060000600000220000008800000055000000000f00f000ff000060060666555550000000000044000
00600000006600000000600000060000000000000060000500000005000000000000000000000000000000000000000000000600666665560000000000000000
00066000000660000066000000606000000000000006600000000000000000000000000000000000000000000000000000000000666665660000000000000000
60060060fff0fff5ffff00000f000f05000000000000000000000ff50000f0000000000000000005000000000000000555655555555555555555555555555555
06060600f0f0f0f0f00f000000f0f00006666600006666600000ff0f00000f0000000000000000000000000000000000566555555ee556665666565656665666
00000000fff0fff5f0ffff00000f000566000660006000600000f00f000000f0066060600660666506600666666066056666655555e555565556565656555655
6600066000f0f000f0f00f00fff0fff00600060066666000000f0ff00fffffff600060606000060006060060660066005665565555e556665566566656665666
00000000000f0005fff00f0000f0f00506666600066600000000f005f0fffff0006066606000060506060060600060655565566555e556555556555655565656
0606060000f0f00000f00f0000f0f00060000060006000000fffff00f00fff0066006060066006000660006060006660555666665eee56665666555656665666
6006006000f0f00500ffff00fff0fff50666660000000000f0fff005f000f0000000000000000005000000000000000555555665555555555555555555555555
000000000000000000000000000000000000000000000000f00f0000000000000000000000000000000000000000000055555655555555555555555555555555
__label__
000000cc00000000000000000000000000000000000000000000000000000f000000000000000000000000000000000000000000000000000000000066006000
b000606c000000000060006000000000000000000000fff00000000000009f00000000000000ff0000000000ff00f00000000000000006000000000060606000
3b0060600002800000600550099000ff00000000000000f000000000000999f00000000000000f00000000000f00f00000000000000600600660660060606000
33b050500022280000505550040909000000000000000ff0000000000900990f0000000000000f00000000000f00fff000000000060060606060606066006660
3330505000222200005055500440000900000000000000f000000000090009090000000000000f00000000000f00f0f000000000060060606060606000606000
33005050000220000050055004000990000000000000fff00000000009000009000000000000fff000000000fff0fff000000000000600606600660000666000
c0005050000000000050005000000000000000000000000000000000009999900000000000000000000000000000000000000000000006000000000000006000
cc000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000660000
ffff0000fff0fff50000000000000000000000000000000500000000000000000000000006606600000000000000000500000000000000000000000000000000
f00f0000f0f0f0f00075550000066000005755000000060000000000000000000000000060006060000000000000000000000000007555000055550000555700
f0ffff00fff0fff50555555000060600055555500006006500000007000000000000000000606600000000000000000500660660055555500555555005555550
f0f00f0000f0f000055555500006600005555550060060600000001770000000fff0fff066006060000000000000000006000060055555500555555005555550
fff00f00000f00050555555000060600055555500600606500000017770000000000000000066000000000000000000500060060055555500555555005555550
00f00f0000f0f0000555555000660600055555500006006000000017777000000000000000600000000000000000000006600666055555500555555005555550
00ffff0000f0f0050055550000660000005555000000060500000017710000000000000000600000000000000000000500000000005555000067550000555500
00000000000000000000000000000000000000000000000000000001100000000000000000066000000000000000000000000000000000000000000000000000
0000f0000f000f050000000000000000000000000000000500000000666066000000000000000000000000000000000500000000000000000000000000000000
00000f0000f0f000007555000000000000555700000000000055550066006060000f0000000000000000ff000000000000000000005557000055550000555500
000000f0000f000505555550066060600555555006606665055555506000660000f0f0006660660000000f000660666500660660055555500555555005555550
0ffffffffff0fff005555550600060600555555060000600055555506000606000f0f0006660606000000f006060060006000006055555500555555005555550
f0fffff000f0f00505555550006066600555555060000605055555500006000000f0f0006060606000000f006660060500060600055555500555555005555550
f00fff0000f0f0000555555066006060055555500660060005555550006060000f000ff0606066000000fff06000060006600666055555500555555005555550
f000f000fff0fff50055550000000000005555000000000500555700006600000000000000000000000000000000000500000000005555000067550000675500
00000000000000000000000000000000000000000000000000000000000660000000000000000000000000000000000000000000000000000000000000000000
0000000000000ff50000000000000000000000000000000500000000660066600000000066606660000000006600666500000000000000000000000000000000
000000000000ff0f00000000fff00000005555000000000000555500606066000055550066600600005557006060660000000000005557000055550000555500
000000000000f00f0000000000f00666055555706660660505555550660060000555555060600600055555506060600506600660055555500555555005555550
00000000000f0ff0000000000ff00060055555506600660005555550606006600555555060606660055555506600066006060606055555500555555005555570
000000000000f0050000000000f00060055555506000606505555550000660000555555000606000055555500006600506060660055555500555555005555550
000000000fffff0000000000fff00060055555506000666005555550006000000555555000060000055555500060000006600606055555500555555005555550
00000000f0fff0050000000000000000005555000000000500557600000060000055760000060000005555000060000500000000005555000067550000555500
00000000f00f00000000000000000000000000000000000000000000006600000000000000606000000000000006600000000000000000000000000000000000
06666666666666666666666666666666666666666660006666666666666000666666666666600066666666666660006666666666666000666666666666600066
66666666655556666666666666656666655700066606770666666666660677066666666666067706666666666606770666666666660677066666666666067706
6668e666656656666665566666555666655500066066067066666666606666706666666660660670666666666066667066666666606666706666666660660670
66888e66656555566655556666656666666666660666666606666666066666070666666606666666066666660666666606666666066666660666666606666666
66888866656566566656656666666666655566560666666606666666066666660666666606666666066666660666666606666666066666660666666606666666
66688666655566566656656666555666656565560666666606666666066666660666666606666666066666660666666606666666060666660666666606666666
66666666666566566656656666666666656555566056666066666666605666606666666660566660666666666056606066666666606666606666666660566660
66666666666555566655556666666666666666666605560666666666660556066666666666055606666666666605560666666666660556066666666666055606
66666666666666666666666666666666666666666660006666666666666000666666666666600066666666666660006666666666666000666666666666600066
667665556ee662226222626262226266666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
6777656566e666626662626262666266666666665556565655666666655656565556666556655566556666555655665656666655665556655666655665566556
6666655566e662226622622262226222666666666566565656566666566656566566666565655665666666556656565656666656565566566666565656665666
6666656566e662666662666266626262666666666566565656566666566656566566666556656666656666566656565656666656565666566666555656665666
666665656eee62226222666262226222666666666566655656566666655665566566666565665565566666655656566566666655666556655666565665566556
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66000006660000066600000666000006660000066600000666000006660000066600000666000006660000066600000666000006660000066600000666000006
60666670606666706066667060666670606666706066667060666670606666706066667060666670606666706066667060666670606666706066667060666670
06666667066666670666666706666667066666670666666706666667066666670666666706666667066666670666666706666667066666670666666706666667
066228660665576606655766066557660662286606655766066557660665576606644966066228660665576606633b6606655766066557660665576606655766
06622266066555660665556606655566066222660665556606655566066555660664446606622266066555660663336606655566066555660665556606655566
06666666066666660666666606666666066666660666666606666666066666660666666606666666066666660666666606666666066666660666666606666666
06666666066666660666666606666666066666660666666606666666066666660666666606666666066666660666666606666666066666660666666606666666
00666660006666600066666000666660006666600066666000666660006666600066666000666660006666600066666000666660006666600066666000666660
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
05665555056655550566555505665555066655550566555505665555056655550666565605665555056655550566555505665555056655550566555505665555
06555555065555550655555506555555065655550655555506555555065555550656566606555555065555550655555506555555065555550655555506555555
06555555065555550655555506555555066655550655555506555555065555550666566606555555065555550655555506555555065555550655555506555555
06565555065655550656555506565555065655550656555506565555065655550656565606565555065655550656555506565555065655550656555506565555
06665555066655550666555506665555065655550666555506665555066655550656555506665555066655550666555506665555066655550666555506665555
05555656055556560555565605555656055556560555565605555656055556560555565605555656055556560555556505555656055556560555565605555656
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
06666666666666666666666666666666666666666660006666666666666000666666666666600066666666666660006666666666666000666666666666600066
66666666655556666666666666656666600055766606770666666666660677066666666666067706666666666606770666666666660677066666666666067706
6668e666656656666665566666555666600055566066667066666666606666706666666660656670666666666066557066666666606666706666666660660670
66888e66656555566655556666656666666666660666666606666666066666660666666606566666066666660666666606666666065666660666666606666666
66888866656566566656656666666666655566560666666606666666066666660666666606666666066666660666666606666666065666660666666606666666
66688666655566566656656666555666656565560666666606666666060666660666666606666666066666660666666606666666066666660666666606666666
66666666666566566656656666666666656555566060666066666666606666606666666660566660666666666056666066666666605666606666666660566660
66666666666555566655556666666666666666666605560666666666660556066666666666055606666666666605560666666666660556066666666666055606
66666666666666666666666666666666666666666660006666666666666000666666666666600066666666666660006666666666666000666666666666600066
667665556ee662226222626262226266666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
6777656566e666626662626262666266666666665556565655666666655656565556666556655566556666555655665656666655665556655666655665566556
6666655566e662226622622262226222666666666566565656566666566656566566666565655665666666556656565656666656565566566666565656665666
6666656566e662666662666266626262666666666566565656566666566656566566666556656666656666566656565656666656565666566666555656665666
666665656eee62226222666262226222666666666566655656566666655665566566666565665565566666655656566566666655666556655666565665566556
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66000006660000066600000666000006660000066600000666000006660000066600000666000006660000066600000666000006660000066600000666000006
60666670606666706066667060666670606666706066667060666670606666706066667060666670606666706066667060666670606666706066667060666670
06666667066666670666666706666667066666670666666706666667066666670666666706666667066666670666666706666667066666670666666706666667
066557660665576606622866066557660665576606655766066557660662286606655766066557660662286606633b6606622866066557660662286606655766
06655566066555660662226606655566066555660665556606655566066222660665556606655566066222660663336606622266066555660662226606655566
06666666066666660666666606666666066666660666666606666666066666660666666606666666066666660666666606666666066666660666666606666666
06666666066666660666666606666666066666660666666606666666066666660666666606666666066666660666666606666666066666660666666606666666
00666660006666600066666000666660006666600066666000666660006666600066666000666660006666600066666000666660006666600066666000666660
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
05665555056655550566555505665555056655550566555505665555056655550566555505665555066556560666555505665555056655550566555505665555
06555555065555550655555506555555065555550655555506555555065555550655555506555555065656660655555506555555065555550655555506555555
06555555065555550655555506555555065555550655555506555555065555550655555506555555065656660665555506555555065555550655555506555555
06565555065655550656555506565555065655550656555506565555065655550656555506565555065656560655555506565555065655550656555506565555
06665555066655550666555506665555066655550666555506665555066655550666555506665555066655550655555506665555066655550666555506665555
05555555055555550555555505555555055555550555555505555555055555550555555505555555055555550555555505555555055555550555555505555555
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555556665555555556555555555555555555566655555555565555555555555555555666555555555655555555555555555
55555555555555555555555555555555556655555555655655666555556655555566555555556556556665555566555555665555555565565566655555665555
555555555555555555555555555555555565528855655656555656655565655655655288556556565556566555656556556558ee556556565556566555656556
5555555555555555555555555555555555555228556556565556565655656565555552285565565655565656556565655555588e556556565556565655656565
55555555555555555555555555555555556562225555655655565656556655665565622255556556555656565566556655656888555565565556565655665566
55555555555555555555555555555555555655555555556555555555555555555556555555555565555555555555555555565555555555655555555555555555
55555555555555555555555555555555556565555555555555555555555555555565655555555555555555555555555555656555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555566665555555555555555555500550055500085555080055550800555656565655000055550008555500005555665566550000555500005555000055
5558e555565565555556655555555555577057705000000550000005500000055656565658000005500000055000000556065600500000055000008550000005
55888e55565666655566665555555555577757575000000550000005500000055666566650000005500000055800000556665655580000055000000558000005
55888855565655655565565555555555570757575000000550000005500000055606560650000005500000055000000556005066500000055000000550000005
55588555566655655565565555555555577757755000000550000005500000055050505050000005500000055000000550555500500000055000000550000005
55555555555655655565565555555555555555555500005555000055550000555555555555000055550000555500005555555555550000555500005555000055
55555555555666655566665555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
557556665ee552225222525252225255556656655580005555080055550800555566565655000055550000555500005555665566558000555508005555000855
5777565655e555525552525252555255560056065000000550000005500000055600566650000005500000055000000556005606500000055000000550000005
5555566655e552225522522252225222505656565000000550000005500000055655500650000005500000055000008550565666500000055000000550000005
5555565655e552555552555255525252566056605000000550000005500000055066566058000005500000055000000556605600500000055000000550000005
555556565eee52225222555252225222500550055000000550000005500000055500500550000005500000855000000550055055500000055000000550000005
55555555555555555555555555555555555555555500005555000055550000555555555555000055550000555500005555555555550000555500005555000055
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55000005550000055500000555000005550000055500000555000005550000055500000555000005550000055500000555000005550000055500000555000005
50555560505555605055556050555560505555605055556050555560505555605055556050555560505555605055556050555560505555605055556050555560
05555556055555560555555605555556055555560555555605555556055555560555555605555556055555560555555605555556055555560555555605555556
05588e550556675505566755055667550556675505522855055667550556675505588e55055667550556675505533b5505566755055667550552285505566755
05588855055666550556665505566655055666550552225505566655055666550558885505566655055666550553335505566655055666550552225505566655
05555555055555550555555505555555055555550555555505555555055555550555555505555555055555550555555505555555055555550555555505555555
05555555055555550555555505555555055555550555555505555555055555550555555505555555055555550555555505555555055555550555555505555555
00555550005555500055555000555550005555500055555000555550005555500055555000555550005555500055555000555550005555500055555000555550

__map__
07e905ac000000c10000000000ec292a07e905ac0000c0c10000c000c0ec292a07e705ac00eec5c300eec5eec5ec292a0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
f2c785288527000009e0000c17858585c6cb842884270000000026b717848484f2c784288427001726d00000008484840000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
f7c985f885f986e1eae409e618858585c7c884f884f90000000026b418848484f7c984f884f9001826d00000008484840000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000c85fa85fb86e286e386e519858585cac984fa84fb0000000026b919848484000084fa84fb001926d00000008484840000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
bb1c1b1a02341e341e341e341e341e340c0ddfdf1d341e341e341e341e341e34000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
a2dfdf1d1dd4d5d6d7d8d9dadbdcddde1c1b1a021dd4d5d6d7d8d9dadbdcddde000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1010101010101010101010101010101010101010101010101010101010101010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
5555555555555555555555555555555555555555555555555555555555555555000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
a1a1a1a1ab959394ab959394ab9593940b0aa1a1977698769a769c769e76ae76000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
bd0b0aa1977676769a7676769e767676fca1a1a1937693769376937693769376000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
a6a1a1a1987676769c767676ae767676a6fdfeff947694769476947694769476000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1313131313131313131313131313131313131313131313131313131313131313000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000b0aa1a1a1959394a1959394a1959394000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000fca1a1a1977676769a7676769e767676000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000a6fdfeff987676769c767676ae767676000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000013131313131313131313131313131313000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000001900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
