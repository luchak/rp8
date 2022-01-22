pico-8 cartridge // http://www.pico-8.com
version 34
__lua__
-- rp-8
-- by luchak

semitone=2^(1/12)

function log(a,b,c,d)
 local s=''
 for ss in all({a,b,c,d}) do
  s..=tostr(ss)..' '
 end
 printh(s,'log')
end

function copy_state()
 printh(state:save(),'@clip')
end

function paste_state()
 local pd=stat(4)
 if pd!='' then
  state=state_load(pd)
  seq_helper.state=state
 end
end

rec_menuitem=4
audio_rec=false
function start_rec()
 audio_rec=true
 menuitem(rec_menuitem, 'stop recording', stop_rec)
 extcmd'audio_rec'
end

function stop_rec()
 if (audio_rec) extcmd'audio_end'
 menuitem(rec_menuitem, 'start recording', start_rec)
end

function _init()
 cls()
 --extcmd('set_title', 'pb-0x')

 ui,state=ui_new(),state_new()

 header_ui_init(ui,0)
 pbl_ui_init(ui,'b0',32)
 pbl_ui_init(ui,'b1',64)
 pirc_ui_init(ui,'drum',96)

 pbl0,pbl1=synth_new(),synth_new()
 kick,snare,hh,cy,perc=
  sweep_new(unpack_split'0.092,0.0126,0.12,0.7,0.7,0.4'),
  snare_new(),
  hh_cy_new(unpack_split'1,0.8,0.75,0.35,-1,2'),
  hh_cy_new(unpack_split'1.3,0.5,0.5,0.18,0.3,0.8'),
  sweep_new(unpack_split'0.12,0.06,0.2,1,0.85,0.6')
 drum_mixer=submixer_new({kick,snare,hh,cy,perc})
 delay=delay_new(3000,0)

 mixer=mixer_new(
  {
   b0={obj=pbl0,lev=0.5,od=0.0,fx=0},
   b1={obj=pbl1,lev=0.5,od=0.5,fx=0},
   drum={obj=drum_mixer,lev=0.5,od=0.5,fx=0},
  },
  delay,
  1.0
 )
 comp=comp_new(mixer,unpack_split'0.5,4,0.05,0.005')
 seq_helper=seq_helper_new(
  state,comp,function()
   local tr,song,sq=
    state.transport,
    state.song,
    state.seq
   if (not tr.playing) return
   local now,nl=tr.tick,tr.note_len
   if (sq.b0.on) pbl0:note(state.b0,sq.b0,now,nl)
   if (sq.b1.on) pbl1:note(state.b1,sq.b1,now,nl)
   if sq.drum.on then
    kick:note(state.bd,sq.bd,now,nl)
    snare:note(state.sd,sq.sd,now,nl)
    hh:note(state.hh,sq.hh,now,nl)
    cy:note(state.cy,sq.cy,now,nl)
    perc:note(state.pc,sq.pc,now,nl)
   end
   local sm=sq.mixer
   mixer.lev=sm.lev*3
   delay.l=(0.9*sm.dl_t+0.1)*sample_rate
   delay.fb=sqrt(sm.dl_fb)*0.95

   local ms=mixer.srcs
   ms.b0.lev=sm.b0_lev
   ms.b1.lev=sm.b1_lev
   ms.drum.lev=sm.drum_lev*2
   ms.b0.od=sm.b0_od
   ms.b1.od=sm.b1_od
   ms.drum.od=sm.drum_od
   ms.b0.fx=sm.b0_fx^2*0.8
   ms.b1.fx=sm.b1_fx^2*0.8
   ms.drum.fx=sm.drum_fx^2*0.8
   comp.thresh=0.1+0.9*sm.comp_thresh

   state:next_tick()
  end
 )

 poke(0x5f36,(@0x5f36)|0x20)
 menuitem(1, 'save to clip', copy_state)
 menuitem(2, 'load from clip', paste_state)
 menuitem(3, 'clear seq', function()
  state=state_new()
  seq_helper.state=state
 end)
 menuitem(rec_menuitem, 'start recording', start_rec)
 menuitem(5, 'toggle output lpf', function() poke(0x5f36,(@0x5f36)^^0x20) end)

 log'init complete'
end

-- give audio time to settle
-- before starting synthesis
init_wait_frames=6
function _update60()
 audio_update()
 if init_wait_frames<=0 then
  ui:update(state)
  audio_set_root(seq_helper)
 else
  init_wait_frames-=1
 end
end

function _draw()
 ui:draw(state)

 --rectfill(0,0,30,6,0)
 --print(stat(0),0,0,7)
 palt(0,false)
end

-->8
-- utils

function pick(t,keys)
 local r={}
 for k in all(keys) do
  r[k]=t[k]
 end
 return r
end

function die(msg)
 assert(false,msg)
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

function is_empty(t)
 for _ in pairs(t) do
  return false
 end
 return true
end

function diff_tables(base,diff)
 for k,v in pairs(base) do
  local dk=diff[k]
  if type(v)=='table' and type(dk)=='table' then
   diff_tables(v,dk)
   if (is_empty(v)) base[k]=nil
  elseif dk then
   base[k]=nil
  end
 end
