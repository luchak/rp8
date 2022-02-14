pico-8 cartridge // http://www.pico-8.com
version 35
__lua__
-- rp-8
-- by luchak

semitone=2^(1/12)

-- give audio time to settle
-- before starting synthesis
pause_frames=6

function copy_state()
 pause_frames=2
 audio_set_root(nil)
 printh(state:save(),'@clip')
end

function paste_state()
 pause_frames=2
 audio_set_root(nil)
 local pd=stat(4)
 if pd!='' then
  state=state_load(pd) or state
  seq_helper.state=state
 end
end

rec_menuitem=4
audio_rec=false
function start_rec()
 audio_rec=true
 menuitem(rec_menuitem,'stop recording',stop_rec)
 extcmd'audio_rec'
end

function stop_rec()
 if (audio_rec) extcmd'audio_end'
 menuitem(rec_menuitem,'start recording',start_rec)
end

function _init()
 cls()

 ui,state=ui_new(),state_new()

 header_ui_init(ui,0)
 pbl_ui_init(ui,unpack_split'b0,7,32')
 pbl_ui_init(ui,unpack_split'b1,21,64')
 pirc_ui_init(ui,'dr',96)

 pbl0,pbl1=synth_new(7),synth_new(21)
 kick,snare,hh,cy,perc=
  sweep_new(unpack_split'41,0.092,0.0126,0.12,0.7,0.7,0.4'),
  snare_new(),
  hh_cy_new(unpack_split'47,1,0.8,0.75,0.35,-1,2'),
  hh_cy_new(unpack_split'50,1.3,0.5,0.5,0.18,0.3,0.8'),
  sweep_new(unpack_split'53,0.12,0.06,0.2,1,0.85,0.6')
 drum_mixer=submixer_new({kick,snare,hh,cy,perc})
 delay=delay_new(3000,0)

 mixer=mixer_new(
  {
   b0={obj=pbl0,lev=0.5,od=0.0,fx=0},
   b1={obj=pbl1,lev=0.5,od=0.5,fx=0},
   dr={obj=drum_mixer,lev=0.5,od=0.5,fx=0},
  },
  delay,
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
    kick:note(dseq.bd,patch,now,nl)
    snare:note(dseq.sd,patch,now,nl)
    hh:note(dseq.hh,patch,now,nl)
    cy:note(dseq.cy,patch,now,nl)
    perc:note(dseq.pc,patch,now,nl)
   end

   local mix_lev,dl_t,dl_fb,comp_thresh=unpack_patch(patch,3,6)
   local b0_lev,b0_od,b0_fx=unpack_patch(patch,7,9)
   local b1_lev,b1_od,b1_fx=unpack_patch(patch,21,23)
   local drum_lev,drum_od,drum_fx=unpack_patch(patch,35,37)
   mixer.lev=mix_lev*3
   delay.l=(0.9*dl_t+0.1)*sample_rate
   delay.fb=sqrt(dl_fb)*0.95

   local ms=mixer.srcs
   ms.b0.lev=b0_lev
   ms.b1.lev=b1_lev
   ms.dr.lev=drum_lev*2
   ms.b0.od=b0_od
   ms.b1.od=b1_od
   ms.dr.od=drum_od
   ms.b0.fx=b0_fx*b0_fx*0.8
   ms.b1.fx=b1_fx*b1_fx*0.8
   ms.dr.fx=drum_fx*drum_fx*0.8
   comp.thresh=0.1+0.9*comp_thresh

   state:next_tick()
  end
 )

 function toggle_output_lpf()
  poke(0x5f36,@0x5f36^^0x20)
 end
 toggle_output_lpf()

 menuitem(1, 'save to clip', copy_state)
 menuitem(2, 'load from clip', paste_state)
 menuitem(3, 'clear seq', function()
  state=state_new()
  seq_helper.state=state
 end)
 menuitem(rec_menuitem, 'start recording', start_rec)
 menuitem(5, 'toggle output lpf', toggle_output_lpf)

 log'init complete'
end

function _update60()
 audio_update()
 if pause_frames<=0 then
  ui:update(state)
  audio_set_root(seq_helper)
 else
  pause_frames-=1
 end
end

function _draw()
 ui:draw(state)

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
_schunk,_tgtchunks=100,1
_bufpadding,_chunkbuf=4*_schunk,{}
sample_rate=5512.5

function audio_set_root(obj)
 _root_obj=obj
end

function audio_dochunk()
 local buf=_chunkbuf
 if _root_obj then
  _root_obj:update(buf,1,_schunk)
 else
  for i=1,_schunk do
   buf[i]=0
  end
 end
 for i=1,_schunk do
  -- soft saturation to make
  -- clipping less unpleasant
  local x=mid(-1,buf[i],1)
  x-=0.148148*x*x*x
  -- add dither to keep delay
  -- tails somewhat nicer
  -- also ensure that e(0) is
  -- on a half-integer value
  poke(0x42ff+i,flr((x<<7)+0.375+(rnd()>>2))+128)
 end
 serial(0x808,0x4300,_schunk)
end

function audio_update()
 local bufsize,inbuf,newchunks=stat(109),stat(108),0

 while inbuf<_schunk do
  log'behind'
  audio_dochunk()
  newchunks+=1
  inbuf+=_schunk
 end

 -- always generate at least 1
 -- chunk if there is space
 -- and time
 if newchunks<_tgtchunks and inbuf<bufsize+_bufpadding and stat(1)<0.3 then
  audio_dochunk()
  inbuf+=_schunk
  newchunks+=1
 end
end
-->8
-- audio gen

