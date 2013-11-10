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

