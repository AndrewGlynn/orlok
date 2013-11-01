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

define method intersects? (a :: <circle>, b :: <circle>)
 => (intersection? :: <boolean>)
  distance-squared(a.center, b.center) < (a.radius + b.radius) ^ 2
end;

define method intersects? (c :: <circle>, v :: <vec2>)
 => (intersection? :: <boolean>)
  distance-squared(c.center, v) < (c.radius ^ 2)
end;

define method intersects? (v :: <vec2>, c :: <circle>)
 => (intersection? :: <boolean>)
  intersects?(c, v)
end;


