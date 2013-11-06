module: rect
author: Andrew Glynn
copyright: See LICENSE file in this distribution.

// These concepts are so widely applicable that we leave the generics
// wide open.
define open generic width  (obj) => (width  :: <real>);
define open generic height (obj) => (height :: <real>);

// Axis-aligned rectangle.
// Note: Per standard practice, y increases downwards, so bottom > top.
define class <rect> (<object>)
  virtual slot left   :: <single-float>;
  virtual slot right  :: <single-float>;
  virtual slot bottom :: <single-float>;
  virtual slot top    :: <single-float>;

  virtual constant slot width  :: <single-float>;
  virtual constant slot height :: <single-float>;

  virtual slot center-x :: <single-float>;
  virtual slot center-y :: <single-float>;
  
  virtual slot center       :: <vec2>;
  virtual slot left-bottom  :: <vec2>;
  virtual slot right-bottom :: <vec2>;
  virtual slot left-top     :: <vec2>;
  virtual slot right-top    :: <vec2>;

  slot %left   :: <single-float> = 0.0;
  slot %top    :: <single-float> = 0.0;
  slot %width  :: <single-float> = 0.0;
  slot %height :: <single-float> = 0.0;
end;

define method initialize (rect :: <rect>,
                          #key left:         l,
                               right:        r,
                               bottom:       b,
                               top:          t,
                               center-x:     cx,
                               center-y:     cy,
                               left-top:     lt,
                               right-top:    rt,
                               left-bottom:  lb,
                               right-bottom: rb,
                               center:       c,
                               width:        w,
                               height:       h,
                               size:         s)
  next-method();

  // Extract components from composite values, if supplied.
  // Note that this will overwrite the individual component keywords without
  // warning.
  if (s) w := s.vx;  h := s.vy; end;
  if (lt) l := lt.vx; t := lt.vy; end;
  if (rt) r := rt.vx; t := rt.vy; end;
  if (lb) l := lb.vx; b := lb.vy; end;
  if (rb) r := rb.vx; b := rb.vy; end;
  if (c) cx := c.vx; cy := c.vy; end;

  // Check for over- and under-specified rects. Essentially, we require
  // that exactly two keywords be specified for each axis (horizontal and
  // vertical).

  local method count (val)
                 if (val) 1 else 0 end
               end;

  let horz-count = count(l) + count(r) + count(cx) + count(w);
  let vert-count = count(b) + count(t) + count(cy) + count(h);

  if (horz-count > 2)
    error("<rect> is overspecified in the horizontal axis");
  end;
  if (horz-count < 2)
    error("<rect> is underspecified in the horizontal axis");
  end;
  if (vert-count > 2)
    error("<rect> is overspecified in the vertical axis");
  end;
  if (vert-count < 2)
    error("<rect> is underspecified in the vertical axis");
  end;

  // Set the easy values first.

  if (l) rect.left   := l; end;
  if (r) rect.right  := r; end;
  if (b) rect.bottom := b; end;
  if (t) rect.top    := t; end;

  // Then infer other values (if necessary).

  case
    l & cx => rect.right := rect.left  + (cx - rect.left) * 2.0;
    r & cx => rect.left  := rect.right - (rect.right - cx) * 2.0;
    l & w  => rect.right := rect.left  + w;
    r & w  => rect.left  := rect.right - w;
    otherwise => #f; // not a problem!
  end;

  case
    b & cy => rect.top    := rect.bottom - (rect.bottom - cy) * 2.0;
    t & cy => rect.bottom := rect.top + (cy - rect.top) * 2.0;
    b & h  => rect.top    := rect.bottom - h;
    t & h  => rect.bottom := rect.top + h;
    otherwise => #f; // not a problem!
  end;
end;

define sealed method shallow-copy (r :: <rect>) => (copy :: <rect>)
  make(<rect>,
       left:   r.left,
       bottom: r.bottom,
       width:  r.width,
       height: r.height)
end;

define method left (r :: <rect>) => (l :: <single-float>)
  r.%left
end;

define method left-setter (new :: <single-float>, r :: <rect>)
 => (new :: <single-float>)
  let new-width = (r.%left - new) + r.width;
  r.%width := new-width;
  r.%left  := new
end;

define method left-setter (new :: <real>, r :: <rect>)
 => (new :: <single-float>)
  r.%left := as(<single-float>, new)
end;

define method right (r :: <rect>) => (r :: <single-float>)
  r.left + r.width
end;

define method right-setter (new :: <single-float>, r :: <rect>)
 => (new :: <single-float>)
  r.%width := new - r.left;
  new
end;

define method right-setter (new :: <real>, r :: <rect>)
 => (new :: <single-float>)
  r.right := as(<single-float>, new)
