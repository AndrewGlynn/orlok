module: circle
author: Andrew Glynn
copyright: See LICENSE file in this distribution.

define class <circle> (<object>)
  slot vx     :: <single-float> = 0.0, init-keyword: x:;
  slot vy     :: <single-float> = 0.0, init-keyword: y:;
  slot radius :: <single-float> = 0.0, init-keyword: radius:;
end;

define method center (c :: <circle>) => (_ :: <vec2>)
  vec2(c.vx, c.vy)
end;



