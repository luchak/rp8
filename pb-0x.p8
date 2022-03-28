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

audio_rec=false
function start_rec()
 audio_rec=true
 menuitem(4,'stop recording',stop_rec)
 extcmd'audio_rec'
end

function stop_rec()
 if (audio_rec) extcmd'audio_end'
 menuitem(4,'start recording',start_rec)
end

function _init()
 cls()

 -- turn off output lpf for less
 -- muffled sound
 poke(0x5f36,@0x5f36^^0x20)

 -- turn on mouse
 poke(0x5f2d, 0x1)

 ui,state=ui_new(),state_new()

 header_ui_init(ui,0)
 pbl_ui_init(ui,unpack_split'b0,7,32')
 pbl_ui_init(ui,unpack_split'b1,19,64')
 pirc_ui_init(ui,'dr',96)

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
 local delay=delay_new(3000,0)
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
 comp=comp_new(mixer,unpack_split'0.5,4,0.05,0.008')
 seq_helper=seq_helper_new(
  state,comp,function()
   local patch,pseq,pstat=
    state.patch,
    state.pat_seqs,
    state.pat_status
   if (not state.playing) return
   local now,nl=state.tick,state.note_len
   if (pstat.b0.on) pbl0:note(pseq.b0,patch,now,nl)
   if (pstat.b1.on) pbl1:note(pseq.b1,patch,now,nl)
   if pstat.dr.on then
    local dseq=pseq.dr
    for idx,drum in ipairs(drums) do
     drum:note(dseq[drum_keys[idx]],patch,now,nl)
    end
   end
   drum_mixer:note(patch)
   mixer:note(patch)
   svf:note(patch)

   local mix_lev,dl_t,dl_fb,comp_thresh=unpack_patch(patch,3,6)
   local b0_lev,b0_od,b0_fx=unpack_patch(patch,7,9)
   local b1_lev,b1_od,b1_fx=unpack_patch(patch,19,21)
   local drum_lev,drum_od,drum_fx=unpack_patch(patch,31,33)
   mixer.lev=pow3(mix_lev)*8
   delay.l=((dl_t<<4)+0.25)*state.base_note_len
   delay.fb=sqrt(dl_fb)*0.95

   local ms=mixer.srcs
   ms.b0.lev=8*pow3(b0_lev)
   ms.b1.lev=8*pow3(b1_lev)
   ms.dr.lev=16*pow3(drum_lev)
   ms.b0.od=b0_od*b0_od
   ms.b1.od=b1_od*b1_od
   ms.dr.od=drum_od*drum_od
   ms.b0.fx=pow3(b0_fx)
   ms.b1.fx=pow3(b1_fx)
   ms.dr.fx=pow3(drum_fx)
   comp.thresh=0.01+0.99*pow3(comp_thresh)

   state:next_tick()
  end
 )

 menuitem(1, 'save to clip', copy_state)
 menuitem(2, 'load from clip', paste_state)
 menuitem(3, 'clear seq', function()
  state=state_new()
  seq_helper.state=state
 end)
 menuitem(4, 'start recording', start_rec)

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

--cpumax={}
--cpumaxf=0
function _draw()
 ui:draw(state)

--cpumax[cpumaxf%100+1]=stat(1)
--cpumaxf+=1
--rectfill(0,0,30,6,0)
--print(max(unpack(cpumax)),0,0,7)

 --rectfill(0,0,30,6,0)
 --print(stat(0),0,0,7)
 --rectfill(0,0,30,12,0)
 --print(stat(1),0,0,7)
 --print(stat(2),0,6,7)
 palt(0,false)
end

#include utils.lua

-->8
-- audio driver

-- at 5512hz/60fps, we need to
-- produce 92 samples a frame
-- 96-104 is just enough extra
-- to avoid jitter problems
-- on machines i have tested on
_schunk,_tgtchunks=100,4
_bufpadding,_chunkbuf=4*_schunk,{}
sample_rate=5512.5
_audio_dcf=0

function audio_dochunk()
 local dcf=_audio_dcf
 local buf=_chunkbuf
 if audio_root_obj then
  audio_root_obj:update(buf,1,_schunk)
 else
  for i=1,_schunk do
   buf[i]=0
  end
 end
 for i=1,_schunk do
  -- dc filter, plus
  -- soft saturation to make
  -- clipping less unpleasant
  local x=buf[i]
  dcf+=(x-dcf)>>8
  x=mid(-1,x-dcf,1)
  x-=0.148148*x*x*x
  -- add dither to keep delay
  -- tails somewhat nicer
  -- also ensure that e(0) is
  -- on a half-integer value
  poke(0x42ff+i,flr((x<<7)+0.375+(rnd()>>2))+128)
 end
 serial(0x808,0x4300,_schunk)
 _audio_dcf=dcf
end

function audio_update()
 local bufsize,inbuf,newchunks=stat(109),stat(108),0

 while inbuf<_schunk do
  log('behind')
  audio_dochunk()
  newchunks+=1
  inbuf+=_schunk
 end

 -- always generate at least 1
 -- chunk if there is space
 -- and time
 if newchunks<_tgtchunks and inbuf<bufsize+_bufpadding then
  audio_dochunk()
  inbuf+=_schunk
  newchunks+=1
 end
end
-->8
-- audio gen

function synth_new(base)
 -- simple saw wave synth
 -- filter:
 --  karlsen fast ladder iii
 local obj=parse[[{
  op=0,
  odp=0.001,
  todp=0.001,
  todpr=0.999,
  fc=0.5,
  fr=3.6,
  os=4,
  env=0.5,
  acc=0.5,
  detune=1,
  saw=false,
  _fc=0,
  _f1=0,
  _f2=0,
  _f3=0,
  _f4=0,
  _fosc=0,
  _ffb=0,
  _me=0,
  _med=0.99,
  _ae=0,
  _aed=0.997,
  _mr=false,
  _ar=false,
  _gate=false,
  _nt=0,
  _nl=900,
  _ac=false,
  _sl=false,
  _lsl=false
 }]]

 obj.note=function(self,pat,patch,step,note_len)
  local patstep=pat.st[step]
  local saw,tun,cut,res,env,dec,acc=unpack_patch(patch,base+5,base+11)

  self.fc=(100/sample_rate)*(2^(4*cut))/self.os
  self.fr=res*4.9+0.1
  self.env=env*env+0.1
  self.acc=acc*1.9+0.1
  self.saw=saw>0
  local pd=dec-1
  if (patstep==n_ac or patstep==n_ac_sl) pd=-0.99
  self._med=0.999-0.01*pd*pd*pd*pd
  self._nt,self._nl=0,note_len
  self._lsl=self._sl
  self._gate=false
  self.detune=semitone^(flr(24*(tun-0.5)+0.5))
  self._ac=patstep==n_ac or patstep==n_ac_sl
  self._sl=patstep==n_sl or patstep==n_ac_sl
  if (patstep==n_off) return

  self._gate=true
  local f=55*(semitone^(pat.nt[step]+3))
  --ordered for numeric safety
  self.todp=(f/self.os)/(sample_rate>>8)

  if (self._ac) self.env+=acc
  if self._lsl then
   self.todpr=0.015
  else
   self.todpr=0.995
   self._mr=true
  end

  self._nt=0
 end

 obj.update=function(self,b,first,last)
  local odp,op,detune=self.odp,self.op,self.detune
  local todp,todpr=self.todp,self.todpr
  local f1,f2,f3,f4=self._f1,self._f2,self._f3,self._f4
  local fr,fcb,os=self.fr,self.fc,self.os
  local ae,aed,me,med,mr=self._ae,self._aed,self._me,self._med,self._mr
  local env,saw,lev,acc=self.env,self.saw,self.lev,self.acc
  local gate,nt,nl,sl,ac=self._gate,self._nt,self._nl,self._sl,self._ac
  local fosc,ffb=self._fosc,self._ffb
  for i=first,last do
   -- I forgot why this is 0.37
   -- I think it's more or less
   -- arbitrary
   local fc=min(0.4/os,fcb+((me*env)>>4))
   -- very very janky dewarping
   -- arbitrary scaling constant
   -- is 0.75*2*pi because???
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
   self._nt+=1
   for j=1,os do
    local osc=op>>7
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
    if (op>128) op-=256
   end
   local out=(f4*ae)>>2
   if (ac) out+=acc*me*out
   b[i]=out
  end
  self.op,self.odp,self._gate=op,odp,gate
  self._f1,self._f2,self._f3,self._f4=f1,f2,f3,f4
  self._me,self._ae,self._mr=me,ae,mr
  self._fosc,self._ffb=fosc,ffb
 end

 return obj