end

function stringify(v)
 local t=type(v)
 if t=='number' or t=='boolean' then
  return tostr(v)
 elseif t=='string' then
  return '"'..v..'"'
 elseif t=='table' then
  local s='{'
  for k,v in pairs(v) do
   s..=k..'='..stringify(v)..','
  end
  return s..'}'
 else
  die'unsupported type in stringify'
 end
end

function make_reader(s)
 local p,n=0,#s
 return function(inc)
  p+=inc or 1
  if (p>n) return ''
  return sub(s,p,p)
 end
end

function parse(s)
 return _parse(make_reader(s))
end

function is_digit(c)
 return (c>='0' and c<='9') or c=='.'
end

function is_whitespace(c)
 return c==' ' or c=='\n' or c=='\t'
end

-- this is super fragile
-- can easily hang the program!
-- make sure to always use
-- double quotes in serialized
-- data, single quotes will hang
function _parse(input)
 local c
 repeat
  c=input()
 until not is_whitespace(c)
 if c=='"' then
  local s=''
  repeat
   c=input()
   if (c=='"') return s
   s..=c
  until false
 elseif c=='-' or is_digit(c) then
  local s=c
  repeat
   c=input()
   local d=is_digit(c)
   if (d) s..=c
  until not d
  input(-1)
  return tonum(s)
 elseif c=='{' then
  local t={}
  repeat
   c=input()
   while is_whitespace(c) or c==',' do
    c=input()
   end
   if (c=='}') return t
   local k=c
   repeat
    c=input()
    if (c=='=') break
    k..=c
   until false
   k=tonum(k) or k
   t[k]=_parse(input)
  until false
 elseif c=='t' then
  input(3)
  return true
 elseif c=='f' then
  input(4)
  return false
 else
  die('cannot parse, c="'..c..'"')
 end
end

function unpack_split(s)
 return unpack(split(s))
end

function trn(c,t,f)
 return (c and t) or f
end

-->8
-- audio driver

-- at 5512hz/60fps, we need to
-- produce 92 samples a frame
-- 96 is just enough extra
-- to avoid jitter problems
-- on machines i have tested on
_schunk,_tgtchunks=96,1
_bufpadding,_chunkbuf=4*_schunk,{}
sample_rate=5512

function audio_set_root(obj)
 _root_obj=obj
end

function audio_dochunk()
 local buf=_chunkbuf
 if (_root_obj) _root_obj:update(buf,1,_schunk)
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

 while inbuf<bufsize do
  log'behind'
  audio_dochunk()
  newchunks+=1
  inbuf+=_schunk
 end

 -- always generate at least 1
 -- chunk if there is space
 -- and time
 if newchunks<_tgtchunks and inbuf<bufsize+_bufpadding and stat(1)<0.8 then
  audio_dochunk()
  inbuf+=_schunk
  newchunks+=1
 end
end
-->8
-- audio gen

--fir_coefs={0,0.0642,0.1362,0.1926,0.2139,0.1926,0.1362,0.0642}

function synth_new()
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

 obj.note=function(self,pat,par,step,note_len)
  local patstep=pat.steps[step]

  self.fc=(100/sample_rate)*(2^(4.25*par.cut))/self.os
  self.fr=par.res*4.1+0.1
  self.env=par.env*par.env+0.1
  self.acc=par.acc*1.9+0.1
  self.saw=par.saw
  local pd=par.dec-1
  if (patstep==n_ac or patstep==n_ac_sl) pd=-0.99
  self._med=0.999-0.01*pd*pd*pd*pd
  self._nt,self._nl=0,note_len
  self._lsl=self._sl
  self._gate=false
  self.detune=semitone^(flr(24*(par.tun-0.5)+0.5))
  self._ac=patstep==n_ac or patstep==n_ac_sl
  self._sl=patstep==n_sl or patstep==n_ac_sl
  if (patstep==n_off) return

  self._gate=true
  local f=55*(semitone^(pat.notes[step]+3))
  --ordered for numeric safety
  self.todp=(f/self.os)/(sample_rate>>8)

  if (self._ac) self.env+=par.acc
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
    if saw then
     osc=0.5-(osc>>1)
     osc*=osc
     osc=(osc<<1)-0.66667
    else
     local sq=(osc&0x8000)>>>14
     osc=sq*(osc-0.5)-osc+1
     local mask=osc>>31
     osc*=(mask^^osc)-mask
     -- osc -> osc
     -- 1-osc => sq-sq*osc => (1-sq)*(1-osc)+sq*osc => 1-sq-osc+2*sq*osc => 2*sq*(osc-0.5)-osc+1
     -- 1 if osc is negative, 0 if pos
    end
    local x=osc-fr*(f4-osc)
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
 end

 return obj
end

