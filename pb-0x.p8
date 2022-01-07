pico-8 cartridge // http://www.pico-8.com
version 34
__lua__
-- pb-0x
-- by luchak

_maxcpu=0
_smoothcpu=-1
semitone=2^(1/12)

function copy_seq()
 printh(seq:save(seq),'@clip')
end

function paste_seq()
 local pd=stat(4)
 if (pd!='') then
  seq=seq_load(pd)
  seq_helper.seq=seq
 end
end

rec_menuitem=4
audio_rec=false
function start_rec()
 audio_rec=true
 menuitem(rec_menuitem, 'stop recording', stop_rec)
 extcmd('audio_rec')
end

function stop_rec()
 if (audio_rec) extcmd('audio_end')
 menuitem(rec_menuitem, 'start recording', start_rec)
end

function _init()
 cls()
 --extcmd('set_title', 'pb-0x')

 ui=ui_new()
 seq=seq_load([[
pb0x{pats={sd={1={lev=0.6094,dec=0.1875,tun=0.5,steps={1=0,2=0,3=0,4=0,5=2,6=0,7=0,8=0,9=0,10=1,11=0,12=1,13=2,14=0,15=0,16=0,},},2={tun=0.5,steps={1=0,2=0,3=0,4=0,5=0,6=0,7=0,8=0,9=0,10=0,11=0,12=0,13=0,14=0,15=0,16=0,},lev=0.5,dec=0.5,},},b0={1={cut=0.2968,acc=0.5,notes={1=19,2=19,3=31,4=14,5=15,6=19,7=22,8=19,9=19,10=19,11=19,12=19,13=19,14=26,15=19,16=19,},dec=0.3438,lev=0.5,res=0.5,saw=true,env=0.6406,steps={1=1,2=0,3=1,4=3,5=1,6=1,7=1,8=1,9=0,10=1,11=0,12=0,13=0,14=1,15=0,16=0,},},3={cut=0.5,acc=0.5,env=0.5,dec=0.5,notes={1=19,2=19,3=19,4=19,5=19,6=19,7=19,8=19,9=19,10=19,11=19,12=19,13=19,14=19,15=19,16=19,},res=0.5,saw=true,lev=0.5,steps={1=0,2=0,3=0,4=0,5=0,6=0,7=0,8=0,9=0,10=0,11=0,12=0,13=0,14=0,15=0,16=0,},},},b1={1={cut=0.2031,acc=0.5,notes={1=7,2=7,3=7,4=7,5=7,6=7,7=7,8=19,9=7,10=7,11=7,12=7,13=7,14=5,15=7,16=7,},dec=0.5,lev=0.5,res=0.8125,saw=false,env=0.5,steps={1=0,2=0,3=1,4=0,5=0,6=0,7=1,8=2,9=0,10=0,11=1,12=0,13=0,14=3,15=1,16=0,},},2={cut=0.5,acc=0.5,env=0.5,dec=0.5,notes={1=19,2=19,3=19,4=19,5=19,6=19,7=19,8=19,9=19,10=19,11=19,12=19,13=19,14=19,15=19,16=19,},res=0.5,saw=true,lev=0.5,steps={1=0,2=0,3=0,4=0,5=0,6=0,7=0,8=0,9=0,10=0,11=0,12=0,13=0,14=0,15=0,16=0,},},},cy={1={lev=0.5,dec=0.6406,tun=0.6875,steps={1=0,2=0,3=0,4=0,5=0,6=0,7=0,8=0,9=0,10=0,11=0,12=0,13=1,14=0,15=0,16=0,},},2={tun=0.5,steps={1=0,2=0,3=0,4=0,5=0,6=0,7=0,8=0,9=0,10=0,11=0,12=0,13=0,14=0,15=0,16=0,},lev=0.5,dec=0.5,},},bd={1={lev=0.5,dec=0.5,tun=0.5,steps={1=2,2=0,3=0,4=0,5=2,6=0,7=0,8=0,9=2,10=0,11=0,12=0,13=2,14=0,15=0,16=0,},},2={tun=0.5,steps={1=0,2=0,3=0,4=0,5=0,6=0,7=0,8=0,9=0,10=0,11=0,12=0,13=0,14=0,15=0,16=0,},lev=0.5,dec=0.5,},},pc={1={lev=0.3906,dec=0,tun=0.5781,steps={1=1,2=0,3=0,4=0,5=0,6=2,7=0,8=0,9=1,10=2,11=0,12=1,13=0,14=0,15=1,16=0,},},2={tun=0.5,steps={1=0,2=0,3=0,4=0,5=0,6=0,7=0,8=0,9=0,10=0,11=0,12=0,13=0,14=0,15=0,16=0,},lev=0.5,dec=0.5,},},hh={1={lev=0.4062,dec=0.6875,tun=0.4375,steps={1=0,2=0,3=2,4=0,5=0,6=0,7=2,8=1,9=0,10=0,11=2,12=0,13=0,14=0,15=2,16=0,},},2={tun=0.5,steps={1=0,2=0,3=0,4=0,5=0,6=0,7=0,8=0,9=0,10=0,11=0,12=0,13=0,14=0,15=0,16=0,},lev=0.5,dec=0.5,},},},song={loop_len=4,loop_start=1,},mixer={drum_fx=0.2969,b0_lev=0.4844,b0_od=0.5156,delay_time=0.2969,comp_thresh=0.4375,delay_fb=0.625,tempo=0.5,drum_lev=0.5469,lev=0.6562,b1_od=0,b1_lev=0.5468,b1_fx=0,b0_fx=0.625,drum_od=0.5156,shuffle=0.3125,},}
 ]])
 
 header_ui_init(ui,0)
 pbl_ui_init(ui,'b0',32)
 pbl_ui_init(ui,'b1',64)
 pirc_ui_init(ui,'drum',96)
 map(unpack_split('0,8,0,96,16,4'))
 map(unpack_split('0,0,0,0,16,4'))
 
 pbl0,pbl1=synth_new(),synth_new()
 kick,snare,hh,cy,perc=
  sweep_new(0.1008,0.0126,0.12,0.7,0.7,0.4),
  snare_new(),
  hh_cy_new(1,0.8,0.75,0.35,-1,2),
  hh_cy_new(1.3,0.5,0.5,0.18,0.3,0.8),
  sweep_new(0.12,0.06,0.2,1,0.85,0.6)
 drum_mixer=submixer_new({kick,snare,hh,cy,perc})
 delay=delay_new(nil,3000,0)

 mixer=mixer_new(
  {
   b0={obj=pbl0,lev=0.5,od=0.0,fx=0},
   b1={obj=pbl1,lev=0.5,od=0.5,fx=0},
   drum={obj=drum_mixer,lev=0.5,od=0.5,fx=0},
  },
  delay,
  1.0
 )
 comp=comp_new(mixer,0.5,4,0.05,0.005)
 seq_helper=seq_helper_new(
  seq,comp,function()
   local st,si,sv,sm=
    seq.transport,
    seq.internal,
    seq.view,
    seq.mixer
   if (not st.playing) return
   local now,nl=st.note,si.note_len
   if (sm.b0_on) pbl0:note(seq.b0,now,nl)
   if (sm.b1_on) pbl1:note(seq.b1,now,nl)
   if sm.drum_on then
    kick:note(seq.bd,now,nl)
    snare:note(seq.sd,now,nl)
    hh:note(seq.hh,now,nl)
    cy:note(seq.cy,now,nl)
    perc:note(seq.pc,now,nl)
   end
   mixer.lev=sm.lev*3
   delay.l=(0.9*sm.delay_time+0.1)*sample_rate
   delay.fb=sqrt(sm.delay_fb)*0.95

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
   
   seq_next_note(seq)
  end
 )
 
 menuitem(1, 'save to clip', copy_seq)
 menuitem(2, 'load from clip', paste_seq)
 menuitem(3, 'clear seq', function()
  seq=seq_new()
  seq_helper.seq=seq
 end)
 menuitem(rec_menuitem, 'start recording', start_rec)
 
 log('starting audio...')
 audio_init()