end

function sweep_new(base,_dp0,_dp1,ae_ratio,boost,te_base,te_scale)
 local obj,_op,_dp,_ae,_aemax,_aed,_ted,_detune=
  {},unpack_split'0,6553.6,0,0.6,0.995,0.05,1'

 obj.note=function(self,pat,patch,step,note_len)
  local s=pat[step]
  local tun,dec,lev=unpack_patch(patch,base,base+2)
  if s!=d_off then
   -- TODO: param updates should be reflected on every step?
   _detune=2^(1.5*tun-0.75)
   _op,_dp=0,(_dp0<<16)*_detune
   _ae=lev*lev*boost*trn(s==d_ac,1.5,0.6)
   _aemax=0.5*_ae
   _ted=0.5*((te_base-te_scale*dec)^4)
   _aed=1-ae_ratio*_ted
  end
 end

 obj.subupdate=function(self,b,first,last)
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

 obj.note=function(self,pat,patch,step,note_len)
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
   local pd4=(0.65-0.25*dec)^4
   _aesd=1-0.1*pd4
   _aend=1-0.04*pd4
  end
 end
 
 obj.subupdate=function(self,b,first,last)
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

 obj.note=function(self,pat,patch,step,note_len)
  local s=pat[step]
  local tun,dec,lev=unpack_patch(patch,base,base+2)
  if s!=d_off then
   _op,_dp=0,_dp0
   _ae=lev*lev*trn(s==d_ac,2.0,0.8)

   _detune=2^(tbase+tscale*tun)
   local pd=(dbase-dscale*dec)

   _aed=1-0.04*pd*pd*pd*pd
  end
 end

 obj.subupdate=function(self,b,first,last)
  local ae,f1,f2=_ae,_f1,_f2
  local op1,op2,op3,op4,detune=_op1,_op2,_op3,_op4,_detune
  local odp1,odp2,odp3,odp4=_odp1*detune,_odp2*detune,_odp3*detune,_odp4*detune
  local aed,tlev,nlev=_aed,_tlev,_nlev

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

 obj.note=function(self,pat,patch,step,note_len)
  local s=pat[step]
  local tun,dec,lev=unpack_patch(patch,base,base+2)
  _dec=1-(0.01*(1-dec)^4)
  _detune=2^(flr((tun-0.5)*24+0.5)/12)
  if s!=d_off then
   _pos=1
   _amp=lev*lev
  end
 end

 obj.subupdate=function(self,b,first,last)
  -- TODO: samp should probably be passed in in note?
  local pos,dec,samp=_pos,_dec,state.samp
  local amp,detune=_amp,_detune
  local n=#samp
  for i=first,last do
   if (pos>=n) break
   local pi=pos&0xffff.0000
   local po=pos-pi
   local s0,s1=samp[pi],samp[pi+1]
   local val=s0+po*(s1-s0)

   b[i]+=amp*((val>>7)-1)
   amp*=dec
   pos+=detune
  end
  _pos,_amp=pos,amp
 end

 return obj
end
-->8
-- audio fx

function delay_new(l,fb)
 local obj={
  dl={},
  p=1,
  l=l,
  fb=fb,
  f1=0
 }

 -- initialize maximum-length delay buffer
 for i=1,0x7fff do
  obj.dl[i]=0
 end

 obj.update=function(self,b,first,last)
  local dl,l,fb,p=self.dl,self.l,self.fb,self.p
  local f1=self.f1
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
  self.p,self.f1=p,f1
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
    if (self.fx & dr_src_fx_masks[i] > 0) src:subupdate(b,first,last) else src:subupdate(bypass,first,last)
   end
  end
 }
end

