-->8
-- audio fx

function delay_new()
 local obj,_dl,_p,_f1={l=20,fb=0},{},1,0

 for i=0,0x7fff do
  _dl[i]=0
 end

 function obj:update(b,first,last)
  local dl,fb,p,f1=_dl,self.fb,_p,_f1
  local tap=(p-flr(self.l))&0x7fff
  for i=first,last do
   local x,y=b[i],dl[tap]
   b[i]=y
   y=x+fb*y
   f1+=(y-f1)>>4
   dl[p]=y-(f1>>2)
   p=(p+1)&0x7fff
   tap=(tap+1)&0x7fff
  end
  _p,_f1=p,f1
 end

 return obj
end


dr_fx_masks=split'1,1,2,2,4,4'
function drum_mixer_new(srcs)
 return {
  srcs=srcs,
  fx=127,
  note=function(self,patch) self.fx=patch[45] end,
  update=function(self,b,first,last,bypass)
   for i=first,last do
    b[i]=0
    bypass[i]=0
   end

   for i,src in ipairs(self.srcs) do
    if (self.fx&dr_fx_masks[i]>0) src:subupdate(b,first,last) else src:subupdate(bypass,first,last)
   end
  end
 }
end

filtmap=parse[[{b0=3,b1=4,dr=5}]]
mixer_params=parse[[{
 b0={p0=7,p1=9,lev=8},
 b1={p0=23,p1=25,lev=8},
 dr={p0=39,p1=41,lev=16},
}]]
function mixer_new(_srcs,_fx,_filt,_lev)
 local _tmp,_bypass,_fxbuf,_filtsrc,_xp1={},{},{},1,parse[[{b0=0,b1=0,dr=0}]]
 return {
  note=function(self,patch)
   _lev=pow3(patch[3]>>7)*8
   _filtsrc=patch[64]
   for key,src in pairs(mixer_params) do
    local sk=_srcs[key]
    local lev,od,fx=unpack_patch(patch,src.p0,src.p1)
    sk.lev,sk.od,sk.fx=src.lev*pow3(lev),od*od,pow3(fx)
   end
  end,
  update=function(self,b,first,last)
   local fxbuf,tmp,bypass,lev,filtsrc=_fxbuf,_tmp,_bypass,_lev,_filtsrc
   for i=first,last do
    b[i],fxbuf[i]=0,0
   end

   for k,src in pairs(_srcs) do
    local od,fx,xp1=src.od,src.fx,_xp1[k]
    src.obj:update(tmp,first,last,bypass)
    local odg=0.2+63.8*od
    local odgi=(1+6*od)/odg
    for i=first,last do
     local x1,x0=tmp[i]
     x0,xp1=(xp1+x1)>>1,x1
     local pre=x1+x0
     x0*=odg
     x1*=odg
     local m0,m1=x0>>31,x1>>31
     if (x0^^m0>1.5) x0=1.5^^m0
     if (x1^^m1>1.5) x1=1.5^^m1
     tmp[i]+=(odgi*(x0+x1-0.148148*(x0*x0*x0+x1*x1*x1))-pre)>>1
     tmp[i]*=src.lev
    end
    _xp1[k]=xp1
    if (filtmap[k]==filtsrc) _filt:update(tmp,first,last)
    for i=first,last do
     local x=tmp[i]
     b[i]+=x*lev
     fxbuf[i]+=x*fx
    end
   end

   _fx:update(fxbuf,first,last)
   local drlev=_srcs.dr.lev
   for i=first,last do
    b[i]+=(fxbuf[i]+bypass[i]*drlev)*lev
   end
   if (filtsrc==2) _filt:update(b,first,last)
  end
 }
end

function comp_new(src,th,_ratio,_att,_rel)
 local _env=0
 return {
  src=src,
  th=th,
  update=function(self,b,first,last)
   self.src:update(b,first,last)
   local env,att,rel=_env,_att,_rel
   local th,ratio=self.th,1/_ratio
   -- makeup targets 0.6
   local makeup=max(1,0.6/((0.6-th)*ratio+th))
   for i=first,last do
    local x=b[i]
    x=x^^(x>>31)
    local c
    if (x>env) c=att else c=rel
    env+=c*(x-env)
    local g,te=makeup,th/(env+0x0.0010)
    if (env>th) g*=te+ratio*(1-te)
    b[i]*=g
   end
   _env=env
  end
 }
end

svf_pats=parse[[(
"@///////////////"
"@///////"
"@///"
"@/"
"@"
"@//@//@//@//@//@"
"//@//@////@//@//"
"/123456789:;<=>@"
"8899::;;<<==>>@@"
"8/9/:/;/</=/>/@/"
"@/>/=/</;/:/9/8/"
"==/3@@:/23@114:;92>:5<:27<@//;>8;3;43;64</;883=4:"
">/3/7/</=/8/5/>/2/@/5/4/2/>/3/@/7/3/3/;/</6/2/;/7/"
"@;:=<@:=;8@;<>>@8@<999;8=<==:99:=<8:=:=<;8<<@8=<8"
";/=/>/@/;/:/9/;/@/;/=/</@/@/</</>/</;/:/@/</;/</@/"
"@//"
"@////"
"@//////"
"@//:/"
"////////@///////"
"////@///"
"//@/"
"/@"
":///@/////:/@///"
)]]

-- see note 005
function svf_new()
 local _z1,_z2,_rc,_gc,_wet,_fe,_bp,_dec=unpack_split'0,0,0.1,0.2,1,1,0,1'
 return {
  note=function(self,patch,bar,tick)
   local r,gc,dec
   _bp,gc,r,_wet,_,dec=unpack_patch(patch,65,70)
   _rc=1-r*0.96
   local svf_pat=svf_pats[patch[69]]
   local pat_val=ord(svf_pat,(bar*16+tick-17)%#svf_pat+1)-48
   if (pat_val>=0 and state.playing) _fe=pat_val>>4
   _dec=1-(pow3(1-dec)>>7)
   _gc=gc*gc*0x0.fe+0x0.02
  end,
  update=function(self,b,first,last)
   local z1,z2,rc,gc_base,wet,fe,is_bp,dec=_z1,_z2,_rc,_gc,_wet,_fe,_bp,_dec
   for i=first,last do
    gc=gc_base*fe
    local rrpg=(rc<<1)+gc
    local hpn,inp=1/gc+rrpg,b[i]
    local hpgc=(inp-rrpg*z1-z2)/hpn
    local bp=hpgc+z1
    z1,z2=hpgc+bp,((bp*gc)<<1)+z2

    -- 2x oversample
    hpgc=(inp-rrpg*z1-z2)/hpn
    bp=hpgc+z1
    local lp=bp*gc+z2
    z1,z2=hpgc+bp,bp*gc+lp

    -- rc*bp is 1/2 of unity gain bp
    b[i]=inp+wet*(lp+is_bp*(rc*bp+bp-lp)-inp)
    fe*=dec
   end
   _z1,_z2,_fe=z1,z2,fe
  end
 }
end