end

-- give audio time to settle
-- before starting synthesis
init_wait_frames=6
function _update60()
 audio_update()
 if init_wait_frames<=0 then
  if (not seq.transport.playing) then
   seq_next_bar(seq)
  end
  ui:update(seq)
  audio_set_root(seq_helper)
 else
  init_wait_frames-=1
 end
end

function _draw()
 ui:draw(seq)
 
 local cpu=stat(1)
 _maxcpu=max(cpu,_maxcpu)
 if (_smoothcpu<0) _smoothcpu=cpu
 _smoothcpu+=0.02*(cpu-_smoothcpu)
 --rectfill(0,0,30,6,0)
 --print(_smoothcpu,0,0,7)
 --print(stat(0),0,0,7)
 palt(0,false)
end

function getbin(v,l,h,n)
 return flr((v-l)/((h+0.0001)-l)*n)
end

-->8
-- utils

function newbuf(n)
 local b={}
 for i=1,n do
  b[i]=0
 end
 return b
end

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

function merge_tables(base,new)
 for k,v in pairs(new) do
  if type(v)=='table' then
   if type(base[k])=='table' then
    merge_tables(base[k],v)
   else
    base[k]=merge_tables({},v)
   end
  else
   base[k]=v
  end
 end
 return base
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
   s=s..k..'='..stringify(v)..','
  end
  return s..'}'
 end
 -- skip nil, functions, etc.
end

function make_reader(s)
 local p=0
 return function(undo)
  if undo then
   p-=1
  else
   p+=1
   return sub(s,p,p)
  end
 end
end

function parse(s)
 return _parse(make_reader(s))
end

function is_digit(c)
 return (c>='0' and c<='9') or c=='.' 
end

-- this is super fragile
-- can easily hang the program!
-- make sure to always use
-- double quotes in serialized
-- data, single quotes will hang
function _parse(input)
 repeat
  c=input()
 until c!=' ' and c!='\n'
 if c=='"' then
  local s=''
  repeat
   c=input()
   if (c=='"') return s
   s=s..c
  until c==''
 elseif c=='-' or is_digit(c) then
  local s=c
  repeat
   c=input()
   local d=is_digit(c)
   if (d) s=s..c
  until not d
  input{}
  return tonum(s)
 elseif c=='{' then
  local t={}
  repeat
   c=input()
   while c==' ' or c=='\n' or c==',' do
    c=input()
   end
   if (c=='}') return t
   local k=c
   repeat
    c=input()
    if (c=='=') break
    k=k..c
   until c==''
   k=tonum(k) or k
   t[k]=_parse(input)
  until c==''
 elseif c=='t' then
  for i=1,3 do input() end
  return true
 elseif c=='f' then
  for i=1,4 do input() end
  return false
 else
  assert(false, 'cannot parse, c='..c)
 end
end

function unpack_split(...)
 return unpack(split(...))
end

function log(s)
 printh(s,'log')
end

function trn(c,t,f)
 if (c) return t else return f
end
-->8
-- audio driver

-- at 5512hz/60fps, we need to
-- produce 92 samples a frame
-- 96 is just enough extra
-- to avoid jitter problems
-- on machines i have tested on
_schunk=96
_nchunk=4
_tgtchunks=1
_chunkbuf=newbuf(_schunk)
sample_rate=5512

function audio_init()
 _empty={}
 _full={}
 for i=0,_nchunk-1 do
  add(_empty,0x4300+i*_schunk)
 end
end

function audio_set_root(obj)
 _root_obj=obj
end

function audio_fillchunk()
 local n,c=_schunk,deli(_empty,1)
 local b,cm1=_chunkbuf,c-1
 if (_root_obj) _root_obj:update(b,1,n)
 local minx,maxx=32767,-32767
 for i=1,n do
  local x=mid(-1,b[i],1)
  x-=0.148148*x*x*x
  -- add dither to keep delay
  -- tails somewhat nicer
  -- also ensure that e(0) is
  -- on a half-integer value
  poke(cm1+i,flr((x<<7)+0.375+(rnd()>>2))+128)
 end

 add(_full,c)
end

function audio_sendchunk()
 local c=deli(_full,1)
 serial(0x808,c,_schunk)
 add(_empty,c)
end

function audio_update()
 local req,newchunks=stat(109)-stat(108),0
 local empty,full,n=_empty,_full,_schunk

 --assert(#empty+#full==_nchunk)
 while req>0 do
  if #full==0 then
   log('behind')
   audio_fillchunk()
   newchunks+=1
  end
  audio_sendchunk()
  req-=n
 end
 
 -- always generate at least 1
 -- chunk if there is space
 -- and time
 if newchunks<_tgtchunks and #empty>0 and stat(1)<0.8 then
  audio_fillchunk()
  newchunks+=1
 end 
end
-->8
-- audio gen

fc_min=120
fc_oct=4
fr_min=0.1
fr_rng=4.2-fr_min
env_oct=3.0
rise_inc=1/20
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
  saw=false,
  _fc=0,
  _f1=0,
  _f2=0,
  _f3=0,
  _f4=0,
  _up=0,
  _dn=0,
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
  _lsl=false,
  _lastdn={},
  _thisdn={}
 }]]

 for i=1,4 do
  obj._lastdn[i]=0
  obj._thisdn[i]=0
 end
 
 obj.note=function(self,pat,step,note_len)
  local patstep=pat.steps[step]

  self.fc=(fc_min/sample_rate)*(2^(fc_oct*pat.cut))/self.os
  self.fr=pat.res*pat.res*fr_rng+fr_min
  self.env=pat.env*pat.env+0.1
  self.acc=pat.acc*1.9+0.1
  self.saw=pat.saw
  local pd=pat.dec-1
  if (patstep==n_ac or patstep==n_ac_sl) pd=-0.99
  self._med=0.9994-0.0117*pd*pd*pd*pd
  self._nt=0
  self._nl=note_len
  self._ac=false
  self._lsl=self._sl
  self._sl=false
  self._gate=false
  if (patstep==n_off) return
  if (patstep==n_ac or patstep==n_ac_sl) self._ac=true
  if (patstep==n_sl or patstep==n_ac_sl) self._sl=true
 
  self._gate=true
  local f=55*(semitone^(pat.notes[step]+3))
  --ordered for numeric safety
  self.todp=((f/self.os)<<5)/sample_rate

  if (self._ac) self.env+=pat.acc
  if self._lsl then
   self.todpr=0.012
  else
   self.todpr=0.995
   self._mr=true
  end
  
  self._nt=0
 end
 
 obj.update=function(self,b,first,last)
  local odp,op=self.odp,self.op
  local todp,todpr=self.todp,self.todpr
  local f1,f2,f3,f4=self._f1,self._f2,self._f3,self._f4
  local fr,fcb=self.fr,self.fc
  local os,up,dn=self.os
  local ae,aed,me,med,mr=self._ae,self._aed,self._me,self._med,self._mr
  local env,saw,lev,acc,ovr=self.env,self.saw,self.lev,self.acc,self.ovr
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
    me+=rise_inc
    mr=not (me>0.99)
   else
    me*=med
   end
   odp+=todpr*(todp-odp)
   self._nt+=1
   for j=1,os do
    dn=0
    local osc=(op>>4)
    if not saw then
     osc=(osc>>2)+0.5+((osc&0x8000)>>15)
    end
    local x=osc-fr*(f4-osc)
    local xc=mid(-1,xc,1)
    x=xc+(x-xc)*0.9840
        
    f1+=(x-f1)*fc
    f2+=(f1-f2)*fc
    f3+=(f2-f3)*fc
    f4+=(f3-f4)*fc
  
    op+=odp
    if (op>16) op-=32
   end
   local out=f4*ae
   if (ac) out*=1+acc*me
   b[i]=out>>2
  end
  self.op,self.odp=op,odp
  self._f1,self._f2,self._f3,self._f4=f1,f2,f3,f4
  self._up,self._dn=up,dn
  self._me,self._ae,self._mr=me,ae,mr
  self._gate=gate
 end
 
 return obj
