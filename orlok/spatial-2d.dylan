module: spatial-2d
author: Andrew Glynn
copyright: copyright: See LICENSE file in this distribution.


// Simple base class for objects with a 2D spatial transform.

define abstract class <spatial-2d> (<object>)
  virtual slot pos-x    :: <single-float>;
  virtual slot pos-y    :: <single-float>;
  virtual slot pos      :: <vec2>;
  virtual slot scale-x  :: <single-float>;
  virtual slot scale-y  :: <single-float>;
  virtual slot scale    :: <vec2>;
  virtual slot rotation :: <single-float>;

  constant slot %pos      :: <vec2>         = vec2(0.0, 0.0);
  constant slot %scale    :: <vec2>         = vec2(1.0, 1.0);
  slot          %rotation :: <single-float> = 0.0;
  slot          %dirty?   :: <boolean>      = #f;

  constant slot %cached-transform :: <affine-transform-2d>
    = make(<affine-transform-2d>);
end;

define method initialize (s :: <spatial-2d>,
                          #key pos-x: tx = 0.0,
                               pos-y: ty = 0.0,
                               pos = #f,
                               scale-x: sx = 1.0,
                               scale-y: sy = 1.0,
                               scale = #f,
                               rotation = 0.0)
  next-method();

  if (pos)
    s.%pos.xy := pos;
  else
    s.%pos.vx := as(<single-float>, tx);
    s.%pos.vy := as(<single-float>, ty);
  end;

  if (scale)
    s.%scale.xy := scale;
  else
    s.%scale.vx := as(<single-float>, sx);
    s.%scale.vy := as(<single-float>, sy);
  end;

  s.%rotation := as(<single-float>, rotation);

  if (~has-identity-transform?(s))
    s.%dirty? := #t;
  end;
end;

//============================================================================
//----------    Virtual Slots    ----------
//
// Note that for the virtual slots of type <single-float> we provide methods
// on <real> (which perform conversion to <single-float>) as a convenience.
//============================================================================

define method pos-x (s :: <spatial-2d>) => (x :: <single-float>)
  s.%pos.vx
end;

define method pos-x-setter (new-x :: <single-float>, s :: <spatial-2d>)
 => (new-x :: <single-float>)
  s.%dirty? := #t;
  s.%pos.vx := new-x;
end;

define method pos-x-setter (new-x :: <real>, s :: <spatial-2d>)
 => (new-x :: <real>)
  s.%dirty? := #t;
  s.%pos.vx := as(<single-float>, new-x);
end;

define method pos-y (s :: <spatial-2d>) => (y :: <single-float>)
  s.%pos.vy
end;

define method pos-y-setter (new-y :: <single-float>, s :: <spatial-2d>)
 => (new-y :: <single-float>)
  s.%dirty? := #t;
  s.%pos.vy := new-y;
end;

define method pos-y-setter (new-y :: <real>, s :: <spatial-2d>)
 => (new-y :: <real>)
  s.%dirty? := #t;
  s.%pos.vy := as(<single-float>, new-y);
end;

define method pos (s :: <spatial-2d>) => (t :: <vec2>)
  s.%pos.xy
end;

define method pos-setter (new-t :: <vec2>, s :: <spatial-2d>)
 => (new-t :: <vec2>)
  s.%dirty? := #t;
  s.%pos.xy := new-t;
  new-t
end;

define method scale-x (s :: <spatial-2d>) => (sx :: <single-float>)
  s.%scale.vx
end;

define method scale-x-setter (new-sx :: <single-float>,
                              s :: <spatial-2d>)
 => (new-sx :: <single-float>)
  s.%dirty?   := #t;
  s.%scale.vx := new-sx;
end;

define method scale-x-setter (new-sx :: <real>,
                              s :: <spatial-2d>)
 => (new-sx :: <real>)
  s.%dirty?   := #t;
  s.%scale.vx := as(<single-float>, new-sx);
end;

define method scale-y (s :: <spatial-2d>) => (sy :: <single-float>)
  s.%scale.vy
end;

define method scale-y-setter (new-sy :: <single-float>,
                              s :: <spatial-2d>)
 => (new-sy :: <single-float>)
  s.%dirty?   := #t;
  s.%scale.vy := new-sy;
end;

define method scale-y-setter (new-sy :: <real>,
                              s :: <spatial-2d>)
 => (new-sy :: <real>)
  s.%dirty?   := #t;
  s.%scale.vy := as(<single-float>, new-sy);
end;

define method scale (s :: <spatial-2d>) => (s :: <vec2>)
  s.%scale.xy
end;

define method scale-setter (new-s :: <vec2>,
                            s :: <spatial-2d>)
 => (new-s :: <vec2>)
  s.%dirty?   := #t;
  s.%scale.xy := new-s;
  new-s
end;

define method rotation (s :: <spatial-2d>) => (angle :: <single-float>)
  s.%rotation
end;

define method rotation-setter(new-angle :: <single-float>,
                              s :: <spatial-2d>)
 => (new-angle :: <single-float>)
  s.%dirty?   := #t;
  s.%rotation := new-angle;
end;

define method rotation-setter(new-angle :: <real>,
                              s :: <spatial-2d>)
 => (new-angle :: <real>)
  s.%dirty?   := #t;
  s.%rotation := as(<single-float>, new-angle);
end;

//============================================================================
//----------    Utilities and Helpers    ----------
//============================================================================

define method has-identity-transform? (s :: <spatial-2d>)
 => (identity? :: <boolean>)
  s.pos-x    == 0.0 & s.pos-y   == 0.0 &
  s.scale-x  == 1.0 & s.scale-y == 1.0 &
  s.rotation == 0.0
end;

// Get an <affine-transform-2d> representing the transformation defined
// by a <spatial-2d>.
// The result is not freshly allocated, and should not be modified.
define method transform-2d (s :: <spatial-2d>)
 => (a :: <affine-transform-2d>)
  if (s.%dirty?)
    %update-cached-transform(s);
  end;

  s.%cached-transform
end;

define method has-invertible-transform? (s :: <spatial-2d>)
 => (invertible? :: <boolean>)
  s.scale-x ~= 0.0 & s.scale-y ~= 0.0
end;

// Get the inverse of a <spatial-2d>'s transform.
define method inverse-transform-2d (s :: <spatial-2d>)
 => (inv-t :: <affine-transform-2d>)
  if (~s.has-invertible-transform?)
    orlok-error("transform is not invertible");
  end;

  let inv = make(<affine-transform-2d>);
  if (s.%scale.vx ~= 1.0 | s.%scale.vy ~= 1.0)
    scale!(inv, 1.0 / s.%scale);
  end;
  if (s.%rotation ~= 0.0)
    rotate!(inv, -s.%rotation);
  end;
  if (s.%pos.vx ~= 0.0 | s.%pos.vy ~= 0.0)
    translate!(inv, -s.%pos);
  end;
  inv
end;

define function %update-cached-transform (s :: <spatial-2d>) => ()
  let t = s.%cached-transform;
  set-identity!(t);
  if (s.pos-x ~= 0.0 | s.pos-y ~= 0.0)
    translate!(t, s.%pos);
  end;
  if (s.rotation ~= 0.0)
    rotate!(t, s.%rotation);
  end;
  if (s.scale-x ~= 1.0 | s.scale-y ~= 1.0)
    scale!(t, s.%scale);
  end;
  s.%dirty? := #f;
end;

