module: multi-tween
synopsis: <multi-tween> is a tween containing multiple sub-tweens.
author: Andrew Glynn
copyright: copyright: See LICENSE file in this distribution.


define class <elem> (<object>)
  constant slot tween      :: <tween>, required-init-keyword: tween:;
  constant slot start-time :: <single-float>, required-init-keyword: start-time:;
  constant slot end-time   :: <single-float>, required-init-keyword: end-time:;

  slot started?  :: <boolean> = #f;
  slot finished? :: <boolean> = #f;
end;

define sealed domain make (singleton(<elem>));

define class <multi-tween> (<tween-base>)
  slot elems :: limited(<stretchy-vector>, of: <elem>)
    = make(limited(<stretchy-vector>, of: <elem>));
  slot reinitializing? :: <boolean> = #f;
end;

define method start-tween (m :: <multi-tween>, #key reinitialize? = #f) => ()
  next-method();
  m.reinitializing? := reinitialize?;

  for (e in m.elems)
    e.started?  := #f;
    e.finished? := #f;
  end;
end;

// Update m, recursively updating any active sub-tweens.
// Sub-tweens will be started, updated, and finished as appropriate.
// BUG: Note that although any and all appropriate on-start and on-finish callbacks
// will be triggered, the order in which they are called is undefined and might
// not reflect the actual order in which they should occur.
define method update-tween (m  :: <multi-tween>,
                            dt :: <single-float>) => ()
  next-method();
  if (~m.paused? & m.current-time >= 0.0)
    update-elems(m, dt / m.time-scale)
  end
end;

define function update-elems (m  :: <multi-tween>,
                              dt :: <single-float>) => ()
  let t0 = m.current-time;
  let t1 = t0 + dt;

  // update tweens that were active for at least part of the update step
  //
  //        t0        t1
  //           |----|         
  //     |-------|            
  //             |--------|   
  //     |----------------|
  //
  for (e in m.elems)
    let start  = e.start-time;
    let finish = e.end-time;
    let tw     = e.tween;

    if (start <= t1 & ~e.started?)
      start-tween(tw, reinitialize?: m.reinitializing?);
      e.started? := #t;
    end;

    if (finish <= t1 & ~e.finished?)
      finish-tween(tw);
      e.finished? := #t;
    end;
    
    if (e.started? & ~e.finished?)
      update-tween(tw, t1 - t0);
    end;
  end;
end;

define inline function elem-sorter (a :: <elem>, b :: <elem>)
 => (sorted? :: <boolean>)
  a.start-time < b.start-time
end;

define method add-tween (m          :: <multi-tween>,
                         start-time :: <single-float>,
                         tw         :: <tween>,
                         #key recompute-duration? :: <boolean> = #t) => ()
  if (start-time < 0.0)
    error("illegal negative start time for element of <multi-tween>")
  end;

  let elem = make(<elem>,
                  tween:      tw,
                  start-time: start-time,
                  end-time:   start-time + tw.duration);

  // optimize: don't sort every time, only when first starting the group?
  m.elems := add!(m.elems, elem);
  m.elems := sort!(m.elems, test: elem-sorter); // TODO: stable? do I care?
  
  if (recompute-duration?)
    compute-duration(m);
  end;
end;

define function compute-duration (m :: <multi-tween>) => ()
  m.local-duration := map-reduce(max, end-time, 0.0, m.elems)
end;


