module: orlok-core
author: Andrew Glynn
copyright: See LICENSE file in this distribution.


//============================================================================
//----------------  Errors and Warnings  ----------------
//============================================================================

define class <orlok-error> (<error>)
  constant slot orlok-error-format :: <string>,
    required-init-keyword: format:;
  constant slot orlok-error-args :: <sequence>,
    required-init-keyword: args:;
end class;

define function orlok-error (format :: <string>, #rest args) => ()
  error(make(<orlok-error>, format: format, args: args))
end function;

define class <orlok-warning> (<condition>)
  constant slot orlok-warning-format :: <string>,
    required-init-keyword: format:;
  constant slot orlok-warning-args :: <sequence>,
    required-init-keyword: args:;
end class;

define function orlok-warning (format :: <string>, #rest args) => ()
  signal(make(<orlok-warning>, format: format, args: args))
end function;


//============================================================================
//----------------  App  ----------------
//============================================================================


define open abstract class <app> (<object>)
  constant slot config :: <app-config>,
    required-init-keyword: config:;
  constant slot dispose-on-shutdown-pool :: <table> = make(<table>);
end class;

// Return the currently running app.
// Signals an error if no app is running.
define generic the-app () => (app :: <app>);

// Basic application configuration.
// If app-width and app-height are not supplied, they will be initialized to
// be equal to the window dimensions.
define abstract class <app-config> (<object>)
  required keyword window-width:;
  required keyword window-height:;
  keyword app-width: = #f;
  keyword app-height: = #f;
  keyword force-app-aspect-ratio?: = #f;
  keyword full-screen?: = #f;
  keyword frames-per-second: = 60;
end;

// Physical/device dimensions.
define generic window-width (cfg) => (w :: <integer>);
define generic window-height (cfg) => (h :: <integer>);

// Logical application dimensions.
// Most apps should pay attention to these values rather than the window
// (physical) dimensions.
define generic app-width (cfg :: <app-config>) => (w :: <integer>);
define generic app-height (cfg :: <app-config>) => (h :: <integer>);

// If true, the app will be rendered with only uniform scaling to the window,
// at the expense of requiring either horizontal or vertical black letterbox
// bars if the app and window aspect ratios don't match.
// Otherwise, the app will fill up the window entirely, possibly with
// stretching in the horizontal or vertical directions.
define generic force-app-aspect-ratio? (cfg :: <app-config>)
 => (force-aspect-ratio? :: <boolean>);

// If true, the app is currently in full-screen mode, otherwise the app is
// windowed.
define generic full-screen? (cfg) => (full? :: <boolean>);

// The desired framerate of the app. Note that the actual framerate may
// fluctuate, and in particular may be significantly lower depending on
// the complexity of the app's computations and rendering.
// See also average-frames-per-second.
define generic frames-per-second (cfg :: <app-config>) => (fps :: <integer>);


// Run your app.
// 1) Performs necessary system initializations.
// 2) Sends a <startup-event>.
// 3) Opens window based on app.config’s values.
// 4) Begins main loop, which repeatedly:
//    a) Sends <input-event>s.
//    b) Sends an <update-event>.
//    c) Sends a <render-event>.
// 5) Sends a <shutdown-event> when the main loop exits.
define generic run-app(app :: <app>) => ();

// Notify the system that the app wishes to quit. The main loop continues 
// until its current iteration completes. At that point, a <shutdown-event> 
// will be sent.
define generic quit-app (app :: <app>) => ();

// Return the elapsed seconds since the app began. Note that this is in
// "logical" app time, which assumes a fixed framerate, regardless of
// actual framerate fluctuations.
define generic app-time (app :: <app>) => (elapsed-seconds :: <single-float>);

// Return the current actual average frames per second over a certain sample
// interval (not specified).
define generic average-frames-per-second (app :: <app>)
 => (fps :: <single-float>);

// Switch to or return from full-screen mode.
// The app's physical dimensions are likely to change when switching modes
// (ie, window-width and window-height). A <resize-event> will be sent in
// these cases.
define generic set-full-screen (app :: <app>, full-screen? :: <boolean>)
 => ();

// Update the app's logical size.
// This does not change the physical window size or screen resolution.
define generic set-app-size (app :: <app>,
                             width :: <integer>,
                             height :: <integer>) => ();

// If force? is true, force the app to render without non-uniformly stretching
// the image (possibly requiring letterbox bars). Otherwise, the app image
// will stretch to fit the entire window regardless of aspect ratio.
define generic set-force-app-aspect-ratio (app :: <app>,
                                           force? :: <boolean>) => ();


//============================================================================
//----------------  Events  ----------------
//============================================================================


define open abstract class <event> (<object>)
end class;

// Generic event handler interface.
// Note that the type of handlers is not constrained, to allow for open
// extension. The results (if any) depend on the event type.
define open generic on-event (e :: <event>, handler) => (#rest results);

// Default do-nothing method for application events, so apps need only
// implement what they require.
define method on-event (e :: <event>, app :: <app>) => (#rest results)
  // do nothing
end method;

// Sent once, after initialization but before the main loop begins.
// This is a good time to load/create images, sounds, etc.
define class <startup-event> (<event>)
end class;

// Sent once, after the main loop exits (ie, after the final render event).
define class <shutdown-event> (<event>)
end class;

// Sent once per frame, after input events and before rendering.
define class <update-event> (<event>)
  // Time elapsed since the last frame, in seconds. This is fixed based on the
  // app's framerate, so this is really just a convenience. From this it
  // follows that this will be non-zero even for the first frame.
  // Note that this is not wall-clock time but simulation time. In particular,
  // if the actual framerate drops, the delta-time will still stay the same.
  // Apps are responsible for maintaining an adequate actual framerate.
  constant slot delta-time :: <single-float>,
    required-init-keyword: delta-time:;
end class;

// Sent when the window is resized.
// The slots indicate the new window size and full-screen status.
// Note that a series of <resize-event>s may be sent (e.g., while animating
// to a new size or while dragging to a new size). Don't assume this will
// only be sent when the new "target" size is reached.
// Also, this is likely to be sent when switching to/from full-screen mode.
// The app's <app-config> will be updated before this event is sent.
define class <resize-event> (<event>)
  constant slot window-width :: <integer>,
    required-init-keyword: window-width:;
  constant slot window-height :: <integer>,
    required-init-keyword: window-height:;
  constant slot full-screen? :: <boolean>,
    required-init-keyword: full-screen?:;
end;


//============================================================================
//----------------  Input  ----------------
//============================================================================


define constant <key-id> = <integer>;

// Test whether a key is currently down.
define generic key-down? (app :: <app>, key :: <key-id>)
    => (down? :: <boolean>);

// Test whether a key is currently up.
define generic key-up? (app :: <app>, key :: <key-id>)
    => (up? :: <boolean>);

// The <input-event> hierarchy is overly complex, particularly for
// <mouse-event>s, but the idea is that you can implement methods for events
// that are as specific or general as you require.

define open abstract class <input-event> (<event>)
end class;

define abstract class <key-event> (<input-event>)
  constant slot key-id :: <key-id>, required-init-keyword: id:;
end class;

define class <key-down-event> (<key-event>)
end class;

define class <key-up-event> (<key-event>)
end class;

// Note: Methods on <app> are defined for these.
define generic mouse-x (ob) => (x :: <real>);
define generic mouse-y (ob) => (y :: <real>);
define generic mouse-left-button? (ob) => (down? :: <boolean>);
define generic mouse-right-button? (ob) => (down? :: <boolean>);
define generic mouse-middle-button? (ob) => (down? :: <boolean>);

// Convenience function.
define function mouse-vector (ob) => (v :: <vec2>)
  vec2(ob.mouse-x, ob.mouse-y)
end;

define open abstract class <mouse-event> (<input-event>)
  constant slot mouse-x :: <real> = 0.0,
    init-keyword: x:;
  constant slot mouse-y :: <real> = 0.0,
    init-keyword: y:;
  constant slot mouse-left-button? :: <boolean> = #f,
    init-keyword: left-button?:;
  constant slot mouse-right-button? :: <boolean> = #f,
    init-keyword: right-button?:;
  constant slot mouse-middle-button? :: <boolean> = #f,
    init-keyword: middle-button?:;
end class;

// All mouse events support a with-mouse-state-from keyword argument.
// If supplied, this is another <mouse-event> whose mouse state (position
// and button state) will be copied into the new mouse event. In this case
// none of the standard <mouse-event> keywords need be supplied.
define method initialize
    (m :: <mouse-event>,
     #rest init-args,
     #key with-mouse-state-from: other :: false-or(<mouse-event>) = #f)
 => ()
  if (other)
    apply(next-method,
          x: other.mouse-x,
          y: other.mouse-y,
          left-button?: other.mouse-left-button?,
          right-button?: other.mouse-right-button?,
          middle-button?: other.mouse-middle-button?,
          init-args)
  else
    next-method()
  end
end;

define class <mouse-move-event> (<mouse-event>)
end class;

define abstract class <mouse-button-event> (<mouse-event>)
end class;

define abstract class <mouse-button-down-event> (<mouse-button-event>)
end class;

define abstract class <mouse-button-up-event> (<mouse-button-event>)
end class;

define abstract class <mouse-left-button-event> (<mouse-button-event>)
end class;

define abstract class <mouse-right-button-event> (<mouse-button-event>)
end class;

define abstract class <mouse-middle-button-event> (<mouse-button-event>)
end class;

define class <mouse-left-button-down-event>
    (<mouse-left-button-event>, <mouse-button-down-event>)
end class;

define class <mouse-left-button-up-event>
    (<mouse-left-button-event>, <mouse-button-up-event>)
end class;

define class <mouse-right-button-down-event>
    (<mouse-right-button-event>, <mouse-button-down-event>)
end class;

define class <mouse-right-button-up-event>
    (<mouse-right-button-event>, <mouse-button-up-event>)
end class;

define class <mouse-middle-button-down-event>
    (<mouse-middle-button-event>, <mouse-button-down-event>)
end class;

define class <mouse-middle-button-up-event>
    (<mouse-middle-button-event>, <mouse-button-up-event>)
end class;


//============================================================================
//----------------  Disposable  ----------------
//============================================================================


// Clean up any resources managed by disposable.
define open generic dispose (disposable) => ();

// A convenience base class to provide checks for multiple-disposal errors.
// Subclasses dispose methods should call next-method first to detect
// multiple disposal errors.
define open abstract class <disposable> (<object>)
  slot already-disposed? :: <boolean> = #f;
end class;

define method dispose (d :: <disposable>) => ()
  if (d.already-disposed?)
    orlok-error("attempt to re-dispose object: %=", d);
  end;
  d.already-disposed? := #t;
end method;


// Register a disposable object to be disposed when the app
// receives a <shutdown-event>.
define function dispose-on-shutdown (app :: <app>, disposable) => (disposable)
  app.dispose-on-shutdown-pool[disposable] := disposable;
  disposable
end;

// Remove a disposable object from an app's dispose-on-shutdown pool.
// Returns #t if the object was already registered and was removed,
// #f if the object was not registered.
define function remove-from-dispose-on-shutdown (app :: <app>, disposable)
 => (removed? :: <boolean>)
  remove-key!(app.dispose-on-shutdown-pool, disposable)
end;


//============================================================================
//----------------  Resources  ----------------
//============================================================================


// A resource is just a named disposable object. (Useful for debugging.)
define abstract class <resource> (<disposable>)
  constant slot resource-name :: <string>,
    required-init-keyword: resource-name:;
end;


//============================================================================
//----------------  Audio  ----------------
//============================================================================


// Get/set master volume. Values are clamped to the range [0..1]
define generic get-master-volume () => (volume :: <single-float>);
define generic set-master-volume (volume :: <single-float>) => ();

// A sound that can be played.
define abstract class <sound> (<resource>)
end;

// Load a new <sound>. Signals an error if no such resource is found.
define generic load-sound (resource-name :: <string>) => (snd :: <sound>);

// Begin playing a (new) instance of a <sound>.
define generic play-sound (snd :: <sound>, #key volume = 1.0) => ();

// A music track.
define abstract class <music> (<resource>)
  virtual slot volume :: <single-float>;
end;

// Load a new <music>. Signals an error if no such resource is found.
define generic load-music (resource-name :: <string>) => (mus :: <music>);

// Start or continue playing some <music>.
// If loop? is true, repeat from the beginning when the music finishes.
// If restart? is true, reset the music to the beginning before starting
// to play.
define generic play-music (mus :: <music>,
                           #key loop? :: <boolean> = #t,
                                restart? :: <boolean> = #f) => ();

// Stop playing some <music>. A subsequent call to play-music will continue
// playing where the music left off (unless play-music's restart? keyword is
// #t).
define generic stop-music (mus :: <music>) => ();


//============================================================================
//----------------  Misc (TODO: Organize better)  ----------------
//============================================================================


// Return the axis-aligned bounding rect of obj, in obj's local coordinate
// space. Methods should try to ensure the result is as tight as possible.
define generic bounding-rect (obj) => (bounds :: <rect>);


//============================================================================
//----------------  Bitmaps  ----------------
//============================================================================

// Class of 2D arrays of pixels (aka, surface, etc.).
define abstract class <bitmap> (<disposable>)
  constant slot width :: <integer>, required-init-keyword: width:;
  constant slot height :: <integer>, required-init-keyword: height:;
end;

// Create a new empty <bitmap> of a specified size.
// All pixels will have rgba value 0x000000.
// Both width and height must be > 0, or an error will be signaled.
define generic create-bitmap (width :: <integer>, height :: <integer>)
 => (bmp :: <bitmap>);

// Create a new bitmap as a (possibly partial) copy of source. Source may be
// another <bitmap>, a <texture>, or an <image>. If source-region is not #f,
// the created bitmap is a copy of only the specified source-region of source.
// Note that the actual source-region used is the intersection of source-region
// and source.bounding-rect, so the resulting <bitmap> may be smaller than
// source-region specifies (due to clipping). If the intersection has zero
// width or height an error is signaled. If source-region is #f, the full
// bounds of source are used.
define generic create-bitmap-from (source,
                                   #key source-region :: false-or(<rect>) = #f)
 => (bmp :: <bitmap>);

// Load a <bitmap> from an image resource. If the resource does not exist or
// does not specify an image of a supported type, an error is signaled.
define generic load-bitmap (resource-name :: <string>) => (bmp :: <bitmap>);

define sealed method bounding-rect (bmp :: <bitmap>) => (bounds :: <rect>)
  make(<rect>, left: 0, top: 0, width: bmp.width, height: bmp.height)
end;

// Copy a rectangular area of source onto destination.
// The point of source-region specified by alignment will be mapped to
// destination-pt in destination.
// All components of source-region and destination-pt will be rounded to
// <integer> values.
// TOOD: Does this respect transparency? More generally, what is the blend
//       function?
define generic copy-pixels
    (#key source :: <bitmap>,
          source-region :: <rect>,
          destination :: <bitmap>,
          destination-pt :: <vec2> = vec2(0.0, 0.0),
          align :: <alignment> = $left-top) => ();

// Clear a <bitmap> to a given color. If region is not false, clear only the
// specified region (region's coordinates will be rounded to the nearest
// integer values).
define generic clear-bitmap (bmp :: <bitmap>, color :: <color>,
                             #key region :: false-or(<rect>) = #f) => ();

// Premultiply a <bitmap>'s red/green/blue components by the corresponding
// alpha component values.
define generic bitmap-premultiply (bmp :: <bitmap>) => ();

// Undo premultiplication of a <bitmap>'s red/green/blue components by the
// corresponding alpha component values. Essentially, divide r, g, and
// b by a.
define generic bitmap-unpremultiply (bmp :: <bitmap>) => ();

// Flip a <bitmap> vertically (i.e., over the horizontal axis).
define generic bitmap-flip-vertical (bmp :: <bitmap>) => ();

// TODO: Remove <bitmap-filter> and resize-bitmap?

define enum <bitmap-filter> ()
  $bitmap-filter-box;
  $bitmap-filter-triangle;
  $bitmap-filter-gaussian;
end;

define generic resize-bitmap (bmp :: <bitmap>,
                              new-width :: <integer>,
                              new-height :: <integer>,
                              #key filter = $bitmap-filter-box) => ();


//============================================================================
//----------------  Textures  ----------------
//============================================================================

define class <texture-error> (<orlok-error>)
end;

define enum <texture-filter> ()
  $texture-filter-nearest-neighbor;
  $texture-filter-bilinear;
end;

define enum <texture-wrap> ()
  $texture-wrap-clamp;
  $texture-wrap-repeat;
end;

define abstract class <texture> (<disposable>)
  constant slot width :: <integer>,
    required-init-keyword: width:;
  constant slot height :: <integer>,
    required-init-keyword: height:;
  constant slot texture-filter :: <texture-filter> = $texture-filter-bilinear,
    init-keyword: filter:;
  constant slot texture-wrap :: <texture-wrap> = $texture-wrap-clamp,
    init-keyword: wrap:;
end;

// A special <texture> suitable for use as a render target.
// Set the <renderer>'s render-to-texture slot to a <render-texture> to direct
// all rendering to the texture rather than the screen.
define abstract class <render-texture> (<texture>)
end;

define sealed method bounding-rect (tex :: <texture>) => (bound :: <rect>)
  make(<rect>, left: 0, top: 0, width: tex.width, height: tex.height)
end;

// Create a new texture with the given dimensions.
// The contents of the new texture are undefined. Signals <texture-error> on
// failure (e.g., not enough texture memory, invalid dimensions, etc.).
define generic create-texture (width :: <integer>, height :: <integer>)
 => (tex :: <texture>);

// Create a new texture with the same contents as bmp.
// If source-region is specified, the new texture will be a copy of that
// portion of source contained in:
//    rect-intersection(source.bounding-rect, source-region).
// Signals <texture-error> if something doesn't work.
define generic create-texture-from (source,
                                    #key source-region :: false-or(<rect>) = #f)
 => (tex :: <texture>);

// Create a new <render-texture> with the given dimensions.
// Signals <texture-error> if something doesn't work.
define generic create-render-texture (width :: <integer>, height :: <integer>)
 => (tex :: <render-texture>);

// Replace the pixels of tex with those in bmp.
// If bitmap-region is #f, bmp must be the same size as tex.
// If bitmap-region is not false, bitmap-region must be the same size as
// tex (after rounding), and must fall entirely within bmp.
// Signals <texture-error> on failure.
define generic update-texture (tex :: <texture>, bmp :: <bitmap>,
                               #key bitmap-region :: false-or(<rect>) = #f)
 => ();


//============================================================================
//----------------  Shaders  ----------------
//============================================================================


define class <shader-error> (<orlok-error>)
end;

// A class encapsulating a vertex shader and a pixel/fragment shader.
define abstract class <shader> (<disposable>)
end;

// Load a <shader> from its vertex-shader and fragment-shader component
// resources. Signals a <shader-error> if something goes wrong (no such
// resource, shader compile error, etc.).
define generic load-shader (vertex-shader-resource :: <string>,
                            fragment-shader-resource :: <string>)
 => (shader :: <shader>);

// Create a new <shader> directly from vertex-shader and fragment-shader
// source code strings. Signals a <shader-error> if there is an error
// compiling the source code.
define generic create-shader (vertex-shader-source :: <string>,
                              fragment-shader-source :: <string>)
 => (shader :: <shader>);

// Set a named uniform value in a shader.
// Methods are defined for values of type:
//   <integer>      => int
//   <single-float> => float
//   <vec2>         => vec2
//   <color>        => vec4 (rgba)
// Note that all shaders have an implicitly defined uniform "tex0" of type
// sampler2D that will be bound to the renderer's active texture.
define generic set-uniform (shader :: <shader>,
                            name :: <string>,
                            value) => ();


//============================================================================
//----------------  Fonts  ----------------
//============================================================================


define abstract class <font> (<disposable>)
  virtual constant slot font-name :: <string>;
  virtual constant slot font-size :: <single-float>;
  virtual constant slot font-ascent :: <single-float>;
  virtual constant slot font-descent :: <single-float>;
  virtual constant slot font-leading :: <single-float>;
end;

define generic load-font (font-file-name :: <string>, size :: <real>)
 => (f :: <font>);

// Get a <rect> describing the bounding box for the given text in the given
// font. Note that the left and bottom edges of the extents may be (and
// probably are!) negative.
define generic font-extents (f :: <font>, text :: <string>)
 => (extents :: <rect>);


//============================================================================
//----------------  Renderer  ----------------
//============================================================================

// TODO: Replace and improve this concept.
define enum <blend-mode> ()
  $blend-normal;
  $blend-additive;
end;

// A <renderer> is used for actually drawing to the window (or potentially
// an offscreen target). 
// Important: The transform-2d virtual slot will return a *copy* of the
// renderer's actual transform. Modifications to this copy will not affect
// the renderer's transform. You must set it (via transform-2d-setter) to
// actually update the transform. Alternatively, <renderer> supports methods
// on translate!, rotate!, and scale! that directly affect its internal
// transform. So, given a <renderer> ren, the following are not equivalent:
//    rotate!(ren, 3.0); // rotates ren's actual transform
//    rotate!(ren.transform-2d, 3.0); // rotates temporary copy! useless!
define class <renderer> (<object>)
  virtual slot texture            :: false-or(<texture>);
  virtual slot shader             :: false-or(<shader>);
  virtual slot render-to-texture  :: false-or(<texture>);
  virtual slot transform-2d       :: <affine-transform-2d>;
  virtual slot logical-size       :: <vec2>; // TODO: better name???
  virtual slot viewport           :: <rect>;
  virtual slot blend-mode         :: <blend-mode>;
  virtual slot render-color       :: <color>; // TODO: better name?
end;

// The type of "paint" is determined by subclasses.
// Note that some objects other than <renderer>s may also be clearable,
// e.g., <vg-context>.
define open generic clear (clearable, paint) => ();

// Draw a rectangle, as transformed by the renderer’s current transform
// matrix, aligning the given alignment point of the rect to the point ‘at’.
// If color is not #f, render as a solid color.
// If texture is not #f, set it as the renderer’s current texture
// temporarily while rendering (then revert to the previous value). Otherwise
// use the renderer’s current texture (unless ‘color’ is specified).
// If texture-rect is not #f, use that for the texture coordinates (in texel
// coordinates, not normalized texture coordinates).
// If shader is not #f, temporarily set it as the renderer’s shader, unless
// color is specified.
define generic draw-rect (ren :: <renderer>, rect :: <rect>,
                          #key at :: <vec2> = vec2(0, 0),
                               align :: false-or(<alignment>) = #f,
                               texture :: false-or(<texture>) = #f,
                               texture-rect :: false-or(<rect>) = #f,
                               shader :: false-or(<shader>) = #f,
                               color :: false-or(<color>) = #f) => ();

// Draw text using the given font, as transformed by the renderer’s current
// transform matrix, aligning the given alignment point of the text to the
// point ‘at’. If color is not #f, render the text using the given color.
// If shader is not #f, render the text using the given shader.
define generic draw-text (ren :: <renderer>,
                          text :: <string>,
                          font :: <font>,
                          #key at :: <vec2> = vec2(0, 0),
                               align :: <alignment> = bottom-left,
                               color :: false-or(<color>) = #f,
                               shader :: false-or(<shader>) = #f) => ();

// Draw a line of the given color and width.
define generic draw-line (ren :: <renderer>,
                          from :: <vec2>,
                          to :: <vec2>,
                          color :: <color>,
                          width :: <single-float>) => ();

// Sent once per frame, after updating.
// Apps should perform all rendering in their handler for this event.
define class <render-event> (<event>)
  constant slot renderer :: <renderer>,
    required-init-keyword: renderer:;
end;


//============================================================================
//----------------  Misc.  ----------------
//============================================================================

// Macro to save certain state elements and automatically restore them to
// these saved values after a code block.
// For example, to ensure that a <renderer>'s transform-2d and texture
// are restored to their initial values after a block of code that might
// modify them:
//
//    with-saved-state (ren.transform-2d, ren.texture)
//       // code that modifies transform-2d and texture
//    end
//
// Saving and restoring are both accomplished via assignment, so only
// constructs that can accept assignment syntax are valid. This also implies
// that mutations to saved objects will _not_ be undone when the macro
// completes. For example, the value of p.vx after the following code
// executes will be 3 rather than 0.
//
//    let p = vec2(0, 0);
//    with-saved-state(p)
//      p.vx := 3;
//    end
//
// TODO: Support some kind of custom save/restore functions so we can deal
//       better with mutable objects and other more complicated cases.
define macro with-saved-state
  {
    with-saved-state (?states)
      ?:body
    end
  }
 =>
  {
    // TODO: This does allocations, function calls, and iterations. The ideal
    //       expansion would avoid all this overhead (just a sequence of assignments).
    //       Not sure how to do that via Dylan's macro system.
    let saved-values = vector(?states);
    let restore-values = %restore-functions(?states);
    block ()
      ?body;
    cleanup
      // restore saved values in reverse order
      for (restore in restore-values using backward-iteration-protocol,
           saved in saved-values using backward-iteration-protocol)
        restore(saved);
      end;
    end
  }

states:
  {} => {}
  { ?:expression, ... } => { ?expression, ... }
end;

define macro %restore-functions
  { %restore-functions (?states) }
    => { vector(?states) }

states:
  {} => {}
  { ?:expression, ... } => { method (x) ?expression := x end, ... }
end;


// Support interpolation (and hence tweening) on <vec2>.
define sealed method interpolate (initial :: <vec2>,
                                  final :: <vec2>,
                                  t :: <single-float>) => (result :: <vec2>)
  vec2(interpolate(initial.vx, final.vx, t),
       interpolate(initial.vy, final.vy, t))
end;

