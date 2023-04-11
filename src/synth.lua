-->8
-- audio gen

_lfsr=0.5

function pbstep(rp)
 return rp+rp-((rp*rp+1)^^(rp>>31))
end

function synth_new(base)
 local obj,_op,_todp,_todpr,_fc,_fr,_env,_acc,
       _detune,_med,_nt,_nl,_o2p,_o2detune,_o2mix={},
       unpack_split'0,.001,.999,.5,3.6,.5,.5,0,9,900,900,0,1,0'
 local _mr,_ar,_gate,_saw,_ac,_sl,_lsl

 local function update(b,first,last)
  local f1,f2,f3,f4,fosc,ffb,e1,e2,odp,fcbf,ae,me=0,0,0,0,0,0,0,0,0,0.1,0,0
  local tanh=tanh

  repeat
   b,first,last=yield()

   local op,detune,todp,todpr,o2p=_op,_detune,_todp,_todpr,_o2p
   local o2detune,o2mix=_o2detune,_o2mix>>2
   local fr,fcb=_fr,_fc
   local med,mr=_med,_mr
   local gate,nt,nl,sl,ac=_gate,_nt,_nl,_sl,_ac
   local env,saw,acc=_env,_saw,ac and _acc or 0
   local res_comp=(saw and 16 or 11)/(fr+16)
   local mix1,mix2=cos(o2mix),-sin(o2mix)

   for i=first,last do
    fcbf+=(fcb-fcbf)>>5
    local fc=min(0.1,fcbf+(me/10)*env)<<2
    -- janky dewarping
    -- scaling constant is 0.75*2*pi because???
    --fc=4.71*fc/(1+fc)
    local fc1=(0.4+3*fc)>>2
    if gate then
     -- 1/7 amp multiplier, 1/4 oversampling multiplier
     ae+=(0.03572-ae)>>3
     if ((nt>(nl>>1) and not sl) or nt>nl) gate=false
    else
     ae*=0.9974
    end
    if mr then
     me+=(1-me)>>3
     mr=me<=0.995
    else
     me*=med
    end
    odp+=todpr*(todp-odp)
    local dodp,dodp2,out,aa_osc=odp*detune,odp*o2detune,0
    _nt+=1

    local opr=op+0x8000
    local o2pr=o2p+0x8000
    local c1r=(opr^^(opr>>31))<dodp and pbstep(opr/dodp) or 0
    local c2r=(o2pr^^(o2pr>>31))<dodp2 and pbstep(o2pr/dodp2) or 0
    if saw then
     aa_osc=mix1*((op>>15)-c1r)+mix2*((o2p>>15)-c2r)
    else
     local c1=(op^^(op>>31))<dodp and pbstep(op/dodp) or 0
     local c2=(o2p^^(o2p>>31))<dodp2 and pbstep(o2p/dodp2) or 0
     aa_osc=mix1*((1^^(op>>31))+c1-c1r)+
            mix2*((1^^(o2p>>31))+c2-c2r)
    end
    -- coefs are polyblep compensation FIR
    aa_osc,e1,e2=-0.1469*(aa_osc+e2)+1.2674*e1,aa_osc,e1
    op+=dodp
    o2p+=dodp2

    for _=1,4 do
     local osc=aa_osc-fosc
     fosc+=osc>>5
     local ffb_diff=f4-ffb
     ffb+=ffb_diff>>3
     osc-=fr*(ffb_diff-osc)
     local m=osc>>31
     osc=osc^^m>22.8 and 6^^m or tanh[(osc*89.82456+2048.5)&-1]

     f1+=fc1*(osc-f1)
     f2+=fc*(f1-f2)
     f3+=fc*(f2-f3)
     f4+=fc*(f3-f4)

     out+=f4
    end
    b[i]=out*ae*(1+acc*me)*res_comp
   end
   _op,_gate,_o2p,_mr=op,gate,o2p,mr
  until false
 end

 local _update=cocreate(update)
 coresume(_update)

 function obj:note(pat,patch,step,note_len)
  local patstep,saw,tun,_,o2fine,o2mix,cut,res,env,dec,acc=pat.st[step],unpack_patch(patch,base+5,base+14)

  _o2mix=o2mix
  -- range is approx. 110hz to 1750Hz
  _fc=0.005+0.075*cut^2.5
  _fr=res^1.1*11+.2
  _env=env+0.02
  _acc=acc*1.9+0.1
  _saw=saw>0
  local pd=1-dec
  _lsl,_ac,_sl=_sl,get_ac_mode(patstep)
  _sl=_sl and state.playing
  --if(base==23)log(_lsl,_sl)
  if (_ac) pd=0.8+0.2*pd
  _med=0.9997-0.005*pd*pd
  _nt,_nl=0,note_len
  _gate=false
  _detune=2^(flr(24*tun-11.5)/12)
  _o2detune=_detune*2^((flr(pat.dt[step]-64)+o2fine-0.5)/12)
  if (patstep==n_off or not state.playing) return

  _gate=true
  -- constant is 55*65536/(5512.5 * 4)
  --_todp=2^(pat.nt[step]/12+2.25)*163.46848
  _todp=2^(pat.nt[step]/12)*777.59152

  if (_ac) _env+=acc>>1
  if _lsl then
   _todpr=0.015
  else
   _o2p=_op
   _todpr=0.995
   _mr=true
  end

  _nt=0
 end

 function obj:update(b,first,last)
  coresume(_update,b,first,last)
 end

 return obj