end

function sweep_new(_dp0,_dp1,ae_ratio,boost,te_base,te_scale)
 local obj=parse[[{
  op=0,
  dp=0.1,
  ae=0.0,
  aemax=0.6,
  aed=0.995,
  ted=0.05,
  detune=1.0
 }]]
 
 obj.note=function(self,pat,step,note_len)
  local s=pat.steps[step]
  if (s!=d_off) then
   self.detune=2^(1.5*pat.tun-0.75)
   self.op,self.dp=0,_dp0*self.detune
   self.ae=pat.lev*pat.lev*boost*trn(s==d_ac,1.5,0.6)
   self.aemax=0.5*self.ae
   self.ted=0.5*((te_base-te_scale*pat.dec)^4)
   self.aed=1-ae_ratio*self.ted
  end
 end
 
 obj.subupdate=function(self,b,first,last)
  local op,dp,dp1,ae,aed,ted=self.op,self.dp,_dp1*self.detune,self.ae,self.aed,self.ted
  local aemax,boost=self.aemax
  for i=first,last do
   op+=dp
   dp+=ted*(dp1-dp)
   ae*=aed
   if (op>=1) op-=1
   b[i]+=min(ae,aemax)*sin(op)
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
 
 obj.note=function(self,pat,step,note_len)
  local s=pat.steps[step]
  if (s!=d_off) then
   self.detune=2^(2*pat.tun-1)
   self.op,self.dp=0,self.dp0*self.detune
   self.aes,self.aen=0.7,0.4
   if (s==d_ac) self.aes,self.aen=1.5,0.85
   self.aes+=(pat.tun-0.5)*-0.2
   self.aen+=(pat.tun-0.5)*0.2
   self.aes*=pat.lev*pat.lev
   self.aen*=pat.lev*pat.lev
   self.aemax=self.aes*0.5
   local pd4=(0.65-0.25*pat.dec)^4
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
  op1=0.0,
  odp1=0.45,
  op2=0.0,
  odp2=0.52,
  op3=0.0,
  odp3=0.47,
  op4=0.0,
  odp4=0.485,
  aed=0.995,
  detune=1
 }]]
 
 obj.note=function(self,pat,step,note_len)
  local s=pat.steps[step]
  if (s!=d_off) then
   self.op,self.dp=0,self.dp0
   self.ae=pat.lev*pat.lev*trn(s==d_ac,2.0,0.8)
 
   self.detune=2^(tbase+tscale*pat.tun)
   local pd4=(dbase-dscale*pat.dec)
   pd4*=pd4*pd4*pd4
   
   self.aed=1-0.04*pd4
  end
 end
 
 obj.subupdate=function(self,b,first,last)
  local ae,f1=self.ae,self.f1
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
   f1+=0.9999*(r-f1)
   ae*=aed
   b[i]+=ae*((r-f1)<<10)
   op1+=odp1
   if (op1>1) op1-=2
   op2+=odp2
   if (op2>1) op2-=2
   op3+=odp3
   if (op3>1) op3-=2
   op4+=odp4
   if (op4>1) op4-=2
  end
  self.ae,self.f1=ae,f1
  self.op1,self.op2,self.op3,self.op4=op1,op2,op3,op4
 end
 
 return obj
end
-->8
-- audio fx

buf_max=sample_rate*4

function delay_new(src,l,fb)
 local obj={
  dl=newbuf(buf_max),
  p=1,
  src=src,
  l=l,
  fb=fb
 }
 
 obj.update=function(self,b,first,last)
  if (self.src) self.src:update(b,first,last)
  local dl,l,fb,p=self.dl,min(self.l,buf_max),self.fb,self.p
  for i=first,last do
 	 local x,y=b[i],dl[p]
 	 if (abs(y) < 0.0001) y=0
 	 b[i]=y
 	 y=x+fb*y
 	 dl[p]=y
 	 p+=1
 	 if (p>l) p=1
  end
  self.p=p
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
  tmp=newbuf(buf_max),
  fxbuf=newbuf(buf_max),
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
    local x=abs(b[i])+0.0001
    local c
    if (x>env) c=att else c=rel
    env+=c*(x-env)
    local g=makeup
    local te=thresh/env
    if (env>thresh) g*=te+ratio*(1-te)
    b[i]*=g
   end
   self.env=env
  end
 }
end
-->8
-- sequencer

-- a pattern has both top-level
-- and note-level data. all
-- synth params exist at top
-- level. (with note-level over-
-- rides?) notes are obviously
-- note level

n_off,n_on,n_ac,n_sl,n_ac_sl=0,1,2,3,4
d_off,d_on,d_ac=0,1,2

save_keys=parse[[
{1="pats",2="mixer",3="song",}
]]

all_synths=split('b0,b1,bd,sd,hh,cy,pc')
drum_synths=split('bd,sd,hh,cy,pc')

copy_bufs={}

function seq_new(savedata)
 local s=parse[[{
  pats={},
  transport={
   song_mode=false,
   bar=1,
   note=1,
   playing=false,
   recording=false
  },
  view={
   drum="bd",
   b0_next=1,
   b1_next=1,
   drum_next=1,
   b0_pat=1,
   b1_pat=1,
   drum_pat=1,
   b0_bank=1,
   b1_bank=1,
   drum_bank=1,
  },
  internal={
   base_note_len=750,
   note_len=750,
  },
  mixer={
   tempo=0.5,
   shuffle=0,
   lev=0.5,
   delay_time=0.5,
   delay_fb=0.5,
   bo_on=true,
   b0_lev=0.5,
   b0_on=0,
   b0_fx=0,
   b1_on=true,
   b1_lev=0.5,
   b1_od=0,
   b1_fx=0,
   drum_on=true,
   drum_lev=0.5,
   drum_od=0,
   drum_fx=0,
   comp_thresh=1.0
  },
  song={
   loop_start=1,
   loop_len=4,
   looping=true,
  }
 }]]
 if (savedata) merge_tables(s,pick(savedata,save_keys))


 s.get=function(self,syn,par)
  if (syn=='drum') syn=self.view[syn]
  return self[syn][par]
 end

 s.set=function(self,syn,par,v)
  if (syn=='drum') syn=self.view[syn]
  self[syn][par]=v
 end
 
 s.save=function(self)
  return 'pb0x'..stringify(pick(self,save_keys))
 end

 seq_next_bar(s)
 return s
