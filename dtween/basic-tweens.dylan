module: basic-tweens
author: Andrew Glynn
copyright: See LICENSE file in this distribution.

//============================================================================
//----------    <object-tween>    ----------
//============================================================================

// A basic tween targeting a single object.
// This can affect multiple target slots, however.
define class <object-tween> (<tween-base>)
  constant slot target-object, required-init-keyword: target:;

  slot target-slot-getters :: <sequence>, init-keyword: target-slot-getters:;
  slot target-slot-setters :: <sequence>, init-keyword: target-slot-setters:;
  slot initial-values      :: <sequence>;
  slot final-values        :: <sequence>, init-keyword: final-values:;
  slot ease-function       :: <function> = ease-linear,
    init-keyword: ease-function:;
  slot initialized?        :: <boolean>  = #f;
end;

define method start-tween (tween :: <object-tween>, #key reinitialize? = #f)
 => ()
  next-method();

  if (~tween.initialized? | reinitialize?)
    tween.initial-values := make(<vector>, size: tween.target-slot-getters.size);
    for (getter in tween.target-slot-getters,
         i from 0)
      tween.initial-values[i] := getter(tween.target-object)
    end;
    tween.initialized? := #t;
  else
    // reset to previous initial values
    for (setter in tween.target-slot-setters,
         i from 0)
      setter(tween.initial-values[i], tween.target-object)
    end;
  end;
end;
  
define method finish-tween (tween :: <object-tween>) => ()
  for (setter in tween.target-slot-setters,
       final  in tween.final-values)
    setter(final, tween.target-object);
  end;
  next-method();
end;

define method update-tween (tween :: <object-tween>, dt :: <single-float>)
 => ()
  next-method();
  if (~tween.paused? & tween.current-time >= 0.0)
    update-slot-values(tween, tween.current-time);
  end;
end;

define function update-slot-values
    (tween :: <object-tween>, t :: <single-float>)
 => ()
  for (initial in tween.initial-values,
       final   in tween.final-values,
       setter  in tween.target-slot-setters)
    let v = evaluate(initial,
                     final,
                     tween.local-duration,
                     t,
                     tween.ease-function);
    setter(v, tween.target-object);
  end
end;

//============================================================================
//----------    <expression-tween>    ----------
//============================================================================

// A tween for tweening arbitrary assignable expressions.
define class <expression-tween> (<tween-base>)
  constant slot init-functions :: <sequence>,
    required-init-keyword: init-functions:;
  constant slot update-functions :: <sequence>,
    required-init-keyword: update-functions:;
  slot initial-values :: <sequence>;
  constant slot final-values :: <sequence>,
    required-init-keyword: final-values:;
  slot ease-function :: <function> = ease-linear,
    init-keyword: ease-function:;
  slot initialized? :: <boolean> = #f;
end;

define method start-tween (tween :: <expression-tween>,
                           #key reinitialize? = #f) => ()
  next-method();

  if (~slot-initialized?(tween, initial-values))
    tween.initial-values := make(<vector>, size: tween.init-functions.size);
  end;

  if (~tween.initialized? | reinitialize?)
    for (init in tween.init-functions,
         i from 0)
      tween.initial-values[i] := init();
    end;

    tween.initialized? := #t;
  else
    // reset to previous initial values
    for (updater in tween.update-functions,
         init    in tween.initial-values)
      updater(init);
    end;
  end;
end;
  
define method finish-tween (tween :: <expression-tween>) => ()
  for (updater in tween.update-functions,
       final   in tween.final-values)
    updater(final);
  end;

  next-method();
end;

define method update-tween (tween :: <expression-tween>, dt :: <single-float>)
 => ()
  next-method();
  if (~tween.paused? & tween.current-time >= 0.0)
    update-expression-values(tween, tween.current-time);
  end;
end;

define function update-expression-values
    (tween :: <expression-tween>, t :: <single-float>)
 => ()
  for (initial in tween.initial-values,
       final   in tween.final-values,
       updater in tween.update-functions)
    updater(evaluate(initial,
                     final,
                     tween.local-duration,
                     t,
                     tween.ease-function));
  end;
end;

//============================================================================
//----------    Helpers    ----------
//============================================================================


define inline function evaluate (initial-value,
                                 final-value,
                                 duration      :: <single-float>,
                                 t             :: <single-float>,
                                 ease-function :: <function>) => (result)
  case
    duration < 0.0  => t := 0.0; // TODO: should this be an error?
    duration == 0.0 => t := 1.0;
    otherwise       => t := t / duration; // normalize
  end;

  case
    t <= 0.0  => initial-value;
    t >= 1.0  => final-value;
    otherwise => interpolate(initial-value, final-value, ease-function(t));
  end;
end;


// Swap a tween's initial and final values. This has the effect of changing
// a tween _to_ a location to a tween _from_ a location (and vice versa).
// Calling this after a tween has been updated might have strange results.
// TODO: But what if the tween hasn't initialized (!) its initial-values yet?
/*
define function swap-initial/final-values (tween :: <object-tween>) => ()
  let tmp = tween.final-values;
  tween.final-values := tween.initial-values;
  tween.initial-values := tmp;
end;
*/