function sweep_new(_dp0,_dp1,ae_ratio,boost,te_base,te_scale)
 local obj=parse[[{
  op=0,
  dp=6553.6,
  ae=0.0,
  aemax=0.6,
  aed=0.995,
  ted=0.05,
  detune=1.0
 }]]

 obj.note=function(self,pat,par,step,note_len)
  local s=pat.steps[step]
  if s!=d_off then
   self.detune=2^(1.5*par.tun-0.75)
   self.op,self.dp=0,(_dp0<<16)*self.detune
   self.ae=par.lev*par.lev*boost*trn(s==d_ac,1.5,0.6)
   self.aemax=0.5*self.ae
   self.ted=0.5*((te_base-te_scale*par.dec)^4)
   self.aed=1-ae_ratio*self.ted
  end
 end

 obj.subupdate=function(self,b,first,last)
  local op,dp,dp1,ae,aed,ted=self.op,self.dp,_dp1*self.detune,self.ae,self.aed,self.ted
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
 
 obj.note=function(self,pat,par,step,note_len)
  local s=pat.steps[step]
  if s!=d_off then
   self.detune=2^(2*par.tun-1)
   self.op,self.dp=0,self.dp0*self.detune
   self.aes,self.aen=0.7,0.4
   if (s==d_ac) self.aes,self.aen=1.5,0.85
   self.aes+=(par.tun-0.5)*-0.2
   self.aen+=(par.tun-0.5)*0.2
   self.aes*=par.lev*par.lev
   self.aen*=par.lev*par.lev
   self.aemax=self.aes*0.5
   local pd4=(0.65-0.25*par.dec)^4
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

function hh_cy_new(_nlev,_tlev,dbase,dscale,tbase,tscale)
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
 
 obj.note=function(self,pat,par,step,note_len)
  local s=pat.steps[step]
  if s!=d_off then
   self.op,self.dp=0,self.dp0
   self.ae=par.lev*par.lev*trn(s==d_ac,2.0,0.8)

   self.detune=2^(tbase+tscale*par.tun)
   local pd4=(dbase-dscale*par.dec)
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

 for i=1,0x7fff do
  obj.dl[i]=0
 end

 obj.update=function(self,b,first,last)
  local dl,l,fb,p=self.dl,self.l,self.fb,self.p
  local f1=self.f1
  for i=first,last do
   local x,y=b[i],dl[p]
   if (abs(y) < 0.0001) y=0
   b[i]=y
   y=x+fb*y
   f1+=0.08*(y-f1)
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
    b[i]=0
    fxbuf[i]=0
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
-->8
-- state

-- a pattern has both top-level
-- and note-level data. all
-- synth params exist at top
-- level. (with note-level over-
-- rides?) notes are obviously
-- note level

n_off,n_on,n_ac,n_sl,n_ac_sl,d_off,d_on,d_ac=unpack_split'0,1,2,3,4,0,1,2'

save_keys=parse[[
{1="pats",2="pat_seq",3="song",}
]]

all_pats=split'b0,b1,drum'
all_synths=split'b0,b1,bd,sd,hh,cy,pc'
drum_synths=split'bd,sd,hh,cy,pc'
syn_groups=parse[[{
 bd="drum",
 sd="drum",
 hh="drum",
 cy="drum",
 pc="drum",
 b0="b0",
 b1="b1",
}]]

-- patterns:
--  saved
--  changes applied instantly
--  not used directly
--  same in song/pat mode
-- transport:
--  not saved
-- seq:
--  saved
--  applies to pattern mode
-- [synth states]:
--  present directly on seq
--  not saved
--  applies to pattern mode
-- song:
--  saved
--  applies to song mode
--
-- move pat idx to mixer
-- and access indirectly?
-- how to store next pat? 
--
-- messages stored in a buffer
-- applied on note? or immediate?
-- 
-- knob changes should be
-- visible immediately
--
-- in song mode, accumulate
-- controls into "record buffer"
-- apply various parts of that
-- as necessary
--
-- bar/note functions both
-- update the current seq
-- from the song and update the
-- record buffer as necessary

