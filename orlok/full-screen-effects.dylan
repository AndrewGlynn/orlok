module: full-screen-effects-implementation
author: Andrew Glynn
copyright: copyright: See LICENSE file in this distribution.


define abstract class <full-screen-effect> (<disposable>)
end;

// Before instantiating and using a <full-screen-effect> you must first
// install its type into the <app>.
// TODO: Is subtype() implemented? It would be useful here (and below).
define generic install-effect (app :: <app>, effect-type :: <class>) => ();

// Uninstall a <full-screen-effect> subtype from an <app> if it is no longer
// needed. Note that an effect type that is not uninstalled will still
// properly release its resources at shutdown. As such, this function is
// purely an optimization to free up resources earlier.
define generic uninstall-effect (app :: <app>, effect-type :: <class>) => ();

// Begin rendering using the given effect. Nothing will be rendered to the
// screen until the corresponding call to end-effect.
define generic begin-effect (e :: <full-screen-effect>, ren :: <renderer>)
 => ();

// Finish and apply a <full-screen-effect> to the screen.
define generic end-effect (e :: <full-screen-effect>, ren :: <renderer>)
 => ();
