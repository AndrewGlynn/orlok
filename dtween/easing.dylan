module: easing
author: Andrew Glynn
copyright: See LICENSE file in this distribution.

// Some standard easing functions.
// Note that all of these expect a normalized t between 0 and 1 inclusive.
// When t=0, the ease function should return 0, and when t=1 the
// ease function should return 1. Beyond that, they can do what they want.

define constant $half-pi :: <single-float> = 1.570796;

define inline function ease-linear (t :: <single-float>)
 => (result :: <single-float>)
  t
end;

define inline function ease-snap-in (t :: <single-float>)
 => (result :: <single-float>)
    1.0
end;

define inline function ease-snap-out (t :: <single-float>)
 => (result :: <single-float>)
  if (t >= 1.0)
    1.0
  else
    0.0
  end
end;

define inline function ease-in-quad (t :: <single-float>)
 => (result :: <single-float>)
  t * t
end;

define inline function ease-out-quad (t :: <single-float>)
 => (result :: <single-float>)
  -t * (t - 2.0)
end;

define inline function ease-in-cubic (t :: <single-float>)
 => (result :: <single-float>)
  t * t * t
end;

define inline function ease-out-cubic (t :: <single-float>)
 => (result :: <single-float>)
  let tt = t - 1.0;
  (tt * tt * tt) + 1.0
end;

define inline function ease-in-quartic (t :: <single-float>)
 => (result :: <single-float>)
  t * t * t * t
end;

define inline function ease-out-quartic (t :: <single-float>)
 => (result :: <single-float>)
  let tt = (t - 1.0);
  -((tt * tt * tt * tt) - 1.0)
end;

define inline function ease-in-quintic (t :: <single-float>)
 => (result :: <single-float>)
  t * t * t * t * t
end;

define inline function ease-out-quintic (t :: <single-float>)
 => (result :: <single-float>)
  let tt = (t - 1.0);
  (tt * tt * tt * tt * tt) + 1.0
end;

define inline function ease-out-sine (t :: <single-float>)
 => (result :: <single-float>)
  sin(t * $half-pi)
end;

define inline function ease-in-sine (t :: <single-float>)
 => (result :: <single-float>)
  1.0 - cos(t * $half-pi)
end;

// etc: circ, elastic, back, bounce

// Macro to make defining in-out ease functions simpler.
// You could also use this to create out-in easing functions, or strange
// combinations like in-quad-out-circle, etc.
define macro split-ease-function-definer
  { define split-ease-function ?:name (?ease1:name, ?ease2:name) }
 =>
  {
    define inline function ?name (t :: <single-float>)
     => (result :: <single-float>)
      if (t <= 0.5)
        ?ease1(t * 2.0) / 2.0
      else
        (?ease2((t - 0.5) * 2.0) / 2.0) + 0.5
      end
    end
  }
end;

define split-ease-function ease-in-out-quad    (ease-in-quad,    ease-out-quad);
define split-ease-function ease-in-out-cubic   (ease-in-cubic,   ease-out-cubic);
define split-ease-function ease-in-out-quartic (ease-in-quartic, ease-out-quartic);
define split-ease-function ease-in-out-quintic (ease-in-quintic, ease-out-quintic);
define split-ease-function ease-in-out-sine    (ease-in-sine,    ease-out-sine);
