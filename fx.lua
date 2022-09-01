-->8
-- audio fx

function delay_new()
 local obj,_dl,_p,_f1=eval--[[language::loaf]][[
 (unpack (' ({l=20 fb=0} {} 1 0)))
 ]]

 for i=0,0x7fff do
  _dl[i]=0
 end

 function obj:update(b,first,last)
  local dl,fb,p,f1=_dl,self.fb,_p,_f1
  local tap=(p-(self.l&-1))&0x7fff
  for i=first,last do
   local x,y=b[i],dl[tap]
   b[i]=y
   y=x+fb*y
   f1+=(y-f1)>>4
   dl[p]=y-f1
   p=(p+1)&0x7fff
   tap=(tap+1)&0x7fff
  end
  _p,_f1=p,f1
 end

 return obj
end


eval--[[language::loaf]][[
(set filtmap (' {b0=3,b1=4,dr=5}))
(set mixer_params (' {
 b0={p0=7,p1=9,lev=8},
 b1={p0=23,p1=25,lev=8},
 dr={p0=39,p1=41,lev=16},
}))
(set dr_fx_masks (' (1 2 4 8 16 32)))

(set svf_pats (' (
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
)))
]]

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

function mixer_new(_srcs,_fx,_filt,_lev)
 local _tmp,_bypass,_fxbuf,_filtsrc,_state,_shape=eval--[[language::loaf]][[
 (unpack (' ({} {} {} 1 {b0=(0 0) b1=(0 0) dr=(0 0)} 0)))
 ]]

 return {
  note=function(self,patch)
   _lev=pow3(patch[3]>>7)<<3
   _filtsrc=patch[64]
   _shape=patch[71]>>8
   for key,src in pairs(mixer_params) do
    local sk=_srcs[key]
    local lev,od,fx=unpack_patch(patch,src.p0,src.p1)
    sk.lev,sk.od,sk.fx=src.lev*pow3(lev),od*od,pow3(fx)
   end
  end,
  update=function(self,b,first,last)
   local fxbuf,tmp,bypass,lev,filtsrc,shape=_fxbuf,_tmp,_bypass,_lev,_filtsrc,_shape
   for i=first,last do
    b[i],fxbuf[i]=0,0
   end

   for k,src in pairs(_srcs) do
    local od,fx,xp1,hpf=src.od,src.fx,unpack(_state[k])
    src.obj:update(tmp,first,last,bypass)
    od=od^0.8
    local odg=0.2+79.8*od
    local odgi=(1+4*od)/odg
    -- ensure 0 DC -> 0 DC
    for i=first,last do
     local tmp_i=tmp[i]
     local x1,xp1,x0=tmp_i,tmp_i,(tmp_i+xp1)>>1
     local pre=x1+x0
     x0*=odg
     x1*=odg
     local m0,m1=x0>>31,x1>>31
     if (x0^^m0>1.5) x0=1.5^^m0
     if (x1^^m1>1.5) x1=1.5^^m1
     local x02,x12=x0*x0,x1*x1
     local diff=(odgi*(x0+x1+shape*(x02+x12)-0.148148*(x02*x0+x12*x1))-pre)>>1
     hpf+=(diff-hpf)>>8
     tmp[i]=(tmp_i+diff-hpf)*src.lev
    end
    _state[k]={xp1,hpf}
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

function comp_new(src,_th,_ratio,_att,_rel)
 local _env=0
 return {
  src=src,
  th=_th,
  update=function(self,b,first,last)
   self.src:update(b,first,last)
   local env,att,rel=_env,_att,_rel
   local th,ratio=self.th,1/_ratio
   -- makeup targets 0.6
   local makeup=max(1,0.6/((0.6-th)*ratio+th))
   for i=first,last do
    local s=b[i]
    local x=s^^(s>>31)
    env+=(x>env and att or rel)*(x-env)
    local g=makeup
    local te=th/(env+0x0.0010)
    if (env>th) g*=te+ratio*(1-te)
    b[i]=s*g
   end
   _env=env
  end
 }
end

-- see note 005
function svf_new()
 local _z1,_z2,_rc,_gc_base,_gc_range,_fe,_gc,_bp,_dec=unpack_split'0,0,.1,.2,1,1,0,0,1'
 return {
  note=function(self,patch,bar,tick)
   local r,gc_base,amt,dec,_
   _bp,gc_base,r,amt,_,dec=unpack_patch(patch,65,70)
   _rc=1-r*0.96
   local svf_pat=svf_pats[patch[69]]
   local pat_val=ord(svf_pat,(bar*16+tick-17)%#svf_pat+1)-48
   if (pat_val>=0 and state.playing) _fe=pat_val>>4
   _dec=1-(pow3(1-dec)>>7)
   _gc_base=pow3(gc_base)*0x0.fe+0x0.02
   _gc_range=pow3(amt)*(1-_gc_base)
  end,
  update=function(self,b,first,last)
   local z1,z2,rc,gc_base,gc_range,fe,gc,is_lp,dec=_z1,_z2,_rc,_gc_base,_gc_range,_fe,_gc,_bp==0,_dec
   local rc1=rc<<1
   for i=first,last do
    gc+=(gc_base+gc_range*fe-gc)>>5
    local rc1gc=rc1+gc
    local hpn,inp=1/gc+rc1gc,b[i]
    local hpgc=(inp-rc1gc*z1-z2)/hpn
    local bp=hpgc+z1
    z1=hpgc+bp
    z2+=(bp*gc)<<1

    -- 2x oversample
    hpgc=(inp-rc1gc*z1-z2)/hpn
    bp=hpgc+z1
    local lp=bp*gc+z2
    z1=hpgc+bp
    z2=bp*gc+lp

    -- rc*bp is 1/2 of unity gain bp
    b[i]=is_lp and lp or rc*bp+bp
    fe*=dec
   end
   _z1,_z2,_fe,_gc=z1,z2,fe,gc
  end
 }
end