function state_new(savedata)
 local s=parse[[{
  pats={},
  transport={
   bar=1,
   tick=1,
   playing=false,
   recording=false,
   base_note_len=750,
   note_len=750,
   drum="bd",
   b0_bank=1,
   b1_bank=1,
   drum_bank=1,
   b0_next=1,
   b1_next=1,
   drum_next=1
  },
  song={
   song_mode=false,
   loop_start=1,
   loop_len=4,
   looping=true,
   bar_seqs={},
   default_seq={},
  },
  pending={
   bar={},
   tick={}
  },
  pat_seq={},
  seq={}
 }]]

 -- to fill:
 -- pat_seq
 -- song.default_seq
 -- seq
 
 -- seq-typed things:
 --  pending
 --  pat_seq
 --  seq
 --  song.bar_seqs[x][y]

 -- format of song.bar_seqs:
 -- bar_seqs[x][y] ->
 --  tick y at bar x
 -- only tick 1 should have
 -- pattern changes
 --
 -- these bar seqs are fragments
 -- applied onto default_seq

 s.seq=seq_new()
 s.pat_seq=seq_new()
 s.song.default_seq=seq_new()
 if (savedata) merge_tables(s,pick(savedata,save_keys))

 s.toggle_playing=function(self)
  local t=s.transport
  if t.playing then
   if (t.recording) self:toggle_recording()
   t.tick=1
  end
  t.playing=not t.playing
 end

 s.toggle_recording=function(self)
  local t=s.transport
  t.recording=(not t.recording) and s.song.song_mode
  if not t.recording then
   self:_reset_pending()
  end
 end

 s.toggle_song_mode=function(self)
  local song=s.song
  if (self.transport.playing) self:toggle_playing()
  song.song_mode=not song.song_mode
  self:_init_bar()
 end

 s._init_bar=function(self)
  local song=self.song
  local t=self.transport
  t.tick=1
  if song.song_mode then
   if t.recording then
    self:_apply_pending(true,true)
   end
   self.seq=merge_tables(
    song.default_seq,
    self:_get_song_seq(t.bar,1),
    true
   )
  else
   self:_apply_pending(true)
   self.seq=copy_table(self.pat_seq)
  end

  for syn,group in pairs(syn_groups) do
   self:_sync_pat(group,syn)
  end

  self:_init_tick()
 end

 s._sync_pat=function(self,pat_syn,syn)
  -- todo: just synthesize these on
  -- load? can we avoid saving
  -- them in that case?
  local syn_pats=self.pats[syn]
  if not syn_pats then
   syn_pats={}
   self.pats[syn]=syn_pats
  end
  assert(self.seq[pat_syn],pat_syn)
  local pat_idx=self.seq[pat_syn].pat
  local pat=syn_pats[pat_idx]
  if not pat then
   if (syn=='b0' or syn=='b1') pat=pbl_pat_new() else pat=drum_pat_new()
   syn_pats[pat_idx]=pat
  end
  self[syn]=pat
 end

 s._get_song_seq=function(self,bar,step,create)
  local bar_seqs=self.song.bar_seqs[bar]
  if not bar_seqs then
   bar_seqs={}
   if (create) self.song.bar_seqs[bar]=bar_seqs
  end
  local seq=bar_seqs[step]
  if not seq then
   seq={}
   if (create) bar_seqs[step]=seq
  end
  return seq
 end

 s._reset_pending=function(self)
  self.pending={bar={},tick={}}
 end

 s._apply_pending=function(self,apply_bar,keep)
  local song_mode,t=self.song.song_mode,self.transport
  local target,pending=self.pat_seq,self.pending
  if (song_mode) target=self:_get_song_seq(t.bar,t.tick,true)
  assert(target, 'apply target not found')
  if apply_bar then
   merge_tables(pending.bar, pending.tick)
   merge_tables(target, pending.bar)
   if song_mode then
    for i=2,16 do
     diff_tables(self:_get_song_seq(t.bar,i),pending.bar)
    end
   end
   if (not keep) self:_reset_pending()
   pending.tick={}
  else
   merge_tables(target, pending.tick)
   -- need to clear anything automated that's in bar but not in tick
   if (not keep) pending.tick={}
  end
 end

 s.go_to_bar=function(self,bar)
  assert(self.song.song_mode, 'navigation outside of song mode')
  local t=self.transport
  t.bar=mid(1,bar,999)
  t.tick=1
  self:_init_bar()
 end

 s.next_tick=function(self)
  local song,t=self.song,self.transport
  t.tick+=1

  -- dump pending changes if we're
  -- not recording
  if (song.song_mode and not t.recording) self:_reset_pending()

  if t.tick>16 then
   -- end of bar
   if song.song_mode then
    -- next bar
    local bar=t.bar+1
    if t.playing and song.looping and bar==song.loop_start+song.loop_len then
     -- clear pending before
     -- go_to_bar so we don't
     -- apply changes on loop
     self:_reset_pending()
     bar=song.loop_start
    end
    self:go_to_bar(bar)
   else
    -- pattern mode, re-init pattern bar
    self:_init_bar()
   end
  else
   -- same bar
   self:_apply_pending(false,t.recording)
   if song.song_mode then
    merge_tables(
     self.seq,
     self:_get_song_seq(t.bar,t.tick)
    )
   end
   self:_init_tick()
  end

 end

 s._init_tick=function(self)
  local t,m=self.transport,self.seq.mixer
  local nl=sample_rate*(15/(56+128*m.tempo))
  local shuf_diff=nl*m.shuf*(0.5-(t.tick&1))
  t.note_len,t.base_note_len=
   flr(0.5+nl+shuf_diff),nl
 end

 s._apply_diff=function(self,cat,diff)
  local t,song,pending=self.transport,self.song,self.pending
  if (cat=='tick') merge_tables(self.seq,diff)
  merge_tables(pending[cat],diff)
  if (not t.playing) and (t.recording or not song.song_mode) then
   self:_apply_pending(true,t.recording)
   -- pick up new changes
   self:_init_bar()
  end
 end

 s.get_pat=function(self,syn)
  -- assume pats are aliased, always editing current
  if (syn=='drum') syn=self.transport.drum
  return self[syn]
 end

 s.set_bank=function(self,syn,bank)
  self.transport[syn..'_bank']=bank
 end

 s.save=function(self)
  return 'rp80'..stringify(pick(self,save_keys))
 end

 s.cut_seq=function(self)
  self:copy_seq()
  local song=self.song
  local bs,ls,ll,nbs=
   song.bar_seqs,
   song.loop_start,
   song.loop_len,
   {}
  for i,b in pairs(bs) do
   if i>=ls then
    if i>=ls+ll then
     nbs[i-ll]=b
    end
   else
    nbs[i]=b
   end
  end
  song.bar_seqs=nbs
  self:_init_bar()
 end

 s.copy_seq=function(self)
  local c,song={},self.song
  if song.song_mode then
   for i=1,song.loop_len do
    local bar=i+song.loop_start-1
    c[i]={
     merge_tables(song.default_seq,self:_get_song_seq(bar,1),true)
    }
    for j=2,16 do
     local tick_seq=(song.bar_seqs[bar] or {})[j]
     if (tick_seq) c[i][j]=copy_table(tick_seq)
    end
   end
  else
   c[1]={
    copy_table(self.seq)
   }
  end
  copy_buf_seq=c
 end

 s.paste_seq=function(self)
  if (not copy_buf_seq) return
  local song,n=self.song,#copy_buf_seq
  if song.song_mode then
   for i=0,song.loop_len-1 do
    local bar=song.loop_start+i
    song.bar_seqs[bar]=copy_table(copy_buf_seq[i%n+1])
   end
  else
   self.pat_seq=copy_table(copy_buf_seq[1][1])
  end
  self:_init_bar()
 end

 s.insert_seq=function(self)
  local song=self.song
  local bs,ls,ll,nbs=
   song.bar_seqs,
   song.loop_start,
   song.loop_len,
   {}
  for i,b in pairs(bs) do
   if i>=ls then
    nbs[i+ll]=b
   else
    nbs[i]=b
   end
  end
  song.bar_seqs=nbs
  self:paste_seq()
 end

 s._init_bar(s)
 return s