filtmap=parse[[{b0=3,b1=4,dr=5}]]
function mixer_new(srcs,fx,filt,lev)
 return {
  srcs=srcs,
  lev=lev,
  tmp={},
  bypass={},
  fxbuf={},
  filtsrc=1,
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
    --local odfi=1/(4*(atan2(odf,1)-0.75))
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

-- absolutely ghastly but a
-- very very fast log function
-- is needed to make progress
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
   -- makeup targets 0.2
   local makeup=max(1,0.2/((0.2-thresh)*ratio+thresh))
   for i=first,last do
    -- avoid divide-by-zero
    local x=abs(b[i])+0x0.0010
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

-- heavily inspired by
-- https://github.com/JordanTHarris/VAStateVariableFilter
function svf_new()
 return {
  z1=0,
  z2=0,
  rc=0.1,
  gc=0.2,
  wet=1,
  fe=0,
  bp=0,
  note=function(self,patch)
   --local q=1/(2*(1-res))
   --self.rc=1/(2*q)
   -- configurable decay?
   local r,bp,gc
   bp,gc,r,self.wet=unpack_patch(patch,56,59)
   self.rc=1-(r*0.96)
   --self.fe=0.6
   self.bp=(bp&0x0.02>0 and 1) or 0
   self.gc=gc*gc+0x0.02
  end,
  update=function(self,b,first,last)
   local z1,z2,rc,gc_base,wet,fe,is_bp=
    self.z1,
    self.z2,
    self.rc,
    self.gc,
    self.wet,
    self.fe,
    self.bp
   for i=first,last do
    gc=min(gc_base+fe,1)
    local rrpg=2*rc+gc
    local hpn,inp=1/gc+rrpg,b[i]
    local hpgc=(inp-rrpg*z1-z2)/hpn
    local bp=hpgc+z1
    local lp=bp*gc+z2
    z1,z2=hpgc+bp,bp*gc+lp

    -- why does this sound o
    -- much better oversampled??
    -- is it just that there's
    -- no frequency warping, or
    -- something else?
    hpgc=(inp-rrpg*z1-z2)/hpn
    bp=hpgc+z1
    lp=bp*gc+z2
    z1,z2=hpgc+bp,bp*gc+lp

    -- rc*bp is 1/2 of unity gain bp
    -- bp is just bp
    b[i]=inp+wet*(lp+is_bp*(rc*bp+bp-lp)-inp)
    fe*=0.99
   end
   self.z1,self.z2,self.fe=z1,z2,fe
  end
 }
end

#include events.lua

-->8
-- state

n_off,n_on,n_ac,n_sl,n_ac_sl,d_off,d_on,d_ac=unpack_split'64,65,66,67,68,64,65,66'

syn_base_idx=parse[[{
 b0=7,
 b1=21,
 dr=35,
 bd=42,
 sd=45,
 hh=48,
 cy=51,
 pc=54,
 sp=57,
}]]

pat_param_idx=parse[[{
 b0=11,
 b1=25,
 dr=39,
}]]

syn_base_idx=parse[[{
 b0=7,
 b1=19,
 dr=31,
 bd=38,
 sd=41,
 hh=44,
 cy=47,
 pc=50,
 sp=53,
}]]

pat_param_idx=parse[[{
 b0=11,
 b1=23,
 dr=35,
}]]

-- float values: 0=>0,128=>1
-- bool values: 0=>false,128 (or any nonzero)=>true
-- int values: identity map
default_patch=parse[[{
1=64,
2=0,
3=64,
4=64,
5=64,
6=128,
7=64,
8=0,
9=0,
10=128,
11=1,
12=128,
13=64,
14=64,
15=64,
16=64,
17=64,
18=64,
19=64,
20=0,
21=0,
22=128,
23=1,
24=128,
25=64,
26=64,
27=64,
28=64,
29=64,
30=64,
31=64,
32=0,
33=0,
34=128,
35=1,
36=64,
37=127,
38=64,
39=64,
40=64,
41=64,
42=64,
43=64,
44=64,
45=64,
46=64,
47=64,
48=64,
49=64,
50=64,
51=64,
52=64,
53=64,
54=64,
55=64,
56=2,
57=64,
58=64,
59=128,
60=0
}]]
 -- 01 mix_tempo=0.5,
 -- 02 mix_shuf=0,
 -- 03 mix_lev=0.5,
 -- 04 mix_dl_t=0.5,
 -- 05 mix_dl_fb=0.5,
 -- 06 mix_comp_thresh=1.0,
 -- 07 b0_lev=0.5,
 -- 08 b0_od=0,
 -- 09 b0_fx=0,
 -- 10 b0_on=true,
 -- 11 b0_pat=1,
 -- 12 b0_saw=true,
 -- 13 b0_tun=0.5,
 -- 14 b0_cut=0.5,
 -- 15 b0_res=0.5,
 -- 16 b0_env=0.5,
 -- 17 b0_dec=0.5,
 -- 18 b0_acc=0.5,
 -- 19 b1_lev=0.5,
 -- 20 b1_od=0,
 -- 21 b1_fx=0,
 -- 22 b1_on=true,
 -- 23 b1_pat=1,
 -- 24 b1_saw=true,
 -- 25 b1_tun=0.5,
 -- 26 b1_cut=0.5,
 -- 27 b1_res=0.5,
 -- 28 b1_env=0.5,
 -- 29 b1_dec=0.5,
 -- 30 b1_acc=0.5,
 -- 31 dr_lev=0.5,
 -- 32 dr_od=0,
 -- 33 dr_fx=0,
 -- 34 dr_on=true,
 -- 35 dr_pat=1,
 -- 36 dr_acc=64,
 -- 37 dr_fx_en=127/128
 -- 38 bd_tun=0.5,
 -- 39 bd_dec=0.5,
 -- 40 bd_lev=0.5,
 -- 41 sd_tun=0.5,
 -- 42 sd_dec=0.5,
 -- 43 sd_lev=0.5,
 -- 44 hh_tun=0.5,
 -- 45 hh_dec=0.5,
 -- 46 hh_lev=0.5,
 -- 47 cy_tun=0.5,
 -- 48 cy_dec=0.5,
 -- 49 cy_lev=0.5,
 -- 50 pc_tun=0.5,
 -- 51 pc_dec=0.5,
 -- 52 pc_lev=0.5,
 -- 53 sp_tun=0.5,
 -- 54 sp_dec=0.5,
 -- 55 sp_lev=0.5,
 -- 56 fl_src_type=2
 -- 57 fl_cut=0.5
 -- 58 fl_res=0.5
 -- 59 fl_wet=1
 -- 60 fl_pat=0

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
  samp={1=128,2=0,3=0,4=0,5=128,6=255,7=255,8=255}
 }]]

 s.tl=timeline_new(default_patch)
 s.pat_patch=copy_table(default_patch)
 s.patch={}
 s.pat_seqs={}
 s.pat_status={}
 if savedata then
  s.tl=timeline_new(default_patch,savedata.tl)
  s.pat_patch=dec_byte_array(savedata.pat_patch)
  s.song_mode=savedata.song_mode
  s.pat_store=map_table_deep(savedata.pat_store,dec_byte_array,2)
  s.samp=dec_byte_array(savedata.samp)
 end

 s._apply_diff=function(self,k,v)
  self.patch[k]=v
  if self.song_mode then
   self.tl:record_event(k,v)
   if (not self.playing) self:load_bar()
  else
   self.pat_patch[k]=v
   self.patch[k]=v
  end
 end

 s._init_tick=function(self)
  local patch=self.patch
  local nl=sample_rate*(15/(60+patch[1]))
  local shuf_diff=nl*(patch[2]>>7)*(0.5-(self.tick&1))
  self.note_len,self.base_note_len=flr(0.5+nl+shuf_diff),nl
 end

 s.load_bar=function(self,i)
  local tl=self.tl
  if self.song_mode then
   self.tl:load_bar(self.patch,i)
   self.tick=tl.tick
  else
   self.patch=copy_table(self.pat_patch)
   self.tick=1
  end
  self:_sync_pats()
  self:_init_tick()
 end
 local load_bar=function(i) s:load_bar(i) end

 s.next_tick=function(self)
  local tl=self.tl
  if self.song_mode then
   tl:next_tick(self.patch, load_bar)
   self.bar,self.tick=tl.bar,tl.tick
  else
   self.tick+=1
   if (self.tick>16) load_bar()
  end
  self:_init_tick()
 end

 s.toggle_playing=function(self)
  local tl=self.tl
  if self.playing then
   if (tl.recording) tl:toggle_recording()
   tl:clear_overrides()
  end
  load_bar()
  self.playing=not self.playing
 end

 s.toggle_recording=function(self)
  self.tl:toggle_recording()
 end

 s.toggle_song_mode=function(self)
  self.song_mode=not self.song_mode
  self:stop_playing()
  load_bar()
 end

 s._sync_pats=function(self)
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
    if (syn=='b0' or syn=='b1') pat=copy_table(pbl_pat_template) else pat=copy_table(drum_pat_template)
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

 s.go_to_bar=function(self,bar)
  load_bar(mid(1,bar,999))
 end

 s.get_pat_steps=function(self,syn)
  -- assume pats are aliased, always editing current
  if (syn=='dr') return self.pat_seqs.dr[self.drum_sel] else return self.pat_seqs[syn].st
 end

 s.set_bank=function(self,syn,bank)
  self[syn..'_bank']=bank
 end

 s.save=function(self)
  return 'rp80'..stringify({
   tl=self.tl:get_serializable(),
   song_mode=self.song_mode,
   pat_patch=enc_byte_array(self.pat_patch),
   pat_store=map_table_deep(self.pat_store,enc_byte_array,2),
   samp=enc_byte_array(self.samp)
  })
 end

 s.stop_playing=function(self)
  if (self.playing) self:toggle_playing()
 end

 s.cut_seq=function(self)
  self:stop_playing()
  copy_buf_seq=self.tl:cut_seq()
  self:load_bar()
 end

 s.copy_seq=function(self)
  if self.song_mode then
   copy_buf_seq=self.tl:copy_seq()
  else
   copy_buf_seq={{
    t0=enc_byte_array(self.pat_patch),
    ev={}
   }}
  end
 end

 s.paste_seq=function(self)
  if (not copy_buf_seq) return
  self:stop_playing()
  local n=#copy_buf_seq
  if self.song_mode then
   self.tl:paste_seq(copy_buf_seq)
  else
   self.pat_patch=dec_byte_array(copy_buf_seq[1].t0)
  end
  self:load_bar()
 end

 s.insert_seq=function(self)
  if (not copy_buf_seq) return
  self:stop_playing()
  self.tl:insert_seq(copy_buf_seq)
  self:load_bar()
 end

 s:load_bar()
 return s