--fir_coefs={0,0.0642,0.1362,0.1926,0.2139,0.1926,0.1362,0.0642}

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
  assert(step<=16)
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
   local fc=min(0.37/os,fcb+((me*env)>>4))
   -- very very janky dewarping
   -- arbitrary scaling constant
   -- is 0.75*2*pi because???
   fc=4.71*fc/(1+fc)
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
    fosc+=(osc-fosc)*0.025
    osc-=fosc
    ffb+=(f4-ffb)>>5
    local x=osc-fr*(f4-ffb-osc)
    local xc=mid(-1,x,1)
    x=xc+(x-xc)*0.9840

    f1+=(x-f1)*fc
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
 local obj=parse[[{
  op=0,
  dp=6553.6,
  ae=0.0,
  aemax=0.6,
  aed=0.995,
  ted=0.05,
  detune=1.0
 }]]

 obj.note=function(self,pat,patch,step,note_len)
  local s=pat[step]
  local tun,dec,lev=unpack_patch(patch,base,base+2)
  if s!=d_off then
   self.detune=2^(1.5*tun-0.75)
   self.op,self.dp=0,(_dp0<<16)*self.detune
   self.ae=lev*lev*boost*trn(s==d_ac,1.5,0.6)
   self.aemax=0.5*self.ae
   self.ted=0.5*((te_base-te_scale*dec)^4)
   self.aed=1-ae_ratio*self.ted
  end
 end

 obj.subupdate=function(self,b,first,last)
  local op,dp,dp1,ae,aed,ted=self.op,self.dp,(_dp1<<16)*self.detune,self.ae,self.aed,self.ted
  local aemax=self.aemax
  for i=first,last do
   op+=dp
   dp+=ted*(dp1-dp)
   ae*=aed
   b[i]+=min(ae,aemax)*sin(0.5+(op>>16))
  end
  self.op,self.dp,self.ae=op,dp,ae
 end

 return obj
end

function snare_new()
 local obj=parse[[{
  dp0=0.08,
  dp1=0.042,
  op=0,
  dp=0.05,
  aes=0.0,
  aen=0.0,
  detune=10,
  aesd=0.99,
  aend=0.996,
  aemax=0.4
 }]]
 
 obj.note=function(self,pat,patch,step,note_len)
  local s=pat[step]
  local tun,dec,lev=unpack_patch(patch,44,46)
  if s!=d_off then
   self.detune=2^(2*tun-1)
   self.op,self.dp=0,self.dp0*self.detune
   self.aes,self.aen=0.7,0.4
   if (s==d_ac) self.aes,self.aen=1.5,0.85
   self.aes-=(tun-0.5)*0.2
   self.aen+=(tun-0.5)*0.2
   self.aes*=lev*lev
   self.aen*=lev*lev
   self.aemax=self.aes*0.5
   local pd4=(0.65-0.25*dec)^4
   self.aesd=1-0.1*pd4
   self.aend=1-0.04*pd4
  end
 end
 
 obj.subupdate=function(self,b,first,last)
  local op,dp,dp1=self.op,self.dp,self.dp1*self.detune
  local aes,aen,aesd,aend=self.aes,self.aen,self.aesd,self.aend
  local aemax=self.aemax
  for i=first,last do
   op+=dp
   dp+=(dp1-dp)>>7
   aes*=aesd
   aen*=aend
   if (op>=1) op-=2
   b[i]+=(min(aemax,aes)*sin(op)+aen*(2*rnd()-1))*0.3
  end
  self.dp,self.op,self.aes,self.aen=dp,op,aes,aen
 end
 
 return obj
end

function hh_cy_new(base,_nlev,_tlev,dbase,dscale,tbase,tscale)
 local obj=parse[[{
  ae=0.0,
  f1=0.0,
  f2=0.0,
  op1=0.0,
  odp1=14745.6,
  op2=0.0,
  odp2=17039.36,
  op3=0.0,
  odp3=15400.96,
  op4=0.0,
  odp4=15892.48,
  aed=0.995,
  detune=1
 }]]
 
 obj.note=function(self,pat,patch,step,note_len)
  local s=pat[step]
  local tun,dec,lev=unpack_patch(patch,base,base+2)
  if s!=d_off then
   self.op,self.dp=0,self.dp0
   self.ae=lev*lev*trn(s==d_ac,2.0,0.8)

   self.detune=2^(tbase+tscale*tun)
   local pd4=(dbase-dscale*dec)
   pd4*=pd4*pd4*pd4

   self.aed=1-0.04*pd4
  end
 end

 obj.subupdate=function(self,b,first,last)
  local ae,f1,f2=self.ae,self.f1,self.f2
  local op1,op2,op3,op4=self.op1,self.op2,self.op3,self.op4
  local odp1,odp2,odp3,odp4=self.odp1*self.detune,self.odp2*self.detune,self.odp3*self.detune,self.odp4*self.detune
  local aed,tlev,nlev=self.aed,_tlev,_nlev

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
  self.ae,self.f1,self.f2=ae,f1,f2
  self.op1,self.op2,self.op3,self.op4=op1,op2,op3,op4
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
   if (abs(y)<0.0001) y=0
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

function submixer_new(srcs)
 return {
  srcs=srcs,
  update=function(self,b,first,last)
   for i=first,last do
    b[i]=0
   end

   for src in all(self.srcs) do
    src:subupdate(b,first,last)
   end
  end
 }
end

function mixer_new(srcs,fx,lev)
 return {
  srcs=srcs,
  fx=fx,
  lev=lev,
  tmp={},
  fxbuf={},
  update=function(self,b,first,last)
   local fxbuf,tmp,lev=self.fxbuf,self.tmp,self.lev
   for i=first,last do
    b[i],fxbuf[i]=0,0
   end

   for k,src in pairs(self.srcs) do
    local slev,od,fx=src.lev,src.od*src.od,src.fx
    src.obj:update(tmp,first,last)
    local odf=0.3+31.7*od
    --local odfi=1/(4*(atan2(odf,1)-0.75))
    local odfi=(1+3*od)/odf
    for i=first,last do
     local x=mid(-1,tmp[i]*odf,1)
     x=slev*odfi*(x-0.148148*x*x*x)
     b[i]+=x*lev
     fxbuf[i]+=x*fx
    end
   end

   self.fx:update(fxbuf,first,last)
   for i=first,last do
    b[i]+=fxbuf[i]*lev
   end
  end
 }
end

