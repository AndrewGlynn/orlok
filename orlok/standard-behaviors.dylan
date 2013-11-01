module: visual
author: Andrew Glynn
copyright: copyright: See LICENSE file in this distribution.


//============================================================================
//----------    <debug-bounding-rect-behavior>    ----------
//============================================================================


define class <debug-bounding-rect-behavior> (<behavior>)
  constant slot color :: <color> = make-rgba(0.0, 1.0, 1.0, 0.5),
    init-keyword: color:;
  constant slot show-origin? :: <boolean> = #f,
    init-keyword: show-origin?:;
  constant slot origin-color :: <color> = make-rgba(1.0, 0.0, 0.0, 0.5),
    init-keyword: origin-color:;
end;

define method on-event (e :: <render-event>,
                        d :: <debug-bounding-rect-behavior>)
 => ()
  draw-rect(e.renderer, d.behavior-owner.bounding-rect,
            color: d.color);
  if (d.show-origin?)
    let origin-rect = make(<rect>, left: -2, top: -2, width: 4, height: 4);
    draw-rect(e.renderer, origin-rect, color: d.origin-color);
  end;

  next-method();
end;


//============================================================================
//----------    <draggable-behavior>    ----------
//============================================================================


define class <draggable-behavior> (<behavior>)
  slot drag-over?  :: <boolean> = #f;
  slot dragging?   :: <boolean> = #f;
  slot drag-offset :: <vec2>    = vec2(0.0, 0.0);
end;

define method on-event (e :: <mouse-in-event>, d :: <draggable-behavior>) => ()
  d.drag-over? := #t;
  next-method();
end;

define method on-event (e :: <mouse-out-event>, d :: <draggable-behavior>) => ()
  d.drag-over? := #f;
  next-method();
end;

define method on-event (e :: <mouse-left-button-down-event>,
                        d :: <draggable-behavior>) 
 => (consumed? :: <boolean>)
  if (d.drag-over?)
    d.dragging?   := #t;
    d.drag-offset := vec2(e.mouse-x, e.mouse-y);
    capture-mouse(d.behavior-owner);
    #t
  else
    next-method();
  end;
end;

