module: transform2
author: Andrew Glynn
copyright: copyright: See LICENSE file in this distribution.

// We represent the 3x3 homogeneous matrix like this (also includes an example
// of multiplying a vector by the matrix):
//
//     sx shx  tx     x       x*sx  + y*shx + 1*tx
//    shy  sy  ty     y   =   x*shy + y*sy  + 1*ty
//      0   0   1     1       x*0   + y*0   + 1*1

define class <affine-transform-2d> (<object>)
  slot sx  :: <single-float> = 1.0, init-keyword: sx:;
  slot shy :: <single-float> = 0.0, init-keyword: shy:;
  slot shx :: <single-float> = 0.0, init-keyword: shx:;
  slot sy  :: <single-float> = 1.0, init-keyword: sy:;
  slot tx  :: <single-float> = 0.0, init-keyword: tx:;
  slot ty  :: <single-float> = 0.0, init-keyword: ty:;
end;

define sealed domain make (singleton(<affine-transform-2d>));

define sealed method shallow-copy (t :: <affine-transform-2d>)
    => (copy :: <affine-transform-2d>)
  make(<affine-transform-2d>,
       sx:  t.sx,
       shy: t.shy,
       shx: t.shx,
       sy:  t.sy,
       tx:  t.tx,
       ty:  t.ty)
end;

define method transform-components (t :: <affine-transform-2d>)
 => (sx :: <single-float>, shy :: <single-float>, shx :: <single-float>,
     sy :: <single-float>, tx :: <single-float>, ty :: <single-float>)
  values(t.sx, t.shy, t.shx, t.sy, t.tx, t.ty)
end;

// Multiply a and b, placing the result in c (avoids allocating c).
// Note that c must not be == to a or b.
define inline function mat-mult (a :: <affine-transform-2d>,
                                 b :: <affine-transform-2d>,
                                 c :: <affine-transform-2d>) => ()
  c.sx  := (a.sx  * b.sx)  + (a.shy * b.shx);
  c.shy := (a.sx  * b.shy) + (a.shy * b.sy);
  c.shx := (a.shx * b.sx)  + (a.sy  * b.shx);
  c.sy  := (a.shx * b.shy) + (a.sy  * b.sy);
  c.tx  := (a.tx  * b.sx)  + (a.ty  * b.shx) + b.tx;
  c.ty  := (a.tx  * b.shy) + (a.ty  * b.sy)  + b.ty;
end;

// Multiply a and b, placing the result back in b.
define inline function mat-concat (a :: <affine-transform-2d>,
                                   b :: <affine-transform-2d>) => ()

  let new-sx  = (a.sx  * b.sx)  + (a.shy * b.shx);
  let new-shy = (a.sx  * b.shy) + (a.shy * b.sy);
  let new-shx = (a.shx * b.sx)  + (a.sy  * b.shx);
  let new-sy  = (a.shx * b.shy) + (a.sy  * b.sy);
  let new-tx  = (a.tx  * b.sx)  + (a.ty  * b.shx) + b.tx;
  let new-ty  = (a.tx  * b.shy) + (a.ty  * b.sy)  + b.ty;

  b.sx  := new-sx;
  b.shy := new-shy;
  b.shx := new-shx;
  b.sy  := new-sy;
  b.tx  := new-tx;
  b.ty  := new-ty;
end;

define sealed method \* (a :: <affine-transform-2d>, b :: <affine-transform-2d>)
 => (c :: <affine-transform-2d>)
  let c = make(<affine-transform-2d>);
  mat-mult(a, b, c);
  c
end;

define method set-identity! (t :: <affine-transform-2d>)
    => (t :: <affine-transform-2d>)
  t.sx  := 1.0;
  t.shy := 0.0;
  t.shx := 0.0;
  t.sy  := 1.0;
  t.tx  := 0.0;
  t.ty  := 0.0;
  t
end;

define sealed method identity? (t :: <affine-transform-2d>)
 => (_ :: <boolean>)
  t.sx  == 1.0 & t.sy  == 1.0 &
  t.shx == 0.0 & t.shy == 0.0 &
  t.tx  == 0.0 & t.ty  == 0.0
end;

define sealed method translate! (t :: <affine-transform-2d>, v :: <vec2>)
 => (t :: <affine-transform-2d>)
  let trans = make(<affine-transform-2d>,
                   tx: v.vx,
                   ty: v.vy);
  mat-concat(trans, t);
  t
end;

define sealed method rotate! (t :: <affine-transform-2d>, angle :: <single-float>)
 => (t :: <affine-transform-2d>)
  let cos-angle = as(<single-float>, cos(angle));
  let sin-angle = as(<single-float>, sin(angle));
  let rot = make(<affine-transform-2d>,
                 sx: cos-angle, shx: - sin-angle,
                 shy: sin-angle, sy: cos-angle);
  mat-concat(rot, t);
  t
end;

define sealed method scale! (t :: <affine-transform-2d>, s :: <vec2>)
 => (t :: <affine-transform-2d>)
  let scl = make(<affine-transform-2d>,
                 sx: s.vx,
                 sy: s.vy);
  mat-concat(scl, t);
  t
end;

// uniform scale
define sealed method scale! (t :: <affine-transform-2d>, s :: <single-float>)
    => (t :: <affine-transform-2d>)
  scale!(t, vec2(s, s))
end;

define sealed method shear! (t :: <affine-transform-2d>, sh :: <vec2>)
 => (t :: <affine-transform-2d>)
  let shr = make(<affine-transform-2d>,
                 shx: sh.vx,
                 shy: sh.vy);
  mat-concat(shr, t);
  t
end;

define method transform (v :: <vec2>, t :: <affine-transform-2d>)
 => (transformed-point :: <vec2>)
  vec2(v.vx * t.sx  + v.vy * t.shx + t.tx,
       v.vx * t.shy + v.vy * t.sy  + t.ty)
end;

define method transform! (v :: <vec2>, t :: <affine-transform-2d>)
 => (v :: <vec2>)
  let new-x = v.vx * t.sx  + v.vy * t.shx + t.tx;
  let new-y = v.vx * t.shy + v.vy * t.sy  + t.ty;

  v.vx := new-x;
  v.vy := new-y;
  v
end;

/*
define method invertible? (t :: <affine-transform-2d>) => (well? :: <boolean>)
  // TODO
  #f
end;

define method inverse (t :: <affine-transform-2d>) => (inv :: <affine-transform-2d>)
  if (~ invertible?(t))
    error("transform is not invertible");
  end;

  // TODO
  t;
end;
*/

define method matrix-components (t :: <affine-transform-2d>)
 => (sx, shy, w0, shx, sy, w1, tx, ty, w2)
  values(t.sx, t.shy, 0.0, t.shx, t.sy, 0.0, t.tx, t.ty, 1.0)
end;


// some helpers for common things

define function rotation-about-point (pt :: <vec2>, angle :: <real>)
 => (t :: <affine-transform-2d>)
  let t = make(<affine-transform-2d>);

  translate!(t, vec2(- pt.vx, - pt.vy));
  rotate!(t, angle);
  translate!(t, vec2(pt.vx, pt.vy));
  t;
end;


