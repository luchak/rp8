pico-8 cartridge // http://www.pico-8.com
version 35
__lua__
#include utils.lua

function _draw()
cls()
var1=10
var2=15
print(eval('(+,4,6)'))
print('hi2')
print(eval('(+,$var1,$var2)'))
eval('(print hello)')
--dbl=eval([[(fn,(x),(*,$x,2))]])
--eval([[(defun dbl (x) (*,$x,2))]])
eval([[(set dbl (fn (x) (* $x 2)))]])
print(type(dbl))
print('q'..dbl(dbl(3)))
print('r'..eval('(dbl 3)'))
px=eval('(fn (str) (print $str))')
eval[[($foreach (' (q r x)) $print)]]
--foreach(parse('(q,r,x)'), print)
tbl={a=5,b=7}
hm=eval('(@ $tbl b)')
print(hm)
eval('(for 61 63 $print)')
eval('(set myvar helloworld)')
print(myvar)

eval('(let myvar3 bye) (print $myvar3) (set myvar4 huh)')
print(myvar3)
print(myvar4)

eval('(print (+ 4 5))')


eval('(for 71 72 (fn (x) (print (* 0.5 $x))))')
end

__gfx__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
