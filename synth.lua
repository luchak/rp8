-->8
-- audio gen

function synth_new(base)
 local obj,_op,_odp,_todp,_todpr,_fc,_fr,_env,_acc,
       _detune,_f1,_f2,_f3,_f4,_fosc,_ffb,_me,_med,
       _ae,_aed,_nt,_nl,_fcbf,_o2p,_o2detune,_o2mix={},
       unpack_split'0,0.001,0.001,0.999,0.5,3.6,0.5,0.5,1,0,0,0,0,0,0,0,0.99,0,0.9971,900,900,0,0,1,0'
 local _mr,_ar,_gate,_saw,_ac,_sl,_lsl

 function obj:note(pat,patch,step,note_len)
  local patstep,saw,tun,_,o2fine,o2mix,cut,res,env,dec,acc,atk=pat.st[step],unpack_patch(patch,base+5,base+15)

  _o2mix=o2mix
  -- constant is (100/(4*5512.5))
  _fc=0.00454*(2^(cut<<2))
  _fr=(res+sqrt(res))*3.5
  _env=env*env+0.1
  _acc=acc*1.9+0.1
  _saw=saw>0
  local pd=1-dec
  _ac=patstep==n_ac or patstep==n_ac_sl
  _sl=patstep>=n_sl
  if (_ac) pd=1
  _med=0.9996-0.0086*pd*pd
  _nt,_nl=0,note_len
  _lsl=_sl
  _gate=false
  _detune=2^(flr(24*(tun-0.5)+0.5)/12)
  _o2detune=_detune*2^((flr(pat.dt[step]-64)+o2fine-0.5)/12)
  if (patstep==n_off or not state.playing) return

  _gate=true
  -- constant is 55*65536/(5512.5 * 4)
  _todp=2^(pat.nt[step]/12+0.25)*163.46848

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
  local odp,op,detune,todp,todpr,o2p=_odp,_op,_detune,_todp,_todpr,_o2p
  local o2detune,o2mix=_o2detune,_o2mix>>2
  local f1,f2,f3,f4,fosc,ffb=_f1,_f2,_f3,_f4,_fosc,_ffb
  local fr,fcb,fcbf=_fr,_fc,_fcbf
  local ae,aed,me,med,mr=_ae,_aed,_me,_med,_mr
  local env,saw,acc=_env,_saw,_acc
  local gate,nt,nl,sl,ac=_gate,_nt,_nl,_sl,_ac
  local res_comp=7/(fr+7)
  local mix1,mix2=cos(o2mix),-sin(o2mix)
  for i=first,last do
   fcbf+=(fcb-fcbf)>>6
   local fc=min(0.1,fcbf+(me>>4)*env)
   -- janky dewarping
   -- scaling constant is 0.75*2*pi because???
   fc=4.71*fc/(1+fc)
   local fc1=(0.5+fc)>>1
   if gate then
    -- 1/7 amp multiplier * 1/4 oversampling normalization
    ae+=(0.03571-ae)>>2
    if ((nt>(nl>>1) and not sl) or nt>nl) gate=false
   else
    ae*=aed
   end
   if mr then
    me+=(1-me)>>2
    mr=me<=0.99
   else
    me*=med
   end
   odp+=todpr*(todp-odp)
   local dodp,dodp2,out=odp*detune,odp*o2detune,0
   _nt+=1
   for _=1,4 do
    local osc=mix1*((saw and op or (op>>31)^^0x8000)>>15) +
              mix2*((saw and o2p or (o2p>>31)^^0x8000)>>15)
    fosc+=(osc-fosc)/104
    osc-=fosc
    ffb+=(f4-ffb)/36
    osc-=fr*(f4-ffb-osc)
    local m=osc>>31
    local clip=osc^^m<0.18 and osc or 0.18^^m
    --if (osc^^m>0.18) clip=0.18^^m
    -- if (osc^^m>0.75) clip=0.5^^m else clip-=0.5926*clip*clip*clip
    -- if (osc^^m>1.5) clip=1^^m else clip-=0.14815*clip*clip*clip

    f1+=(clip+(osc-clip)*0.94-f1)*fc1
    -- f1+=(clip+(osc-clip)*0.55-f1)*fc1
    -- f1+=(clip-f1)*fc1
    f2+=fc*(f1-f2)
    f3+=fc*(f2-f3)
    f4+=fc*(f3-f4)
    out+=f4

    op+=dodp
    o2p+=dodp2
   end
   out*=ae
   if (ac) out+=acc*me*out
   b[i]=out*res_comp
  end
  _op,_odp,_gate,_o2p=op,odp,gate,o2p
  _f1,_f2,_f3,_f4,_fosc,_ffb,_fcbf=f1,f2,f3,f4,fosc,ffb,fcbf
  _me,_ae,_mr=me,ae,mr
 end

 return obj
end