end

function state_load(str)
 if (sub(str,1,4)!='rp80') return nil
 return state_new(parse(sub(str,5)))
end

seq_proto=parse[[{
 mixer={
  tempo=0.5,
  shuf=0,
  lev=0.5,
  dl_t=0.5,
  dl_fb=0.5,
  b0_lev=0.5,
  b0_od=0,
  b0_fx=0,
  b1_lev=0.5,
  b1_od=0,
  b1_fx=0,
  drum_lev=0.5,
  drum_od=0,
  drum_fx=0,
  comp_thresh=1.0,
 },
 b0={
  on=true,
  pat=1,
  saw=true,
  tun=0.5,
  cut=0.5,
  res=0.5,
  env=0.5,
  dec=0.5,
  acc=0.5,
 },
 b1={
  on=true,
  pat=1,
  saw=true,
  tun=0.5,
  cut=0.5,
  res=0.5,
  env=0.5,
  dec=0.5,
  acc=0.5,
 },
 bd={
  tun=0.5,
  dec=0.5,
  lev=0.5,
 },
 sd={
  tun=0.5,
  dec=0.5,
  lev=0.5,
 },
 hh={
  tun=0.5,
  dec=0.5,
  lev=0.5,
 },
 cy={
  tun=0.5,
  dec=0.5,
  lev=0.5,
 },
 pc={
  tun=0.5,
  dec=0.5,
  lev=0.5,
 },
 drum={
  on=true,
  pat=1,
 }
}]]

function seq_new()
 return copy_table(seq_proto)
end

function pbl_pat_new()
 local pat={
  notes={},
  steps={},
 }

 for i=1,16 do
  pat.notes[i],pat.steps[i]=19,n_off
 end

 return pat
end

function transpose_pat(pat,d)
 for i=1,16 do
  pat.notes[i]=mid(0,pat.notes[i]+d,35)
 end
end

function drum_pat_new()
 local pat={
  steps={},
 }

 for i=1,16 do
  pat.steps[i]=n_off
 end

 return pat
end

function state_make_get_set_param(cat,syn,key)
 if (not key) cat,syn,key='tick',cat,syn
 return
  function(state) return state.seq[syn][key] end,
  function(state,val) state:_apply_diff(cat, {[syn]={[key]=val}}) end
end

function state_make_get_set(a,b)
 return
  state_make_get(a,b),
  function(s,v) s[a][b]=v end
end

function state_make_get(a,b,c)
 return function(s) return s[a][b] end
end

state_is_song_mode=state_make_get('song','song_mode')

-- passthrough audio generator
-- that splits blocks to allow
-- for sample-accurate note
-- triggering
function seq_helper_new(state,root,note_fn)
 return {
  state=state,
  root=root,
  note_fn=note_fn,
  t=state.transport.note_len,
  update=function(self,b,first,last)
   local p,nl=first,self.state.transport.note_len
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
   if (not self.state.transport.playing) self.t=0
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
    rectfill(wx,wy,wx+tw,wy+7,bg)
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
   return 64+state:get_pat(syn).notes[step]
  end,
  input=function(self,state,b)
   local n=state:get_pat(syn).notes
   n[step]=mid(0,35,n[step]+b)
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
   local t=state.transport
   if (t.playing and t.tick==step) return sprites[n+1]
   local v=state:get_pat(syn).steps[step]
   return sprites[v+1]
  end,
  input=function(self,state,b)
   local st=state:get_pat(syn).steps
   st[step]+=b
   st[step]=(st[step]+n)%n
  end
 }