define method on-event (e :: <mouse-left-button-up-event>,
                        d :: <draggable-behavior>)
 => (consumed? :: <boolean>)
  if (d.dragging?)
    d.dragging? := #f;
    // TODO: Really this should be an assertion.
    if (mouse-capture-visual() == d.behavior-owner)
      capture-mouse(#f);
    end;
    // TODO: notify subject of drop somehow (event? something else?)
    #t
  else
    next-method()
  end;
end;

define method on-event (e :: <mouse-move-event>,
                        d :: <draggable-behavior>) => ()
  if (d.dragging?)
    d.behavior-owner.pos :=
      d.behavior-owner.pos + e.mouse-vector - d.drag-offset;
    #t
  else
    next-method();
  end;
end;


//============================================================================
//----------    <event-listener-behavior>    ----------
//
// A behavior that just listens for a particular event type, then
// calls a function in response.
//============================================================================

define class <event-listener-behavior> (<behavior>)
  constant slot event-type :: <class>,
    required-init-keyword: event-type:;
  // If true, don't pass the event on to the next behavior.
  constant slot consume-event? :: <boolean> = #f,
    init-keyword: consume-event?:;
  // must accept a single event argument of type event-type
  constant slot activated :: <function>, required-init-keyword: do:;
end;

// Convenience macro for defining listeners.

define macro listen-for
  {
    listen-for (?target:expression, ?:name :: ?event-type:expression)
      ?:body
    end
  }
 =>
  {
    let listener = make(<event-listener-behavior>,
                        event-type: ?event-type,
                        do: method (?name :: ?event-type)
                              ?body
                            end);
    attach-behavior(?target, listener);
    listener
  }
end;

define sealed method on-event (e :: <event>,
                               listener :: <event-listener-behavior>)
 => (#rest _)
  if (instance?(e, listener.event-type))
    listener.activated(e);
    if (~listener.consume-event?)
      next-method();
    end;
  else
    next-method();
  end;
end;


//============================================================================
//----------    <button-behavior>    ----------
//============================================================================

define class <button-behavior> (<behavior>)
  constant slot up-state   :: <visual>, required-init-keyword: up-state:;
  constant slot over-state :: <visual>, required-init-keyword: over-state:;
  constant slot down-state :: <visual>, required-init-keyword: down-state:;

  slot button-state :: one-of(#"up", #"over", #"down") = #"up";
  slot mouse-down?  :: <boolean> = #f;
end;

// When a <visual> with a <button-behavior> is clicked, this event is sent
// to that <visual>.
// Generally, you should attach an <event-listener-behavior> for this event
// on the button in order to perform an action in response to the click.
define class <button-click-event> (<event>)
  constant slot button-click-source-event :: <mouse-event>,
    required-init-keyword: source-event:;
  constant slot button-click-button :: <visual>,
    required-init-keyword: button:;
end;

// up-state, over-state, and down-state should be children of btn
define function attach-button-behavior (btn        :: <visual>,
                                        up-state   :: <visual>,
                                        over-state :: <visual>,
                                        down-state :: <visual>)
 => (btn :: <visual>)
  let behavior =  make(<button-behavior>,
                       up-state:   up-state,
                       over-state: over-state,
                       down-state: down-state);
  attach-behavior(btn, behavior);
  up-state.visible?   := #t;
  over-state.visible? := #f;
  down-state.visible? := #f;
  btn
end;

define method on-event (e :: <mouse-in-event>, btn :: <button-behavior>) => ()
  %set-button-state(btn, #"over");
end;

define method on-event (e :: <mouse-out-event>, btn :: <button-behavior>) => ()
  %set-button-state(btn, #"up");
end;

define method on-event (e :: <mouse-move-event>, btn :: <button-behavior>)
 => ()
  // While mouse is captured we don't get mouse-in/out events (because when
  // captured, the mouse is always considered "in") , so we need to detect
  // it ourselves.
  if (btn.mouse-down?)
    if (intersects?(e.mouse-vector, btn.behavior-owner.bounding-rect))
      %set-button-state(btn, #"down");
    else
      %set-button-state(btn, #"over");
    end;
  end;
end;

define method on-event (e :: <mouse-left-button-down-event>,
                        btn :: <button-behavior>) => (consumed? :: <boolean>)
  if (btn.button-state == #"over")
    %set-button-state(btn, #"down");
    btn.mouse-down? := #t;
    capture-mouse(btn.behavior-owner);
  end;
  #t
end;

define method on-event (e :: <mouse-left-button-up-event>,
                        btn :: <button-behavior>) => (consumed? :: <boolean>)
  // TODO: Really this should be an assertion.
  if (mouse-capture-visual() == btn.behavior-owner)
    capture-mouse(#f);
  end;
  btn.mouse-down? := #f;

  if (btn.button-state == #"down")
    on-event(make(<button-click-event>,
                  source-event: e,
                  button:       btn.behavior-owner),
             btn.behavior-owner);
  end;

  if (intersects?(e.mouse-vector, btn.behavior-owner.bounding-rect))
    %set-button-state(btn, #"over");
  else
    %set-button-state(btn, #"up");
  end;
  #t
end;

define function %set-button-state (btn :: <button-behavior>,
                                  state :: <symbol>) => ()
  btn.button-state        := state;
  btn.up-state.visible?   := #f;
  btn.over-state.visible? := #f;
  btn.down-state.visible? := #f;

  select (state)
    #"up"   => btn.up-state.visible?   := #t;
    #"over" => btn.over-state.visible? := #t;
    #"down" => btn.down-state.visible? := #t;
  end;
end;


//============================================================================
//----------    <tween-group-behavior>    ----------
//============================================================================

define class <tween-group-behavior> (<behavior>)
  constant slot tween-group :: <tween-group> = make(<tween-group>);
end;

define method on-event (e :: <update-event>, t :: <tween-group-behavior>) => ()
  update-tween-group(t.tween-group, e.delta-time);
  next-method();
end;

// By defining this method on <visual>s, we can now treat a <visual> as if it
// were a <tween-group> (ie, use as the target in tween macros, etc).
// However, you must be sure to add a <tween-group-behavior> to a <visual>
// before attempting to use it as a tween group, or an error will be signaled.
// Note: This method finds the first <tween-group-behavior> attached to group.
// If there are more than one, the later ones will be ignored.
define method add-tween-to-group (group :: <visual>, tw :: <tween>) => ()
  let behavior = find-behavior-by-type(group, <tween-group-behavior>);
  if (behavior)
    add-tween-to-group(behavior.tween-group, tw);
  else
    orlok-error("<visual> %= provides no tween-group behavior", group);
  end;
end;


//============================================================================
//----------    <tooltip-behavior>    ----------
//============================================================================


define constant $default-tooltip-delay = 1.5;
define constant $tooltip-fade-in-duration = 0.1;
define constant $tooltip-fade-out-duration = 1.0;

define class <tooltip-behavior> (<behavior>)
  constant slot tooltip-visual :: <visual>,
    required-init-keyword: tooltip-visual:;
  constant slot tooltip-offset :: <vec2>,
    required-init-keyword: tooltip-offset:;
   // delay before popping up tooltip
  constant slot tooltip-delay :: <single-float> = $default-tooltip-delay,
    init-keyword: tooltip-delay:;
  slot rollover-time :: <single-float> = 0.0;
  slot fade-tween :: false-or(<tween>) = #f;
  slot mouse-over? :: <boolean> = #f;
  slot showing-tooltip? :: <boolean> = #f;
end;

define method on-event (e :: <mouse-in-event>, t :: <tooltip-behavior>)
 => ()
  t.rollover-time := 0.0;
  t.mouse-over? := #t;
  next-method();
end;

define method on-event (e :: <mouse-out-event>, t :: <tooltip-behavior>)
 => ()
  t.mouse-over? := #f;
  hide-tooltip(t);
  next-method();
end;

define method on-event (e :: <mouse-button-down-event>,
                        t :: <tooltip-behavior>)
 => (consumed? :: <boolean>)
  // Ensure we hide the tooltip if the user clicks on the thing.
  t.mouse-over? := #f; // TODO: ???
  hide-tooltip(t, fade-out-duration: 0.0);
  next-method();
end;

define method on-event (e :: <update-event>, t :: <tooltip-behavior>)
 => ()
  if (t.mouse-over?)
    t.rollover-time := t.rollover-time + e.delta-time;
  end;

  if ((t.rollover-time > t.tooltip-delay) & ~t.showing-tooltip?)
    show-tooltip(t);
  end;

  if (t.fade-tween)
    update-tween(t.fade-tween, e.delta-time);
  end;

  next-method();
end;

define function show-tooltip (t :: <tooltip-behavior>) => ()
  if (t.fade-tween)
    finish-tween(t.fade-tween);
    t.fade-tween := #f;
  end;

  t.showing-tooltip? := #t;
  t.tooltip-visual.visible? := #t;
  t.tooltip-visual.pos
    := global-to-local(local-to-global(t.tooltip-offset, t.behavior-owner),
                       t.tooltip-visual.parent);
  t.fade-tween := tween-to ($tooltip-fade-in-duration)
                    t.tooltip-visual.alpha => 1.0
                  end;
  start-tween(t.fade-tween);
end;

define function hide-tooltip
    (t :: <tooltip-behavior>,
     #key fade-out-duration = $tooltip-fade-out-duration) => ()
  if (t.fade-tween)
    finish-tween(t.fade-tween);
    t.fade-tween := #f;
  end;

  t.showing-tooltip? := #f;
  t.rollover-time := 0.0;

  // fade out if not already invisible
  if (t.tooltip-visual.visible?)
    t.fade-tween := sequentially ()
                      tween-to (fade-out-duration)
                        t.tooltip-visual.alpha => 0.0;
                      end;
                      action
                        t.tooltip-visual.visible? := #f
                      end
                    end;
    start-tween(t.fade-tween);
  end;
end;

define function add-tooltip (v :: <visual>,
                             tooltip-visual :: <visual>,
                             #key offset :: <vec2>,
                                  tooltip-delay = #f)
 => (tooltip :: <tooltip-behavior>)
  tooltip-visual.visible? := #f;
  tooltip-visual.alpha := 0.0;
  let t = make(<tooltip-behavior>,
               tooltip-visual: tooltip-visual,
               tooltip-offset: offset,
               tooltip-delay:  tooltip-delay | $default-tooltip-delay);
  attach-behavior(v, t);
  t
end;

