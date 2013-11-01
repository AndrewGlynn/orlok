module: vector-graphics-implementation
author: Andrew Glynn
copyright: copyright: See LICENSE file in this distribution.


//============================================================================
//----------------  Paints  ----------------
//============================================================================

// Defines how to extend a <paint> beyond its natural borders (e.g., past
// the edges of a <bitmap>, or beyond the start/end points of a gradient).
define enum <paint-extend> ()
  $paint-extend-none;
  $paint-extend-repeat;
  $paint-extend-reflect;
  $paint-extend-pad;
end;

define abstract class <gradient> (<object>)
  slot gradient-extend :: <paint-extend> = $paint-extend-none;
  slot color-stops :: <stretchy-vector> = make(<stretchy-vector>);
end;

define function add-color-stop (g :: <gradient>,
                                offset :: <single-float>,
                                color :: <color>) => ()
  offset := clamp(offset, 0.0, 1.0);

  block(done)
    for (i from 0 below g.color-stops.size)
      let stop = g.color-stops[i];

      if (stop[1] = offset)
        stop[0] := color; // overwrite this stop
        done()
      end;
      
      if (stop[1] > offset)
        // insert the new stop into the sequence
        g.color-stops
          := replace-subsequence!(g.color-stops,
                                  vector(vector(color, offset), stop),
                                  start: i,
                                  end: i + 1);
        done()
      end;
    end;

    // insert at end
    add!(g.color-stops, vector(color, offset));
  end block;
end;

define class <linear-gradient> (<gradient>)
  slot gradient-start :: <vec2>,
    required-init-keyword: start:;
  slot gradient-end :: <vec2>,
    required-init-keyword: end:;
end;

define class <radial-gradient> (<gradient>)
  slot gradient-start :: <circle>,
    required-init-keyword: start:;
  slot gradient-end :: <circle>,
    required-init-keyword: end:;
end;

define constant <paint> = type-union(<color>, <gradient>, <bitmap>);


//============================================================================
//----------------  Brushes  ----------------
//============================================================================

define abstract class <brush> (<object>)
end;

define class <fill> (<brush>)
  slot fill-paint :: <paint>,
    required-init-keyword: paint:;
end;

define enum <line-join> ()
  $line-join-miter;
  $line-join-round;
  $line-join-bevel;
end;

define enum <line-cap> ()
  $line-cap-butt;
  $line-cap-round;
  $line-cap-square;
end;

define class <stroke> (<brush>)
  slot line-join :: <line-join> = $line-join-miter,
    init-keyword: line-join:;
  slot line-cap :: <line-cap> = $line-cap-butt,
    init-keyword: line-cap:;
  slot line-width :: <single-float> = 2.0,
    init-keyword: line-width:;
  slot stroke-paint :: <paint>,
    required-init-keyword: paint:;
  slot dash-pattern :: false-or(<sequence>) = #f;
end;


//============================================================================
//----------------  Paths  ----------------
//============================================================================


define enum <path-command> ()
  $path-move-to;
  $path-line-to;
  $path-quad-to;
  $path-curve-to;
  $path-close;
end;

define class <path> (<object>)
  constant slot path-commands :: <stretchy-vector> = make(<stretchy-vector>);
  constant slot path-points :: <stretchy-vector> = make(<stretchy-vector>);
end;

// Clears current path (if any), and moves the “pen” to start.
define method begin-path (p :: <path>, start :: <vec2>) => ()
  p.path-commands.size := 0;
  p.path-points.size := 0;
  add!(p.path-points, start.xy); // first point has no command
end;

// Ends the current path. If close? is true, first connect the final point
// to the initial point with a line.
define method end-path (p :: <path>, #key close? :: <boolean> = #f) => ()
  if (close?)
    add!(p.path-commands, $path-close);
  end;
end;

// Return #t if path is empty (no lines or curves?).
define method empty-path? (p :: <path>) => (empty? :: <boolean>)
  p.path-commands.empty?
end;

define method move-to (p :: <path>, pt :: <vec2>) => ()
  add!(p.path-commands, $path-move-to);
  add!(p.path-points, pt);
end;

define method line-to (p :: <path>, pt :: <vec2>) => ()
  add!(p.path-commands, $path-line-to);
  add!(p.path-points, pt);
end;

define method quad-to (p :: <path>, pt1 :: <vec2>, pt2 :: <vec2>) => ()
  add!(p.path-commands, $path-quad-to);
  add!(p.path-points, pt1);
  add!(p.path-points, pt2);
end;

define method curve-to (p :: <path>,
                        pt1 :: <vec2>,
                        pt2 :: <vec2>,
                        pt3 :: <vec2>) => ()
  add!(p.path-commands, $path-curve-to);
  add!(p.path-points, pt1);
  add!(p.path-points, pt2);
  add!(p.path-points, pt3);
end;

// TODO: arc-to
// TODO: relative versions? with keyword? with mode slot on <path>? none?
// TODO: transform-path (<path>, <affine-transform-2d>)


//============================================================================
//----------------  VG (Vector Graphics) Contexts  ----------------
//============================================================================

define class <context-state> (<object>)
  slot context-state-transform :: <affine-transform-2d>,
    required-init-keyword: transform:;
end;


define abstract class <vg-context> (<disposable>)
  constant slot bitmap-target :: <bitmap>,
    required-init-keyword: bitmap-target:;
  constant slot state-stack :: limited(<deque>, of: <context-state>)
    = make(limited(<deque>, of: <context-state>));
end;

define method initialize (ctx :: <vg-context>, #key)
  next-method();

  // start with a single identity transform
  let st = make(<context-state>, transform: make(<affine-transform-2d>));
  push(ctx.state-stack, st)
end;

// Draw an arbitrary shape on ctx using the given brush.
// Methods are provided for <vec2> (strokes only), <rect>, <circle>,
// and <path>.
define generic vg-draw-shape (ctx :: <vg-context>,
                              shape,
                              brush :: <brush>) => ();


// Draw text on ctx in a specified font with a specified brush.
define generic vg-draw-text (ctx :: <vg-context>,
                             text :: <string>,
                             font :: <font>,
                             #key brush :: <brush>,
                                  at :: <vec2> = vec2(0, 0),
                                  align :: <alignment> = $align-left-bottom);


define method save-state (ctx :: <vg-context>) => ()
  let new = make(<context-state>,
                 transform: shallow-copy(ctx.current-transform));
  push(ctx.state-stack, new);
end;

define method restore-state (ctx :: <vg-context>) => ()
  if (ctx.state-stack.size <= 1)
    orlok-error("cannot remove last state from <vg-context>");
  else
    pop(ctx.state-stack);
  end;
end;

define method current-transform (ren :: <vg-context>)
 => (trans :: <affine-transform-2d>)
  ren.state-stack.first.context-state-transform
end;

define method apply-transform (ren :: <vg-context>,
                               t :: <affine-transform-2d>)
 => ()
  unless (identity?(t))
    ren.state-stack.first.context-state-transform
      := t * ren.current-transform;
  end;
end;

// just used by the following macro
define constant $identity-transform = make(<affine-transform-2d>);
ignore($identity-transform);

define macro with-context-state
  {
    // TODO: maybe allow multiple transforms, to be concatenated?
    with-context-state (?ren:expression,
                        #key ?transform:expression = $identity-transform)
      ?:body
    end
  }
 =>
  {
    // TODO: profile this version against non-block-based version

    let c = ?ren;
    let t = ?transform;

    save-state(c);
    block ()
      apply-transform(c, t);
      ?body
    cleanup
      restore-state(c);
    end;
  }
end;