end

function dial_new(x,y,s0,bins,get,set)
 bins-=0x0.0001
 return {
  x=x,y=y,
  get_sprite=function(self,state)
   return s0+get(state)*bins
  end,
  input=function(self,state,b)
   local x=mid(0,1,get(state)+trn(b>0,0.015625,-0.015625))
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

function pat_btn_new(x,y,syn,bank_size,pib,s_off,s_on,s_next)
 local get_bank=state_make_get('transport',syn..'_bank')
 local get_pat,set_pat=state_make_get_set_param('bar',syn,'pat')
 return {
  x=x,y=y,w=5,
  get_sprite=function(self,state)
   local bank,pat=get_bank(state),get_pat(state)
   local pending=state.pending.bar
   pending=pending and pending[syn] and pending[syn].pat
   local val=(bank-1)*bank_size+pib
   if (pending==val and pending!=pat) return s_next
   return trn(pat==val,s_on,s_off)
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
   if state.song.song_mode then
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

function pbl_ui_init(ui,key,yp)
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
  momentary_new(16,yp+8,26,function(state,b)
   transpose_pat(state[key],b)
  end)
 )
 ui:add_widget(
  momentary_new(0,yp+8,28,function(state,b)
   copy_buf_pbl=merge_tables({},state[key])
  end)
 )
 ui:add_widget(
  momentary_new(8,yp+8,27,function(state,b)
   local v=copy_buf_pbl
   if (v) merge_tables(state[key],v)
  end)
 )

 for k,x in pairs(parse[[{
  tun=40,
  cut=56,
  res=72,
  env=88,
  dec=104,
  acc=120
 }]]) do
  ui:add_widget(
   dial_new(
    x,yp,43,21,
    state_make_get_set_param(key,k)
   )
  )
 end

 ui:add_widget(
  toggle_new(16,yp,2,3,state_make_get_set_param(key,'saw'))
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
  bd={x=16,s=150},
  sd={x=40,s=152},
  hh={x=64,s=154},
  cy={x=88,s=156},
  pc={x=112,s=158}
 }]]) do
  ui:add_widget(
   radio_btn_new(d.x,yp+16,k,d.s,d.s+1,state_make_get_set('transport','drum'))
  )
  ui:add_widget(
   dial_new(d.x+8,yp+16,100,12,state_make_get_set_param(k,'lev'))
  )
  ui:add_widget(
   dial_new(d.x,yp,100,12,state_make_get_set_param(k,'tun'))
  )
  ui:add_widget(
   dial_new(d.x+8,yp,100,12,state_make_get_set_param(k,'dec'))
  )

  ui:add_widget(
   momentary_new(0,yp+16,11,function(state,b)
    local v={}
    for syn in all(drum_synths) do
     v[syn]=copy_table(state[syn])
    end
    copy_buf_pirc=v
   end)
  )
  ui:add_widget(
   momentary_new(8,yp+16,10,function(state,b)
    local b=copy_buf_pirc
    if b then
     for k,v in pairs(b) do
      merge_tables(state[k],v)
     end
    end
   end)
  )

 end
 map(0,8,0,yp,16,4)
end

function header_ui_init(ui,yp)
 local function hdial(x,y,p)
 ui:add_widget(
  dial_new(x,yp+y,116,12,state_make_get_set_param('mixer',p))
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
   state_make_get('transport','playing'),
   function(s) s:toggle_playing() end
  )
 )
 ui:add_widget(
  toggle_new(
   24,yp,142,143,
   state_is_song_mode,
   function(s) s:toggle_song_mode() end
  )
 )
 song_only(
  toggle_new(
   8,yp,231,232,
   state_make_get('transport','recording'),
   function(s) s:toggle_recording() end
  ),
  233
 )
 song_only(
  momentary_new(
   16,yp,5,
   function()
    state:go_to_bar(trn(state.song.looping,state.song.loop_start,1))
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
  1="16,8,tempo",
  2="32,8,lev",
  3="32,16,comp_thresh",
  4="16,16,shuf",
  5="16,24,dl_t",
  6="32,24,dl_fb",
 }]]) do
  hdial(unpack_split(s))
 end

 for pt,ypc in pairs(parse[[{b0=8,b1=16,drum=24}]]) do
  ypc+=yp
  ui:add_widget(
   toggle_new(64,ypc,22,38,state_make_get_set_param('bar',pt,'on'))
  )
  hdial(104,ypc,pt..'_lev')
  hdial(112,ypc,pt..'_od')
  hdial(120,ypc,pt..'_fx')

  ui:add_widget(
   spin_btn_new(72,ypc,split'208,209,210,211',state_make_get_set('transport',pt..'_bank'))
  )
  for i=1,6 do
   ui:add_widget(
    pat_btn_new(75+i*4,ypc,pt,6,i,127+i,133+i,163+i)
   )
  end
 end
 ui:add_widget(
  transport_number_new(32,yp,unpack_split'16,transport,bar')
 )
 song_only(
  momentary_new(48,yp,192,
   function(state,b)
    state:go_to_bar(state.transport.bar+b)
   end
  ),
  197
 )
 song_only(
  toggle_new(56,yp,193,194,state_make_get_set('song','looping')),
  195
 )
 ui:add_widget(
  transport_number_new(64,yp,unpack_split'16,song,loop_start')
 )
 song_only(
  momentary_new(80,yp,192,
   function(state,b)
    local s=state.song
    local ns=s.loop_start+b
    s.loop_start=mid(1,ns,999)
    s.loop_len=mid(1,s.loop_len,1000-ns)
   end
  ),
  197
 )
 ui:add_widget(
  transport_number_new(88,yp,unpack_split'8,song,loop_len')
 )
 song_only(
  momentary_new(96,yp,192,
   function(state,b)
    local s=state.song
    s.loop_len=mid(1,s.loop_len+b,1000-s.loop_start)
   end
  ),
  197
 )

 -- last 0 should be yp
 map(unpack_split'32,0,0,0,16,4')
