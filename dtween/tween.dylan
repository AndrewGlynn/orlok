module: tween
author: Andrew Glynn
copyright: copyright: See LICENSE file in this distribution.

define abstract class <tween> (<object>)
end;

// Return the duration of the tween, including any start delay, time-scale,
// repeats, etc.
define open generic duration (tw :: <tween>) => (time :: <single-float>);

// If a tween (or other object) is paused, updating it has no effect.
define open generic paused? (obj) => (p? :: <boolean>);
define open generic paused?-setter (p? :: <boolean>, obj) => (p? :: <boolean>);

// A tween is expired if it has advanced to its duration or beyond.
// The tween's on-complete callback will be called during the first update
// in which expired?(tween) becomes true.
define open generic expired? (obj) => (finished? :: <boolean>);

// Set/reset the tween to time zero. The first time this is called for a tween,
// the tween's initial values will be read from the target object.
// For later calls the initial values will only be read from the target object
// if reinitialize is true.
// If present, the tween's on-init callback will be triggered.
define generic start-tween (tw :: <tween>, #key reinitialize? = #f) => ();

// Advance tw by dt seconds.
// This may update the target object's slots, fire off callbacks, etc.
define generic update-tween (tw :: <tween>, dt :: <single-float>) => ();

// Immediately finish the tween (equivalent to updating it to its
// duration).
define generic finish-tween (tw :: <tween>) => ();

// Callback function called every time tw is (re)started.
// It will be called with tw as its only parameter.
define generic on-start (tw :: <tween>) => (callback :: false-or(<function>));
define generic on-start-setter
    (new-callback :: false-or(<function>), tw :: <tween>)
 => (new-callback :: false-or(<function>));

// Callback function called when tw finishes. 
// It will be called with tw as its only parameter.
define generic on-finish (tw :: <tween>)
 => (callback :: false-or(<function>));
define generic on-finish-setter
    (new-callback :: false-or(<function>), tw :: <tween>)
 => (new-callback :: false-or(<function>));

// Delay a tween's actions by a given amount.
// Note, however, that the on-start callback will be called immediately
// when start-tween is called rather than waiting for the delay to finish.
define generic start-delay (tw :: <tween>) => (delay :: <single-float>);
define generic start-delay-setter (delay :: <single-float>, tw :: <tween>)
 => (delay :: <single-float>);

// Objects that support a time scale can modify the rate at which they update.
// (But note that negative time-scales might not work!)
define open generic time-scale (obj) => (scale :: <single-float>);
define open generic time-scale-setter (scale :: <single-float>, obj)
 => (scale :: <single-float>);




