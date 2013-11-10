module: visual
author: Andrew Glynn
copyright: See LICENSE file in this distribution.


//============================================================================
//----------    <behavior>    ----------
//============================================================================


define open abstract class <behavior> (<object>)
  slot next-behavior :: false-or(<behavior>) = #f; // note: private!
  slot behavior-owner = #f;
end;

// Default event handler method just forwards all events to the next
// behavior in the chain, if any.
define method on-event (e :: <event>, b :: <behavior>) => (#rest _)
  if (b.next-behavior)
    on-event(e, b.next-behavior);
  end;
end;

// Default dispose method on <behavior> just calls dispose on next-behavior
// recursively.
define method dispose (b :: <behavior>) => ()
  if (b.next-behavior)
    dispose(b.next-behavior);
  end;
end;


//============================================================================
//----------    <visual>    ----------
//============================================================================

// Note that a <visual> that is not visible should not be rendered, but
// this up to the owner/parent to handle (the should-render? function is
// provided for this purpose). The render method for a <visual>
// subtype should assume this check has already taken place (and therefore need
// not perform the check itself).

define open abstract class <visual> (<spatial-2d>)
  slot alpha :: <single-float> = 1.0, init-keyword: alpha:;
 
  // If #f, this <visual> should not be rendered. Note that this is the
  // parent's responsibility; <visual>s need not make this check themselves.
  slot visible? :: <boolean> = #t, init-keyword: visible?:;

  // If #f, this <visual> should not receive <update-event>s.
  // Note that this is the parent's responsibility; <visual>s need not make
  // this check themselves.
  slot running? :: <boolean> = #t, init-keyword: running?:;

  // If #f, this <visual> should not receive <input-event>s.
  // Note that this is the parent's responsibility; <visual>s need not make
  // this check themselves.
  slot interactive? :: <boolean> = #t, init-keyword: interactive?:;

  slot %parent :: false-or(<visual-container>) = #f;
  slot behavior-chain :: false-or(<behavior>) = #f;
end;

define method initialize (v :: <visual>, #key parent: p)
  next-method();
  if (p)
    v.parent := p;
  end;
end;

define method dispose (v :: <visual>) => ()
  if (v.behavior-chain)
    dispose(v.behavior-chain);
  end;
end;

define method parent (v :: <visual>) => (_ :: false-or(<visual-container>))
  v.%parent
end;

define method parent-setter (new-parent :: false-or(<visual-container>),
                             v :: <visual>)
 => (new-parent :: false-or(<visual-container>))
  let old = v.parent;
  let new = new-parent;

  if (old ~== new)
    if (old)
      remove-child(old, v);
    end;
    if (new)
      add-child(new, v);
    end;
  end;

  new-parent
end;

define method should-render? (v :: <visual>)
 => (render? :: <boolean>)
  v.visible? & v.alpha > 0.0 & v.scale-x ~= 0.0 & v.scale-y ~= 0.0
end;

// Default handler method of <visual> just dispatches to the
// behavior-chain. If v has no behavior-chain, the event is ignored.
// Methods overriding this default should be sure to call next-method
// to ensure the method is sent to the behavior chain.
define method on-event (e :: <event>, v :: <visual>) => (#rest _)
  if (v.behavior-chain)
    on-event(e, v.behavior-chain);
  end;
end;

// Attach a behavior to the head of a visual's behavior-chain.
// It is an (undetected) error to attach a behavior to more than one
// visual (or to the same visual more than once).
define function attach-behavior (v :: <visual>, b :: <behavior>)
 => ()
  b.next-behavior := v.behavior-chain;
  v.behavior-chain := b;
  b.behavior-owner := v;
end;

define function %remove-behavior (v :: <visual>,
                                  b :: <behavior>,
                                  prev :: false-or(<behavior>))
 => ()
  if (~prev)
    v.behavior-chain := b.next-behavior;
  else
    prev.next-behavior := b.next-behavior;
  end;

  b.next-behavior := #f; // just to avoid confusion
  b.behavior-owner := #f;
end;

define function remove-behavior (v :: <visual>, b :: <behavior>)
 => (removed? :: <boolean>)
  iterate deeper (prev = #f, next = v.behavior-chain)
    if (~next)
      #f
    elseif (next == b)
      %remove-behavior(v, b, prev);
      #t
    else
      deeper(next, next.next-behavior)
    end
  end;
end;

// Remove all behaviors of a given type (including subtypes).
define function remove-behavior-by-type (v :: <visual>,
                                         behavior-type :: <type>)
 => (removed-behavior :: false-or(<behavior>))
  iterate deeper (prev = #f, next = v.behavior-chain)
    if (~next)
      #f
    elseif (instance?(next, behavior-type))
      %remove-behavior(v, next, prev);
      next
    else
      deeper(next, next.next-behavior)
    end
  end;
end;

define function remove-all-behaviors (v :: <visual>) => ()
  while (v.behavior-chain)
    %remove-behavior(v, v.behavior-chain, #f);
  end;
end;

// Find the first behavior in a visual's behavior-chain matching a given
// type (including subtypes). If skip is not zero, return the skip'th
// matching behavior. Returns #f if no match is found.
define function find-behavior-by-type (v :: <visual>,
                                       behavior-type :: <type>,
                                       #key skip = 0)
 => (behavior :: false-or(<behavior>))
  iterate next (b = v.behavior-chain)
    if (b & skip >= 0)
      if (instance?(b, behavior-type))
        if (skip = 0)
          b
        else
          skip := skip - 1;
        end;
      else
        next(b.next-behavior)
      end;
    else
      #f
    end;
  end;
end;

// Apply a function to each <behavior> in a <visual>.
define function do-behaviors (v :: <visual>,
                              f :: <function>) => ()
  for (b = v.behavior-chain then b.next-behavior,
       while: b)
    f(b)
  end;
end;


//============================================================================
//----------    <child-visuals>    ----------
//============================================================================

// We define a special class for the child-visuals of a <visual-container>
// that lets clients manipulate it as an immutable sequence (since we need to
// carefully manage adding and removing elements from it).
define class <child-visuals> (<sequence>)
  slot rep :: limited(<stretchy-vector>, of: <visual>)
    = make(limited(<stretchy-vector>, of: <visual>));

  slot fip-finished-state? :: <function>;
  slot fip-current-element :: <function>;
end;

define method initialize (cv :: <child-visuals>, #key)
  next-method();

  let (initial-state, limit, next-state, finished-state?, current-key,
       current-element, current-element-setter-not-used, copy-state)
    = cv.rep.forward-iteration-protocol;

  cv.fip-finished-state? := method (col, state, limit)
                              finished-state?(cv.rep, state, limit)
                            end;
  cv.fip-current-element := method (col, state)
                              current-element(cv.rep, state)
                            end;
end;

define function %fip-next-state (cv :: <child-visuals>, state)
 => (next-state)
  state + 1
end;

define function %fip-current-key (cv :: <child-visuals>, state)
 => (key)
  state
end;

define function %fip-current-element-setter (value, collection, state) => (value)
  orlok-error("illegal attempt to modify child-visuals sequence");
end;

define function %fip-copy-state (cv :: <child-visuals>, state)
 => (new-state)
  state
end;

define sealed method forward-iteration-protocol (cv :: <child-visuals>)
 => (initial-state, limit, next-state :: <function>,
     finished-state? :: <function>, current-key :: <function>,
     current-element :: <function>, current-element-setter :: <function>,
     copy-state :: <function>)
  values(0, cv.rep.size, %fip-next-state, cv.fip-finished-state?,
         %fip-current-key, cv.fip-current-element, %fip-current-element-setter,
         %fip-copy-state)
end;

// TODO: backward-iteration-protocol?

define sealed method element (cv :: <child-visuals>, k :: <integer>,
                              #key default = $unsupplied)
 => (elem :: <visual>)
  element(cv.rep, k, default: default)
end;

define sealed method size (cv :: <child-visuals>) => (sz :: <integer>)
  cv.rep.size
end;

define sealed method type-for-copy (cv :: <child-visuals>)
 => (type :: <type>)
  <stretchy-vector>
end;


//============================================================================
//----------    <visual-container>    ----------
//============================================================================

// A <visual> that manages a sequence of child <visual>s.
define abstract class <visual-container> (<object>)
  constant slot child-visuals :: <child-visuals> = make(<child-visuals>);
end;

// If insert-at-index is an <integer>, add the child at the given index in the
// parent’s display-list, moving any children at that index and higher up by
// one. Signals an error if the index is out of range.
define method add-child (the-parent :: <visual-container>,
                         child :: <visual>,
                         #key insert-at-index :: false-or(<integer>) = #f)
 => (child :: <visual>)
  // TODO: early out if the-parent == child.parent already?

  if (child.parent)
    remove-child(the-parent, child);
  end;

  if (insert-at-index)
    if (insert-at-index < 0 | insert-at-index > the-parent.child-visuals.rep.size)
      orlok-error("child index out of bounds in add-child");
    else
      the-parent.child-visuals.rep
        := replace-subsequence!(the-parent.child-visuals.rep,
                                vector(child),
                                start: insert-at-index,
                                end: insert-at-index);
    end;
  else
    the-parent.child-visuals.rep := add!(the-parent.child-visuals.rep, child);
  end;

  child.%parent := the-parent;
  child
end;

// Remove child from parent’s display-list and return #t, or return #f if
// child is not in parent’s display-list.
// If the removal succeeds, child.parent will be #f.
define method remove-child (the-parent :: <visual-container>,
                            child :: <visual>) => (removed? :: <boolean>)
  let old-size = the-parent.child-visuals.rep.size;
  the-parent.child-visuals.rep := remove!(the-parent.child-visuals.rep, child);

  if (the-parent.child-visuals.rep.size < old-size)
    child.%parent := #f;
    #t
  else
    #f
  end;
end;

// Remove the child at the given index from parent’s display-list and return it,
// or signal an error if the index is out of bounds.
define method remove-child-at (the-parent :: <visual-container>,
                               index :: <integer>)
 => (removed-child :: <visual>)
  if (index < 0 | index >= the-parent.child-visuals.rep.size)
    orlok-error("child index out of bounds in remove-child-at");
  end;

  let removed = the-parent.child-visuals.rep[index];
  remove-child(the-parent, the-parent.child-visuals.rep[index]);
  removed
end;


//============================================================================
//----------    <group-visual>    ----------
//============================================================================

// We leave this class concrete so it can be instantiated as a featureless
// parent for other <visual>s.
// TODO: Instead, create a concrete subclass to do the same, but what to
//       call it?
define open class <group-visual> (<visual>, <visual-container>)
  // track which children the mouse was over last frame
  constant slot was-mouse-over? :: <table> = make(<table>);
end;

// Just update all children.
define method on-event (e :: <update-event>,
                        g :: <group-visual>) => ()
  next-method();
  for (child in g.child-visuals.rep)
    if (child.running?)
      on-event(e, child);
    end;
  end;
end;

// Render all the objects in a <visual-container>s display list, in order.
// Thus the first element in the list will render first and will appear
// furthest back.
define method on-event (e :: <render-event>,
                        g :: <group-visual>) => ()
  
  // TODO: Should this be before or after doing children? I can see arguments
  //       both ways. (Or separate into pre/post events.)
  next-method();

  for (child in g.child-visuals.rep)
    if (should-render?(child))
      with-saved-state (e.renderer.transform-2d, e.renderer.render-color)
        unless (has-identity-transform?(child))
          e.renderer.transform-2d := child.transform-2d * e.renderer.transform-2d;
        end;
        if (child.alpha < 1.0)
          e.renderer.render-color :=
            e.renderer.render-color * make-rgba(1.0, 1.0, 1.0, child.alpha);
        end;
        on-event(make(<pre-render-event>, renderer: e.renderer), child);
        on-event(e, child);
        on-event(make(<post-render-event>, renderer: e.renderer), child);
      end;
    end;
  end;
end;

// Assuming e is in v's parent's coordinate space, create and return a
// new <mouse-event> identical to e except that it is in v's own coordinate
// space. However, if v has a non-invertible transform, just return #f.
define function transform-visual-event (v :: <visual>, e :: <mouse-event>)
 => (new-e :: false-or(<mouse-event>))
  if (~v.has-invertible-transform?)
    #f
  else
    let vec = transform!(e.mouse-vector, v.inverse-transform-2d);
    make(e.object-class,
         x: vec.vx,
         y: vec.vy,
         left-button?: e.mouse-left-button?,
         right-button?: e.mouse-right-button?,
         middle-button?: e.mouse-middle-button?)
  end;
end;

// For <mouse-events>, pass on to the children of the container, in
// front-to-back order until the event is consumed or all children
// have been tried.
define method on-event (e :: <mouse-event>, g :: <group-visual>)
 => (consumed? :: <boolean>)
  // TODO: This is a mess (and broken in various ways). Figure out what
  //       I really want to do here. For example, do we always send
  //       <mouse-in/out-event>s, even if a previous child consumed the
  //       original event?
  block (return)
    if (next-method(e, g))
      return(#t);
    else
      for (child in g.child-visuals using backward-iteration-protocol)
        if (child.interactive? & child.has-invertible-transform?)
          let new-e = transform-visual-event(child, e);
          if (intersects?(child.bounding-rect, new-e.mouse-vector))
            if (~has-key?(g.was-mouse-over?, child))
              g.was-mouse-over?[child] := #t;
              on-event(make(<mouse-in-event>, with-mouse-state-from: new-e),
                       child);
            end;
            if (on-event(new-e, child)) // pass on to child
              return(#t);
            end;
          elseif (has-key?(g.was-mouse-over?, child))
            remove-key!(g.was-mouse-over?, child);
            on-event(make(<mouse-out-event>, with-mouse-state-from: new-e),
                     child);
          end;
        end;
      end for;
      return(#f);
    end;
  end;
end;

define function merged-child-bounding-rects (g :: <group-visual>)
 => (bounds :: <rect>)
  if (g.child-visuals.rep.empty?)
    // If no children, just assume a point at g's origin.
    make(<rect>, left: 0.0, right: 0.0, top: 0.0, bottom: 0.0)
  else
    // Transform each child's bounding-rect's corners into g's space,
    // and then bound the resulting point cloud with a <rect>.

    let point-cloud = make(<vector>, size: g.child-visuals.rep.size * 4);
    let i = 0;

    for (child in g.child-visuals.rep)
      let trans = child.transform-2d;
      if (identity?(trans))
        let (a, b, c, d) = rect-corners(child.bounding-rect);
        point-cloud[i] := a; i := i + 1;
        point-cloud[i] := b; i := i + 1;
        point-cloud[i] := c; i := i + 1;
        point-cloud[i] := d; i := i + 1;
      else
        let (a, b, c, d) = transform-rect(child.bounding-rect, trans);
        point-cloud[i] := a; i := i + 1;
        point-cloud[i] := b; i := i + 1;
        point-cloud[i] := c; i := i + 1;
        point-cloud[i] := d; i := i + 1;
      end;
    end;

    bound-points-with-rect(point-cloud)
  end
end;

define method bounding-rect (g :: <group-visual>) => (bounds :: <rect>)
  merged-child-bounding-rects(g)
end;


//============================================================================
//----------    <root-visual>    ----------
//============================================================================

// Represents the root of a visual tree.
define class <root-visual> (<group-visual>)
end;

define method on-event (e :: <render-event>, root :: <root-visual>) => ()
  // <root-visual>s are the only ones that apply their own transform
  // (since someone has to!)
  with-saved-state (e.renderer.transform-2d)
    unless (has-identity-transform?(root))
      e.renderer.transform-2d := root.transform-2d * e.renderer.transform-2d;
    end;
    next-method();
  end;
end;

define method on-event (e :: <mouse-event>, root :: <root-visual>)
 => (consumed? :: <boolean>)
  if (mouse-capture-visual())
    let v = global-to-local(e.mouse-vector, mouse-capture-visual());
    let new-e = make(e.object-class,
                     x: v.vx,
                     y: v.vy,
                     left-button?: e.mouse-left-button?,
                     right-button?: e.mouse-right-button?,
                     middle-button?: e.mouse-middle-button?);
    on-event(new-e, mouse-capture-visual());
  else
    // Ensure mouse events are transformed by root's own transform.
    if (~root.has-invertible-transform?)
      orlok-error("non-invertible transform on root <visual>");
    end;
    let new-e = transform-visual-event(root, e);
    next-method(new-e, root);
  end;
end;

define method on-event (e :: <key-event>, root :: <root-visual>) => ()
  if (keyboard-focus-visual())
    on-event(e, keyboard-focus-visual());
  else
    next-method(e, root);
  end;
end;


//============================================================================
//----------    <box>    ----------
//============================================================================

define class <box> (<group-visual>)
  slot box-rect :: <rect> = make(<rect>, left: 0, top: 0, width: 100, height: 100),
    init-keyword: rect:;
  slot box-color :: <color> = $magenta,
    init-keyword: color:;
  // TODO: Support texture and/or custom shader?
end;

define method bounding-rect (b :: <box>) => (bounds :: <rect>)
  let bounds = b.box-rect;

  unless (b.child-visuals.rep.empty?)
    bounds := rect-union(next-method(), bounds);
  end;

  bounds
end;

define method on-event (e :: <render-event>, b :: <box>) => ()
  draw-rect(e.renderer, b.box-rect, color: b.box-color);
  next-method(); // draw children on top of rect
end;
  


//============================================================================
//----------    Miscellaneous functions    ----------
//============================================================================


// Methods for aligning <visual>s based on their bounding-rects.

define method object-alignment-offset (v :: <visual>,
                                       h-align-amount :: <single-float>,
                                       v-align-amount :: <single-float>)
 => (x-offset :: <single-float>, y-offset :: <single-float>)
  let (dx, dy) = object-alignment-offset(v.bounding-rect,
                                         h-align-amount,
                                         v-align-amount);
  values(dx, dy)
end;

define method align-object (v :: <visual>,
                            h-align-amount :: false-or(<single-float>),
                            v-align-amount :: false-or(<single-float>),
                            align-to :: <vec2>) => ()
  let (dx, dy) = object-alignment-offset(v.bounding-rect,
                                         h-align-amount | 0.0,
                                         v-align-amount | 0.0);
  let d = transform(vec2(dx, dy), v.transform-2d);

  if (h-align-amount)
    v.pos-x := align-to.vx - d.vx;
  end;

  if (v-align-amount)
    v.pos-y := align-to.vy - d.vy;
  end;
end;

// Methods for converting between coordinate spaces within a tree of <visual>s.

define method local-to-global-transform (local-coordinate-space :: <visual>)
 => (trans :: <affine-transform-2d>)
  let v = local-coordinate-space;
  if (v.parent)
    v.transform-2d * local-to-global-transform(v.parent)
  else
    v.transform-2d;
  end;
end;

define method global-to-local-transform (local-coordinate-space :: <visual>)
 => (trans :: <affine-transform-2d>)
  let v = local-coordinate-space;
  if (v.parent)
     global-to-local-transform(v.parent) * v.inverse-transform-2d
  else
    v.inverse-transform-2d
  end;
end;

define method local-to-global (local-pt :: <vec2>,
                               local-coordinate-space :: <visual>)
 => (global-pt :: <vec2>)
  transform(local-pt, local-to-global-transform(local-coordinate-space))
end;

define method global-to-local (global-pt :: <vec2>,
                               local-coordinate-space :: <visual>)
 => (local-pt :: <vec2>)
  transform(global-pt, global-to-local-transform(local-coordinate-space))
end;

// Given point pt in from's coordinate space, return that same point in
// to's coordinate space. This assumes that from and to share a common
// ancestor.
define method change-coordinate-space (pt :: <vec2>,
                                       #key from :: <visual>,
                                            to :: <visual>)
 => (transformed-pt :: <vec2>)
  // First ensure from and to are members of the same tree, otherwise
  // their spaces are not related.
  let from-root = from;
  let to-root = to;

  while (from-root.parent)
    from-root := from-root.parent;
  end;
  while (to-root.parent)
    to-root := to-root.parent;
  end;
  
  if (from-root ~== to-root)
    orlok-error("no shared coordinate space for %= and %= (no common ancestor)",
                from, to);
  end;

  global-to-local(local-to-global(pt, from), to)
end;

// Compute the bounding rect of v from the point of view of 'relative-to's
// coodinate space. Both v and relative-to must be rooted under the same
// <root-visual>.
define function relative-bounding-rect (v :: <visual>,
                                        relative-to :: <visual>)
 => (bounds :: <rect>)
  let trans = global-to-local-transform(relative-to) * local-to-global-transform(v);
  let (a, b, c, d) = transform-rect(v.bounding-rect, trans);
  bound-points-with-rect(vector(a, b, c, d));
end;

// Move v such that v’s alignment point matches target’s target-alignment
// point. Both v and target must be rooted under the same <root-visual>
// for this to work.
define function align-visual (v :: <visual>,
                              alignment :: <alignment>,
                              target :: <visual>,
                              target-alignment :: <alignment>) => ()
  let (dx, dy) = alignment-offset(target, target-alignment);
  let target-pt = local-to-global(vec2(dx, dy), target);

  if (v.parent)
    target-pt := global-to-local(target-pt, v.parent);
  end;

  align(alignment, of: v, to: target-pt);
end;

// Globals and functions related to capturing mouse and keyboard events.

define variable *mouse-capture-visual* :: false-or(<visual>) = #f;
define variable *keyboard-focus-visual* :: false-or(<visual>) = #f;

// If v is not #f, all subsequent mouse events will be sent directly to v
// rather than originating at the root <visual>. Call with #f to return
// to standard behavior.
define function capture-mouse (v :: false-or(<visual>)) => ()
  *mouse-capture-visual* := v;
end;

// The <visual> that currently has captured mouse input, or #f if none.
define function mouse-capture-visual () => (v :: false-or(<visual>))
  *mouse-capture-visual*
end;

// If v is not #f, all subsequent keyboard events will be sent directly
// to v, until this function is called with #f.
define function focus-keyboard (v :: false-or(<visual>)) => ()
  *keyboard-focus-visual* := v;
end;

// The <visual> that currently has keyboard focus, or #f if none.
define function keyboard-focus-visual () => (v :: false-or(<visual>))
  *keyboard-focus-visual*
end;


//============================================================================
//  New events
//============================================================================

// Sent when the mouse enters an object's bounding-rect.
define class <mouse-in-event> (<mouse-event>)
end;

// Sent when the mouse leaves an object's bounding-rect.
define class <mouse-out-event> (<mouse-event>)
end;

// Sent immediately before the <render> event is sent to a <visual>.
// Note that this is *not* sent to a <root-visual>.
define class <pre-render-event> (<event>)
  constant slot renderer :: <renderer>,
    required-init-keyword: renderer:;
end;

// Sent immediately after the <render> event is sent to a <visual>.
// Note that this is *not* sent to a <root-visual>.
define class <post-render-event> (<event>)
  constant slot renderer :: <renderer>,
    required-init-keyword: renderer:;
end;


