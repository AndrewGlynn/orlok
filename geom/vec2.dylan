module: vec2
author: Andrew Glynn
copyright: See LICENSE file in this distribution.

// The x and y components are named vx and vy since using just x and y
// would be error prone given Dylan's flat namespace, and using a longer name
// like vector-x would just annoy me.
// Note that these are declared as open generics to allow other types to
// act like a <vec2> if that seems convenient.

define open generic vx (obj) => (x :: <single-float>);
define open generic vy (obj) => (y :: <single-float>);

define open generic vx-setter (new-x :: <single-float>, obj)
    => (new-x :: <single-float>);
define open generic vy-setter (new-y :: <single-float>, obj)
    => (new-y :: <single-float>);

// Basic 2D vector class. This library does not attempt to be strict about
// the difference between vectors and points, so <vec2> is generally used to
// define points.
define class <vec2> (<object>)
  sealed slot vx :: <single-float> = 0.0, init-keyword: x:;
  sealed slot vy :: <single-float> = 0.0, init-keyword: y:;
end;

define sealed domain make (singleton(<vec2>));

// Convenience constructor function.
define generic vec2 (x :: <real>, y :: <real>) => (v :: <vec2>);

define inline method vec2(x :: <single-float>, y :: <single-float>)
 => (v :: <vec2>)
  make(<vec2>, x: x, y: y)
end;

define inline method vec2(x :: <real>, y :: <real>)
 => (v :: <vec2>)
  make(<vec2>, x: as(<single-float>, x), y: as(<single-float>, y))
end;

define sealed method shallow-copy (v :: <vec2>) => (copy :: <vec2>)
  vec2(v.vx, v.vy)
end;

// This just returns a copy of v.
define inline sealed method xy (v :: <vec2>) => (v-copy ::  <vec2>)
  vec2(v.vx, v.vy)
end;

// Useful for making dst into a copy of src.
define inline sealed method xy-setter (src :: <vec2>, dst :: <vec2>)
    => (src :: <vec2>)
  dst.vx := src.vx;
  dst.vy := src.vy;
  src
end;

// Return a <vec2> like v with its x and y swapped.
define inline sealed method yx (v :: <vec2>) => (v-copy ::  <vec2>)
  vec2(v.vy, v.vx)
end;

// Copy src's x into dst's y and src's y into dst's x.
define inline sealed method yx-setter (src :: <vec2>, dst :: <vec2>)
    => (src :: <vec2>)
  dst.vy := src.vx;
  dst.vx := src.vy;
  src
end;

define sealed inline method distance-squared (a :: <vec2>, b :: <vec2>)
    => (d2 :: <single-float>)
  let dx = b.vx - a.vx;
  let dy = b.vy - a.vy;

  (dx * dx) + (dy * dy)
end;

define sealed method distance (a :: <vec2>, b :: <vec2>)
    => (d :: <single-float>)
  sqrt(distance-squared(a, b))
end;

define sealed inline method magnitude-squared (v :: <vec2>)
    => (m2 :: <single-float>)
  (v.vx * v.vx) + (v.vy * v.vy)
end;

define sealed method magnitude (v :: <vec2>) => (m :: <single-float>)
  sqrt(magnitude-squared(v))
end;

define sealed method \+ (a :: <vec2>, b :: <vec2>) => (c :: <vec2>)
  vec2(a.vx + b.vx, a.vy + b.vy)
end;

define sealed method \- (a :: <vec2>, b :: <vec2>) => (c :: <vec2>)
  vec2(a.vx - b.vx, a.vy - b.vy)
end;

define sealed method negative (a :: <vec2>) => (b :: <vec2>)
  vec2(-a.vx, -a.vy)
end;

define sealed method \* (a :: <vec2>, b :: <single-float>) => (c :: <vec2>)
  vec2(a.vx * b, a.vy * b)
end;

define sealed method \* (a :: <single-float>, b :: <vec2>) => (c :: <vec2>)
  vec2(b.vx * a, b.vy * a)
end;

define sealed method \/ (a :: <vec2>, b :: <single-float>) => (c :: <vec2>)
  vec2(a.vx / b, a.vy / b)
