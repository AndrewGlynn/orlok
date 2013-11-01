module: line2
author: Andrew Glynn
copyright: copyright: See LICENSE file in this distribution.

define abstract class <linear-component-2d> (<object>)
  slot from-point :: <vec2>, required-init-keyword: from:;
  slot to-point   :: <vec2>, required-init-keyword: to:;
end;

define class <line-2d> (<linear-component-2d>)
end;

define class <ray-2d> (<linear-component-2d>)
end;

define class <line-segment-2d> (<linear-component-2d>)
end;

define function segments-intersect? (a :: <line-segment-2d>,
                                     b :: <line-segment-2d>)
 => (intersection? :: <boolean>)
  local direction (pi :: <vec2>, pj :: <vec2>, pk :: <vec2>)
         => (d :: <single-float>)
          cross(pk - pi, pj - pi)
        end;
  local on-segment? (pi :: <vec2>, pj :: <vec2>, pk :: <vec2>)
         => (_ :: <boolean>)
          min(pi.vx, pj.vx) <= pk.vx & pk.vx <= max(pi.vx, pj.vx) &
          min(pi.vy, pj.vy) <= pk.vy & pk.vy <= max(pi.vy, pj.vy)
        end;

  let p1 = a.from-point;
  let p2 = a.to-point;
  let p3 = a.from-point;
  let p4 = a.to-point;
  
  let d1 = direction(p3, p4, p1);
  let d2 = direction(p3, p4, p2);
  let d3 = direction(p1, p2, p3);
  let d4 = direction(p1, p2, p4);

  case
    ((d1 > 0.0 & d2 < 0.0) | (d1 < 0.0 & d2 > 0.0)) &
    ((d3 > 0.0 & d4 < 0.0) | (d3 < 0.0 & d4 > 0.0))
      => #t;
    d1 = 0.0 & on-segment?(p3, p4, p1)
      => #t;
    d2 = 0.0 & on-segment?(p3, p4, p2)
      => #t;
    d3 = 0.0 & on-segment?(p1, p2, p3)
      => #t;
    d4 = 0.0 & on-segment?(p1, p2, p4)
      => #t;
    otherwise
      => #f;
  end;
end;