end;

define method bottom (r :: <rect>) => (b :: <single-float>)
  r.top + r.height
end;

define method bottom-setter (new :: <single-float>, r :: <rect>)
 => (new :: <single-float>)
  r.%height := new - r.top;
  new
end;

define method bottom-setter (new :: <real>, r :: <rect>)
 => (new :: <single-float>)
  r.bottom := as(<single-float>, new)
end;

define method top (r :: <rect>) => (r :: <single-float>)
  r.%top
end;

define method top-setter (new :: <single-float>, r :: <rect>)
 => (new :: <single-float>)
  // TODO: clamp or error if top crosses bottom? (also, elsewhere)
  let new-height = (r.%top - new) + r.height;
  r.%height := new-height;
  r.%top    := new
end;

define method top-setter (new :: <real>, r :: <rect>)
 => (new :: <single-float>)
  r.top := as(<single-float>, new)
end;

define method width (r :: <rect>) => (w :: <single-float>)
  r.%width
end;

define method height (r :: <rect>) => (h :: <single-float>)
  r.%height
end;

// NOTE: Currently only the center*-setter functions actually move the entire
// <rect> (rather than one or two of its sides). 
// If you want to move a <rect> in more general ways, see move-rect and align.

define method center-x (r :: <rect>) => (x :: <single-float>)
  r.left + (r.width / 2.0)
end;

define method center-x-setter (new :: <single-float>, r :: <rect>)
 => (new :: <single-float>)
  let dx = new - r.center-x;
  r.left  := r.left + dx;
  r.right := r.right + dx;
  new
end;

define method center-x-setter (new :: <real>, r :: <rect>)
 => (new :: <single-float>)
  r.center-x := as(<single-float>, new)
end;

define method center-y (r :: <rect>) => (y :: <single-float>)
  r.top + (r.height / 2.0)
end;

define method center-y-setter (new :: <single-float>, r :: <rect>)
 => (new :: <single-float>)
  let dy = new - r.center-y;
  r.top    := r.top + dy;
  r.bottom := r.bottom + dy;
  new
end;

define method center-y-setter (new :: <real>, r :: <rect>)
 => (new :: <single-float>)
  r.center-y := as(<single-float>, new)
end;

define method center (r :: <rect>) => (c :: <vec2>)
  vec2(r.center-x, r.center-y)
end;

define method center-setter (new :: <vec2>, r :: <rect>)
 => (new :: <vec2>)
  r.center-x := new.vx;
  r.center-y := new.vy;
  new
end;

define method left-bottom (r :: <rect>) => (_ :: <vec2>)
  vec2(r.left, r.bottom)
end;

define method left-bottom-setter (new :: <vec2>, r :: <rect>)
 => (new :: <vec2>)
  r.left   := new.vx;
  r.bottom := new.vy;
  new
end;

define method left-top (r :: <rect>) => (_ :: <vec2>)
  vec2(r.left, r.top)
end;

define method left-top-setter (new :: <vec2>, r :: <rect>)
 => (new :: <vec2>)
  r.left := new.vx;
  r.top  := new.vy;
  new
end;

define method right-bottom (r :: <rect>) => (_ :: <vec2>)
  vec2(r.right, r.bottom)
end;

define method right-bottom-setter (new :: <vec2>, r :: <rect>)
 => (new :: <vec2>)
  r.right  := new.vx;
  r.bottom := new.vy;
  new
end;

define method right-top (r :: <rect>) => (_ :: <vec2>)
  vec2(r.right, r.top)
end;

define method right-top-setter (new :: <vec2>, r :: <rect>)
 => (new :: <vec2>)
  r.right := new.vx;
  r.top   := new.vy;
  new
end;

// Note: No setters for these.
// TODO: Maybe remove setter for center as well?

define method left-center (r :: <rect>) => (_ :: <vec2>)
  vec2(r.left, r.center-y)
end;

define method right-center (r :: <rect>) => (_ :: <vec2>)
  vec2(r.right, r.center-y)
end;

define method center-top (r :: <rect>) => (_ :: <vec2>)
  vec2(r.center-x, r.top)
end;

define method center-bottom (r :: <rect>) => (_ :: <vec2>)
  vec2(r.center-x, r.bottom)
end;

define method rect-intersection (a :: <rect>, b :: <rect>)
 => (result :: false-or(<rect>))
  let lt = max(a.left, b.left);
  let rt = min(a.right, b.right);
  let bt = min(a.bottom, b.bottom);
  let tp = max(a.top, b.top);

  if (lt > rt | tp > bt)
    #f
  else
    make(<rect>, left: lt, right: rt, bottom: bt, top: tp)
  end
end;

