module: tween-base
author: Andrew Glynn
copyright: copyright: See LICENSE file in this distribution.

define class <tween-base> (<tween>)
  slot local-duration :: <single-float>       = 1.0, init-keyword: duration:;
  slot on-start       :: false-or(<function>) = #f;
  slot on-finish      :: false-or(<function>) = #f;
  slot start-delay    :: <single-float>       = 0.0;
  slot time-scale     :: <single-float>       = 1.0;
  slot paused?        :: <boolean>            = #f;

  // the "transient" portion (can I split them up somehow?):
  slot current-time :: <single-float> = 0.0;
  slot completed?   :: <boolean> = #f;
end;

define method duration (tween :: <tween-base>) => (time :: <single-float>)
  tween.start-delay + (tween.local-duration * tween.time-scale)
end;

define method expired? (tween :: <tween-base>) => (dead? :: <boolean>)
  tween.current-time >= tween.local-duration
end;

define method start-tween (tween :: <tween-base>, #key reinitialize? = #f) => ()
  if (tween.start-delay > 0.0)
    tween.current-time := - tween.start-delay
  else
    tween.current-time := 0.0
  end;

  tween.completed? := #f;

  if (tween.on-start)
    tween.on-start(tween)
  end;
end;

define method update-tween (tween :: <tween-base>, dt :: <single-float>)
 => ()
  if (~tween.paused?)
    tween.current-time := tween.current-time + (dt / tween.time-scale);
    
    if (expired?(tween))
      kill(tween)
    end;
  end;
end;

define method finish-tween (tween :: <tween-base>) => ()
  tween.current-time := tween.local-duration;
  kill(tween);
end;

define function kill (tween :: <tween-base>) => ()
  let was-completed? = tween.completed?;
  tween.completed? := #t;
  
  if (tween.on-finish & ~was-completed?)
    tween.on-finish(tween);
  end;
end;