end

function seq_get_or_create_pat(seq,syn,idx,factory)
 syn_pats=seq.pats[syn]
 if not syn_pats then
  syn_pats={}
  seq.pats[syn]=syn_pats
 end
 pat=syn_pats[idx]
 if not pat then
  pat=factory()
  syn_pats[idx]=pat
 end
 seq[syn]=pat
end

function seq_next_note(seq)
 local t=seq.transport
 t.note+=1
 if (t.note>16) seq_next_bar(seq)
 local nl=sample_rate*(15/(90+64*seq.mixer.tempo))
 local shuf_diff=nl*seq.mixer.shuffle*0.33
 if (t.note&1>0) shuf_diff=-shuf_diff
 seq.internal.note_len=flr(0.5+nl+shuf_diff)
 seq.internal.base_note_len=nl
end

function seq_next_bar(seq)
 local v=seq.view
 local b0n,b1n,dn=v.b0_next,v.b1_next,v.drum_next
 seq_get_or_create_pat(
  seq,'b0',b0n,pbl_pat_new
 )
 v.b0_pat=b0n
 seq_get_or_create_pat(
  seq,'b1',b1n,pbl_pat_new
 )
 v.b1_pat=b1n
 for drum in all(drum_synths) do
  seq_get_or_create_pat(
   seq,drum,v.drum_next,drum_pat_new
  )
 end
 v.drum_pat=v.drum_next
 if (seq.transport.song_mode and seq.transport.playing) seq.transport.bar+=1
 if (seq.song.looping and seq.transport.playing and seq.transport.bar==(seq.song.loop_start+seq.song.loop_len)) seq.transport.bar=seq.song.loop_start
 if (seq.transport.playing) seq.transport.note=1
end

function seq_load(str)
 if (sub(str,1,4)!='pb0x') return nil
 return seq_new(parse(sub(str,5)))
end

function pbl_pat_new()
 local pat=parse[[{
  saw=true,
  lev=0.5,
  cut=0.5,
  res=0.5,
  env=0.5,
  dec=0.5,
  acc=0.5,
  notes={},
  steps={}
 }]]
 
 for i=1,16 do
  pat.notes[i]=19
  pat.steps[i]=n_off
 end
 
 return pat
end

function transpose_pat(pat,d)
 for i=1,16 do
  pat.notes[i]=mid(0,pat.notes[i]+d,35)
 end
end 

function drum_pat_new()
 local pat=parse[[{
  tun=0.5,
  dec=0.5,
  lev=0.5,
  steps={}
 }]]
 
 for i=1,16 do
  pat.steps[i]=n_off
 end
 
 return pat
end