end

function state_load(str)
 if (sub(str,1,4)!='rp80') return nil
 return state_new(parse(sub(str,5)))
end

function transpose_pat(pat,d)
 for i=1,16 do
  pat.nt[i]=mid(0,pat.nt[i]+d,35)
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
 local mask=1<<(bit or 7)
 return
  function(state) return (state.patch[idx]&mask)>0 end,
  function(state,val) local old=state.patch[idx] state:_apply_diff(idx,trn(val,old|mask,old&(~mask))) end
end

function state_make_get_set(a,b)
 return
  function(s) if b then return s[a][b] else return s[a] end end,
  function(s,v) if (b) s[a][b]=v else s[a]=v end
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
   local p,nl=first,self.state.note_len
   while p<=last do
    if self.t>=nl then
     self.t=0
     note_fn()
    end
    local n=min(nl-self.t,last-p+1)
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

ui_btns={⬅️,➡️,⬆️,⬇️,❎,🅾️}
-- custom retrigger frame intervals
-- for buttons
ui_reps=parse[[{
 1=true,
 11=true,
 19=true,
 25=true,
 29=true
}]]
--31=true
widget_defaults=parse[[{
 w=2,
 h=2,
 active=true,
 act_on_click=false,
 drag_amt=0,
 btn_amt=1
}]]