end

__gfx__
0000000000000ccc6666666666666666000000000000000000000000000000000000000000000000555555555666655506666666666666666666666600000000
000000000000000c655566566555665600000000006000606000f0f0b00060600777707700077770555665555655655565555655566556666666666600000000
007007000000000c656565566565655600000000006005505600f0f03b0060600770707700077070556666555656666565565655656556666666666600000000
0007700000000000556555555565555500000000005055505560909033b050500777707777077770556556555656556560000600066006666666666600000000
00077000000000006666666666666666000000000050555055509090333050500660006606066060556556555666556560066600606006666666666600000000
00700700c00000006005555665550056000000000050055055009090330050500660006606000600556556555556556560066600066000066666666600000000
00000000c00000006000555665550006000000000050005050009090300050500660006666066060556666555556666566666666666666666666666600000000
00000000ccc000006666666666666666000000000000000000000000000000000000000000000000555555555555555566666666666666666666066600000000
66000006660000066600000655000005550000055500000500000000000000000000000000000000666666666666666665555666666666666666666666666660
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
05555565055555650555556505555565055555650555556505555565055555650555556505555565055555650555556505555656055556560555565605555656
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
06665555066655550666565605665555056656560666555506665656066655550566555505665656066555550665565606665555066655550666565605665555
06555555065555550655566606555555065556660656555506565666065655550655555506555666065655550656566606555555065555550655566606555555
06655555066555550665566606555555065556660666555506665666066555550655555506555666065655550656566606655555066555550665566606555555
06555555065555550655565606565555065656560656555506565656065655550655555506555656065655550656565606555555065555550655565606565555
06665555065555550655555506665555066655550656555506565555066655550566555505665555066655550666555506665555065555550655555506665555
05555656055556560555565605555656055556560555565605555656055556560555566605555666055556660555566605555666055556660555566605555666
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
05665656066655550666565606665555550000555500005555000055550000555500005555000055550000555500005555000055550000555500005555000055
06555666065655550656566606565555500000055000000550000005500000055080000550080005500080055000080550000005500000055000000550000005
06555666066655550666566606655555500000055000000550000005508000055000000550000005500000055000000550000805500000055000000550000005
06565656065655550656565606565555500000055000000550800005500000055000000550000005500000055000000550000005500008055000000550000005
06665555065655550656555506665555502800055080000550000005500000055000000550000005500000055000000550000005500000055000080550008205
05555666055556660555566605555666550000555500005555000055550000555500005555000055550000555500005555000055550000555500005555000055
00000000000000000000000000000000555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000005555000055550000555500005555000055550000555500005555000055550000555500005555000055550000555500
06606060066066600660066666606600055555500555555005555550055555500575555005575550055575500555575005555550055555500555555005555550
60006060600006000606006060006600055555500555555005555550057555500555555005555550055555500555555005555750055555500555555005555550
00606660600006000606006066006060055555500555555005755550055555500555555005555550055555500555555005555550055557500555555005555550
66006060066006000660006060006660056755500575555005555550055555500555555005555550055555500555555005555550055555500555575005557650
00000000000000000000000000000000005555000055550000555500005555000055550000555500005555000055550000555500005555000055550000555500
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000055555555555555550000000000000000
05500000055500000555000005050000055500000500000006600000066600000666000006060000066600000600000056665665500050050000000000000000
00500000000500000005000005050000050000000500000000600000000600000006000006060000060000000600000056065006577757700ff00099099000ff
0050000005550000005500000555000005550000055500000060000006660000006600000666000006660000066600005666565057075057090f040004090900
00500000050000000005000000050000000500000505000000600000060000000006000000060000000600000606000056005666577757000990000404400009
05550000055500000555000000050000055500000555000006660000066600000666000000060000066600000666000050555000575557770900044004000990
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000055555555555555550000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000055555555555555550000000000000000
55555555055555555555555555555555555555550000000055555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555577555577555775555666555556655550000000056655665500550055566566555005005565656565050505055665656550050505666566550005005
55505555560655560656005555565665556565660000000056665606577057705600560650775770565656565757575756005666507757075606506557775775
55505555565656565656555555565656556565650000000056665656577757575056565657505757566656665707570756555006575557775666556557075575
55505555566050566056555555565656556655660000000056605660577757575660566050075707560656065777577750665660570050075600566657775070
55505555560556560656555555555555555555550000000050055005577557755005500557755775505050505757575755005005557757755055500057555777
55505555565556565650665555555555555555550000000055555555555555555555555555555555555555555555555555555555555555555555555555555555
55505555505550505055005555555555555555550000000055555555555555555555555555555555555555555555555555555555555555555555555555555555
55505555555555550000000000000005000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
555055555555555500000000000000050ff000000fff00000fff00000f0f00000fff00000f000000000000000000000000000000000000000000000000000000
5550555555555555000000000000000500f00000000f0000000f00000f0f00000f0000000f000000000000000000000000000000000000000000000000000000
5550555555555555000000000000000500f000000fff000000ff00000fff00000fff00000fff0000000000000000000000000000000000000000000000000000
5550555555555555000000000000000500f000000f000000000f0000000f0000000f00000f0f0000000000000000000000000000000000000000000000000000
555055555555555500000000000000050fff00000fff00000fff0000000f00000fff00000fff0000000000000000000000000000000000000000000000000000
55505555555555550000000000000005000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
55505555555555550000000000000005000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
5550555500ccc0000000000000000000000000000000000000000000000000000000000000222200000000000000000000000000000000000000000000000000
555055550000c0000000000000000000000000000000000000000000000000000022220002888820000000000000000000000000000000000000000000000000
555055550000c000000000000000000000000000000000000000000000aaaa0009aaaa9009aaaa90000000000000000000000000000000000000000000000000
55505555000000000000000000000000000000000000000000999900009999000099990000999900000000000000000000000000000000000000000000000000
555055550000000000000000000000000000000000bbbb0003bbbb3003bbbb3003bbbb3003bbbb30000000000000000000000000000000000000000000000000
55505555c00000000000000000000000003333000033330000333300003333000033330000333300000000000000000000000000000000000000000000000000
55555555c0000000000000000033330003bbbb3003bbbb3003bbbb3003bbbb3003bbbb3003bbbb30000000000000000000000000000000000000000000000000
55555555ccc000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
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
0000e0e07770eee077700ee07770ee00656655565656666665565556656666656566556556666665565656556666665566655665566656566556655666666666
00000000575000005750000057500000666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
00000000000000000000000000000000666666666666666666666666666666666666066666666666666666666666666666606666666666666666666666666666
06666666066666660666666606666666055555550000000000000000000000000000000000000000000000000000000000006000000000000000000000000000
66766555667665556676665566666556557556660000000000000000000000000000000000000000000000000000000000600600000000000000000000000000
67776565677765656777656666666565577756560000000000000000000280000008e00000056000000000000000000000060600000000000000000000000000
666665556666655666666566666665655555566600000000000000000022280000888e000055560000000000000000000606060000000000fff0fff000000000
66666565666665656666656666666565555556560000000000000000002222000088880000555500000000000000000000060600000000000000000000000000
66666565677765556777665567776556555556560000000000000000000220000008800000055000000000000000000000600600000000000000000000000000
66666666667666666676666666766666555555550000000000000000000000000000000000000000000000000000000000006000000000000000000000000000
66666666666666666666666666666666555555550000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
60060060666066606666000006000600000000000000000000000066000060000000000000000000000000000000000000000000000000000000000000000000
06060600606060606006000000606000066666000066666000000606000006000000000000000000000000000000000000000000066000066600066600060600
00000000666066606066660000060000660006600060006000000666000000600000000000000000000000000000000000000000006000000600000600060600
66000660006060006060060066606660060006006666600000060606066666660000000000000000000000000000000000000000006000066600006600066600
00000000000600006660060000606000066666000666000000006000606666600000000000000000000000000000000000000000006000060000000600000600
06060600006060000060060000606000600000600060000006666600600666000000000000000000000000000000000000000000066600066600066600000600
60060060006060000066660066606660066666000000000060666000600060000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000060060000000000000000000000000000000000000000000000000000000000000000000000000000
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
080907008e0000c000c0c10000c000c007e9ff8e0000c0c10000c000c0ec292a07e7058e00eec5c300eec5eec5ec292a0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
782878271726782718267827192678277828782700000000c6cb26b717787878f2c778287827001726d00000007878780000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
787078717829782a7829782a7829782a7870787100000000c7c826b418787878f7c978707871001826d00000007878780000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
78727873d00000a3d00000a3d00000a37872787300000000cac926b919787878000078727873001926d00000007878780000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0c0d031d1d341e341e341e341e341e34e0dfdfdf1d341e341e341e341e341e34000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1c1b1a1d1dd4d5d6d7d8d9dadbdcddde1c1b1a021dd4d5d6d7d8d9dadbdcddde000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1010101010101010101010101010101010101010101010101010101010101010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
5555555555555555555555555555555555555555555555555555555555555555000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
91926767906767906767906767906767e4a1a1a1976798679a679c679e678c67000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
a1a19394a09394a09394a09394a09394a1a1a1a1936793679367936793679367000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0b0a9767b09867b09a67b09c67b09e67a1a1a1a1946794679467946794679467000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1313131313131313131313131313131313131313131313131313131313131313000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000001900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
