module: macros
author: Andrew Glynn
copyright: See LICENSE file in this distribution.


define macro tween-to
  {
    tween-to (?duration:expression,
              #key ?ease:expression       = ease-linear,
                   ?delay:expression      = 0.0,
                   ?time-scale:expression = 1.0,
                   ?on-start:expression   = #f,
                   ?on-finish:expression  = #f,
                   ?group:expression      = #f)
      ?items:*
    end
  }
 =>
  {
    let t = make(<expression-tween>,
                 duration:         ?duration,
                 init-functions:   expr-init-functions(?items),
                 update-functions: expr-update-functions(?items),
                 final-values:     expr-final-values(?items),
                 ease-function:    ?ease);

    t.start-delay   := ?delay;
    t.time-scale    := ?time-scale;
    t.on-start      := ?on-start;
    t.on-finish     := ?on-finish;

    let g = ?group;

    if (g)
      add-tween-to-group(g, t)
    end;

    t
  }
end;

// auxiliary macros for tween-to

define macro expr-init-functions
  { expr-init-functions (?values) } => { vector(?values) }
values:
  {} => {}
  { ?assignable:expression => ?final:expression; ... }
 =>
  { method () ?assignable end, ... }
end;

define macro expr-update-functions
  { expr-update-functions (?values) } => { vector(?values) }
values:
  {} => {}
  { ?assignable:expression => ?final:expression; ... }
 =>
  { method (v) ?assignable := v end, ... }
end;

define macro expr-final-values
  { expr-final-values (?values) } => { vector(?values) }
values:
  {} => {}
  { ?assignable:expression => ?final:expression; ... }
 =>
  { ?final, ... }
end;

// Macro for creating a basic object tween.
define macro tween-object-to
  {
    tween-object-to (?target:expression,
                     ?duration:expression,
                     #key ?ease:expression       = ease-linear,
                          ?delay:expression      = 0.0,
                          ?time-scale:expression = 1.0,
                          ?on-start:expression   = #f,
                          ?on-finish:expression  = #f,
                          ?group:expression      = #f)
      ?items:*
    end
  }
 =>
  {
    let t = make(<object-tween>,
                 target: ?target,
                 duration: ?duration,
                 target-slot-getters: object-getters(?items),
                 target-slot-setters: object-setters(?items),
                 final-values: object-final-values(?items),
                 ease-function: ?ease);

    t.start-delay   := ?delay;
    t.time-scale    := ?time-scale;
    t.on-start      := ?on-start;
    t.on-finish     := ?on-finish;

    if (?group)
      add-tween-to-group(?group, t)
    end;

    t
  }
end;

// auxiliary macros for tween-object-to

define macro object-getters
  { object-getters (?items) } => { vector(?items) }
items:
  {} => {}
  { ?:name => ?:expression, ... } => { ?name, ... }
end;

define macro object-setters
  { object-setters (?items) } => { vector(?items) }
items:
  {} => {}
  { ?:name => ?:expression, ... } => { ?name ## "-setter", ... }
end;

define macro object-final-values
  { object-final-values (?items) } => { vector(?items) }
items:
  {} => {}
  { ?:name => ?:expression, ... } => { ?expression, ... }
end;

// Create and return a <multi-tween> by sequencing a series of tweens end to end.
// Optionally specify a <tween-group> to which the resulting <multi-tween>
// will be added.
define macro sequentially
  { sequentially (#key ?group:expression = #f) ?tween-list end }
    =>
  {
    let group = ?group;
    let m     = make(<multi-tween>);
    let t     = 0.0;

    for (tw in vector(?tween-list))
      add-tween(m, t, tw, recompute-duration?: #f);
      t := t + tw.duration;
    end;

    compute-duration(m);

    if (group)
      add-tween-to-group(group, m);
    end;

    m
  }

tween-list:
  {} => {}
  { ?tween:expression; ... } => { ?tween, ... }
end;

// Create and return a <multi-tween> to run a set of tweens simultaneously.
// Optionally specify a <tween-group> to which the resulting <multi-tween>
// will be added.
define macro concurrently
  { concurrently (#key ?group:expression = #f) ?tween-list end }
    =>
  {
    let group = ?group;
    let m     = make(<multi-tween>);

    for (tw in vector(?tween-list))
      add-tween(m, 0.0, tw, recompute-duration?: #f);
    end;

    compute-duration(m);

    if (group)
      add-tween-to-group(group, m);
    end;

    m
  }

tween-list:
  {} => {}
  { ?tween:expression; ... } => { ?tween, ... }
end;


// Convenience function to create a tween that has no effect yet
// has a duration (useful in the 'sequentially' macro).
define function pause-for (time :: <single-float>) => (tw :: <object-tween>)
  tween-object-to(#f, time) end
end;

// Really only useful in a <multi-tween>, an action is just an instantaneous
// event that is used for its side-effects.
define macro action
  { action ?:body end }
    =>
  {
    tween-to(0.0, on-finish: method(ignored) ?body end) end
  }
end;

// Delay evaluation of a body of code by a certain duration,
// as determined by a tween group.
define macro delay
  {
    delay (?duration:expression, group: ?tween-group:expression)
      ?:body
    end
  }
 =>
  {
    tween-to(?duration,
             group: ?tween-group,
             on-finish: method (_) ?body end)
    end
  }
end;
