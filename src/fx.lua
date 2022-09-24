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
(set dr_fx_masks (' {bd=1 sd=2 hh=4 cy=8 pc=16 fm=32}))

(set svf_pats (' (
"@///////"
"@///"
"@//"
"@/"
"@"
"@//@"
"@/@/@@/@@/@/@@/@"
"@/@//@//@//@//@/"
"/@//@//@/@/@//@/"
"@@//@/@@/@/@@/@/"
"@/@//@/"
"02468:=>@>=:8642"
"0123456789:;<=>?@?>=<;:987654321"
"024689:<>@><:986421"
"0123456789:;<=>?@?>=<:9875432"
"@<84"
"5@;"
">///:///?///>///6///@///8///>///"
"=//://?//>//6//@//7//=//://@//"
"=/8/</;/4/=/6/</@/7/;/9/</=/8/"
">8=;5>6;@8:9=?9<79;8<7:896?9="
"</>//@//<//>//=/"
"4/:/@//0//87///9"
"</>/<//>1//>@1//"
"53>><4?4@6=3258;"
"83/78/33//9:@5/4"
"//8//>2/>>=/8@7:"
"<//@>/9//;</=?//"
"//8@////>/76//?/"
"5//9;//@/7/3:/;/"
"=/@//<//>1//>@1/"
"4/7/:/1//065///75@8>=51/=17"
"</>/=//>1/"
)))
(@= $svf_pats 0 "@///////////////")
]]
-- "/123456789:;<=>?@"

function drum_mixer_new(srcs)
 local fx=127
 return {
  note=function(self,patch) fx=patch[45] end,
  update=function(self,b,first,last,bypass)
   for i=first,last do
    b[i]=0
    bypass[i]=0
   end

   for key,src in pairs(srcs) do
    if (fx&dr_fx_masks[key]>0) src:subupdate(b,first,last) else src:subupdate(bypass,first,last)
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
   _shape=patch[71]>>7
   for key,src in pairs(mixer_params) do
    local sk=_srcs[key]
    local lev,od,fx=unpack_patch(patch,src.p0,src.p1)
    sk.lev,sk.od,sk.fx=src.lev*pow3(lev),od,pow3(fx)
   end
  end,
  update=function(self,b,first,last)
   local fxbuf,tmp,bypass,lev,filtsrc=_fxbuf,_tmp,_bypass,_lev,_filtsrc
   for i=first,last do
    b[i],fxbuf[i]=0,0
   end

   for k,src in pairs(_srcs) do
    local slev,od,fx,xp1,hpf=src.lev,src.od,src.fx,unpack(_state[k])
    src.obj:update(tmp,first,last,bypass)
    local odg=0.2+79.8*od*od
    local odgi=(1+9*od*od)/odg
    local bias=_shape*od*1.5
    local bias3x2=pow3(bias)<<1
    for i=first,last do
     local tmp_i=tmp[i]
     local x1,x0=tmp_i,(tmp_i+xp1)>>1
     xp1=tmp_i
     local pre=x1+x0
     x0=x0*odg+bias
     x1=x1*odg+bias
     local m0,m1=x0>>31,x1>>31
     if (x0^^m0>1.5) x0=1.5^^m0
     if (x1^^m1>1.5) x1=1.5^^m1
     local diff=(odgi*(x0+x1-bias-bias-0.148148*(1+bias)*(x0*x0*x0+x1*x1*x1-bias3x2))-pre)>>1
     local err=diff-hpf
     tmp[i]=(tmp_i+err)*slev
     hpf+=err>>8
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
  th=_th,
  update=function(self,b,first,last)
   src:update(b,first,last)
   local env,att,rel=_env,_att,_rel
   local th,ratio=self.th,1/_ratio
   -- makeup targets 0.6
   local makeup=max(1,0.6/((0.6-th)*ratio+th))
   for i=first,last do
    local s=b[i]
    local x=s^^(s>>31)
    env+=(x>env and att or rel)*(x-env)
    local g,te=makeup,th/(env+0x0.0010)
    if (env>th) g*=te+ratio-te*ratio
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
   r=r^0.25
   _rc=1-r*0.96
   local svf_pat=svf_pats[patch[69]]
   local pat_val=ord(svf_pat,(bar*16+tick-17)%#svf_pat+1)-48
   if (pat_val>=0 and state.playing) _fe=pat_val>>4
   _dec=1-((1-dec)*(1-dec)>>7)
   _gc_base=pow3(gc_base)*0x0.fc+0x0.04
   _gc_range=pow3(amt)*(1-_gc_base)
  end,
  update=function(self,b,first,last)
   local z1,z2,rc,gc_base,gc_range,fe,gc,is_lp,dec=_z1,_z2,_rc,_gc_base,_gc_range,_fe,_gc,_bp==0,_dec
   local rc1=rc<<1
   for i=first,last do
    gc+=(gc_base+gc_range*fe-gc)>>2
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

