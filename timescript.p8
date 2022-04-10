pico-8 cartridge // http://www.pico-8.com
version 35
__lua__
#include utils.lua

cls()

function ec(txt)
 return _es2(parse(txt))({})
end

script=[[(fn () (
(set var2 (+ (* $var1 (+ $var2 -5)) (* (+ $var2 0.1) 0.2)))
(set var2 (+ (* $var1 (+ $var2 -5)) (* (+ $var2 0.1) 0.2)))
(set var2 (+ (* $var1 (+ $var2 -5)) (* (+ $var2 0.1) 0.2)))
(set var2 (+ (* $var1 (+ $var2 -5)) (* (+ $var2 0.1) 0.2)))
(set var2 (+ (* $var1 (+ $var2 -5)) (* (+ $var2 0.1) 0.2)))
(set var2 (+ (* $var1 (+ $var2 -5)) (* (+ $var2 0.1) 0.2)))
(set var2 (+ (* $var1 (+ $var2 -5)) (* (+ $var2 0.1) 0.2)))
(set var2 (+ (* $var1 (+ $var2 -5)) (* (+ $var2 0.1) 0.2)))
(set var2 (+ (* $var1 (+ $var2 -5)) (* (+ $var2 0.1) 0.2)))
(set var2 (+ (* $var1 (+ $var2 -5)) (* (+ $var2 0.1) 0.2)))
))]]

fn_script=eval(script)

fn_compiled=ec(script)

fn_native=function()
 var2=var1*(var2-5)+(var2+0.1)*0.2
 var2=var1*(var2-5)+(var2+0.1)*0.2
 var2=var1*(var2-5)+(var2+0.1)*0.2
 var2=var1*(var2-5)+(var2+0.1)*0.2
 var2=var1*(var2-5)+(var2+0.1)*0.2
 var2=var1*(var2-5)+(var2+0.1)*0.2
 var2=var1*(var2-5)+(var2+0.1)*0.2
 var2=var1*(var2-5)+(var2+0.1)*0.2
 var2=var1*(var2-5)+(var2+0.1)*0.2
 var2=var1*(var2-5)+(var2+0.1)*0.2
end

t0=stat(1)
for i=1,100 do
 eval(script)
end
print(stat(1)-t0)

t0=stat(1)
for i=1,100 do
 ec(script)
end
print(stat(1)-t0)

print('check')
var1=10
var2=15
fn_script()
print(var2)
var1=10
var2=15
fn_compiled()
print(var2)
var1=10
var2=15
fn_native()
print(var2)

t0=stat(1)
for i=1,1000 do
 fn_script()
end
tint=stat(1)-t0

t0=stat(1)
for i=1,1000 do
 fn_compiled()
end
tcomp=stat(1)-t0

t0=stat(1)
for i=1,1000 do
 fn_native()
end
tnat=stat(1)-t0

print('int / native:  '..tostr(tint/tnat))
print('comp / native: '..tostr(tcomp/tnat))
print('int / comp:    '..tostr(tint/tcomp))

__gfx__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