-- passthrough audio generator
-- that splits blocks to allow
-- for sample-accurate note
-- triggering
function seq_helper_new(seq,root,note_fn)
 return {
  seq=seq,
  root=root,
  note_fn=note_fn,
  t=seq.internal.note_len,
  update=function(self,b,first,last)
   local p,nl=first,self.seq.internal.note_len
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
 local obj={
  focus=nil,
  widgets={},
  sprites={},
  dirty={},
  holds={},
  by_tile={},
  has_tiles_x={},
  has_tiles_y={}
 }
 
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
    local t,tw,bg,fg=unpack_split(sp)
    t=tostr(t)
    rectfill(wx,wy,wx+tw,wy+7,bg)
    print(t,wx+tw-(#t*4),wy+1,fg)
   end
  end
  self.dirty={}
  local f=self.focus
  if (f==nil) return
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
   if (btn(b)) then
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

  local diffs={0,-1,1,-2,2}
  for db in all(diffs) do
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
  x=x,y=y,syn=syn,step=step,
  get_sprite=function(self,seq)
   local ns=seq:get(self.syn,'notes')
   local n=ns[self.step]
   return 64+n
  end,
  input=function(self,seq,b)
   local n,s=seq:get(self.syn,'notes'),self.step
   n[s]=mid(0,35,n[s]+b)
  end
 }
end

function spin_btn_new(x,y,syn,par,sprites)
 return {
  x=x,y=y,syn=syn,par=par,sprites=sprites,n=#sprites,
  get_sprite=function(self,seq)
   local v=seq:get(self.syn,self.par)
   return self.sprites[v]
  end,
  input=function(self,seq,b)
   local v=seq:get(self.syn,self.par)
   seq:set(self.syn,self.par,mid(1,v+b,self.n))
  end
 }
end

function step_btn_new(x,y,syn,step,sprites)
 return {
  x=x,y=y,syn=syn,step=step,sprites=sprites,n=#sprites-1,
  get_sprite=function(self,seq)
   if (seq.transport.playing and seq.transport.note==self.step) return self.sprites[self.n+1]
   local v=seq:get(self.syn,'steps')[self.step]
   return self.sprites[v+1]
  end,
  input=function(self,seq,b)
   local st,s=seq:get(self.syn,'steps'),self.step
   st[s]+=b
   st[s]=(st[s]+self.n)%self.n
  end
 }
end

function dial_new(x,y,syn,par,s0,bins)
 return {
  x=x,y=y,syn=syn,par=par,s0=s0,bins=bins-0.0001,
  get_sprite=function(self,seq)
   local x=seq:get(self.syn,self.par)
   return self.s0+x*self.bins
  end,
  input=function(self,seq,b)
   local x=seq:get(self.syn,self.par)
   x=mid(0,1,x+trn(b>0,0.015625,-0.015625))
   seq:set(self.syn,self.par,x)
  end
 }
end

function toggle_new(x,y,syn,par,s_off,s_on)
 return {
  x=x,y=y,syn=syn,par=par,s_on=s_on,s_off=s_off,
  get_sprite=function(self,seq)
   local x=seq:get(self.syn,self.par)
   return trn(x,self.s_on,self.s_off)
  end,
  input=function(self,seq)
   local x=seq:get(self.syn,self.par)
   seq:set(self.syn,self.par,not x)   
  end
 }
end

function momentary_new(x,y,s,cb)
 return {
  x=x,y=y,cb=cb,par=par,s=s,
  get_sprite=function(self,seq)
   return s
  end,
  input=function(self,seq,b)
   self.cb(seq,b)
  end
 }
end

function radio_btn_new(x,y,syn,par,val,s_off,s_on)
 return {
  x=x,y=y,syn=syn,par=par,val=val,s_on=s_on,s_off=s_off,
  get_sprite=function(self,seq)
   local x=seq:get(self.syn,self.par)
   return trn(x==self.val,self.s_on,self.s_off)
  end,
  input=function(self,seq)
   seq:set(self.syn,self.par,self.val)
  end
 }
end

function pat_btn_new(x,y,syn,bank_size,pib,s_off,s_on,s_next)
 return {
  x=x,y=y,syn=syn,
  par=syn..'_next',
  bank_par=syn..'_bank',
  last_par=syn..'_pat',
  s_off=s_off,s_on=s_on,
  s_next=s_next, pib=pib,
  w=5,
  get_sprite=function(self,seq)
   local bank=seq:get('view',self.bank_par)
   local x=seq:get('view',self.par)
   local xlast=seq:get('view',self.last_par)
   local val=(bank-1)*bank_size+self.pib
   if (x==val and xlast!=x) return self.s_next
   return trn(x==val,self.s_on,self.s_off)
  end,
  input=function(self,seq)
   local bank=seq:get('view',self.bank_par)
   local val=(bank-1)*bank_size+self.pib
   seq:set('view',self.par,val)
  end
 }
end

function transport_number_new(x,y,w,obj,key)
 return {
	 x=x,y=y,w=w,obj=obj,key=key,noinput=true,
	 get_sprite=function(self,seq)
	  if seq.transport.song_mode then
	   return tostr(seq:get(self.obj,self.key))..','..self.w..',0,15'
	  else
	   return '--,'..self.w..',0,15'
   end
  end,
  update=function() end
 }
end

function wrap_disable(w,syn,key,s_disable)
 local obj={
  get_sprite=function(self,seq)
   local enabled=seq:get(syn,key)
   if enabled then
    self.noinput=false
    return w:get_sprite(seq)
   else
    self.noinput=true
    return s_disable
   end
  end,
  update=function(self,seq,b)
   return w:input(seq,b)
  end,
 }
 w.__index=w
 setmetatable(obj,w)
 assert(w.x)
 assert(obj.update)
 assert(obj.x)
 return obj
end

function pbl_ui_init(ui,key,yp)
 for i=1,16 do
  local xp=(i-1)*8
  ui:add_widget(
   pbl_note_btn_new(xp,yp+24,key,i)
  )
  ui:add_widget(
   step_btn_new(xp,yp+16,key,i,split('16,17,33,18,34,32'))
  )
 end
 
 ui:add_widget(
  momentary_new(16,yp+8,26,function(seq,b)
   transpose_pat(seq[key],b)
  end)
 )
 ui:add_widget(
  momentary_new(0,yp+8,28,function(seq,b)
   copy_bufs['pbl']=merge_tables({},seq[key])
  end)
 )
 ui:add_widget(
  momentary_new(8,yp+8,27,function(seq,b)
   local v=copy_bufs['pbl']
   if (v) merge_tables(seq[key],v)
  end)
 )
 
 for k,x in pairs(parse[[{
  cut=48,
  res=64,
  env=80,
  dec=96,
  acc=112
 }]]) do
  ui:add_widget(
   dial_new(x,yp+0,key,k,43,21)
  )
 end

 ui:add_widget(
  toggle_new(16,yp+0,key,'saw',2,3)
 )
 
 map(0,4,0,yp,16,2)
end


function pirc_ui_init(ui,key,yp)
 for i=1,16 do
  local xp=(i-1)*8
  ui:add_widget(
   step_btn_new(xp,yp+24,key,i,split('19,21,20,35'))
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
   radio_btn_new(d.x,yp+16,'view','drum',k,d.s,d.s+1)
  )
  ui:add_widget(
   dial_new(d.x+8,yp+16,k,'lev',100,12)
  )
  ui:add_widget(
   dial_new(d.x,yp,k,'tun',100,12)
  )
  ui:add_widget(
   dial_new(d.x+8,yp,k,'dec',100,12)
  )

 end
 map(0,8,0,yp,16,4)
end

function header_ui_init(ui,yp)
 local function hdial(x,y,p)
 ui:add_widget(
  dial_new(x,yp+y,'mixer',p,116,12)
 )
 end
 
 local function song_only(w,s_disable)
  ui:add_widget(
   wrap_disable(w,'transport','song_mode',s_disable)
  )
 end

 ui:add_widget(
  toggle_new(16,yp,'transport','playing',6,7)
 )
 ui:add_widget(
  toggle_new(32,yp,'transport','song_mode',142,143)
 )
 song_only(
  toggle_new(24,yp,'transport','recording',231,232),
  233
 )
 hdial(0,8,'tempo')
 hdial(16,8,'lev')
 hdial(16,16,'comp_thresh')
 hdial(0,16,'shuffle')
 hdial(0,24,'delay_time')
 hdial(16,24,'delay_fb')

 for pt,xp in pairs({b0=32,b1=64,drum=96}) do
  ui:add_widget(
   toggle_new(xp+8,yp+8,'mixer',pt..'_on',22,38)
  )
  hdial(xp+16,8,pt..'_lev')
  hdial(xp,16,pt..'_od')
  hdial(xp+16,16,pt..'_fx')

  ui:add_widget(
   spin_btn_new(xp,yp+24,'view',pt..'_bank',{208,209,210,211})
  )
  for i=1,4 do
   ui:add_widget(
    pat_btn_new(xp+6+i*5,yp+24,pt,4,i,163+i,167+i,171+i)
   )
  end
 end
 ui:add_widget(
  transport_number_new(40,yp,16,'transport','bar')
 )
 song_only(
  momentary_new(56,yp,192,
   function(seq,b)
    seq.transport.bar=mid(1,seq.transport.bar+b,255)
   end
  ),
  197
 )
 ui:add_widget(
  transport_number_new(64,yp,8,'transport','note')
 )
 song_only(
  toggle_new(80,yp,'song','looping',193,194),
  195
 )
 ui:add_widget(
  transport_number_new(88,yp,16,'song','loop_start')
 )
 ui:add_widget(
  transport_number_new(112,yp,8,'song','loop_len')
 )
 
end

__gfx__
0000000000000ccc6666666666666666666666666666666600000000000000000000000000000000555555555555555506666666666666666666666600000000
000000000000000c655566566555665666666666666666666000f0f0b00060600777707700077770555555555555555565555655566556666666666600000000
007007000000000c6565655665656556662286666688e6665600f0f03b0060600770707700077070552285555588e55565565655656556666666666600000000
0007700000000000556555555565555566222666668886665560909033b050500777707777077770552225555588855560000600066006666666666600000000
00077000000000006666666666666666662226666688866655509090333050500660006606066060552225555588855560066600606006666666666600000000
00700700c00000006005555665550056666666666666666655009090330050500660006606000600555555555555555560066600066000066666666600000000
00000000c00000006000555665550006666666666666666650009090300050500660006666066060555555555555555566666666666666666666666600000000
00000000ccc000006666666666666666666666666666666600000000000000000000000000000000555555555555555566666666666666666666066600000000
66000006660000066600000655000005550000055500000500000000000000000000000000000000666666666666666665555666666666666666666666666660
60666670606666706066667050555560505555605055556000056000066606600666066606660066666566666665566665665666666666666666666666666666
06666667066666670666666705555556055555560555555600555600060600600606000606060600665556666655556665655556666666666666666666666666
06666666066666660666666605555555055555550555555500555500066000600660066606600600666566666656656665656656666666660666666606666666
06666666066666660666666605555555055555550555555500055000060600600606060006060600666666666656656665556656666666660666666606666666
06655766066228660664496605566755055228550554495500000000066606660666066606060066665556666656656666656656666666660666666606666666
06655566066222660664446605566655055222550554445500000000000000000000000000000000666666666655556666655556666666666666666666666666
00666660006666600066666000555550005555500055555000000000000000000000000000000000666666666666666666666666666666666666666666666666
66000006660000066600000655000005550000055500000500000000000060050000000000000000000000056660006666600066666000666660006666600066
6066667060666670606666705055556050555560505555600003b000006006050006600000000000000000056606770666067706660677066606770666067706
06666667066666670666666705555556055555560555555600333b00000606050006060006606600666060656066667060666670606666706066667060666670
06666666066666660666666605555555055555550555555500333300060606050006600060606060660006050666666606666666066666660666666606666666
06666666066666660666666605555555055555550555555500033000000606050006060060606060600006050666666606666666066666660656666606066666
06633b6606688e6606699a6605533b5505588e5505599a5500000000006006050066060066006600600060650666666606566666060666660656666606666666
06633366066888660669996605533355055888550559995500000000000060050066000000000000000000056060666060656660606666606066666060566660
00666660006666600066666000555550005555500055555000000000000000050000000000000000000000056605560666055606660556066605560666055606
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
00000000000000050000000000000005000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000050000000000000005005555000055550000555500005555000055550000555500005555000055550000555500005555000055550000555500
06606060066066650660066666606605055555500555555005555550055555500575555005575550055575500555575005555550055555500555555005555550
60006060600006050606006060006605055555500555555005555550057555500555555005555550055555500555555005555750055555500555555005555550
00606660600006050606006066006065055555500555555005755550055555500555555005555550055555500555555005555550055557500555555005555550
66006060066006050660006060006665056755500575555005555550055555500555555005555550055555500555555005555550055555500555575005557650
00000000000000050000000000000005005555000055550000555500005555000055550000555500005555000055550000555500005555000055550000555500
00000000000000050000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000666666666660006666666666666000666666666666600066666666666660006666666666666000666666666600000000000000000000000000000000
00000000666666666666666666666666666666666666666666666666666666666666666666666666666666666666666600000000000000000000000000000000
00000000666666665565656555666665566555665566666555655665656666655665556655666666556655665566666600000000000000000ff00099099000ff
0000000066666665666565665666666565655665666666655665656565666665656556656666666565656665666666660000000000000000090f040004090900
00000000666666656665656656666665566566666566666566656565656666656565666566666665556566656666666600000000000000000990000404400009
00000000666666665565556656666665656655655666666655656565566666655666556655666665656655665566666600000000000000000900044004000990
00000000666666666666666666666666666666666666666666666666666666666666666666666666666666666666666600000000000000000000000000000000
00000000666666666666666666666666666606666666666666666666666666666666066666666666666666666666666600000000000000000000000000000000
55555555055555555555555555555555555555550000000055555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555577555577555775556665555566555550000000066556655005500555665665550050055656565650505050556656565500505056665566500055005
55505555560655560656005555656655565656650000000066656065770577056005606507757705656565657575757560056665077570756065600577750775
55505555565656565656555555656565565656550000000066656565777575750565656575057575666566657075707565550065755577756665655570757555
55505555566050566056555555656565566556650000000066056605777575756605660500757075606560657775777506656605700500756005066577757005
55505555560556560656555555555555555555550000000000550055775577550055005577557755050505057575757550050055577577550555500575555775
55505555565556565650665555555555555555550000000055555555555555555555555555555555555555555555555555555555555555555555555555555555
55505555505550505055005555555555555555550000000055555555555555555555555555555555555555555555555555555555555555555555555555555555
55505555555555550000000000000005000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
5550555555555555000000000000000505500000055500000555000005050000066000000666000006660000060600000ff000000fff00000fff00000f0f0000
55505555555555550000000000000005005000000005000000050000050500000060000000060000000600000606000000f00000000f0000000f00000f0f0000
55505555555555550000000000000005005000000555000000550000055500000060000006660000006600000666000000f000000fff000000ff00000fff0000
55505555555555550000000000000005005000000500000000050000000500000060000006000000000600000006000000f000000f000000000f0000000f0000
5550555555555555000000000000000505550000055500000555000000050000066600000666000006660000000600000fff00000fff00000fff0000000f0000
55505555555555550000000000000005000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
55505555555555550000000000000005000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
55505555ccc000000000000000000000000000000000000000000000000000000000000000222200000000000000000000000000000000000000000000000000
55505555c00000000000000000000000000000000000000000000000000000000022220002888820000000000000000000000000000000000000000000000000
55505555c0000000000000000000000000000000000000000000000000aaaa0009aaaa9009aaaa90000000000000000000000000000000000000000000000000
55505555000000000000000000000000000000000000000000999900009999000099990000999900000000000000000000000000000000000000000000000000
555055550000000000000000000000000000000000bbbb0003bbbb3003bbbb3003bbbb3003bbbb30000000000000000000000000000000000000000000000000
555055550000c0000000000000000000003333000033330000333300003333000033330000333300000000000000000000000000000000000000000000000000
555555550000c000000000000033330003bbbb3003bbbb3003bbbb3003bbbb3003bbbb3003bbbb30000000000000000000000000000000000000000000000000
5555555500ccc0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000090000000f0000000600000000050000000050050050555055505555000005000500000000000000000000000000000000000600060066660000
057500000000490000009f0000005600057500050050000005050500505050505005000000505000055555000055555000000000000000000060605065560000
0777000000044490000999f000055560077700050555000000000000555055505055550000050000050005000050005000000000000000000006050065666600
00000000040044090900990f05005506000000050000000055000550005050005050050055000550550005505555500000000000000000006600566065655650
07770000040004040900090905000505077700050555000000000000000500005550050005000500055555000555000000000000000000005650065066650650
05750000040000040900000905000005057500050050000005050500005050000050050005000500000000000050000000000000000000000650065000650650
00000000004444400099999000555550000000050000000050050050005050000055550055000550555555500000000000000000000000006650066000666650
00000000000000000000000000000000000000050000000000000000000000000000000000000000000000000000000000000000000000005550005000055550
00000000000000000000000000000000666666666660006666666666666000666666666666600066666666666660006666666666666000666666666600000000
05750eee05750eee057500ee00000ee0666666666666666666666666666666666666666666666666666666666666666666666666666666666666666600000000
07770e0e07770e0e07770e0000000e0e666666666556565655566665566555666556665556556656566666556655566556666655665566556666666600000000
00000eee00000ee000000e0000000e0e666666665666565665666665656556665666665566565656566666565655665666666565656665666666666600000000
00000e0e00000e0e00000e0000000e0e666666665666565665666665566566666656665666565656566666565656665666666555656665666666666600000000
00000e0e07770eee077700ee07770ee0666666666556555665666665656655665566666556565655666666556665566556666565665566556666666600000000
00000000057500000575000005750000666666666666666666666666666666666666666666666666666666666666666666666666666666666666666600000000
00000000000000000000000000000000666666666666666666666666666606666666666666666666666666666660666666666666666666666666666600000000
66666666666666666666666666666666666666666666666666666666000000000000000000000000000000000000000000006000000000000000000000000000
66666666666666666666666666666666666666666666666665555666000000000000000000000000000000000000000000600600000000000000000000000000
65565556556665565556556655666556655665566666666665665666000280000008e00000056000000000000000000000060600000000000000000000000000
566665665656566655665656565656665656566666666666656555560022280000888e000055560000000000000000000606060000000000fff0fff000000000
56666566556666565666565656565666555656666666666665656656002222000088880000555500000000000000000000060600000000000000000000000000
65566566565655666556565655666556565665566666666665556656000220000008800000055000000000000000000000600600000000000000000000000000
66666666666666666666666666666666666666666666666666656656000000000000000000000000000000000000000000006000000000000000000000000000
66666666666666666666666666666666666666666666666666655556000000000000000000000000000000000000000000000000000000000000000000000000
66000066660000666600006666000066660000666600006666000066660000666600006666000066660000666600006600000000000000000000000000000000
60667706606677066066770660667706606677066066770660667706606677066066770660667706606677066066770606600006660006660006060000000000
06666670066666700666667006666670060666700660667006660670066660700666667006666670066666700666667000600000060000060006060000000000
06666660066666600666666006066660066666600666666006666660066666600666606006666660066666600666666000600006660000660006660000000000
06666660066666600606666006666660066666600666666006666660066666600666666006666060066666600666666000600006000000060000060000000000
06506660060666600666666006666660066666600666666006666660066666600666666006666660066660600666056006660006660006660000060000000000
60666606606666066066660660666606606666066066660660666606606666066066660660666606606666066066660600000000000000000000000000000000
66000066660000666600006666000066660000666600006666000066660000666600006666000066660000666600006600000000000000000000000000000000
__label__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000
0777707700077770b000606000000000000000000000000000000000005000000000000005750000000056000000000000000000057500000000000005750000
07707077000770703b006060000560000ff000990000000000000000055500000000000007770000000555600000000000000000077700000000000007770000
077770777707777033b0505000555600090f040000000000fff0fff000000000fff0fff0000000000500550600000000fff0fff000000000fff0fff000000000
06600066060660603330505000555500099000040000000000000000055500000000000007770000050005050000000000000000077700000000000007770000
06600066060006003300505000055000090004400000000000000000005000000000000005750000050000050000000000000000057500000000000005750000
06600066660660603000505000000000000000000000000000000000000000000000000000000000005555500000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000006005000000000000000000000000000060050000000000000000000000000000600500000000000000000000000000006005
00555500000660000055550000600605066606600003b0000055550000600605066606660003b0000055550000600605066600660003b0000055550000600605
055755500006060005555750000606050606006000333b0005575550000606050606000600333b0005557550000606050606060000333b000555755000060605
05555550000660000555555006060605066000600033330005555550060606050660066600333300055555500606060506600600003333000555555006060605
05555550000606000555555000060605060600600003300005555550000606050606060000033000055555500006060506060600000330000555555000060605
05555550006606000555555000600605066606660000000005555550006006050666066600000000055555500060060506060066000000000555555000600605
00555500006600000055550000006005000000000000000000555500000060050000000000000000005555000000600500000000000000000055550000006005
00000000000000000000000000000005000000000000000000000000000000050000000000000000000000000000000500000000000000000000000000000005
0000000000000000000000000000000500000ccc0000000000000000000000050000000000000000000000000000000500000000000000000000000000000005
005555000000000000555500000000050055550c0000000000555500000000050055550000000000005555000000000500555500000000000055550000000005
055555500660606005575550066066650555555c0660660005555750666060650555555006606600055555506660606505557550066066000555555066606065
05755550600060600555555060000605055555506060606005555550660006050555555060606060055555506600060505555550606060600575555066000605
05555550006066600555555060000605055555506060606005555550600006050555555060606060055555506000060505555550606060600555555060000605
05555550660060600555555006600605c56755506600660005555550600060650567555066006600056755506000606505555550660066000555555060006065
00555500000000000055550000000005c05555000000000000555500000000050055550000000000005555000000000500555500000000000055550000000005
00000000000000000000000000000005ccc000000000000000000000000000050000000000000000000000000000000500000000000000000000000000000005
00000000000000000000000000000005000000000000000000000000000000050000000000000000000000000000000500000000000000000000000000000005
0055550000000000005555000000000505750eee00006600055500555005050505750eee00006600055500555005050505750eee000066000555005550050505
0555555006600666055557506660660507770e0e00000600000500005005050507770e0e00000600000500005005050507770e0e000006000005000050050505
0575555006060060055555506000660500000eee00000600055500055005550500000eee00000600055500055005550500000eee000006000555000550055505
0555555006060060055555506600606500000e0e00000600050000005000050500000e0e00000600050000005000050500000e0e000006000500000050000505
0555555006600060055555506000666500000e0e00006660055500555000050500000e0e00006660055500555000050500000e0e000066600555005550000505
00555500000000000055550000000005000000000000000000000000000000050000000000000000000000000000000500000000000000000000000000000005
00000000000000000000000000000000000000000000000000000000000000050000000000000000000000000000000500000000000000000000000000000005
06666666666666666666666666666666666666666666666666600066666666666660006666666666666000666666666666600066666666666660006666666660
65555655566556666555665666666666666666666666666666067706666666666606770666666666660677066666666666067706666666666606770666666666
65565655656556666565655666666666666666666666666660666670666666666066067066666666606665706666666660656670666666666066067066666666
60000600066006665565555566666666666666666666666606666666066666660666666606666666066666560666666606566666066666660666666606666666
60066600606006666666666666666666666666666666666606666666066666660666666606666666066666660666666606666666066666660666666606666666
60066600066000066555005666666666666666666666666606666666066666660666666606666666066666660666666606666666066666660666666606666666
66666666666666666555000666666666666666666666666660566060666666666056666066666666605666606666666660566660666666666056666066666666
66666666666666666666666666666666666666666666666666055606666666666605560666666666660556066666666666055606666666666605560666666666
65555666666666666666666666666666666666666666666666600066666666666660006666666666666000666666666666600066666666666660006666666666
65665666666556666665666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
65655556665555666655566666666666666666666666666655656565556666655665556655666665556556656566666556655566556666665566556655666666
65656656665665666665666666666666666666666666666566656566566666656565566566666665566565656566666565655665666666656565666566666666
65556656665665666666666666666666666666666666666566656566566666655665666665666665666565656566666565656665666666655565666566666666
66656656665665666655566666666666666666666666666655655566566666656566556556666666556565655666666556665566556666656566556655666666
66655556665555666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666606666666666666666666666666666666066666666666666666666666666666660666666666666666666666666666
66000006660000066600000666000006660000066600000666000006660000066600000666000006660000066600000666000006660000066600000666000006
60666670606666706066667060666670606666706066667060666670606666706066667060666670606666706066667060666670606666706066667060666670
06666667066666670666666706666667066666670666666706666667066666670666666706666667066666670666666706666667066666670666666706666667
06666666066666660666666606666666066666660666666606666666066666660666666606666666066666660666666606666666066666660666666606666666
06666666066666660666666606666666066666660666666606666666066666660666666606666666066666660666666606666666066666660666666606666666
06633b66066557660662286606644966066228660662286606622866066228660665576606622866066557660665576606655766066228660665576606655766
06633366066555660662226606644466066222660662226606622266066222660665556606622266066555660665556606655566066222660665556606655566
00666660006666600066666000666660006666600066666000666660006666600066666000666660006666600066666000666660006666600066666000666660
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
05665555056655550566555506655555066556560566555506665656056655550566555505665555056655550566555505665555066555550566555505665555
06555555065555550655555506565555065656660655555506565666065555550655555506555555065555550655555506555555065655550655555506555555
06555555065555550655555506565555065656660655555506665666065555550655555506555555065555550655555506555555065655550655555506555555
06565555065655550656555506565555065656560656555506565656065655550656555506565555065655550656555506565555065655550656555506565555
06665555066655550666555506665555066655550666555506565555066655550666555506665555066655550666555506665555066655550666555506665555
05555656055556560555566605555656055556560555565605555656055556560555565605555656055556560555565605555656055556660555565605555656
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
06666666666666666666666666666666666666666666666666600066666666666660006666666666666000666666666666600066666666666660006666666660
65555655566556666555665666666666666666666666666666067706666666666606770666666666660677066666666666067706666666666606770666666666
65565655656556666565655666666666666666666666666660666670666666666066667066666666606606706666666660660670666666666066067066666666
60000600066006665565555566666666666666666666666606666666066666660666666606666666066666660666666606666666066666660666666606666666
60066600606006666666666666666666666666666666666606066666066666660666665606666666066666660666666606666666066666660666666606666666
60066600066000066005555666666666666666666666666606666666066666660666665606666666066666660666666606666666066666660666666606666666
66666666666666666000555666666666666666666666666660566660666666666056666066666666605666606666666660566660666666666056666066666666
66666666666666666666666666666666666666666666666666055606666666666605560666666666660556066666666666055606666666666605560666666666
65555666666666666666666666666666666666666666666666600066666666666660006666666666666000666666666666600066666666666660006666666666
65665666666556666665666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
65655556665555666655566666666666666666666666666655656565556666655665556655666665556556656566666556655566556666665566556655666666
65656656665665666665666666666666666666666666666566656566566666656565566566666665566565656566666565655665666666656565666566666666
65556656665665666666666666666666666666666666666566656566566666655665666665666665666565656566666565656665666666655565666566666666
66656656665665666655566666666666666666666666666655655566566666656566556556666666556565655666666556665566556666656566556655666666
66655556665555666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666606666666666666666666666666666666066666666666666666666666666666660666666666666666666666666666
66000006660000066600000666000006660000066600000666000006660000066600000666000006660000066600000666000006660000066600000666000006
60666670606666706066667060666670606666706066667060666670606666706066667060666670606666706066667060666670606666706066667060666670
06666667066666670666666706666667066666670666666706666667066666670666666706666667066666670666666706666667066666670666666706666667
06666666066666660666666606666666066666660666666606666666066666660666666606666666066666660666666606666666066666660666666606666666
06666666066666660666666606666666066666660666666606666666066666660666666606666666066666660666666606666666066666660666666606666666
06633b6606655766066228660665576606655766066557660662286606688e660665576606655766066228660665576606655766066449660662286606655766
06633366066555660662226606655566066555660665556606622266066888660665556606655566066222660665556606655566066444660662226606655566
00666660006666600066666000666660006666600066666000666660006666600066666000666660006666600066666000666660006666600066666000666660
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
05665555056655550566555505665555056655550566555505665555056655550566555505665555056655550566555505665555066655550566555505665555
06555555065555550655555506555555065555550655555506555555065555550655555506555555065555550655555506555555065555550655555506555555
06555555065555550655555506555555065555550655555506555555065555550655555506555555065555550655555506555555066555550655555506555555
06565555065655550656555506565555065655550656555506565555065655550656555506565555065655550656555506565555065555550656555506565555
06665555066655550666555506665555066655550666555506665555066655550666555506665555066655550666555506665555065555550666555506665555
05555565055555650555556505555565055555650555556505555565055556560555556505555565055555650555556505555565055555650555556505555565
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
05555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
57755557755577555500005555000055555555555500005555000055555555555500005555000055555555555500005555000055555555555500005555000055
56065556065600555008000550080005555055555008000550000005555055555008000550000005555055555000000550000805555055555000800550000005
56565656565655555000000550000005555055555000000550000005555055555000000550000805555055555000080550000005555055555000000550000005
56605056605655555000000550000005555055555000000550800005555055555000000550000005555055555000000550000005555055555000000550000005
56055656065655555000000550000005555055555000000550000005555055555000000550000005555055555000000550000005555055555000000550280005
56555656565066555500005555000055555055555500005555000055555055555500005555000055555055555500005555000055555055555500005555000055
50555050505500555555555555555555555055555555555555555555555055555555555555555555555055555555555555555555555055555555555555555555
55555555555555555555555555555555555055555555555555555555555055555555555555555555555055555555555555555555555055555555555555555555
55555555555555555666555556655555555055555666555556655555555055555666555556655555555055555666555556655555555055555666555556655555
55555555555555555565665556565665555055555565665556565665555055555565665556565665555055555565665556565665555055555565665556565665
55555555555555555565656556565655555055555565656556565655555055555565656556565655555055555565656556565655555055555565656556565655
55555555555555555565656556655665555055555565656556655665555055555565656556655665555055555565656556655665555055555565656556655665
55555555555555555555555555555555555055555555555555555555555055555555555555555555555055555555555555555555555055555555555555555555
55555555555555555555555555555555555055555555555555555555555055555555555555555555555055555555555555555555555055555555555555555555
55555555555555555555555555555555555055555555555555555555555055555555555555555555555055555555555555555555555055555555555555555555
55555555555555555555555555555555555055555555555555555555555055555555555555555555555055555555555555555555555055555555555555555555
55555555555555550055005555000055555055555665665555000055555055556565656555000055555055555665656555000055555055556665566555000055
55555555555555557705770550080005555055556005606550000805555055556565656550800005555055556005666550080005555055556065600550800005
55555555555555557775757550000005555055550565656550000005555055556665666550000005555055556555006550000005555055556665655550000005
55555555555555557775757550000005555055556605660550000005555055556065606550000005555055550665660550000005555055556005066550000005
55555555555555557755775550000005555055550055005550000005555055550505050550000005555055555005005550000005555055550555500550000005
55555555555555555555555555000055555555555555555555000055555555555555555555000055555555555555555555000055555555555555555555000055
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55000005550000055500000555000005550000055500000555000005550000055500000555000005550000055500000555000005550000055500000555000005
50555560505555605055556050555560505555605055556050555560505555605055556050555560505555605055556050555560505555605055556050555560
05555556055555560555555605555556055555560555555605555556055555560555555605555556055555560555555605555556055555560555555605555556
05555555055555550555555505555555055555550555555505555555055555550555555505555555055555550555555505555555055555550555555505555555
05555555055555550555555505555555055555550555555505555555055555550555555505555555055555550555555505555555055555550555555505555555
05533b55055667550556675505566755055228550556675505566755055667550552285505566755055667550556675505522855055667550556675505566755
05533355055666550556665505566655055222550556665505566655055666550552225505566655055666550556665505522255055666550556665505566655
00555550005555500055555000555550005555500055555000555550005555500055555000555550005555500055555000555550005555500055555000555550

__map__
080907008e0000c000c0c10000c000c007eaebc4c5c928c6c9c8c4c5c9c7c98d07e700eec5c300eec5eec5ec292a008e0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
782878271726782718267827192678277828782717ce782718ce782719ce782778287827b61726d0fcfdfe787878c6c70000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
787078717829782a7829782a7829782a787078717829782a7829782a7829782a78707871b51826d0fcfdfe787878c8c90000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
78727873d00000a3d00000a3d00000a378727873d0fcfdfed0fcfdfed0fcfdfe78727873b91926d0fcfdfe787878cacb0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0c0d031d1d1d341e341e341e341e341f0c0d031d1d1dd4341e341e341e341e34000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1c1b1a1d0e8182838485868788898a8b1c1b1a1d0ed4d4d5d6d7d8d9dadbdcdd000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1010101010101010101010101010101010101010101010101010101010101010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
5555555555555555555555555555555555555555555555555555555555555555000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
919267679067679067679067679067679192a1a1a1a193679367936793679367000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
a1a19394a09394a09394a09394a09394a1a1a1a1a1a194679467946794679467000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
a1a19767b09867b09a67b09c67b09e67a1a1a1a1a1a1976798679a679c679e67000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1313131313131313131313131313131313131313131313131313131313131313000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000001900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
