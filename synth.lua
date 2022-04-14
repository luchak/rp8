-->8
-- audio gen

function synth_new(base)
 local obj,_op,_odp,_todp,_todpr,_fc,_fr,_os,_env,_acc,
       _detune,_fc,_f1,_f2,_f3,_f4,_fosc,_ffb,_me,_med,
       _ae,_aed,_nt,_nl={},
       unpack_split'0,0.001,0.001,0.999,0.5,3.6,4,0.5,0.5,1,0,0,0,0,0,0,0,0,0.99,0,0.997,900'
 local _mr,_ar,_gate,_saw,_ac,_sl,_lsl

 function obj:note(pat,patch,step,note_len)
  local patstep,saw,tun,cut,res,env,dec,acc=pat.st[step],unpack_patch(patch,base+5,base+11)

  _fc=(100/sample_rate)*(2^(4*cut))/_os
  _fr=sqrt(res)*7
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
  local f1,f2,f3,f4,fosc,ffb=_f1,_f2,_f3,_f4,_fosc,_ffb
  local fr,fcb,os=_fr,_fc,_os
  local ae,aed,me,med,mr=_ae,_aed,_me,_med,_mr
  local env,saw,lev,acc=_env,_saw,_lev,_acc
  local gate,nt,nl,sl,ac=_gate,_nt,_nl,_sl,_ac
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
  if s!=n_off then
   -- TODO: update params every step?
   _detune=2^(1.5*tun-0.75)
   _op,_dp=0,(_dp0<<16)*_detune
   _ae=lev*lev*boost*trn(s==n_ac,1.5,0.6)
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
  if s!=n_off then
   _detune=2^(2*tun-1)
   _op,_dp=0,_dp0*_detune
   _aes,_aen=0.7,0.4
   if (s==n_ac) _aes,_aen=1.5,0.85
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
 local obj,_ae,_f1,_op1,_odp1,_op2,_odp2,_op3,_odp3,_op4,_odp4,_aed,_detune=
  {},unpack_split'0,0,0,14745.6,0,17039.36,0,15400.96,0,15892.48,0.995,1'

 function obj:note(pat,patch,step)
  local s=pat[step]
  local tun,dec,lev=unpack_patch(patch,base,base+2)
  if s!=n_off then
   _op,_dp,_ae=0,_dp0,lev*lev*trn(s==n_ac,2.0,0.8)

   _detune=2^(tbase+tscale*tun)

   _aed=1-0.04*pow4(dbase-dscale*dec)
  end
 end

 function obj:subupdate(b,first,last)
  local ae,f1,aed,tlev,nlev=_ae,_f1,_aed,_tlev,_nlev
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
   ae*=aed
   b[i]+=ae*(r-f1)
   op1+=odp1
   op2+=odp2
   op3+=odp3
   op4+=odp4
  end
  _ae,_f1=ae,f1
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
  if s!=n_off then
   _pos=1
   _amp=lev*lev*trn(s==n_ac,1,0.5)
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