// Note: Not the set union of the points defined by the rects, but
// rather the minimal rect that encompasses all of the inputs.
define function rect-union (r :: <rect>, #rest rects :: <rect>)
 => (union :: <rect>)
  make(<rect>,
       left:   reduce(min, r.left, map(left, rects)),
       right:  reduce(max, r.right, map(right, rects)),
       bottom: reduce(max, r.bottom, map(bottom, rects)),
       top:    reduce(min, r.top, map(top, rects)))
end;

define function bound-points-with-rect (pts :: <collection>)
 => (rect-bounding-all-points :: <rect>)
  if (pts.empty?)
    error("cannot find bounding <rect> of empty set of points");
  end;

  let xs = map(vx, pts);
  let ys = map(vy, pts);

  // optimize: could do this in 1 traversal instead of 4
  make(<rect>,
    left:   reduce1(min, xs),
    right:  reduce1(max, xs),
    bottom: reduce1(max, ys),
    top:    reduce1(min, ys))
end;

// TODO: alignment? (for non-centered expansions)
define function expand-rect! (r :: <rect>,
                              #key horizontal-amount: ha = #f,
                                   horizontal-scale:  hs = #f,
                                   vertical-amount:   va = #f,
                                   vertical-scale:    vs = #f)
 => (r :: <rect>)
  case
    ha & hs =>
      error("cannot specify both horizontal-amount and horizontal-scale in expand-rect");
    ha =>
      let w = ha / 2.0;
      r.left  := r.left - w;
      r.right := r.right + w;
    hs =>
      let w = (r.width * hs) / 2.0;
      r.left  := r.center - w;
      r.right := r.center + w;
  end;

  case
    va & vs =>
      error("cannot specify both vertical-amount and vertical-scale in expand-rect");
    va =>
      let h = va / 2.0;
      r.top    := r.top - h;
      r.bottom := r.bottom + h;
    vs =>
      let h = (r.height * vs) / 2.0;
      r.top    := r.center - h;
      r.bottom := r.center + h;
  end;

  r
end;

define function expand-rect (r :: <rect>,
                             #key horizontal-amount: ha = #f,
                                  horizontal-scale:  hs = #f,
                                  vertical-amount:   va = #f,
                                  vertical-scale:    vs = #f)
 => (expanded-rect :: <rect>)
  expand-rect!(shallow-copy(r),
               horizontal-amount: ha,
               horizontal-scale: hs,
               vertical-amount: va,
               vertical-scale: vs)
end;

define function rect-corners (r :: <rect>)
 => (corner-1 :: <vec2>, corner-2 :: <vec2>,
     corner-3 :: <vec2>, corner-4 :: <vec2>)
  values(r.left-top, r.left-bottom, r.right-bottom, r.right-top)
end;

define function move-rect (r :: <rect>, offset :: <vec2>) => ()
  r.%left := r.%left + offset.vx;
  r.%top  := r.%top  + offset.vy;
end;

define function transform-rect (r :: <rect>,
                                trans :: <affine-transform-2d>)
 => (corner-1 :: <vec2>, corner-2 :: <vec2>,
     corner-3 :: <vec2>, corner-4 :: <vec2>)
  values(transform!(r.left-top,     trans),
         transform!(r.left-bottom,  trans),
         transform!(r.right-bottom, trans),
         transform!(r.right-top,    trans))
end;

define sealed method \+ (r :: <rect>,
                         v :: <vec2>) => (new-rect :: <rect>)
  make(<rect>,
       left:   r.left + v.vx,
       top:    r.top  + v.vy,
       width:  r.width,
       height: r.height)
end;

define sealed method \- (r :: <rect>,
                         v :: <vec2>) => (new-rect :: <rect>)
 make(<rect>,
      left:   r.left  - v.vx,
      right:  r.right - v.vy,
      width:  r.width,
      height: r.height)
end;


// Implementation of the alignment protocol for <rect>.

define sealed method object-alignment-offset (r :: <rect>,
                                              h-align-amount :: <single-float>,
                                              v-align-amount :: <single-float>)
 => (x-offset :: <single-float>, y-offset :: <single-float>)
  values(r.left + (r.width  * h-align-amount),
         r.top  + (r.height * v-align-amount))
end;


define sealed method align-object (r :: <rect>,
                                   h-align-amount :: false-or(<single-float>),
                                   v-align-amount :: false-or(<single-float>),
                                   align-to :: <vec2>) => ()
  let (dx, dy) = object-alignment-offset(r,
                                         h-align-amount | 0.0,
                                         v-align-amount | 0.0);

  if (h-align-amount)
    r.%left := align-to.vx - dx;
  end;

  if (v-align-amount)
    r.%top := align-to.vy - dy;
  end;
end;


// Whew! That was a lot of work for a stupid little rectangle!