end;

define sealed method \/ (a :: <single-float>, b :: <vec2>) => (c :: <vec2>)
  vec2(a / b.vx, a / b.vy)
end;

define inline sealed method dot (a :: <vec2>, b :: <vec2>)
    => (d :: <single-float>)
  (a.vx * b.vx) + (a.vy * b.vy)
end;

// Not really a cross-product (since it is not defined in 2D). Rather, the
// z-value of the 3D cross product of a and b extended to 3D with implicit z=0.
define sealed inline method cross (a :: <vec2>, b :: <vec2>)
    => (c :: <single-float>)
  (a.vx * b.vy) - (a.vy * b.vx)
end;


// TODO: The #key is to allow for adding an epsilon factor to avoid problems
// with zero-length vectors, but do I really care? Currently this is used in
// vec3 but not vec2, hence the ugliness here.
define generic unitize(object, #key)  => (u :: <object>);
define generic unitize!(object, #key) => (u :: <object>);

// Return a unit-length version of v.
// PRE: magnitude(v) ~= 0
define sealed method unitize (v :: <vec2>, #key) => (u :: <vec2>)
  v / magnitude(v)
end;

// Make v unit-length.
// PRE: magnitude(v) ~= 0
define sealed method unitize! (v :: <vec2>, #key) => (v :: <vec2>)
  let m = magnitude(v);
  v.vx := v.vx / m;
  v.vy := v.vy / m;
  v
end;

// 90-degree clockwise rotation
define sealed method turn-cw (v :: <vec2>) => (v2 :: <vec2>)
  vec2(v.vy, -v.vx)
end;

// 90-degree counter-clockwise rotation
define sealed method turn-ccw (v :: <vec2>) => (v2 :: <vec2>)
  vec2(-v.vy, v.vx)
end;

define constant $origin-2d = vec2(0.0, 0.0);

// Return a new vector equivalent to v rotated about pivot by the
// given radians.
define sealed method rotate-vec (v          :: <vec2>,
                                 radians    :: <single-float>,
                                 #key pivot :: <vec2> = $origin-2d)
    => (v2 :: <vec2>)
  let rv = v - pivot;
  rv := vec2(rv.vx * cos(radians) - rv.vy * sin(radians),
             rv.vx * sin(radians) + rv.vy * cos(radians));
  rv + pivot
end;

// Rotate v around pivot by the given radians.
define sealed method rotate-vec! (v          :: <vec2>,
                                  radians    :: <single-float>,
                                  #key pivot :: <vec2> = $origin-2d)
    => (v :: <vec2>)
  let x = v.vx - pivot.vx;
  let y = v.vy - pivot.vy;

  v.vx := x * cos(radians) - y * sin(radians);
  v.vy := x * sin(radians) + y * cos(radians);

  v.vx := v.vx + pivot.vx;
  v.vy := v.vy + pivot.vy;
  v
end;

// Get the angle of v with respect to the given origin.
define sealed method angle-of (v :: <vec2>, #key origin :: <vec2> = $origin-2d)
    => (angle :: <single-float>)
  atan2(v.vy - origin.vy, v.vx - origin.vx)
end;

// Return the point between a and b determined by the ratio t.
// If t=0, the result is identical to a, t=1 is b, etc.
define sealed method linear-interpolated (a :: <vec2>,
                                          b :: <vec2>,
                                          t :: <single-float>) => (c :: <vec2>)
  (a * (1.0 - t)) + (b * t)
end;

define sealed method midpoint (a :: <vec2>, b :: <vec2>) => (c :: <vec2>)
  linear-interpolated(a, b, 0.5)
end;

// Find the projection of v onto the axis specified by unit-axis
// (which must be unit-length) as well as the axis perpendicular to
// unit-axis.
define sealed method decompose-on-axis
    (v :: <vec2>, unit-axis :: <vec2>)
    => (parallel-to-axis      :: <single-float>,
        perpendicular-to-axis :: <single-float>)
  values(dot(v, unit-axis),
         dot(v, turn-ccw(unit-axis)))
end;