function ui_new()
 local obj=parse[[{
  widgets={},
  sprites={},
  dirty={},
  holds={},
  by_tile={},
  has_tiles_x={},
  has_tiles_y={},
  mouse_tiles={}
 }]]
 -- obj.focus

 obj.add_widget=function(self,w)
  w=merge_tables(copy_table(widget_defaults),w)
  local widgets=self.widgets
  add(widgets,w)
  w.id=#widgets
  w.tx,w.ty=w.x\4,w.y\4
  self.focus=self.focus or w
  local tile=w.tx+(w.ty<<5)
  self.by_tile[tile]=w
  self.has_tiles_x[w.tx]=true
  self.has_tiles_y[w.ty]=true
  for dx=0,w.w-1 do
   for dy=0,w.h-1 do
    self.mouse_tiles[tile+dx+(dy<<5)]=w
   end
  end
 end

 obj.draw=function(self,state)
  -- restore screen from mouse
  local ldmy,mx,my=self.ldmy,self.mx,self.my
  if ldmy then
   memcpy(0x6000+ldmy*64,0x9000+ldmy*64,512)
   self.ldmy=nil
  end

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
   -- number => draw that sprite
   --  (subject to width value)
   -- string => unpack to text
   --  params and draw those
   if type(sp)=='number' then
    spr(self.sprites[id],wx,wy,1,1)
   else
    local tc,tw,bg,fg=unpack_split(sp)
    tc=tostr(tc)
    rectfill(wx,wy,wx+tw-1,wy+7,bg)
    print(tc,wx+tw-#tc*4,wy+1,fg)
   end
  end
  self.dirty={}
  local f=self.focus
  -- skip nil check
  palt(0,true)
  -- draw focus indicator
  spr(1,f.x,f.y,1,1)
  sspr(32,0,4,4,f.x+f.w*4-4,f.y)

  -- store rows behind mouse and draw mouse
  if mx and my then
   memcpy(0x9000+my*64,0x6000+my*64,512)
   spr(15,mx,my)
   self.ldmy=my
  end
 end

 obj.update=function(self,state)
  local holds,btns=self.holds,{}
  for b in all(ui_btns) do
   if btn(b) then
    local h=holds[b]+1
    holds[b]=h
    btns[b]=ui_reps[h] or h>=31
   else
    holds[b]=0
   end
  end
  local search
  if (btns[⬅️]) search={true,-1}
  if (btns[➡️]) search={true,1}
  if (btns[⬆️]) search={false,-1}
  if (btns[⬇️]) search={false,1}
  if (btns[❎]) self.focus:input(state,1*self.focus.btn_amt)
  if (btns[🅾️]) self.focus:input(state,-1*self.focus.btn_amt)

  self.mx,self.my,click=stat(32),stat(33),stat(34)
  local mx,my=self.mx,self.my

  local new_focus

  if (search) new_focus=self:move_focus(unpack(search))
  if click>0 then
   if click==self.last_click then
    self.drag_dist+=stat(39)
    local diff=flr(self.focus.drag_amt*(self.last_drag-self.drag_dist)+0.5)
    if diff!=0 then
     self.focus:input(state,diff)
     self.last_drag=self.drag_dist
    end
   else
    poke(0x5f2d, 0x5)
    self.click_x,self.click_y,self.drag_dist,self.last_drag=mx,my,0,0
    new_focus=self.mouse_tiles[mx\4 + ((my\4)<<5)]
    if (new_focus and not new_focus.active) new_focus=nil
    if (new_focus and new_focus.act_on_click) new_focus:input(state,trn(click==1,1,-1))
   end
  else
   poke(0x5f2d, 0x1)
  end

  if new_focus then
   self.dirty[self.focus.id]=true
   self.dirty[new_focus.id]=true
   self.focus=new_focus
  end

  self.last_click=click
 end

 local search_diffs=split'0,-1,1,-2,2'
 obj.move_focus=function(self,is_h,dir)
  local f,lim=self.focus,trn(dir>0,31,0)

  local has_tiles,ta,tb,sha,shb
  if is_h then
   has_tiles=self.has_tiles_y
   ta,tb,sha,shb=f.tx,f.ty,0,5
  else
   has_tiles=self.has_tiles_x
   ta,tb,sha,shb=f.ty,f.tx,5,0
  end

  for db in all(search_diffs) do
   local sb=tb+db
   if has_tiles[sb] then
    for sa=ta+dir,lim,dir do
     local r=self.by_tile[(sa<<sha)+(sb<<shb)]
     if (r and r.active) return r
    end
   end
  end

  return f
 end

 return obj
end

function pbl_note_btn_new(x,y,syn,step)
 return {
  x=x,y=y,drag_amt=0.1,
  get_sprite=function(self,state)
   return 64+state.pat_seqs[syn].nt[step]
  end,
  input=function(self,state,b)
   local n=state.pat_seqs[syn].nt
   n[step]=mid(0,36,n[step]+b)
  end
 }
end

function spin_btn_new(x,y,sprites,get,set)
 local n=#sprites
 return {
  x=x,y=y,act_on_click=true,
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
 -- last sprite in list is the
 -- "this step is active" sprite
 local n=#sprites-1
 return {
  x=x,y=y,act_on_click=true,
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

function dial_new(x,y,s0,bins,get,set)
 bins-=0x0.0001
 return {
  x=x,y=y,drag_amt=0.25,btn_amt=2,
  get_sprite=function(self,state)
   return s0+(get(state)>>7)*bins
  end,
  input=function(self,state,b)
   local x=mid(0,128,get(state)+b)
   set(state,x)
  end
 }
end

function toggle_new(x,y,s_off,s_on,get,set)
 return {
  x=x,y=y,act_on_click=true,
  get_sprite=function(self,state)
   return trn(get(state),s_on,s_off)
  end,
  input=function(self,state)
   set(state,not get(state))
  end
 }
end

function momentary_new(x,y,s,cb)
 return {
  x=x,y=y,act_on_click=true,
  get_sprite=function()
   return s
  end,
  input=function(self,state,b)
   cb(state,b)
  end
 }
end

function radio_btn_new(x,y,val,s_off,s_on,get,set)
 return {
  x=x,y=y,act_on_click=true,
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
 local ret_prefix=pib..',4,'..c_bg..','
 return {
  x=x,y=y,w=1,
  get_sprite=function(self,state)
   local bank,pending=get_bank(state),get_pat(state)
   local pat=state.pat_status[syn].idx
   local val=(bank-1)*bank_size+pib
   local col=trn(pat==val,c_on,c_off)
   if (pending==val and pending!=pat) col=c_next
   return ret_prefix..col
  end,
  input=function(self,state)
   local bank=get_bank(state)
   local val=(bank-1)*bank_size+pib
   set_pat(state,val)
  end
 }
end

function transport_number_new(x,y,w,obj,key)
 local get=state_make_get_set(obj,key)
 return {
  x=x,y=y,w=w,active=false,
  get_sprite=function(self,state)
   if state.song_mode then
    return tostr(get(state))..','..w..',0,15'
   else
    return '--,'..w..',0,15'
   end
  end,
  update=function() end
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

function pbl_ui_init(ui,key,base_idx,yp)
 for i=1,16 do
  local xp=(i-1)*8
  ui:add_widget(
   pbl_note_btn_new(xp,yp+24,key,i)
  )
  ui:add_widget(
   step_btn_new(xp,yp+16,key,i,split'16,17,33,18,34,32')
  )
 end

 ui:add_widget(
  momentary_new(24,yp,26,function(state,b)
   -- just inline the function?
   transpose_pat(state.pat_seqs[key],b)
  end)
 )
 ui:add_widget(
  momentary_new(8,yp,28,function(state,b)
   copy_buf_pbl=copy_table(state.pat_seqs[key])
  end)
 )
 ui:add_widget(
  momentary_new(16,yp,27,function(state,b)
   local v=copy_buf_pbl
   if (v) merge_tables(state.pat_seqs[key],v)
  end)
 )
 ui:add_widget(
  toggle_new(0,yp,186,187,state_make_get_set_param_bool(base_idx+3))
 )
 ui:add_widget(
  spin_btn_new(0,yp+8,split'162,163,164,165',state_make_get_set(key..'_bank'))
 )
 for i=1,6 do
  ui:add_widget(
   pat_btn_new(5+i*4,yp+8,key,6,i,2,14,8,6)
  )
 end

 for k,x in pairs(parse[[{
  6=40,
  7=56,
  8=72,
  9=88,
  10=104,
  11=120
 }]]) do
  ui:add_widget(
   dial_new(
    x,yp,43,21,
    state_make_get_set_param(base_idx+k)
   )
  )
 end

 ui:add_widget(
  toggle_new(32,yp,2,3,state_make_get_set_param_bool(base_idx+5))
 )

 map(0,4,0,yp,16,2)
end


function pirc_ui_init(ui,key,yp)
 for i=1,16 do
  local xp=(i-1)*8
  ui:add_widget(
   step_btn_new(xp,yp+24,key,i,split'19,21,20,35')
  )
 end
 for k,d in pairs(parse[[{
  bd={x=32,y=8,s=150,b=38},
  sd={x=32,y=16,s=152,b=41},
  hh={x=64,y=8,s=154,b=44},
  cy={x=64,y=16,s=156,b=47},
  pc={x=96,y=8,s=158,b=50},
  sp={x=96,y=16,s=174,b=53}
 }]]) do
  local cyp=yp+d.y
  ui:add_widget(
   radio_btn_new(d.x,cyp,k,d.s,d.s+1,state_make_get_set('drum_sel'))
  )
  -- lev,tun,dec
  for x,o in pairs(parse[[{8=2,16=0,24=1}]]) do
   ui:add_widget(
    dial_new(d.x+x,cyp,112,16,state_make_get_set_param(d.b+o))
   )
  end
 end

 for x,b in pairs(parse[[{32=0,64=1,96=2}]]) do
  ui:add_widget(
   toggle_new(x,yp,170,171,state_make_get_set_param_bool(37,b))
  )
 end

 ui:add_widget(
  momentary_new(8,yp+8,11,function(state,b)
   copy_buf_pirc=copy_table(state.pat_seqs['dr'])
  end)
 )
 ui:add_widget(
  momentary_new(16,yp+8,10,function(state,b)
   merge_tables(state.pat_seqs['dr'],copy_buf_pirc)
  end)
 )

 ui:add_widget(
  toggle_new(0,yp+8,188,189,state_make_get_set_param_bool(34))
 )

 ui:add_widget(
  spin_btn_new(0,yp+16,split'166,167,168,169',state_make_get_set(key..'_bank'))
 )
 for i=1,6 do
  ui:add_widget(
   pat_btn_new(5+i*4,yp+16,key,6,i,unpack_split'2,14,8,5')
  )
 end

 map(0,8,0,yp,16,4)
end

function header_ui_init(ui,yp)
 local function hdial(x,y,idx)
 ui:add_widget(
  dial_new(x,yp+y,128,16,state_make_get_set_param(idx))
 )
 end

 local function song_only(w,s_not_song)
  ui:add_widget(
   wrap_override(w,s_not_song,state_is_song_mode,false)
  )
 end

 ui:add_widget(
  toggle_new(
   0,yp,6,7,
   state_make_get_set('playing'),
   function(s) s:toggle_playing() end
  )
 )
 ui:add_widget(
  toggle_new(
   24,yp,172,173,
   state_is_song_mode,
   function(s) s:toggle_song_mode() end
  )
 )
 song_only(
  wrap_override(
   toggle_new(
    8,yp,231,232,
    state_make_get_set('tl','recording'),
    function(s) s:toggle_recording() end
   ),
   239,
   function(s) return (not s.tl.has_override) or s.tl.recording end,
   true
  ),
  233
 )
 song_only(
  momentary_new(
   16,yp,5,
   function()
    state:go_to_bar(
     trn(
      state.tl.bar>state.tl.loop_start,
      state.tl.loop_start,
      1
     )
    )
   end
  ),
  5
 )

 ui:add_widget(momentary_new(
  0,yp+8,242,
  function(s)
   s:copy_seq()
  end
 ))
 song_only(momentary_new(
  8,yp+8,241,
  function(s)
   s:cut_seq()
  end
 ),199)
 ui:add_widget(momentary_new(
  0,yp+16,247,
  function(s)
   s:paste_seq()
  end
 ))
 song_only(momentary_new(
  8,yp+16,243,
  function(s)
   s:insert_seq()
  end
 ),201)
 song_only(momentary_new(
  8,yp+24,246,
  function(s)
   s.tl:copy_overrides_to_loop()
  end
 ),204)

 for s in all(parse[[{
  1="16,8,1",
  2="32,8,3",
  3="32,16,6",
  4="16,16,2",
  5="16,24,4",
  6="32,24,5",
  7="48,16,57",
  8="48,24,58",
  9="64,24,59",
 }]]) do
  hdial(unpack_split(s))
 end

 ui:add_widget(
  toggle_new(64,yp+16,234,235,state_make_get_set_param_bool(56,0))
 )
 ui:add_widget(
  spin_btn_new(64,yp+8,parse[[{1="--,8,0,15",2="AL,8,0,15",3="B1,8,0,15",4="B2,8,0,15",5="RC,8,0,15"}]],state_make_get_set_param(56,1))
 )

 for pt,ypc in pairs(parse[[{b0=8,b1=16,dr=24}]]) do
  local base_idx=syn_base_idx[pt]
  ypc+=yp
  for idx,xpc in pairs(parse[[{0=104,1=112,2=120}]]) do
   hdial(xpc,ypc,base_idx+idx)
  end
 end
 ui:add_widget(
  transport_number_new(32,yp,unpack_split'16,tl,bar')
 )
 song_only(
  momentary_new(48,yp,192,
   function(state,b)
    state:go_to_bar(state.tl.bar+b)
   end
  ),
  197
 )
 song_only(
  toggle_new(56,yp,193,194,state_make_get_set('tl','loop')),
  195
 )
 ui:add_widget(
  transport_number_new(64,yp,unpack_split'16,tl,loop_start')
 )
 song_only(
  momentary_new(80,yp,192,
   function(state,b)
    local tl=state.tl
    local ns=tl.loop_start+b
    tl.loop_start=mid(1,ns,999)
    tl.loop_len=mid(1,tl.loop_len,1000-ns)
   end
  ),
  197
 )
 ui:add_widget(
  transport_number_new(88,yp,unpack_split'8,tl,loop_len')
 )
 song_only(
  momentary_new(96,yp,192,
   function(state,b)
    local tl=state.tl
    tl.loop_len=mid(1,tl.loop_len+b,1000-tl.loop_start)
   end
  ),
  197
 )

 -- last 0 should be yp
 map(unpack_split'0,0,0,0,16,4')
end

__gfx__
000000000000000066666666666666660ccc00000000000000000000000000000000000000000000555555555555555500000005000000006666666601000000
00000000000000006555665665556656000c0000006000606000f0f0b00060600666066600000000555555555666655500000000000000006666666617100000
00700700000000006565655665656556000c0000006005505600f0f03b0060600666060600000000555665555655655500000005000000006666666617710000
0007700000000000656555566565555600000000005055505560909033b0505006060666fff0fff0556666555656666500000000000000006666666617771000
00077000000000006666666666666666000000000050555055509090333050500606060600000000556556555656556500000005000000006666666601710000
00700700c00000006005555665550056000000000050055055009090330050500606060600000000556556555666556500000000000000006666666600100000
00000000c00000006000555665550006000000000050005050009090300050500000000000000000556556555556556500000005000000006666666600000000
00000000ccc000006666666666666666000000000000000000000000000000000000000000000000556666555556666500000000000000006666066600000000
66000006660000066600000655000005550000055500000500000000000000000000000000000000666666666666666666666666666666666666666666666660
60666670606666706066667050555560505555605055556000056000000000000000000000000000666566666666666665555666666666666666666666666666
06666667066666670666666705555556055555560555555600555600066006600660066006600066665556666665566665665666666666666666666666666666
06666666066666660666666605555555055555550555555500555500066000600660000606060600666566666655556665655556666666660666666606666666
06666666066666660666666605555555055555550555555500055000060600600606060006600600666666666656656665656656666666660666666606666666
06655766066228660664496605566755055228550554495500000000066606660666066606060066665556666656656665556656666666660666666606666666
06655566066222660664446605566655055222550554445500000000000000000000000000000000666666666656656666656656666666666666666666666666
00666660006666600066666000555550005555500055555000000000000000000000000000000000666666666655556666655556666666666666666666666666
66000006660000066600000655000005550000055500000500000000000000050000000000000000660060006660006666600066666000666660006666600066
6066667060666670606666705055556050555560505555600003b000000006000006600000000000606060006606770666067706660677066606770666067706
06666667066666670666666705555556055555560555555600333b00000600650006060006606600606060006066667060666670606666706066667060666670
06666666066666660666666605555555055555550555555500333300060060600006600060606060660066600666666606666666066666660666666606666666
06666666066666660666666605555555055555550555555500033000060060650006060060606060006060000666666606666666066666660656666606066666
06633b6606688e6606699a6605533b5505588e5505599a5500000000000600600066060066006600006660000666666606566666060666660656666606666666
06633366066888660669996605533355055888550559995500000000000006050066000000000000000060006060666060656660606666606066666060566660
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
000000000000090000000f0000000600000000050000000050050050555055555555000005000505000000000000000000000550000000000000000000000000
057500000000490000009f0000005600057500000050000005050500505050505005000000505000055555000055555000005505000000000000000000000000
0777000000044490000999f000055560077700050555000000000000555055555055550000050005550005500050005000005005000000000000000000000000
00000000040044090900990f05005506000000000000000055000550005050005050050055505550050005005555500000050550000000000000000000000000
07770000040004040900090905000505077700050555000000000000000500055550050000505005055555000555000000005000000000000000000000000000
05750000040000040900000905000005057500000050000005050500005050000050050000505000500000500050000005555500000000000000000000000000
00000000004444400099999000555550000000050000000050050050005050050055550055505555055555000000000050555000000000000000000000000000
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
60060060fff0fff5ffff00000f000f05000000000000000000000ff00000f0000000000000000005000000000000000555655555555555555555555555555555
06060600f0f0f0f0f00f000000f0f00006666600006666600000ff0f00000f0000000000000000000000000000000000566555555ee556665666565656665666
00000000fff0fff5f0ffff00000f000566000660006000600000f00f000000f0066060600660666506600666666066056666655555e555565556565656555655
6600066000f0f000f0f00f00fff0fff00600060066666000000f0ff00fffffff600060606000060006060060660066005665565555e556665566566656665666
00000000000f0005fff00f0000f0f00506666600066600000000f000f0fffff0006066606000060506060060600060655565566555e556555556555655565656
0606060000f0f00000f00f0000f0f00060000060006000000fffff00f00fff0066006060066006000660006060006660555666665eee56665666555656665666
6006006000f0f00500ffff00fff0fff50666660000000000f0fff000f000f0000000000000000005000000000000000555555665555555555555555555555555
000000000000000000000000000000000000000000000000f00f0000000000000000000000000000000000000000000055555655555555555555555555555555
__label__
00000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000060000000000066006000
b0006060000000000060006000000000000000000000000000500000000056000000000000000000005000000000000000500000006006000000000060606000
3b00606000056000006005500ff00099000000000000000005550000000555600000000000000000055500000000000005550000000606000660660060606000
33b050500055560000505550090f040000000000fff0fff0000000000500550600000000fff0fff000000000fff0fff000000000060606006060606066006660
33305050005555000050555009900004000000000000000005550000050005050000000000000000055500000000000005550000000606006060606000606000
33005050000550000050055009000440000000000000000000500000050000050000000000000000005000000000000000500000006006006600660000666000
30005050000000000050005000000000000000000000000000000000005555500000000000000000000000000000000000000000000060000000000000006000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000660000
ffff0000555055550000000000000000000000000000600500000000000000000000000006606600000000000000000500000000000000000000000000000000
f00f0000505050500057550000066000005755000060060000000000000000000000000060006060000000000000000000000000005755000055550000555500
f0ffff0055505555055555500006060005555550000606050000000000000000ff000ff000606600000000000000000506600660055555500555555005555550
f0f00f0000505000055555500006600005555550060606000000000000000000f0f0f00066006060000000000000000006600060055555500555555005555550
fff00f0000050005055555500006060005555550000606050000000000000000ff00f00000066000000000000000000506060060055555500555555005555550
00f00f0000505000055555500066060005555550006006000000000000000000f0f00ff000600000000000000000000006660666055555500555555005555550
00ffff00005050050055550000660000005555000000600500000000000000000000000000600000000000000000000500000000005555000067550000675500
00000000000000000000000000000000000000000000000000000000000000000000000000066000000000000000000000000000000000000000000000000000
0000f0000500050500000000000000000000000000000005000000006660660000000ccc00000000000000000000000500000000000000000000000000000000
00000f0000505000005555000000000000555500000000000055750066006060000f000c00000000000000000000000000000000005755000055550000555500
000000f00005000505555550066060600555555006606665055555506000660000f0f00c66606600000000000660666506600660055555500555555005555550
0fffffff5550555005555550600060600555555060000600055555506000606000f0f00066606060fff0fff06060060006600006055555500555555005555550
f0fffff00050500505555550006066600555555060000605055555500006000000f0f00060606060000000006660060506060600055555500555555005555550
f00fff0000505000055555506600606005555550066006000555555000606000cf000ff060606600000000006000060006660666055555500555555005555550
f000f00055505555006755000000000000557600000000050055550000660000c000000000000000000000000000000500000000005555000067550000675500
0000000000000000000000000000000000000000000000000000000000066000ccc0000000000000000000000000000000000000000000000000000000000000
00000000000000050000000000000000000000000000000500000000660066600000000066606660000000006600666500000000000000000000000000000000
00000000000000000057550000000000005755000000000000575500606066000055550066600600007555006060660000000000005755000055550000555500
00000000000000050555555006600666055555506660660505555550660060000555555060600600055555506060600506600066055555500555555005555550
00000000000000000555555006060060055555506600660005555550606006600555555060606660055555506600066006060600055555500755555005555550
00000000000000050555555006060060055555506000606505555550000660000555555000606000055555500006600506600600055555500555555005555550
00000000000000000555555006600060055555506000666005555550006000000555555000060000055555500060000006060066055555500555555005555550
00000000000000050055550000000000005555000000000500555500000060000055760000060000005555000060000500000000005555000055550000675500
00000000000000000000000000000000000000000000000000000000006600000000000000606000000000000006600000000000000000000000000000000000
06666666666666666666666666666666666666666660006666666666666000666666666666600066666666666660006666666666666000666666666666600066
66666666655556666666666666656666655566566606770666666666660677066666666666067706666666666606770666666666660677066666666666067706
6668e666656656666665566666555666656565566066667066666666606666706666666660666670666666666066667066666666606606706666666660660670
66888e66656555566655556666656666656555560666666606666666065666660666666606666666066666660666666606666666066666660666666606666666
66888866656566566656656666666666666666660666666606666666065666660666666606666606066666660666660606666666066666660666666606666666
66688666655566566656656666555666655500560666666606666666066666660666666606666666066666660666666606666666066666660666666606666666
66666666666566566656656666666666655500066060666066666666605666606666666660566660666666666056666066666666605666606666666660566660
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
06666666066666660666666606666666066666660666666606666666066666660666666606666666066666660666666606666666066666660666666606666666
06666666066666660666666606666666066666660666666606666666066666660666666606666666066666660666666606666666066666660666666606666666
0665576606655766066449660665576606655766066449660665576606655766066228660665576606633b660662286606655766066557660662286606655766
06655566066555660664446606655566066555660664446606655566066555660662226606655566066333660662226606655566066555660662226606655566
00666660006666600066666000666660006666600066666000666660006666600066666000666660006666600066666000666660006666600066666000666660
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
05665555056655550566555505665555056655550566555505665555056655550566565605665555056655550566555505665555056655550666555505665555
06555555065555550655555506555555065555550655555506555555065555550655566606555555065555550655555506555555065555550655555506555555
06555555065555550655555506555555065555550655555506555555065555550655566606555555065555550655555506555555065555550665555506555555
06565555065655550656555506565555065655550656555506565555065655550656565606565555065655550656555506565555065655550655555506565555
06665555066655550666555506665555066655550666555506665555066655550666555506665555066655550666555506665555066655550655555506665555
05555555055555550555555505555555055555550555555505555555055555550555555505555555055555550555555505555555055555550555555505555555
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
06666666666666666666666666666666666666666660006666666666666000666666666666600066666666666660006666666666666000666666666666600066
66666666655556666666666666656666655566566606770666666666660677066666666666067706666666666606770666666666660677066666666666067706
6668e666656656666665566666555666656565566066067066666666606606706666666660660670666666666066067066666666606606706666666660660670
66888e66656555566655556666656666656555560666666606666666066666660666666606666666066666660666666606666666066666660666666606666666
66888866656566566656656666666666666666660666666606666666066666660666666606666666066666660666666606666666066666660666666606666666
66688666655566566656656666555666655500560666666606666666066666660666666606666666066666660666666606666666066666660666666606666666
66666666666566566656656666666666655500066056666066666666605666606666666660566660666666666056666066666666605666606666666660566660
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
06666666066666660666666606666666066666660666666606666666066666660666666606666666066666660666666606666666066666660666666606666666
06666666066666660666666606666666066666660666666606666666066666660666666606666666066666660666666606666666066666660666666606666666
0665576606655766066557660665576606655766066557660665576606655766066557660665576606633b660665576606655766066557660665576606655766
06655566066555660665556606655566066555660665556606655566066555660665556606655566066333660665556606655566066555660665556606655566
00666660006666600066666000666660006666600066666000666660006666600066666000666660006666600066666000666660006666600066666000666660
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
05665555056655550566555505665555056655550566555505665555056655550566555505665555056655550566555505665555056655550566555505665555
06555555065555550655555506555555065555550655555506555555065555550655555506555555065555550655555506555555065555550655555506555555
06555555065555550655555506555555065555550655555506555555065555550655555506555555065555550655555506555555065555550655555506555555
06565555065655550656555506565555065655550656555506565555065655550656555506565555065655550656555506565555065655550656555506565555
06665555066655550666555506665555066655550666555506665555066655550666555506665555066655550666555506665555066655550666555506665555
05555565055555650555556505555565055555650555556505555565055555650555556505555565055555650555556505555565055555650555556505555565
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555556665555555555555555555555555555566655555555555555555555555555555666555555555555555555555555555
55555555555555555555555555566555556655555565555555666555556655555566555555655555556665555566555555665555556555555566655555665555
555555555555555555555555556565665565528855655656555656655565655655655288556556565556566555656556556558ee556556565556566555656556
5555555555555555555555555566656555555228556556565556565655656565555552285565565655565656556565655555588e556556565556565655656565
55555555555555555555555555656566556562225566556555565656556655665565622255665565555656565566556655656888556655655556565655665566
55555555555555555555555555555555555655555555555555555555555555555556555555555555555555555555555555565555555555555555555555555555
55555555555555555555555555555555556565555555555555555555555555555565655555555555555555555555555555656555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555566665555555555555800055500550055500005555080055550800555656565655000055550800555500005555665566550800555508005555080055
5558e555565565555556655550000005577057705000000550000005500000055656565650000005500000055000000556065600500000055000000550000005
55888e55565666655566665550000005577757575000008550000005500000055666566650000005500000055000008556665655500000055000000550000005
55888855565655655565565550000005570757575000000550000005500000055606560650000085500000055000000556005066500000055000000550000005
55588555566655655565565550000005577757755000000550000005500000055050505050000005500000055000000550555500500000055000000550000005
55555555555655655565565555000055555555555500005555000055550000555555555555000055550000555500005555555555550000555500005555000055
55555555555666655566665555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
557556665ee552225222525252225255556656655500005555080055550000555566565655080055550800555508005555665566550800555508005555000055
5777565655e555525552525252555255560056065000000550000005580000055600566650000005500000055000000556005606500000055000000550000005
5555566655e552225522522252225222505656565000000550000005500000055655500650000005500000055000000550565666500000055000000550000005
5555565655e552555552555255525252566056605000008550000005500000055066566050000005500000055000000556605600500000055000000550000005
555556565eee52225222555252225222500550055000000550000005500000055500500550000005500000055000000550055055500000055000000550000085
55555555555555555555555555555555555555555500005555000055550000555555555555000055550000555500005555555555550000555500005555000055
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55000005550000055500000555000005550000055500000555000005550000055500000555000005550000055500000555000005550000055500000555000005
50555560505555605055556050555560505555605055556050555560505555605055556050555560505555605055556050555560505555605055556050555560
05555556055555560555555605555556055555560555555605555556055555560555555605555556055555560555555605555556055555560555555605555556
05555555055555550555555505555555055555550555555505555555055555550555555505555555055555550555555505555555055555550555555505555555
05555555055555550555555505555555055555550555555505555555055555550555555505555555055555550555555505555555055555550555555505555555
0552285505566755055667550556675505566755055667550556675505566755055667550556675505533b550556675505566755055667550556675505566755
05522255055666550556665505566655055666550556665505566655055666550556665505566655055333550556665505566655055666550556665505566655
00555550005555500055555000555550005555500055555000555550005555500055555000555550005555500055555000555550005555500055555000555550

__map__
07e905acefefc0c1efefc0efc0ec292a07e905ac0000c0c10000c000c0ec292a07e705ac00eec5c300eec5eec5ec292a0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
f2c785288527000009e0000c17858585c6cb842884270000000026b717848484f2c784288427001726d00000008484840000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
f7c985f885f986e1eae409e618858585c7c884f884f90000000026b418848484f7c984f884f9001826d00000008484840000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000c85fa85fb86e286e386e519858585cac984fa84fb0000000026b919848484000084fa84fb001926d00000008484840000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
bb1c1b1a02341e341e341e341e341e340c0ddfdf1d341e341e341e341e341e34000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
a2dfdf1d1dd4d5d6d7d8d9dadbdcddde1c1b1a021dd4d5d6d7d8d9dadbdcddde000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1010101010101010101010101010101010101010101010101010101010101010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
5555555555555555555555555555555555555555555555555555555555555555000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
a1a1a1beab959394ab959394ab9593940b0aa1a1977698769a769c769e76ae76000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
bd0b0a76977676769a7676769e767676fca1a1a1937693769376937693769376000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
a6a1a1a1987676769c767676ae767676a6fdfeff947694769476947694769476000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1313131313131313131313131313131313131313131313131313131313131313000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000b0aa1a1a1959394a1959394a1959394000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000fca1a1a1977676769a7676769e767676000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000a6fdfeff987676769c767676ae767676000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000013131313131313131313131313131313000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000001900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