end

function sweep_new(base,_dp0,_dp1,ae_ratio,boost,te_min,te_max)
 local obj,_tri,_op,_dp,_ae,_aemax,_aed,_ted,_detune=
  {},false,unpack_split'0,6553.6,0,0.6,0.995,0.05,1'

 function obj:note(pat,patch,step)
  local s=pat.st[step]
  local tun,dec,lev=unpack_patch(patch,base,base+2)
  if s!=n_off then
   local ac
   ac,_tri=get_ac_mode(s)
   -- TODO: update params every step?
   _detune=2^((pat.dt[step]-64)/12)
   _ted=te_max+(te_min-te_max)*dec
   if state.playing then
    _op,_dp=0,_dp0*_detune*(2^((36*tun-18)/12))
    _ae=lev*lev*boost*trn(ac,1.25,0.5)
    _aemax=_ae*0.85
    if (_tri) _ae*=2.0 else _ted*=1.2
    _aed=1-ae_ratio*_ted*(_tri and 1.0 or 0.6)
   end
  end
 end

 function obj:subupdate(b,first,last)
  local op,dp,dp1,ae,aed,ted,tri=_op,_dp,_dp1*_detune,_ae,_aed,_ted,_tri
  local aemax=_aemax
  for i=first,last do
   op+=dp
   dp+=ted*(dp1-dp)
   ae*=aed
   -- b[i]+=(aemax<ae and aemax or ae)*(tri and ((op>>14)^^(op>>31))-1 or sin(op>>16))
   b[i]+=tri and (aemax<ae and aemax or ae)*(((op>>14)~(op>>31))-1) or ae*sin(op>>16)
  end
  _op,_dp,_ae=op,dp,ae
 end

 return obj
end

function snare_new()
 local obj,_dp0,_dp1,_op,_dp,_aes,_aen,_detune,_aesd,_aend,_aemax,_f1,_hpmix=
  {},unpack_split'0.07446,0.03273,0,.05,0,0,10,.99,.996,.4,0,0'

 function obj:note(pat,patch,step)
  local s=pat.st[step]
  local tun,dec,lev=unpack_patch(patch,49,51)
  if s!=n_off then
   _detune=2^((12*tun-6+(pat.dt[step]-64))/12)
   _op,_dp=0,_dp0*_detune
   if state.playing then
    _aes,_aen=1,0.5
    local ac,mode=get_ac_mode(s)
    if (ac) _aes,_aen=1.9,1.1
    local lev2,aeo=lev*lev,(tun-0.5)*0.1
    _hpmix=mode and 2 or 1
    _aes-=aeo
    _aen+=aeo
    _aes*=lev2*1.2
    _aen*=lev2*0.7
    _aemax=_aes>>1
    local pd2=0.19-0.1725*dec^0.5
    if (not mode) pd2*=1.8 _aen*=1.4 _aes*=.7 _aemax=_aes
    _aesd=.996-.06*pd2
    _aend=.9997-.05*pd2
   end
  end
 end

 function obj:subupdate(b,first,last)
  local op,dp,dp1,f1,hpmix=_op,_dp,_dp1*_detune,_f1,_hpmix
  local aes,aen,aesd,aend=_aes,_aen,_aesd,_aend
  local aemax,lfsr=_aemax,_lfsr
  for i=first,last do
   op+=dp
   dp+=(dp1-dp)>>5
   aes*=aesd
   aen*=aend
   lfsr^^=lfsr*0x70.00f
   local v=(aemax<aes and aemax or aes)*sin(op)+aen*((lfsr&0x0.ffff)-0.5)
   f1+=(v-f1)>>1
   b[i]+=v-(f1>>hpmix)
  end
  _dp,_op,_aes,_aen,_f1,_lfsr=dp,op,aes,aen,f1,lfsr
 end

 return obj