function sweep_new(base,_dp0,_dp1,ae_ratio,boost,te_min,te_max)
 local obj,_op,_dp,_ae,_aemax,_aed,_ted,_detune=
  {},unpack_split'0,6553.6,0,0.6,0.995,0.05,1'

 function obj:note(pat,patch,step)
  local s=pat.st[step]
  local tun,dec,lev=unpack_patch(patch,base,base+2)
  if s!=n_off then
   -- TODO: update params every step?
   _detune=2^((18*tun-9+(pat.dt[step]-64))/12)
   _op,_dp=0,(_dp0<<15)*(1+_detune)
   if (state.playing) _ae=lev*lev*boost*trn(s==n_ac,1.5,0.6)
   _aemax=_ae>>1
   _ted=(te_max+(te_min-te_max)*dec^0.5)
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
   b[i]+=(aemax<ae and aemax or ae)*sin(op>>16)
  end
  _op,_dp,_ae=op,dp,ae
 end

 return obj
end

function snare_new()
 local obj,_dp0,_dp1,_op,_dp,_aes,_aen,_detune,_aesd,_aend,_aemax=
  {},unpack_split'2440,1220,0,0.05,0,0,10,0.99,0.996,0.4'

 function obj:note(pat,patch,step)
  local s=pat.st[step]
  local tun,dec,lev=unpack_patch(patch,49,51)
  if s!=n_off then
   _detune=2^((12*tun-6+(pat.dt[step]-64))/12)
   _op,_dp=0,_dp0*_detune
   if state.playing then
    _aes,_aen=0.8,0.4
    if (s==n_ac) _aes,_aen=1.6,0.9
    local lev2,aeo=lev*lev,(tun-0.5)*0.2
    _aes-=aeo
    _aen+=aeo
    _aes*=lev2
    _aen*=lev2*0.6
    _aemax=_aes>>1
   end
   local pd2=0.18-0.1625*dec^0.5
   _aesd=0.992-0.02*pd2
   _aend=1-0.05*pd2
  end
 end

 function obj:subupdate(b,first,last)
  local op,dp,dp1=_op,_dp,_dp1*_detune
  local aes,aen,aesd,aend=_aes,_aen,_aesd,_aend
  local aemax=_aemax
  for i=first,last do
   op+=dp
   dp+=(dp1-dp)>>5
   aes*=aesd
   aen*=aend
   b[i]+=((aemax<aes and aemax or aes)*sin(op>>15)+aen*(rnd()-0.5))
  end
  _dp,_op,_aes,_aen=dp,op,aes,aen
 end

 return obj
end

function hh_cy_new(base,_nlev,_tlev,dbase,dscale,tbase,tscale)
 local obj,_ae,_f1,_op1,_odp1,_op2,_odp2,_op3,_odp3,_op4,_odp4,_aed,_detune=
  {},unpack_split'0,0,0,14745.6,0,17039.36,0,15600,0,16200,0.995,1'

 function obj:note(pat,patch,step)
  local s=pat.st[step]
  local tun,dec,lev=unpack_patch(patch,base,base+2)
  if s!=n_off and state.playing then
   _ae=lev*lev*trn(s==n_ac,9,3.6)
  end

  _detune=2^(tbase+tscale*tun+(pat.dt[step]-64)/12)
  _aed=1-0.04*pow4(dbase-dscale*dec)
 end

 function obj:subupdate(b,first,last)
  local ae,f1,aed,tlev,nlev=_ae,_f1,_aed,_tlev,_nlev
  local op1,op2,op3,op4,detune=_op1,_op2,_op3,_op4,_detune
  local odp1,odp2,odp3,odp4=_odp1*detune,_odp2*detune,_odp3*detune,_odp4*detune

  for i=first,last do
   local osc=1.0+((op1&0x8000)>>16)+((op2&0x8000)>>16)+((op3&0x8000)>>16)+((op4&0x8000)>>16)

   local r=nlev*((rnd()&0.5)-0.25)+tlev*osc
   f1+=0.96*(r-f1)
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

function fm_new(base)
 local obj,_mdet,_cdet,_mphase,_cphase,_adec,_amp,_mdec,_mamp={},unpack_split'0,0,0,0,0.995,0,0.995,0'

 function obj:note(pat,patch,step)
  local s=pat.st[step]
  local tun,dec,lev=unpack_patch(patch,base,base+2)
  _adec=1-pow4(0.32-0.17*dec)
  _mdec=1-pow4(0.28-0.18*dec)
  if s!=n_off and state.playing then
   _cdet=2^((pat.dt[step]-64)/12)*1165.06958
   _amp=lev*lev*trn(s==n_ac,0.7,0.3)
   _mamp=1.0
  end
  tun<<=2
  local ratio=(0.25<<(tun&7))*(1+(tun&0x0.ffff))
  _mdet=_cdet*ratio
 end

 function obj:subupdate(b,first,last)
  local mdet,cdet,mphase,cphase,adec,amp,mdec,mamp=_mdet,_cdet,_mphase,_cphase,_adec,_amp,_mdec,_mamp
  for i=first,last do
   mphase+=mdet
   cphase+=cdet*(1+mamp*sin(mphase>>14))
   b[i]+=amp*sin(cphase>>14)
   amp*=adec
   mamp*=mdec
  end
  _mphase,_cphase,_amp,_mamp=mphase,cphase,amp,mamp
 end

 return obj
end