-- absolutely ghastly but a
-- very very fast log function
-- is needed to make progress
function comp_new(src,thresh,ratio,att,rel)
 return {
  src=src,
  thresh=thresh,
  ratio=ratio,
  att=att,
  rel=rel,
  env=0,
  update=function(self,b,first,last)
   self.src:update(b,first,last)
   local env,att,rel=self.env,self.att,self.rel
   local thresh,ratio=self.thresh,1/self.ratio
   -- makeup targets 0.67
   local makeup=max(1,0.67/((0.67-thresh)*ratio+thresh))
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

#include events.lua

-->8
-- state

n_off,n_on,n_ac,n_sl,n_ac_sl,d_off,d_on,d_ac=unpack_split'64,65,66,67,68,64,65,66'

pat_groups=split'b0,b1,dr'

syn_base_idx=parse[[{
 b0=7,
 b1=21,
 dr=35,
 bd=40,
 sd=43,
 hh=46,
 cy=49,
 pc=52,
}]]

pat_param_idx=parse[[{
 b0=11,
 b1=25,
 dr=39,
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
20=64,
21=64,
22=0,
23=0,
24=128,
25=1,
26=128,
27=64,
28=64,
29=64,
30=64,
31=64,
32=64,
33=64,
34=64,
35=64,
36=0,
37=0,
38=128,
39=1,
40=127,
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
56=64,
57=64,
58=64,
59=0,
60=64,
61=64,
62=128,
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
 -- 19 b0_??=0.5,
 -- 20 b0_??=0.5,
 -- 21 b1_lev=0.5,
 -- 22 b1_od=0,
 -- 23 b1_fx=0,
 -- 24 b1_on=true,
 -- 25 b1_pat=1,
 -- 26 b1_saw=true,
 -- 27 b1_tun=0.5,
 -- 28 b1_cut=0.5,
 -- 29 b1_res=0.5,
 -- 30 b1_env=0.5,
 -- 31 b1_dec=0.5,
 -- 32 b1_acc=0.5,
 -- 33 b1_??=0.5,
 -- 34 b1_??=0.5,
 -- 35 dr_lev=0.5,
 -- 36 dr_od=0,
 -- 37 dr_fx=0,
 -- 38 dr_on=true,
 -- 39 dr_pat=1,
 -- 40 dr_fx_en=127/128
 -- 41 bd_tun=0.5,
 -- 42 bd_dec=0.5,
 -- 43 bd_lev=0.5,
 -- 44 sd_tun=0.5,
 -- 45 sd_dec=0.5,
 -- 46 sd_lev=0.5,
 -- 47 hh_tun=0.5,
 -- 48 hh_dec=0.5,
 -- 49 hh_lev=0.5,
 -- 50 cy_tun=0.5,
 -- 51 cy_dec=0.5,
 -- 52 cy_lev=0.5,
 -- 53 pc_tun=0.5,
 -- 54 pc_dec=0.5,
 -- 55 pc_lev=0.5,
 -- 56 p2_tun=0.5,
 -- 57 p2_dec=0.5,
 -- 58 p2_lev=0.5,
 -- 59 fl_src_type=0
 -- 60 fl_cut=0.5
 -- 61 fl_res=0.5
 -- 62 fl_wet=1

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
   if (self.tick>16) self:load_bar()
  end
  self:_init_tick()
 end

 s.toggle_playing=function(self)
  local tl=self.tl
  if self.playing then
   if (tl.recording) tl:toggle_recording()
   tl.override_params={}
  end
  self:load_bar()
  self.playing=not self.playing
 end

 s.toggle_recording=function(self)
  self.tl:toggle_recording()
 end

 s.toggle_song_mode=function(self)
  self.song_mode=not self.song_mode
  if (self.playing) self:toggle_playing()
  self:load_bar()
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
  for group in all(pat_groups) do
   local base=syn_base_idx[group]
   self.pat_status[group]={
    on=patch[base+3]>0,
    idx=patch[base+4],
   }
  end
 end

 s.go_to_bar=function(self,bar)
  assert(self.song_mode, 'navigation outside of song mode')
  self:load_bar(mid(1,bar,999))
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
   pat_store=map_table_deep(self.pat_store,enc_byte_array,2)
  })
 end

 s.cut_seq=function(self)
  if (self.playing) self:toggle_playing()
  copy_buf_seq=self.tl:cut_seq()
  self:load_bar()
 end

 s.copy_seq=function(self)
  if self.song_mode then
   copy_buf_seq=self.tl:copy_seq()
  else
   copy_buf_seq={{
    start=enc_byte_array(self.pat_patch),
    events={}
   }}
  end
 end

 s.paste_seq=function(self)
  if (not copy_buf_seq) return
  if (self.playing) self:toggle_playing()
  local n=#copy_buf_seq
  if self.song_mode then
   self.tl:paste_seq(copy_buf_seq)
  else
   self.pat_patch=dec_byte_array(copy_buf_seq[1].start)
  end
  self:load_bar()
 end

 s.insert_seq=function(self)
  if (not copy_buf_seq) return
  if (self.playing) self:toggle_playing()
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

function state_make_get_set_param(idx)
 return
  function(state) return state.patch[idx] end,
  function(state,val) state:_apply_diff(idx,val) end
end

function state_make_get_set_param_bool(idx)
 return
  function(state) return state.patch[idx]>0 end,
  function(state,val) state:_apply_diff(idx,trn(val,128,0)) end
end

function state_make_get_set(a,b)
 return
  state_make_get(a,b),
  function(s,v) if (b) s[a][b]=v else s[a]=v end
end

function state_make_get(a,b)
 return function(s) if (b) return s[a][b] else return s[a] end
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
  note_fn=note_fn,
  t=state.note_len,
  update=function(self,b,first,last)
   local p,nl=first,self.state.note_len
   while p<last do
    if self.t>=nl then
     self.t=0
     self.note_fn()
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
ui_reps=parse[[{
 1=true,
 11=true,
 19=true,
 25=true,
 29=true
}]]
--31=true

function ui_new()
 local obj=parse[[{
  widgets={},
  sprites={},
  dirty={},
  holds={},
  by_tile={},
  has_tiles_x={},
  has_tiles_y={}
 }]]
 -- obj.focus

 local function get_tile(tx,ty)
  return tx+(ty<<5)
 end

 obj.add_widget=function(self,w)
  local widgets=self.widgets
  add(widgets,w)
  w.id=#widgets
  w.tx,w.ty=w.x\4,w.y\4
  local tile=get_tile(w.tx,w.ty)
  w.tile=tile
  self.focus=self.focus or w
  self.by_tile[tile]=w
  self.has_tiles_x[w.tx]=true
  self.has_tiles_y[w.ty]=true
 end

 obj.draw=function(self,state)
  for id,w in pairs(self.widgets) do
   local ns=w:get_sprite(state)
   if ns!=self.sprites[id] then
    self.sprites[id]=ns
    self.dirty[id]=true
   end
  end
  palt(0,false)
  for id,_ in pairs(self.dirty) do
   local w=self.widgets[id]
   local ww,sp=w.w,self.sprites[id]
   local tsp,wx,wy=type(sp),w.x,w.y
   -- number => draw that sprite
   --  (subject to width value)
   -- string => unpack to text
   --  params and draw those
   if tsp=='number' then
    if ww then
     local sp=self.sprites[id]
     local sx,sy=(sp%16)*8,(sp\16)*8
     sspr(sx,sy,ww,8,wx,wy)
    else
     spr(self.sprites[id],wx,wy,1,1)
    end
   else
    local ts,tw,bg,fg=unpack_split(sp)
    ts=tostr(ts)
    rectfill(wx,wy,wx+tw-1,wy+7,bg)
    print(ts,wx+tw-(#ts*4),wy+1,fg)
   end
  end
  self.dirty={}
  local f=self.focus
  -- skip nil check
  palt(0,true)
  if f.w then
   sspr(8,88,f.w,8,f.x,f.y)
  else
   spr(1,f.x,f.y,1,1)
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
  if (btns[❎]) self.focus:input(state,1)
  if (btns[🅾️]) self.focus:input(state,-1)
  if search then
   local new_focus=self:move_focus(unpack(search))
   self.dirty[self.focus.id]=true
   self.dirty[new_focus.id]=true
   self.focus=new_focus
  end
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
     if (r and not r.noinput) return r
    end
   end
  end

  return f
 end

 return obj
end

function pbl_note_btn_new(x,y,syn,step)
 return {
  x=x,y=y,
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
  x=x,y=y,
  get_sprite=function(self,state)
   return sprites[get(state)]
  end,
  input=function(self,state,b)
   set(state,mid(1,get(state)+b,n))
  end
 }
end

function step_btn_new(x,y,syn,step,sprites)
 -- last sprite in list is the
 -- "this step is active" sprite
 local n=#sprites-1
 return {
  x=x,y=y,
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
  x=x,y=y,
  get_sprite=function(self,state)
   return s0+(get(state)>>7)*bins
  end,
  input=function(self,state,b)
   local x=mid(0,128,get(state)+(b<<1))
   set(state,x)
  end
 }
end

function toggle_new(x,y,s_off,s_on,get,set)
 return {
  x=x,y=y,
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
  x=x,y=y,
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
  x=x,y=y,
  get_sprite=function(self,state)
   return trn(get(state)==val,s_on,s_off)
  end,
  input=function(self,state)
   set(state,val)
  end
 }
end

function pat_btn_new(x,y,syn,bank_size,pib,c_off,c_on,c_next,c_bg)
 local get_bank=state_make_get(syn..'_bank')
 local get_pat,set_pat=state_make_get_set_param(syn_base_idx[syn]+4)
 local ret_prefix=pib..',4,'..c_bg..','
 return {
  x=x,y=y,w=4,
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
 local get=state_make_get(obj,key)
 return {
  x=x,y=y,w=w,noinput=true,
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

function wrap_disable(w,s_disable,get_enabled)
 local obj={
  get_sprite=function(self,state)
   if get_enabled(state) then
    self.noinput=false
    return w:get_sprite(state)
   else
    self.noinput=true
    return s_disable
   end
  end,
 }
 w.__index=w
 setmetatable(obj,w)
 return obj
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
  momentary_new(16,yp,26,function(state,b)
   transpose_pat(state.pat_seqs[key],b)
  end)
 )
 ui:add_widget(
  momentary_new(0,yp,28,function(state,b)
   copy_buf_pbl=copy_table(state.pat_seqs[key])
  end)
 )
 ui:add_widget(
  momentary_new(8,yp,27,function(state,b)
   local v=copy_buf_pbl
   if (v) merge_tables(state.pat_seqs[key],v)
  end)
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
  bd={x=32,y=8,s=150,b=41},
  sd={x=32,y=16,s=152,b=44},
  hh={x=64,y=8,s=154,b=47},
  cy={x=64,y=16,s=156,b=50},
  pc={x=96,y=8,s=158,b=53}
 }]]) do
  local cyp=yp+d.y
  ui:add_widget(
   radio_btn_new(d.x,cyp,k,d.s,d.s+1,state_make_get_set('drum_sel'))
  )
  -- lev
  ui:add_widget(
   dial_new(d.x+8,cyp,112,16,state_make_get_set_param(d.b+2))
  )
  -- tun
  ui:add_widget(
   dial_new(d.x+16,cyp,112,16,state_make_get_set_param(d.b+0))
  )
  -- dec
  ui:add_widget(
   dial_new(d.x+24,cyp,112,16,state_make_get_set_param(d.b+1))
  )
 end

 ui:add_widget(
  momentary_new(0,yp+8,11,function(state,b)
   copy_buf_pirc=copy_table(state.pat_seqs['dr'])
  end)
 )
 ui:add_widget(
  momentary_new(8,yp+8,10,function(state,b)
   merge_tables(state.pat_seqs['dr'],copy_buf_pirc)
  end)
 )

 ui:add_widget(
  spin_btn_new(0,yp+16,split'166,167,168,169',state_make_get_set(key..'_bank'))
 )
 for i=1,6 do
  ui:add_widget(
   pat_btn_new(5+i*4,yp+16,key,6,i,2,14,8,5)
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

 local function song_only(w,s_disable)
  ui:add_widget(
   wrap_disable(w,s_disable,state_is_song_mode)
  )
 end

 ui:add_widget(
  toggle_new(
   0,yp,6,7,
   state_make_get('playing'),
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
  toggle_new(
   8,yp,231,232,
   state_make_get('tl','recording'),
   function(s) s:toggle_recording() end
  ),
  233
 )
 song_only(
  momentary_new(
   16,yp,5,
   function()
    state:go_to_bar(trn(state.tl.loop,state.tl.loop_start,1))
   end
  ),
  5
 )

 ui:add_widget(momentary_new(
  0,yp+8,242,
  function()
   state:copy_seq()
  end
 ))
 song_only(momentary_new(
  8,yp+8,241,
  function()
   state:cut_seq()
  end
 ),199)
 ui:add_widget(momentary_new(
  0,yp+16,247,
  function()
   state:paste_seq()
  end
 ))
 song_only(momentary_new(
  8,yp+16,243,
  function()
   state:insert_seq()
  end
 ),201)

 for s in all(parse[[{
  1="16,8,1",
  2="32,8,3",
  3="32,16,6",
  4="16,16,2",
  5="16,24,4",
  6="32,24,5",
 }]]) do
  hdial(unpack_split(s))
 end

 for pt,ypc in pairs(parse[[{b0=8,b1=16,dr=24}]]) do
  local base_idx=syn_base_idx[pt]
  ypc+=yp
  ui:add_widget(
   toggle_new(96,ypc,22,38,state_make_get_set_param_bool(base_idx+3))
  )
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
0000000000000ccc6666666666666666000000000000000000000000000000000000000000000000555555555666655506666666666666666666666600000000
000000000000000c655566566555665600000000006000606000f0f0b00060600666066600000000555665555655655565555655566556666666666600000000
007007000000000c656565566565655600000000006005505600f0f03b0060600666060600000000556666555656666565565655656556666666666600000000
0007700000000000656555566565555600000000005055505560909033b050500606066666606660556556555656556560000600066006666666666600000000
00077000000000006666666666666666000000000050555055509090333050500606060600000000556556555666556560066600606006666666666600000000
00700700c00000006005555665550056000000000050055055009090330050500606060600000000556556555556556560066600066000066666666600000000
00000000c00000006000555665550006000000000050005050009090300050500000000000000000556666555556666566666666666666666666666600000000
00000000ccc000006666666666666666000000000000000000000000000000000000000000000000555555555555555566666666666666666666066600000000
66000006660000066600000655000005550000055500000500000000000000000000000000000000666666666666666605555666666666666666666666666660
60666670606666706066667050555560505555605055556000056000066606600666066606660066666566666665566665665666666666666666666666666666
06666667066666670666666705555556055555560555555600555600060600600606000606060600665556666655556665655556666666666666666666666666
06666666066666660666666605555555055555550555555500555500066000600660066606600600666566666656656665656656666666660666666606666666
06666666066666660666666605555555055555550555555500055000060600600606060006060600666666666656656665556656666666660666666606666666
06655766066228660664496605566755055228550554495500000000066606660666066606060066665556666656656666656656666666660666666606666666
06655566066222660664446605566655055222550554445500000000000000000000000000000000666666666655556666655556666666666666666666666666
00666660006666600066666000555550005555500055555000000000000000000000000000000000666666666666666666666666666666666666666666666666
66000006660000066600000655000005550000055500000500000000000060000000000000000000000000006660006666600066666000666660006666600066
6066667060666670606666705055556050555560505555600003b000006006000006600000000000000000006606770666067706660677066606770666067706
06666667066666670666666705555556055555560555555600333b00000606000006060006606600666060606066667060666670606666706066667060666670
06666666066666660666666605555555055555550555555500333300060606000006600060606060660006000666666606666666066666660666666606666666
06666666066666660666666605555555055555550555555500033000000606000006060060606060600006000666666606666666066666660656666606066666
06633b6606688e6606699a6605533b5505588e5505599a5500000000006006000066060066006600600060600666666606566666060666660656666606666666
06633366066888660669996605533355055888550559995500000000000060000066000000000000000000006060666060656660606666606066666060566660
00666660006666600066666000555550005555500055555000000000000000000000000000000000000000006605560666055606660556066605560666055606
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
55555555577555577555775555555555555555555555555556655665500550055566566555005005565656565050505055665656550050505666566550005005
55505555560655560656005555666555556655555565555556665606577057705600560650775770565656565757575756005666507757075606506557775775
55505555565656565656555555565665556565565565565656065656577757575056565657505757566656665707570756555006575557775666556557075575
55505555566050566056555555565656556565655565565656665660570757575660566050075707560656065777577750665660570050075600566657775070
55505555560556560656555555565656556655665566556550005005577757755005500557755775505050505757575755005005557757755055500057555777
55505555565556565650665555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55505555505550505055005555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55505555555555556666666666666666666666666666666655555555555555555555555555555555556665555566655500000000000000005555555555555555
55505555555555556676655566766555667666556666655655755666557556665575556655555665556555555565555500000000000000005666566550005005
5550555555555555677765656777656567776566666665655777565657775656577756555555565655665555556655550ff00099099000ff5606500657775770
5550555555555555666665556666655666666566666665655555566655555665555556555555565655655288556558ee090f0400040909005666565057075057
55505555555555556666656566666565666665666666656555555656577756565777565557775656555552285555588e09900004044000095600566657775700
55505555555555556666656567776555677766556777655655555656557556665575556655755665556562225565688809000440040009905055500057555777
55505555555555556666666666766666667666666676666655555555555555555555555555555555555655555556555500000000000000005555555555555555
55505555555555556666666666666666666666666666666655555555555555555555555555555555556565555565655500000000000000005555555555555555
5550555500cc00000000000000000000000000000000000000000000000000000000000000222200000000000000000000000000000000005555555500000000
55505555000c00000000000000000000000000000000000000000000000000000022220002888820000000000000000000000000000000005555555500000000
55505555000c0000000000000000000000000000000000000000000000aaaa0009aaaa9009aaaa90000000000000000000000000000000005556655500000000
55505555000000000000000000000000000000000000000000999900009999000099990000999900000000000000000000000000000000005565656600000000
555055550000000000000000000000000000000000bbbb0003bbbb3003bbbb3003bbbb3003bbbb30000000000000000000000000000000005566656500000000
55505555c00000000000000000000000003333000033330000333300003333000033330000333300000000000000000000000000000000005565656600000000
55555555c0000000000000000033330003bbbb3003bbbb3003bbbb3003bbbb3003bbbb3003bbbb30000000000000000000000000000000005555555500000000
55555555cc0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000005555555500000000
000000000000090000000f0000000600000000050000000050050050555055505555000005000500000000000000000000000000000000000000000000000000
057500000000490000009f0000005600057500050050000005050500505050505005000000505000055555000055555005555000000000000000000000000000
0777000000044490000999f000055560077700050555000000000000555055505055550000050000550005500050005005505050000000000000000000000000
00000000040044090900990f05005506000000050000000055000550005050005050050055505550050005005555500005005055000000000000000000000000
07770000040004040900090905000505077700050555000000000000000500005550050000505000055555000555000005555050000000000000000000000000
05750000040000040900000905000005057500050050000005050500005050000050050000505000500000500050000000000000000000000000000000000000
00000000004444400099999000555550000000050000000050050050005050000055550055505550055555000000000005550000000000000000000000000000
00000000000000000000000000000000000000050000000000000000000000000000000000000000000000000000000000500000000000000000000000000000
00000000000000000000000000000000666000666666666666600066666666666660006666666666666000666666666666600066666666666660006666666666
5750eee05750eee057500ee00000ee00666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
7770e0e07770e0e07770e0000000e0e0555656565566666665565656555666655665556655666655565566565666665566555665566665566556655666666666
0000eee00000ee000000e0000000e0e0656656565656666656665656656666656565566566666655665656565666665656556656666656565666566666666666
0000e0e00000e0e00000e0000000e0e0656656565656666656665656656666655665666665666656665656565666665656566656666655565666566666666666
0000e0e07770eee077700ee07770ee00656665565656666665566556656666656566556556666665565656656666665566655665566656566556655666666666
00000000575000005750000057500000666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
00000000000000000000000000000000666666666666666666666666666666666666066666666666666666666666666666606666666666666666666666666666
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006000665666660000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000066660000006000000600600655666660000000000000000
66600660666066606660660066606060666066600000000000000000000280000008e00000056000000006000060600000060600555556660000000000000000
600060006000600060006060600060606000060000000000000000000022280000888e000055560000000600006060000606060065566566fff0fff000000000
66000060660066006600660066006660660006000000000000000000002222000088880000555500000000600060600000060600665665560000000000000000
60006600600060006000606060006660600006000000000000000000000220000008800000055000000000600600066000600600666555550000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006000666665560000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000666665660000000000000000
60060060666066606666000006000600000000000000000000000066000060000000000000000000000000000000000055655555555555555555555555555555
060606006060606060060000006060000666660000666660000006060000060000000000000000000000000000000000566555555ee556665666565656665666
0000000066606660606666000006000066000660006000600000066600000060066060600660666006600666666066006666655555e555565556565656555655
6600066000606000606006006660666006000600666660000006060606666666600060606000060006060060600066005665565555e556665566566656665666
0000000000060000666006000060600006666600066600000000600060666660006066606000060006060060660060605565566555e556555556555655565656
060606000060600000600600006060006000006000600000066666006006660066006060066006000660006060006660555666665eee56665666555656665666
60060060006060000066660066606660066666000000000060666000600060000000000000000000000000000000000055555665555555555555555555555555
00000000000000000000000000000000000000000000000060060000000000000000000000000000000000000000000055555655555555555555555555555555
__label__
00000ccc000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000060000000000000000000
b000606c000000000000000000000000000000000000000000500000000056000000000000000000005000000000000000500000006006000000000000000000
3b00606c00056000005566000ff00099000000000000000005550000000555600000000000000000055500000000000005550000000606000660660066606060
33b050500055560000555600090f040000000000fff0fff0000000000500550600000000fff0fff000000000fff0fff000000000060606006060606066000600
33305050005555000055550009900004000000000000000005550000050005050000000000000000055500000000000005550000000606006060606060000600
c3005050000550000055550009000440000000000000000000500000050000050000000000000000005000000000000000500000006006006600660060006060
c0005050000000000000000000000000000000000000000000000000005555500000000000000000000000000000000000000000000060000000000000000000
ccc00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
66660000555055500000000000000000000000000000600000000000000000000000000000000000000000000000000000000000000000000000000000000000
60060000505050500055550000066000005555000060060000000000066606600003b0005750eee0660055505550505055505000005555000055550000555500
606666005550555005575550000606000555755000060600000000000606006000333b007770e0e0060000500050505050005000055575500555555005555750
6060060000505000055555500006600005555550060606000000000006600060003333000000eee0060055500550555055505550055555500555555005555550
6660060000050000055555500006060005555550000606000000000006060060000330000000e0e0060050000050005000505050055555500555555005555550
0060060000505000055555500066060005555550006006000000000006660666000000000000e0e0666055505550005055505550055555500567555005555550
00666600005050000055550000660000005555000000600000000000000000000000000000000000000000000000000000000000005555000055550000555500
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00006000050005000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000600005050000055550000000000005555000000000000000000066606660003b0005750eee0660055505550505055505000005555000055550000555500
000000600005000005555550066060600555555006606660000000000606000600333b007770e0e0060000500050505050005000055555500555555005555550
0666666655505550055555506000606005755550600006000000000006600666003333000000eee0060055500550555055505550055557500555555005555550
6066666000505000055555500060666005555550600006000000000006060600000330000000e0e0060050000050005000505050055555500555555005555550
6006660000505000056755506600606005555550066006000000000006660666000000000000e0e0666055505550005055505550055555500567555005675550
60006000555055500055550000000000005555000000000000000000000000000000000000000000000000000000000000000000005555000055550000555500
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000066000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000606000000000055550000000000005555000000000000000000066600660003b0005750eee0660055505550505055505000005555000055550000555500
000006660000000005555550066006660555555066606600000000000606060000333b007770e0e0060000500050505050005000055557500555555005555550
0006060600000000055555500606006005755550600066000000000006600600003333000000eee0060055500550555055505550055555500555555005755550
0000600000000000057555500606006005555550660060600000000006060600000330000000e0e0060050000050005000505050055555500575555005555550
0666660000000000055555500660006005555550600066600000000006060066000000000000e0e0666055505550005055505550055555500555555005555550
60666000000000000055550000000000005555000000000000000000000000000000000000000000000000000000000000000000005555000055550000555500
60060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
06666666666666666666666666666666666666666660006666666666666000666666666666600066666666666660006666666666666000666666666666600066
65555655566556666555665666666666666666666606770666666666660677066666666666067706666666666606770666666666660677066666666666067706
65565655656556666565655666666666666666666066667066666666606666706666666660666670666666666066667066666666606666706666666660660670
60000600066006665565555566666666666666660666666606666666066666660666666606066666066666660666666606666666060666660666666606666666
60066600606006666666666666666666666666660666666606666666060666660666666606666666066666660666666606666666066666660666666606666666
60066600066000066005555666666666666666660666666606666666066666660666666606666666066666660666666606666666066666660666666606666666
66666666666666666000555666666666666666666056606066666666605666606666666660566660666666666056606066666666605666606666666660566660
66666666666666666666666666666666666666666605560666666666660556066666666666055606666666666605560666666666660556066666666666055606
65555666666666666666666666666666666666666660006666666666666000666666666666600066666666666660006666666666666000666666666666600066
65665666666556666665666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
65655556665555666655566666666666666666665556565655666666655656565556666556655566556666555655665656666655665556655666655665566556
65656656665665666665666666666666666666666566565656566666566656566566666565655665666666556656565656666656565566566666565656665666
65556656665665666666666666666666666666666566565656566666566656566566666556656666656666566656565656666656565666566666555656665666
66656656665665666655566666666666666666666566555656566666655655566566666565665565566666655656565566666655666556655666565665566556
66655556665555666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666660666666666666666666666666666666066666666666666666666
66000006660000066600000666000006660000066600000666000006660000066600000666000006660000066600000666000006660000066600000666000006
60666670606666706066667060666670606666706066667060666670606666706066667060666670606666706066667060666670606666706066667060666670
06666667066666670666666706666667066666670666666706666667066666670666666706666667066666670666666706666667066666670666666706666667
06666666066666660666666606666666066666660666666606666666066666660666666606666666066666660666666606666666066666660666666606666666
06666666066666660666666606666666066666660666666606666666066666660666666606666666066666660666666606666666066666660666666606666666
0665576606655766066228660665576606688e660665576606622866066228660665576606622866066557660662286606655766066557660665576606633b66
06655566066555660662226606655566066888660665556606622266066222660665556606622266066555660662226606655566066555660665556606633366
00666660006666600066666000666660006666600066666000666660006666600066666000666660006666600066666000666660006666600066666000666660
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
06665555066655550666555506665555066655550666555506665555066556560666565606665555066655550566565606665555056655550666555506665555
06555555065555550655555506555555065555550655555506555555065656660656566606555555065555550655566606555555065555550655555506555555
06655555066555550665555506655555066555550665555506655555065656660666566606655555066555550655566606655555065555550665555506655555
06555555065555550655555506555555065555550655555506555555065656560656565606555555065555550656565606555555065555550655555506555555
06555555065555550655555506555555065555550655555506555555066655550656555506555555065555550666555506555555056655550655555506555555
05555656055556560555565605555656055556660555565605555656055556560555566605555656055556560555565605555656055556660555565605555656
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
06666666666666666666666666666666666666666660006666666666666000666666666666600066666666666660006666666666666000666666666666600066
65555655566556666555665666666666666666666606770666666666660677066666666666067706666666666606770666666666660677066666666666067706
65565655656556666565655666666666666666666066667066666666606666706666666660666670666666666066657066666666606666706666666660666670
60000600066006665565555566666666666666660666666606666666060666660666666606666666066666660666665606666666065666660666666606666666
60066600606006666666666666666666666666660666666606666666066666660666666606066666066666660666666606666666065666660666666606066666
60066600066000066555005666666666666666660666666606666666066666660666666606666666066666660666666606666666066666660666666606666666
66666666666666666555000666666666666666666060666066666666605666606666666660566660666666666056666066666666605666606666666660566660
66666666666666666666666666666666666666666605560666666666660556066666666666055606666666666605560666666666660556066666666666055606
65555666666666666666666666666666666666666660006666666666666000666666666666600066666666666660006666666666666000666666666666600066
65665666666556666665666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
65655556665555666655566666666666666666665556565655666666655656565556666556655566556666555655665656666655665556655666655665566556
65656656665665666665666666666666666666666566565656566666566656566566666565655665666666556656565656666656565566566666565656665666
65556656665665666666666666666666666666666566565656566666566656566566666556656666656666566656565656666656565666566666555656665666
66656656665665666655566666666666666666666566555656566666655655566566666565665565566666655656565566666655666556655666565665566556
66655556665555666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666660666666666666666666666666666666066666666666666666666
66000006660000066600000666000006660000066600000666000006660000066600000666000006660000066600000666000006660000066600000666000006
60666670606666706066667060666670606666706066667060666670606666706066667060666670606666706066667060666670606666706066667060666670
06666667066666670666666706666667066666670666666706666667066666670666666706666667066666670666666706666667066666670666666706666667
06666666066666660666666606666666066666660666666606666666066666660666666606666666066666660666666606666666066666660666666606666666
06666666066666660666666606666666066666660666666606666666066666660666666606666666066666660666666606666666066666660666666606666666
06655766066557660664496606622866066557660662286606655766066557660664496606622866066557660665576606688e660665576606688e6606633b66
06655566066555660664446606622266066555660662226606655566066555660664446606622266066555660665556606688866066555660668886606633366
00666660006666600066666000666660006666600066666000666660006666600066666000666660006666600066666000666660006666600066666000666660
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
06665555066655550666555506665555066655550666555506665555066655550566565606665555066655550666555505665555066655550666555506665555
06555555065555550655555506555555065555550655555506555555065555550655566606555555065555550655555506555555065555550655555506555555
06655555066555550665555506655555066555550665555506655555066555550655566606655555066555550665555506555555066555550665555506655555
06555555065555550655555506555555065555550655555506555555065555550656565606555555065555550655555506555555065555550655555506555555
06555555065555550655555506555555065555550655555506555555065555550666555506555555065555550655555505665555065555550655555506555555
05555565055555650555556505555565055555650555556505555565055555650555556505555565055555650555556505555656055555650555556505555565
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
05555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
57755557755577555500005555000055555555555500005555000055555555555500005555000055555555555500005555000055555555555500005555000055
56065556065600555000000550000805555055555000000550000005555055555000080550000005555055555000080550000805555055555000000550000005
56565656565655555080000550000005555055555080000550800005555055555000000550800005555055555000000550000005555055555000000550800005
56605056605655555000000550000005555055555000000550000005555055555000000550000005555055555000000550000005555055555000080550000005
56055656065655555000000550000005555055555000000550000005555055555000000550000005555055555000000550000005555055555000000550000005
56555656565066555500005555000055555055555500005555000055555055555500005555000055555055555500005555000055555055555500005555000055
50555050505500555555555555555555555055555555555555555555555055555555555555555555555055555555555555555555555055555555555555555555
55555555555555555555555555555555555055555555555555555555555055555555555555555555555055555555555555555555555055555555555555555555
55555555555555555566655555665555555055555566655555665555555055555566655555665555555055555566655555665555555055555566655555665555
55555555555555555556566555656566555055555556566555656566555055555556566555656566555055555556566555656566555055555556566555656566
55555555555555555556565655656565555055555556565655656565555055555556565655656565555055555556565655656565555055555556565655656565
55555555555555555556565655665566555055555556565655665566555055555556565655665566555055555556565655665566555055555556565655665566
55555555555555555555555555555555555055555555555555555555555055555555555555555555555055555555555555555555555055555555555555555555
55555555555555555555555555555555555055555555555555555555555055555555555555555555555055555555555555555555555055555555555555555555
55555555555555555555555555555555555055555555555555555555555055555555555555555555555055555555555555555555555055555555555555555555
55555555555555555555555555555555555055555555555555555555555055555555555555555555555055555555555555555555555055555555555555555555
55555555555555555005500555000055555055555566566555000055555055555656565655000055555055555566565655000055555055555666566555000055
55555555555555555770577050000005555055555600560650000005555055555656565650000005555055555600566650800005555055555606506550800005
55555555555555555777575750000805555055555056565650000805555055555666566650800005555055555655500650000005555055555666556550000005
55555555555555555777575750000005555055555660566050000005555055555606560650000005555055555066566050000005555055555600566650000005
55555555555555555775577550000005555055555005500550000005555055555050505050000005555055555500500550000005555055555055500050000005
55555555555555555555555555000055555555555555555555000055555555555555555555000055555555555555555555000055555555555555555555000055
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55000005550000055500000555000005550000055500000555000005550000055500000555000005550000055500000555000005550000055500000555000005
50555560505555605055556050555560505555605055556050555560505555605055556050555560505555605055556050555560505555605055556050555560
05555556055555560555555605555556055555560555555605555556055555560555555605555556055555560555555605555556055555560555555605555556
05555555055555550555555505555555055555550555555505555555055555550555555505555555055555550555555505555555055555550555555505555555
05555555055555550555555505555555055555550555555505555555055555550555555505555555055555550555555505555555055555550555555505555555
05522855055667550556675505566755055667550554495505566755055228550556675505566755055228550556675505566755055667550556675505533b55
05522255055666550556665505566655055666550554445505566655055222550556665505566655055222550556665505566655055666550556665505533355
00555550005555500055555000555550005555500055555000555550005555500055555000555550005555500055555000555550005555500055555000555550

__map__
07e905ac0000c0c10000c000c0ec292a07e905ac0000c0c10000c000c0ec292a07e705ac00eec5c300eec5eec5ec292a0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
f2c785288527000009e0001726858585c6cb842884270000000026b717848484f2c784288427001726d00000008484840000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
f7c985f885f986e1eae4001826858585c7c884f884f90000000026b418848484f7c984f884f9001826d00000008484840000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000085fa85fb86e286e3001926858585cac984fa84fb0000000026b919848484000084fa84fb001926d00000008484840000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1c1b1aed02341e341e341e341e341e340c0ddfdf1d341e341e341e341e341e34000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
a2dfdf1d1dd4d5d6d7d8d9dadbdcddde1c1b1a021dd4d5d6d7d8d9dadbdcddde000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1010101010101010101010101010101010101010101010101010101010101010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
5555555555555555555555555555555555555555555555555555555555555555000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
a1a1a1beab959394ab959394ab9593940b0aa1a1977698769a769c769e76ae76000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0b0afc76977676769a7676769e767676fca1a1a1937693769376937693769376000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
a6a1a1a1987676769c767676ae767676a6fdfeff947694769476947694769476000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1313131313131313131313131313131313131313131313131313131313131313000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000b0aa1a1a1959394a1959394a1959394000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000fca1a1a1977676769a7676769e767676000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000a6fdfeff987676769c767676ae767676000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000013131313131313131313131313131313000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000001900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
