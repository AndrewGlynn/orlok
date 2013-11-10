module: dylan-user
author: Andrew Glynn
copyright: See LICENSE file in this distribution.

define library geom
  use common-dylan;

  // 2D geometry

  export vec2;
  export line2;
  export transform2;
  export alignment;
  export circle;
  export rect;
  export geom2; // bundles up all 2d modules
end library geom;

define module distance
  use common-dylan;

  create
    distance,
    distance-squared,
    magnitude,
    magnitude-squared;
end module distance;

define module transform
  use common-dylan;

  export
    identity?,
    translate!,
    rotate!,
    scale!,
    shear!,
    transform-components;
end;

define module shapes
  use common-dylan;

  create
    intersects?,
    center, center-setter;
end;

define module vec2
  use common-dylan;
  use transcendentals;
  use distance, export: all;

  export
    <vec2>,
    vec2,
    vx, vx-setter,
    vy, vy-setter,
    xy, xy-setter,
    yx, yx-setter,
    scale-vec, scale-vec!,
    dot,
    cross,
    unitize, unitize!,
    turn-cw,
    turn-ccw,
    rotate-vec, rotate-vec!,
    angle-of,
    linear-interpolated,
    midpoint,
    decompose-on-axis;
end module vec2;

define module line2
  use common-dylan;
  use vec2;

  export
    <linear-component-2d>,
    <line-2d>,
    <ray-2d>,
    <line-segment-2d>,
    from-point, from-point-setter,
    to-point, to-point-setter,
    segments-intersect?;
end module line2;

define module transform2
  use common-dylan;
  use transcendentals;
  use vec2;
  use transform, export: all;

  export
    <affine-transform-2d>,
    set-identity!,
    transform,
    transform!,
    matrix-components,
    rotation-about-point;
end module transform2;

define module alignment
    use common-dylan;
    use vec2;
    
    export
      <alignment>,
      $left-top, $left-bottom, $left-center,
      $right-top, $right-bottom, $right-center,
      $center-top, $center-bottom, $center,

      <h-alignment>,
      $left, $right, $h-center,

      <v-alignment>,
      $top, $bottom, $v-center,

      align,
      h-align,
      v-align,
      alignment-offset,

      align-object,
      object-alignment-offset;
end;


define module circle
  use common-dylan;
  use vec2;
  use shapes, export: all;

  export
    <circle>,
    radius, radius-setter;
end;

define module rect
  use common-dylan;
  use vec2;
  use transform2;
  use alignment;
  use shapes, export: all;

  export
    <rect>,
    width,
    height,
    left, left-setter,
    right, right-setter,
    top, top-setter,
    bottom, bottom-setter,

    left-top, left-top-setter,
    left-bottom, left-bottom-setter,
    right-top, right-top-setter,
    right-bottom, right-bottom-setter,

    center-x, center-x-setter,
    center-y, center-y-setter,

    left-center,
    right-center,
    center-top,
    center-bottom,

    rect-size,
    rect-intersection,
    rect-union,
    bound-points-with-rect,
    expand-rect!, expand-rect,
    rect-corners,
    move-rect,
    transform-rect;
end;

define module intersection
  use common-dylan;
  use vec2;
  use circle;
  use rect;
  use shapes;
end;

define module geom2
  use common-dylan;
  use vec2, export: all;
  use line2, export: all;
  use transform2, export: all;
  use circle, export: all;
  use rect, export: all;
  use alignment, export: all;
end module;

