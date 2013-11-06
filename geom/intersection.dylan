module: intersection

// Note: Intersection is not strict, so a point lying exactly on the
// edge of a shape is considered to be contained in the shape, etc.
// TODO: Is this the right option? Could add a strict? keyword arg...


define macro symmetric-method-definer
  {
    define ?adjectives:* symmetric-method ?:name (?a:variable, ?b:variable)
     => (?result:variable)
      ?:body
    end
  }
 =>
  {
    define ?adjectives method ?name (?a, ?b) => (?result)
      ?body
    end;

    define ?adjectives method ?name (?b, ?a) => (?result)
      ?body
    end;
  }
end;

define sealed symmetric-method intersects? (c :: <circle>, v :: <vec2>)
 => (intersection? :: <boolean>)
  distance-squared(c.center, v) <= (c.radius ^ 2)
end;

define sealed method intersects? (a :: <circle>, b :: <circle>)
 => (intersection? :: <boolean>)
  distance-squared(a.center, b.center) <= (a.radius + b.radius) ^ 2
end;

define sealed symmetric-method intersects? (r :: <rect>, pt :: <vec2>)
 => (intersection? :: <boolean>)
  pt.vx >= r.left  &
  pt.vx <= r.right &
  pt.vy >= r.top   &
  pt.vy <= r.bottom
end;

define method intersects? (a :: <rect>, b :: <rect>)
 => (intersection? :: <boolean>)
  a.left   <= b.right  &
  a.right  >= b.left   &
  a.top    <= b.bottom &
  a.bottom >= b.top
end;

define sealed symmetric-method intersects? (c :: <circle>, r :: <rect>)
=> (_ :: <boolean>)
  // find closest point to c in r
  let pt = c.center.xy;

  if (pt.vx < r.left)
    pt.vx := r.left;
  elseif (pt.vx > r.right)
    pt.vx := r.right;
  end;

  if (pt.vy < r.top)
    pt.vy := r.top;
  elseif (pt.vy > r.bottom)
    pt.vy := r.bottom;
  end;

  distance-squared(pt, c.center) <= (c.radius ^ 2)
end;



/*
define function gjk-intersects? (a, b) => (_ :: <boolean>)
  block (return)
    let dir = vec2(1, 0); // arbitrary starting direction
    let simplex = make(<stretchy-vector>);

    // add our first point
    let s = support(a, b, dir);
    add!(simplex, s);

    // point back toward the origin
    dir := -s;

    while (#t)
      s := support(a, b, dir);

      if (~same-direction(s, dir))
        return(#f);
      end;

      add!(simplex, s);

      if (do-simplex?(simplex, dir))
        return(#t);
      end;
    end;
  end block return;
end;

// Note that both simplex and dir may be modified by this function.
define function do-simplex?(simplex :: <vector>, dir :: <vec2>)
 => (_ :: <boolean>)
  // note: simplex will always have at least two points (a 1-simplex)
  if (simplex.size == 2)
    let a = simplex.last;
    let b = simplex.first;
    let ab = b - a; // vector from a to b
    let a0 = - a; // vector from a to origin

    if (same-direction?(ab, a0))
      dir.xy := turn-cw(ab); // perpendicular to ab
      dir.xy := dir * dot(-a, dir); // ensure points toward a0
    else
      simplex[0] := a;
      simplex.size := simplex.size - 1; // pop b
      dir.xy := a0; // prepare to try again in a new direction
    end;
  else
    debug-assert (simplex.size == 3);
  end;

  define function same-direction? (a :: <vec2>, b :: <vec2>) => (_ :: <boolean>)
    dot(s, dir) > 0.0
  end;

  define function support (a, b, dir)
    farthest-point-in-direction(a, dir) - farthest-point-in-direction(b, -dir)
  end;

  define generic farthest-point-in-direction (shape, dir :: <vec2>)
  => (pt :: <vec2>);

  define sealed method farthest-point-in-direction (pt :: <vec2>, dir :: <vec2>)
   => (pt :: <vec2>)
    pt
  end;

  define sealed method farthest-point-in-direction (c :: <circle>, dir :: <vec2>)
   => (pt :: <vec2>)
    // TODO: point on perimeter in direction dir
  end;

  define sealed method farthest-point-in-direction (r :: <rect>, dir :: <vec2>)
   => (pt :: <vec2>)
    // TODO: choose farthest corner
  end;

  // note: assumes p is convex (should I enforce this somewhere?)
  define sealed method farthest-point-in-direction (p :: <polygon>, dir :: <vec2>)
   => (pt :: <vec2>)
    // TODO: choose farthest point
  end;
*/