end

function hh_cy_new(base,_nlev,_tlev,dbase,dscale,tbase,tscale)
 local obj,_ae,_f1,_f2,_op1,_odp1,_op2,_odp2,_op3,_odp3,_op4,_odp4,_aed,_detune,_dec_mod=
  {},unpack_split'0,0,0,0,0.22278,0,0.25490,0,0.23804,0,0.24719,.995,1,0'

 function obj:note(pat,patch,step)
  local s=pat.st[step]
  local tun,dec,lev=unpack_patch(patch,base,base+2)
  local ac,mode=get_ac_mode(s)
  if s!=n_off and state.playing then
   _ae=lev*lev*trn(ac,9,3.6)
   _dec_mod=mode and 0.5 or 0
  end

  _detune=2^(tbase+tscale*tun+(pat.dt[step]-64)/12)
  _aed=1-0.04*(dbase-dscale*(dec*0.5+_dec_mod))^4
 end

 function obj:subupdate(b,first,last)
  local ae,f1,f2,aed,tlev,nlev=_ae,_f1,_f2,_aed,_tlev,_nlev
  local op1,op2,op3,op4,detune=_op1,_op2,_op3,_op4,_detune
  local odp1,odp2,odp3,odp4,lfsr=_odp1*detune,_odp2*detune,_odp3*detune,_odp4*detune,_lfsr

  for i=first,last do
   local osc=(op1&0.5)+(op2&0.5)+(op3&0.5)+(op4&0.5)-1

   lfsr^^=lfsr*0x70.00f
   local r=nlev*((lfsr&0.5)-0.25)+tlev*osc
   f1+=0.98*(r-f1)
   f2+=0.98*(f1-f2)
   ae*=aed
   b[i]+=ae*(r-f2)
   op1+=odp1
   op2+=odp2
   op3+=odp3
   op4+=odp4
  end
  _ae,_f1,_f2=ae,f1,f2
  _op1,_op2,_op3,_op4,_lfsr=op1,op2,op3,op4,lfsr
 end

 return obj
end

function fm_new(base)
 local obj,_mdet,_cdet,_mphase,_cphase,_adec,_amp,_mdec,_mamp,_mode={},unpack_split'0,0,0,0,.995,0,.995,0'

 function obj:note(pat,patch,step)
  local s=pat.st[step]
  local tun,dec,lev=unpack_patch(patch,base,base+2)
  if s!=n_off and state.playing then
   local ac
   ac,_mode=get_ac_mode(s)
   _cdet=2^((pat.dt[step]-64)/12)*0.07111
   _amp=lev*lev*trn(ac,0.7,0.3)*(_mode and 0.85 or 1)
   _mamp=_mode and 4 or 1
  end
  _adec=1-(0.32-0.17*dec)^4
  _mdec=1-(0.28-0.18*dec)^4
  tun<<=2
  local ratio=(0.25<<(tun&7))*(1+(tun&0x0.ffff))
  _mdet=_cdet*ratio
 end

 function obj:subupdate(b,first,last)
  local mdet,cdet,mphase,cphase,adec,amp,mdec,mamp=_mdet,_cdet,_mphase,_cphase,_adec,_amp,_mdec,_mamp
  for i=first,last do
   mphase+=mdet
   cphase+=cdet*(1+mamp*sin(mphase))
   b[i]+=amp*sin(cphase)
   amp*=adec
   mamp*=mdec
  end
  _mphase,_cphase,_amp,_mamp=mphase,cphase,amp,mamp
 end

 return obj
end
