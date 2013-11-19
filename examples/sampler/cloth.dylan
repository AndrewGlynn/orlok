module: sampler
author: Andrew Glynn
copyright: See LICENSE file in this distribution.
synopsis: Simple Jakobsen-style cloth physics simulation.

//============================================================================
// particles, systems
//============================================================================

// Optimize: Maybe profile and see if splitting out into parallel arrays of
// coordinates/etc within <system> is faster
define class <particle> (<object>)
  // TODO: (BUG?) I can't use 'pos' for the slot name here, even if it is
  //       declared open in orlok/spatial-2d! Why?
  slot loc :: <vec2>, required-init-keyword: loc:;
  slot old-loc :: <vec2> = vec2(0, 0), required-init-keyword: old-loc:;
  slot inv-mass :: <single-float>, required-init-keyword: inv-mass:;
  slot accel :: <vec2> = vec2(0, 0);
end;

define sealed method initialize (p :: <particle>, #key loc: pp, old-loc: old)
  next-method();
  if (~old)
    p.old-loc.xy := p.loc.xy;
  end;
end;

define abstract class <constraint> (<object>)
end;

define generic satisfy (c :: <constraint>) => ();

define class <system> (<object>)
  constant slot particles :: <stretchy-vector> = make(<stretchy-vector>);
  constant slot constraints :: <stretchy-vector> = make(<stretchy-vector>);
  slot relaxation-steps :: <integer> = 1;
  // TODO: If I make this init-keyword required, and then actually pass it
  // into the call to make, I get a missing init keyword #"gravity" error!!!
  // Why? Am I being stupid, or is this a compiler bug?
  // UPDATE: It's only if the *value* of the init arg is a "define constant"
  // which is itself a vec2. Not sure what this means.
  slot gravity :: <vec2>, required-init-keyword: gravity:;
end;

define function add-particle (s :: <system>, p :: <particle>)
 => (p :: <particle>)
  add!(s.particles, p);
  p
end;

define function add-constraint (s :: <system>, c :: <constraint>)
 => (c :: <constraint>)
  add!(s.constraints, c);
  c
end;

define function remove-constraint (s :: <system>, c :: <constraint>)
 => ()
  remove!(s.constraints, c);
end;


define method update-system (s :: <system>, dt :: <single-float>) => ()
  accumulate-forces(s);
  verlet-integrate(s, dt);
  satisfy-constraints(s);
end;

define generic accumulate-forces (s :: <system>) => ();

define method accumulate-forces (s :: <system>) => ()
  for (p in s.particles)
    p.accel := s.gravity;
  end;
end;

define method verlet-integrate (s :: <system>, dt :: <single-float>) => ()
  // Note: A version of this that unwraps all the vector operations to avoid
  // allocations does improve performance, but not by a tremendous amount.
  // The constraint satisfaction code is much more critical.
  for (p in s.particles)
    let temp = p.loc.xy;
    p.loc := p.loc + (p.loc - p.old-loc) + (p.accel * dt * dt);
    p.old-loc.xy := temp;
  end;
end;

define method satisfy-constraints (s :: <system>) => ()
  for (i from 0 below s.relaxation-steps)
    for (c in s.constraints)
      satisfy(c);
    end;
  end;
end;

//============================================================================
// constraints
//============================================================================

define class <pin-constraint> (<constraint>)
  constant slot particle :: <particle>, required-init-keyword: particle:;
  constant slot pin-loc :: <vec2>, required-init-keyword: pin-loc:;
end;

define sealed method satisfy (p :: <pin-constraint>) => ()
  // just move the particle to its pinned location
  p.particle.loc := p.pin-loc.xy;
end;

define class <stick-constraint> (<constraint>)
  constant slot particle-a :: <particle>, required-init-keyword: from:;
  constant slot particle-b :: <particle>, required-init-keyword: to:;
  constant slot stick-length :: <single-float>, required-init-keyword: length:;
end;

define sealed method satisfy (s :: <stick-constraint>) => ()
  // Move particles a and b so that their distance matches s.stick-length.
  // The masses of the particles determine how far each has to move.

  let a = s.particle-a;
  let b = s.particle-b;

// TODO: Using <vec2> operations is way too slow. Need to figure out if I can
//       optimize this stuff enough. There are lots of implicit allocations in
//       this code, so it's not too surprising. For now we'll unwrap the vector
//       operations manually in order to get decent performance.

//  let delta = b.loc - a.loc;
//  let delta-length-squared = delta.magnitude-squared;
//  let length-squared = s.stick-length * s.stick-length;
//  let scale = (length-squared / (delta-length-squared + length-squared)) - 0.5;
//
//  let delta-a = (delta * scale * a.inv-mass);
//  let delta-b = (delta * scale * b.inv-mass);
//
//  s.particle-a.loc.xy := a.loc - delta-a;
//  s.particle-b.loc.xy := b.loc + delta-b;

  //------

  let ax = a.loc.vx;
  let ay = a.loc.vy;
  let bx = b.loc.vx;
  let by = b.loc.vy;
  let dx = bx - ax;
  let dy = by - ay;
  let dl2 = (dx * dx + dy * dy);
  let len2 = s.stick-length * s.stick-length;
  let scale = (len2 / (dl2 + len2)) - 0.5;
  let dxa = dx * scale * a.inv-mass;
  let dya = dy * scale * a.inv-mass;
  let dxb = dx * scale * b.inv-mass;
  let dyb = dy * scale * b.inv-mass;

  s.particle-a.loc.vx := ax - dxa;
  s.particle-a.loc.vy := ay - dya;
  s.particle-b.loc.vx := bx + dxb;
  s.particle-b.loc.vy := by + dyb;
end;

//============================================================================
// cloth
//============================================================================

define constant $particle-mass = 1.0;
define constant $inv-particle-mass = 1.0 / $particle-mass;
define constant $spacing = 10.0;
define constant $g = 900.0;

define function cloth (columns :: <integer>, rows :: <integer>)
 => (s :: <system>)
  let s = make(<system>, gravity: vec2(0, $g));

  // iterate the constraint satisfaction a few times so make cloth a bit stiffer
  s.relaxation-steps := 5;

  // copy particles into a 2D array for ease of addressing
  let ps = make(<array>, dimensions: vector(columns, rows));

  let start-x = (the-app().config.app-width / 2.0) - (columns * $spacing / 2.0);
  let start-y = 80.0;

  for (col from 0 below columns)
    for (row from 0 below rows)
      let p = make(<particle>,
                   loc: vec2(start-x + col * $spacing,
                             start-y + row * $spacing),
                   inv-mass: $inv-particle-mass);
      ps[col, row] := p;
      add-particle(s, p);
    end;
  end;

  // connect each particle to its horizontal and vertical neighbors
  for (col from 0 below columns)
    for (row from 0 below rows)
      if (col < columns - 1)
        add-constraint(s, make(<stick-constraint>,
                               from: ps[col, row],
                               to: ps[col + 1, row],
                               length: $spacing));
      end;
      if (row < rows - 1)
        add-constraint(s, make(<stick-constraint>,
                               from: ps[col, row],
                               to: ps[col, row + 1],
                               length: $spacing));
      end;

      // pin top row
      if (row == 0)
        add-constraint(s, make(<pin-constraint>,
                               particle: ps[col, row],
                               pin-loc: vec2(start-x + col * $spacing, start-y)));
      end;
    end;
  end;

  s;
end;

define function render-cloth (ren :: <renderer>, sys :: <system>) => ()
  for (c in sys.constraints)
    if (instance?(c, <stick-constraint>))
      draw-line(ren, c.particle-a.loc, c.particle-b.loc, $gray, 1.0);
    end;
  end;
end;

define function grab-nearby-particle (sys :: <system>, v :: <vec2>)
 => (p :: false-or(<particle>))
  // slow...could use distance-squared
  let min-distance = 1000000.0;
  let result = #f;
  for (p in sys.particles)
    let d = distance(p.loc, v);
    if (d < min-distance & d < $spacing)
      result := p;
      min-distance := d;
    end;
  end;

  result
end;
