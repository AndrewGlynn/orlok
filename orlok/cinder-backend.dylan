module: cinder-backend
author: Andrew Glynn
copyright: See LICENSE file in this distribution.

// Implementation of orlok using libcinder.

//============================================================================
// Some global variables. Yeah, that's how it's gonna work.
//============================================================================

define variable *app* :: false-or(<app>) = #f;
define variable *renderer* :: false-or(<cinder-gl-renderer>) = #f;
define constant $keyboard = make(<table>);
define variable *mouse-x* :: <real> = 0;
define variable *mouse-y* :: <real> = 0;
define variable *mouse-left-button?* :: <boolean> = #f;
define variable *mouse-right-button?* :: <boolean> = #f;
define variable *mouse-middle-button?* :: <boolean> = #f;

// This should be a <double-float>, but there is a bug in the Dylan C backend
// that currently prevents this.
// TODO: What was the bug? Test it out again and file a bug if it's still there.
define variable *total-time* :: <single-float> = as(<single-float>, 0.0);


//============================================================================
// Core application stuff
//============================================================================


define class <app-config-impl> (<app-config>)
  slot window-width :: <integer>,
    required-init-keyword: window-width:;
  slot window-height :: <integer>,
    required-init-keyword: window-height:;
  slot app-width :: <integer>,
    required-init-keyword: app-width:;
  slot app-height :: <integer>,
    required-init-keyword: app-height:;
  slot force-app-aspect-ratio? :: <boolean>,
    required-init-keyword: force-app-aspect-ratio?:;
  slot full-screen? :: <boolean> = #f,
    init-keyword: full-screen?:;
  constant slot frames-per-second :: <integer> = 60,
    init-keyword: frames-per-second:;
end;

define sealed method make (type == <app-config>,
                           #rest init-args,
                           #key window-width, window-height,
                                app-width, app-height)
 => (cfg :: <app-config-impl>)
  // Default app dimensions to window dimensions.
  if (~app-width)
    app-width := window-width;
  end;
  if (~app-height)
    app-height := window-height;
  end;

  // Be sure to pass the updated app dimensions before init-args to ensure
  // they override the incoming app dimensions (which might be #f).
  apply(make, <app-config-impl>,
        app-width: app-width, app-height: app-height,
        init-args)
end;

define method the-app () => (app :: <app>)
  if (~*app*)
    orlok-error("no app currently running");
  end;
  *app*
end;

define sealed method run-app (app :: <app>) => ()
  if (*app*)
    orlok-error("app already running");
  end;

  *app* := app;
  cinder-run(app.config.window-width,
             app.config.window-height,
             app.config.app-width,
             app.config.app-height,
             app.config.force-app-aspect-ratio?,
             app.config.full-screen?,
             app.config.frames-per-second);
end;

define sealed method quit-app (app :: <app>) => ()
  cinder-quit();
end;

define sealed method app-time (app :: <app>)
 => (elapsed-seconds :: <single-float>)
  *total-time*
end;

define sealed method average-frames-per-second (app :: <app>)
 => (fps :: <single-float>)
  cinder-get-average-fps()
end;

define method set-full-screen (app :: <app>, full? :: <boolean>) => ()
  if (app.config.full-screen? ~= full?)
    app.config.full-screen? := full?;
    cinder-set-full-screen(full?);
  end;
end;

define method set-app-size (app :: <app>, w :: <integer>, h :: <integer>) => ()
  app.config.app-width  := w;
  app.config.app-height := h;
end;

define method set-force-app-aspect-ratio (app :: <app>, force? :: <boolean>)
 => ()
  app.config.force-app-aspect-ratio? := force?;
end;

define method bounding-rect (app :: <app>) => (bounds :: <rect>)
  make(<rect>,
       left: 0.0,
       top: 0.0,
       width: app.config.app-width,
       height: app.config.app-height)
end;


define sealed method key-down? (app :: <app>, key :: <key-id>)
 => (down? :: <boolean>)
  element($keyboard, key, default: #f)
end;

define sealed method key-up? (app :: <app>, key :: <key-id>)
 => (up? :: <boolean>)
  ~key-down?(app, key)
end;

define sealed method mouse-x (app :: <app>) => (x :: <real>)
  *mouse-x*
end;

define sealed method mouse-y (app :: <app>) => (y :: <real>)
  *mouse-y*
end;

define sealed method mouse-left-button? (app :: <app>) => (down? :: <boolean>)
  *mouse-left-button?*
end;

define sealed method mouse-right-button? (app :: <app>) => (down? :: <boolean>)
  *mouse-right-button?*
end;

define sealed method mouse-middle-button? (app :: <app>) => (down? :: <boolean>)
  *mouse-middle-button?*
end;

define constant $vert-pass-thru-shader =
  "void main ()                                 "
  "{                                            "
  "    gl_TexCoord[0] = gl_MultiTexCoord0;      "
  "    gl_Position = ftransform();              "
  "}                                            ";

// Draw in a single color, but use alpha values from the current texture.
define constant $frag-alpha-color-shader =
  "#version 110\n"
  "uniform sampler2D tex0;                                      "
  "uniform vec4 color;                                          "
  "void main()                                                  "
  "{                                                            "
  "    gl_FragColor.rgb = color.rgb;                            "
  "    gl_FragColor.a = texture2D(tex0, gl_TexCoord[0].st).a;   "
  "}                                                            ";

// Draw solid color, ignoring texture.
define constant $frag-solid-color-shader =
  "#version 110\n"
  "uniform sampler2D tex0;                                      "
  "uniform vec4 color;                                          "
  "void main()                                                  "
  "{                                                            "
  "    gl_FragColor.rgb = color.rgb;                            "
  "    gl_FragColor.a   = 1.0;                                  "
  "}                                                            ";


// Shader used for colorizing texture.
define variable *alpha-color-shader* = #f;

// Shader used for drawing using a single color.
define variable *solid-color-shader* = #f; 

//============================================================================
// Dylan functions called from C
//============================================================================

define function cinder-startup () => ()
  // Note: We wait until now to create the renderer since it can rely
  //       on some cinder initialization stuff.
  *renderer* := make(<cinder-gl-renderer>);

  *alpha-color-shader* := create-shader($vert-pass-thru-shader,
                                        $frag-alpha-color-shader);
  *solid-color-shader* := create-shader($vert-pass-thru-shader,
                                        $frag-solid-color-shader);

  let e = make(<startup-event>);
  on-event(e, *app*);
end;

define c-callable-wrapper of cinder-startup
  c-name: "cinder_startup";
end;

define function cinder-shutdown () => ()
  let e = make(<shutdown-event>);
  on-event(e, *app*);
end;

define c-callable-wrapper of cinder-shutdown
  c-name: "cinder_shutdown";
end;

define function cinder-update () => ()
  let dt = 1.0 / as(<single-float>, *app*.config.frames-per-second);
  let e = make(<update-event>, delta-time: dt);

  // TODO: cast dt to <double-float> when type of total-time is fixed (see above).
  *total-time* := *total-time* + dt;

  on-event(e, *app*);
end;

define c-callable-wrapper of cinder-update
  c-name: "cinder_update";
end;

define function cinder-draw () => ()
  begin-draw(*app*, *renderer*);
  on-event(make(<render-event>, renderer: *renderer*), *app*);
  end-draw(*renderer*);
end;

define c-callable-wrapper of cinder-draw
  c-name: "cinder_draw";
end;

define function cinder-resize(new-w :: <integer>,
                              new-h :: <integer>,
                              full-screen? :: <boolean>) => ()
  *app*.config.window-width  := new-w;
  *app*.config.window-height := new-h;

  let e = make(<resize-event>,
               window-width: new-w,
               window-height: new-h,
               full-screen?: full-screen?);
  on-event(e, *app*);
end;

define c-callable-wrapper of cinder-resize
  parameter new-w :: <c-int>;
  parameter new-h :: <c-int>;
  parameter full-screen? :: <c-boolean>;
  c-name: "cinder_resize";
end;

define function cinder-key-down (id :: <integer>) => ()
  $keyboard[id] := #t;
  let e = make(<key-down-event>, id: id, key-down?: #t);
  on-event(e, *app*);
end;

define c-callable-wrapper of cinder-key-down
  parameter id :: <c-int>;
  c-name: "cinder_key_down";
end;

define function cinder-key-up (id :: <integer>) => ()
  $keyboard[id] := #f;
  let e = make(<key-up-event>, id: id, key-down?: #f);
  on-event(e, *app*);
end;

define c-callable-wrapper of cinder-key-up
  parameter id :: <c-int>;
  c-name: "cinder_key_up";
end;

// Helper to convert from window coordinates to app coordinates.
define function window-to-app (window-x :: <integer>, window-y :: <integer>)
 => (app-x :: <real>, app-y :: <real>)
  let window-w = *app*.config.window-width;
  let window-h = *app*.config.window-height;
  let app-w = *app*.config.app-width;
  let app-h = *app*.config.app-height;
  let x-scale = window-w / as(<single-float>, app-w);
  let y-scale = window-h / as(<single-float>, app-h);

  if (*app*.config.force-app-aspect-ratio?)
    let s = min(x-scale, y-scale);
    let ws = app-w * s;
    let hs = app-h * s;
    let x = (window-w - ws) / 2.0;
    let y = (window-h - hs) / 2.0;
    values((window-x - x) / s, (window-y - y) / s);
  else
    values(window-x / x-scale, window-y / y-scale)
  end;
end;

define function emit-mouse-event (clss :: <class>,
                                  x :: <integer>,
                                  y :: <integer>,
                                  left-button? :: <integer>,
                                  right-button? :: <integer>,
                                  middle-button? :: <integer>) => ()
  let (app-x, app-y) = window-to-app(x, y);
  *mouse-x* := app-x;
  *mouse-y* := app-y;
  *mouse-left-button?* := left-button? ~== 0;
  *mouse-right-button?* := right-button? ~== 0;
  *mouse-middle-button?* := middle-button? ~== 0;

  let e = make(clss,
               x: *mouse-x*,
               y: *mouse-y*,
               left-button?: *mouse-left-button?*,
               right-button?: *mouse-right-button?*,
               middle-button?: *mouse-middle-button?*);

  on-event(e, *app*);
end;

define function cinder-mouse-down (btn :: <integer>,
                                   x :: <integer>,
                                   y :: <integer>,
                                   left-button? :: <integer>,
                                   right-button? :: <integer>,
                                   middle-button? :: <integer>) => ()
  let clss :: <class> = select (btn)
                          0 => <mouse-left-button-down-event>;
                          1 => <mouse-right-button-down-event>;
                          2 => <mouse-middle-button-down-event>;
                          otherwise => error("internal error XXX");
                        end;

  emit-mouse-event(clss, x, y, left-button?, right-button?, middle-button?);
end;

define c-callable-wrapper of cinder-mouse-down
  parameter btn :: <c-int>;
  parameter x :: <c-int>;
  parameter y :: <c-int>;
  parameter left_button :: <c-int>;
  parameter right_button :: <c-int>;
  parameter middle_button :: <c-int>;
  c-name: "cinder_mouse_down";
end;

define function cinder-mouse-up (btn :: <integer>,
                                 x :: <integer>,
                                 y :: <integer>,
                                 left-button? :: <integer>,
                                 right-button? :: <integer>,
                                 middle-button? :: <integer>) => ()
  let clss :: <class> = select (btn)
                          0 => <mouse-left-button-up-event>;
                          1 => <mouse-right-button-up-event>;
                          2 => <mouse-middle-button-up-event>;
                          otherwise => error("internal error XXX");
                        end;

  emit-mouse-event(clss, x, y, left-button?, right-button?, middle-button?);
end;

define c-callable-wrapper of cinder-mouse-up
  parameter btn :: <c-int>;
  parameter x :: <c-int>;
  parameter y :: <c-int>;
  parameter left_button :: <c-int>;
  parameter right_button :: <c-int>;
  parameter middle_button :: <c-int>;
  c-name: "cinder_mouse_up";
end;

define function cinder-mouse-move (x :: <integer>,
                                   y :: <integer>,
                                   left-button? :: <integer>,
                                   right-button? :: <integer>,
                                   middle-button? :: <integer>) => ()
  emit-mouse-event(<mouse-move-event>,
                   x, y, left-button?, right-button?, middle-button?);
end;

define c-callable-wrapper of cinder-mouse-move
  parameter x :: <c-int>;
  parameter y :: <c-int>;
  parameter left_button :: <c-int>;
  parameter right_button :: <c-int>;
  parameter middle_button :: <c-int>;
  c-name: "cinder_mouse_move";
end;


//============================================================================
// Bitmaps
//============================================================================

define class <cinder-bitmap> (<bitmap>)
  slot surface-ptr :: <c-void*>,
    required-init-keyword: surface-ptr:;
end;

define sealed method dispose (bmp :: <cinder-bitmap>) => ()
  next-method();
  cinder-surface-free(bmp.surface-ptr);
  bmp.surface-ptr := null-pointer(<c-void*>);
end;

define method create-bitmap (width :: <integer>, height :: <integer>)
 => (bmp :: <cinder-bitmap>)
  if (width <= 0 | height <=0)
    orlok-error("invalid bitmap size specified (non-positive dimension)");
  end;

  let ptr = cinder-surface-create(width, height);

  if (null-pointer?(ptr))
    orlok-error("error creating bitmap of size %dx%d", width, height);
  end;

  make(<cinder-bitmap>, surface-ptr: ptr, width: width, height: height);
end;

define method create-bitmap-from (source :: <cinder-bitmap>,
                                  #key source-region :: false-or(<rect>) = #f)
 => (bmp :: <bitmap>)
  let rect = source.bounding-rect;

  if (source-region)
    rect := rect-intersection(source-region, rect);
    if (~rect)
      orlok-error("invalid source-region for <bitmap> source");
    end;
  end;

  let w = round(rect.width);
  let h = round(rect.height);

  let bmp = create-bitmap(w, h);

  copy-pixels(source: source,
              source-region: rect,
              destination: bmp);

  bmp
end;

// TODO: Add method to create-bitmap-from with source of type <texture>.

define method load-bitmap (filename :: <string>) => (bmp :: <cinder-bitmap>)
  let (ptr, w, h) = cinder-load-surface(filename);
  if (null-pointer?(ptr))
    orlok-error("error loading bitmap: %s", filename);
  end;

  make(<cinder-bitmap>, surface-ptr: ptr, width: w, height: h);
end;

define method copy-pixels
    (#key source         :: <cinder-bitmap>,
          source-region  :: <rect>,
          destination    :: <cinder-bitmap>,
          destination-pt :: <vec2> = vec2(0.0, 0.0),
          align          :: <alignment> = $left-top)
 => ()
  source-region := rect-intersection(source-region, source.bounding-rect);
  if (~source-region)
    orlok-error("invalid source-rect in copy-pixels");
  end;

  let (dx, dy) = alignment-offset(source-region, align);

  destination-pt.vx := destination-pt.vx - dx;
  destination-pt.vy := destination-pt.vy - dy;

  // TODO: Do we need to clip the destination rectangle (which is currently only
  //       implicitly defined) to the destinations bounds, or does cinder do
  //       that on its own?

  let w = round(source-region.width);
  let h = round(source-region.height);

  cinder-surface-copy-pixels
    (source.surface-ptr,
     round(source-region.left),
     round(source-region.top),
     w,
     h,
     destination.surface-ptr,
     round(destination-pt.vx),
     round(destination-pt.vy));
end;

define method clear-bitmap (bmp :: <cinder-bitmap>, color :: <color>,
                            #key region :: false-or(<rect>) = #f) => ()
  let x = 0;
  let y = 0;
  let w = bmp.width;
  let h = bmp.height;

  if (region)
    x := round(region.left);
    y := round(region.top);
    w := round(region.width);
    h := round(region.height);
  end;

  // TODO: Do we need to clip the region, or does cinder do this for us?

  cinder-surface-fill(bmp.surface-ptr,
                      color.red, color.green, color.blue, color.alpha,
                      x, y, w, h);
end;

define method bitmap-premultiply (bmp :: <cinder-bitmap>) => ()
  cinder-surface-premultiply(bmp.surface-ptr);
end;

define method bitmap-unpremultiply (bmp :: <cinder-bitmap>) => ()
  cinder-surface-unpremultiply(bmp.surface-ptr);
end;

define method bitmap-flip-vertical (bmp :: <cinder-bitmap>) => ()
  cinder-surface-flip-vertical(bmp.surface-ptr);
end;

define method resize-bitmap (bmp :: <cinder-bitmap>,
                             new-width :: <integer>,
                             new-height :: <integer>,
                             #key filter = $bitmap-filter-box) => ()
  // If we need parameterized filters this will need to get a bit more
  // complicated.
  let filt = select (filter)
               $bitmap-filter-box      => 0;
               $bitmap-filter-triangle => 1;
               $bitmap-filter-gaussian => 2;
             end;
             
  let ptr = cinder-surface-resize(bmp.surface-ptr, new-width, new-height, filt);
  if (null-pointer?(ptr))
    orlok-error("error resizing bitmap");
  end;

  make(<cinder-bitmap>, surface-ptr: ptr, width: new-width, height: new-height);
end;


//============================================================================
// Textures
//============================================================================


define abstract class <cinder-texture> (<object>)
  slot tex-ptr :: <c-void*>,
    required-init-keyword: tex-ptr:;
end;

define class <cinder-simple-texture> (<cinder-texture>, <texture>)
end;

define sealed method dispose (tex :: <cinder-simple-texture>) => ()
  next-method();
  cinder-gl-free-texture(tex.tex-ptr);
  tex.tex-ptr := null-pointer(<c-void*>);
end;

define function texture-error (format :: <string>, #rest args) => ()
  error(make(<texture-error>, format: format, args: args))
end;

define method create-texture (width :: <integer>, height :: <integer>)
 => (tex :: <cinder-simple-texture>)
  let tex-ptr = cinder-gl-create-texture(width, height);
  if (null-pointer?(tex-ptr))
    texture-error("unable to create texture of dimensions %dx%d",
                  width, height);
  end;

  make(<cinder-simple-texture>, tex-ptr: tex-ptr, width: width, height: height)
end;

define method create-texture-from (bmp :: <cinder-bitmap>,
                                   #key source-region :: false-or(<rect>) = #f)
 => (tex :: <cinder-simple-texture>)
  let rect :: <rect> = bmp.bounding-rect;
  
  if (source-region)
    let inter = rect-intersection(source-region, rect);
    if (~inter)
      texture-error("invalid texture source-region");
    end;
    rect := inter;
  end;

  let x = round(rect.left);
  let y = round(rect.top);
  let w = round(rect.width);
  let h = round(rect.height);

  if (w <= 0 | h <= 0)
    texture-error("invalid texture source-region (width=%d, height=%d)", w, h);
  end;

  let tex-ptr = cinder-gl-create-texture-from-surface(bmp.surface-ptr,
                                                      x, y, w, h);
  if (null-pointer?(tex-ptr))
    texture-error("unable to create texture from %=x%= <bitmap> %=",
                  bmp.width, bmp.height, bmp);
  end;

  make(<cinder-simple-texture>,
       tex-ptr: tex-ptr,
       width:   bmp.width,
       height:  bmp.height)
end;

define class <cinder-render-texture> (<cinder-texture>, <render-texture>)
  slot framebuffer-ptr :: <c-void*>,
    required-init-keyword: framebuffer-ptr:;
end;

define method create-render-texture (width :: <integer>, height :: <integer>)
 => (tex :: <cinder-render-texture>)
  let (ptr, tex, error-msg) = cinder-gl-create-framebuffer(width, height);

  if (null-pointer?(ptr))
    // TODO: If we don't do this the msg doesn't print properly. Is this a
    // c-ffi bug with <c-string>?
    error-msg := as(<byte-string>, error-msg);
    orlok-error("error creating <render-texture>: %s", error-msg);
  end;

  make(<cinder-render-texture>,
       framebuffer-ptr: ptr,
       tex-ptr: tex,
       width: width,
       height: height)
end;

define sealed method dispose (tex :: <cinder-render-texture>) => ()
  next-method();
  cinder-gl-free-framebuffer(tex.framebuffer-ptr);
  tex.framebuffer-ptr := null-pointer(<c-void*>);
  tex.tex-ptr := null-pointer(<c-void*>);
end;

define method update-texture (tex :: <cinder-simple-texture>,
                              bmp :: <cinder-bitmap>,
                              #key bitmap-region :: false-or(<rect>) = #f)
 => ()
  %update-texture(tex, bmp, bitmap-region: bitmap-region);
end;

define method update-texture (tex :: <cinder-render-texture>,
                              bmp :: <cinder-bitmap>,
                              #key bitmap-region :: false-or(<rect>) = #f)
 => ()
  %update-texture(tex, bmp, bitmap-region: bitmap-region);
end;

define method %update-texture (tex :: <cinder-texture>,
                               bmp :: <cinder-bitmap>,
                               #key bitmap-region :: false-or(<rect>) = #f)
 => ()
  let x1 = 0;
  let y1 = 0;
  let x2 = bmp.width;
  let y2 = bmp.height;

  if (bitmap-region)
    bitmap-region := rect-intersection(bitmap-region, bmp.bounding-rect);
    if (~bitmap-region)
      texture-error("invalid bitmap-region in update-texture");
    end;
    x1 := round(bitmap-region.left);
    x2 := round(bitmap-region.right);
    y1 := round(bitmap-region.bottom);
    y2 := round(bitmap-region.top);
  end;

  if (abs(x2 - x1) ~= tex.width | abs(y2 - y1) ~= tex.height)
    texture-error("cannot update texture: invalid size");
  end;

  cinder-gl-update-texture(tex.tex-ptr, bmp.surface-ptr, x1, y1, x2, y2);
end;


//============================================================================
// Shaders
//============================================================================


define class <cinder-shader> (<shader>)
  slot prog-ptr :: <c-void*>, required-init-keyword: prog-ptr:;
  constant slot uniforms :: <string-table> = make(<string-table>);
end;

define method load-shader (vertex-shader :: <string>,
                           fragment-shader :: <string>)
 => (shader :: <cinder-shader>)
  let (ptr, error-msg) = cinder-gl-load-shader-program(vertex-shader,
                                                       fragment-shader);

  if (ptr = null-pointer(<c-void*>))
    // TODO: If we don't do this the msg doesn't print properly. Is this a
    // c-ffi bug with <c-string>?
    error-msg := as(<byte-string>, error-msg);
    error(make(<shader-error>, format: "%s", args: vector(error-msg)));
  end;

  make(<cinder-shader>, prog-ptr: ptr)
end;

define method create-shader (vertex-shader-source :: <string>,
                             fragment-shader-source :: <string>)
 => (shader :: <cinder-shader>)
  let (ptr, error-msg) =
    cinder-gl-create-shader-program(vertex-shader-source,
                                    fragment-shader-source);

  if (ptr = null-pointer(<c-void*>))
    // TODO: If we don't do this the msg doesn't print properly. Is this a
    // c-ffi bug with <c-string>?
    error-msg := as(<byte-string>, error-msg);
    error(make(<shader-error>, format: "%s", args: vector(error-msg)));
  end;

  make(<cinder-shader>, prog-ptr: ptr)
end;

define sealed method dispose (shader :: <cinder-shader>) => ()
  next-method();
  cinder-gl-free-shader-program(shader.prog-ptr);
  shader.prog-ptr := null-pointer(<c-void*>);
end;

define method set-uniform (sh :: <cinder-shader>,
                           name :: <string>,
                           value) => ()
  sh.uniforms[name] := value;
  if (sh == *renderer*.shader)
    %set-uniform(sh, name, value);
  end;
end;

define method %set-uniform (shader :: <cinder-shader>,
                            name :: <string>,
                            i :: <integer>) => ()
  cinder-gl-set-uniform-1i(shader.prog-ptr, name, i);
end;

define method %set-uniform (shader :: <cinder-shader>,
                            name :: <string>,
                            f :: <single-float>) => ()
  cinder-gl-set-uniform-1f(shader.prog-ptr, name, f);
end;

define method %set-uniform (shader :: <cinder-shader>,
                            name :: <string>,
                            v2 :: <vec2>) => ()
  cinder-gl-set-uniform-2f(shader.prog-ptr, name, v2.vx, v2.vy);
end;

define method %set-uniform (shader :: <cinder-shader>,
                            name :: <string>,
                            c :: <color>) => ()
  cinder-gl-set-uniform-4f(shader.prog-ptr, name, c.red, c.green, c.blue, c.alpha);
end;


//============================================================================
// Fonts
//============================================================================


define class <cinder-font> (<font>)
  constant slot font-ptr :: <c-void*>, required-init-keyword: font-ptr:;
end;

define method load-font (font-file-name :: <string>, size :: <real>)
 => (f :: <cinder-font>)
  let ptr = cinder-load-font(font-file-name, as(<single-float>, size));
  if (null-pointer?(ptr))
    orlok-error("unable to load font: %s", font-file-name);
  end;

  make(<cinder-font>, font-ptr: ptr);
end;

define sealed method dispose (f :: <cinder-font>) => ()
  cinder-free-font(f.font-ptr);
end;

define method font-name (f :: <cinder-font>) => (name :: <string>)
  let (name, size, ascent, descent, leading) = cinder-get-font-info(f.font-ptr);
  name
end;

define method font-size (f :: <cinder-font>) => (size :: <single-float>)
  let (name, size, ascent, descent, leading) = cinder-get-font-info(f.font-ptr);
  size
end;

define method font-ascent (f :: <cinder-font>) => (ascent :: <single-float>)
  let (name, size, ascent, descent, leading) = cinder-get-font-info(f.font-ptr);
  ascent
end;

define method font-descent (f :: <cinder-font>) => (descent :: <single-float>)
  let (name, size, ascent, descent, leading) = cinder-get-font-info(f.font-ptr);
  descent
end;

define method font-leading (f :: <cinder-font>) => (leading :: <single-float>)
  let (name, size, ascent, descent, leading) = cinder-get-font-info(f.font-ptr);
  leading
end;

define method font-extents (f :: <cinder-font>, text :: <string>)
 => (extents :: <rect>)
  let (x, y, w, h) = cinder-get-font-extents(f.font-ptr, text);
  make(<rect>, left: x, top: y, width: w, height: h)
end;


//============================================================================
// Renderer
//============================================================================


define class <cinder-gl-renderer> (<renderer>)
  slot %texture           :: false-or(<cinder-texture>) = #f;
  slot %shader            :: false-or(<cinder-shader>) = #f;
  slot %render-to-texture :: false-or(<cinder-render-texture>) = #f;
  slot %transform-2d      :: <affine-transform-2d> = make(<affine-transform-2d>);
  slot %logical-size      :: <vec2> = vec2(1, 1);
  slot %viewport          :: <rect> = make(<rect>,
                                           left: 0, top: 0,
                                           width: 0, height: 0);
  slot %blend-mode        :: <blend-mode> = $blend-normal;
  slot %render-color      :: <color> = $white;
end;

define function begin-draw (app :: <app>, ren :: <cinder-gl-renderer>) => ()
  // Set up viewport and projection based on physical and logical window sizes.
  let app-w    = app.config.app-width;
  let app-h    = app.config.app-height;
  let window-w = app.config.window-width;
  let window-h = app.config.window-height;

  if (app-w < 1) app-w := 1; end;
  if (app-h < 1) app-h := 1; end;

  ren.logical-size := vec2(app-w, app-h);

  if (app.config.force-app-aspect-ratio?)
    // make sure the image is not distorted if the physical aspect ratio
    // doesn't match the logical aspect ratio
    let s = min(window-w / as(<single-float>, app-w),
                window-h / as(<single-float>, app-h));
    let ws = round(app-w * s);
    let hs = round(app-h * s);
    let x  = truncate/(window-w - ws, 2);
    let y  = truncate/(window-h - hs, 2);

    ren.viewport := make(<rect>,
                         left:   x,
                         top:    y,
                         width:  x + ws,
                         height: y + hs);
  else
    ren.viewport := make(<rect>,
                         left:   0,
                         top:    0,
                         width:  window-w,
                         height: window-h);
  end;

  // Start off rendering to screen (for now).
  // Clients must enable this at the appropriate point in their rendering code.
  ren.render-to-texture := #f;

  cinder-gl-push-modelview-matrix();
end;

define function end-draw (ren :: <cinder-gl-renderer>) => ()
  cinder-gl-pop-modelview-matrix();
end;

//---------------------------------------------------------------------------
// Implementations of <renderer> virtual slots
//---------------------------------------------------------------------------

// TODO: Without these definitions I get a runtime error at startup
// in a call to add-getter-method or add-setter-method. Try to either
// understand why this is correct, or file a bug if not!
define generic texture (obj) => (tex :: false-or(<texture>));
define generic texture-setter (tex :: false-or(<texture>), obj)
 => (tex :: false-or(<texture>));
define generic shader (obj) => (shader :: false-or(<shader>));
define generic shader-setter (shader :: false-or(<shader>), obj)
 => (shader :: false-or(<shader>));
define generic render-to-texture (obj) => (target :: false-or(<render-texture>));
define generic render-to-texture-setter (target :: false-or(<render-texture>), obj)
 => (target :: false-or(<render-texture>));


define method texture (ren :: <cinder-gl-renderer>)
 => (tex :: false-or(<texture>))
  ren.%texture
end;

define method texture-setter (tex :: false-or(<texture>),
                              ren :: <cinder-gl-renderer>)
 => (tex :: false-or(<texture>))
  if (tex ~== ren.%texture)
    if (ren.%texture)
      cinder-gl-unbind-texture(ren.%texture.tex-ptr);
    end;
    if (tex)
      cinder-gl-bind-texture(tex.tex-ptr);
    end;
    ren.%texture := tex;
  end;

  tex
end;

define method shader(ren :: <cinder-gl-renderer>)
 => (shader :: false-or(<cinder-shader>))
  ren.%shader
end;

define method shader-setter (shader :: false-or(<cinder-shader>),
                             ren :: <cinder-gl-renderer>)
 => (shader :: false-or(<cinder-shader>))
  if (shader ~== ren.%shader)
    if (ren.%shader)
      cinder-gl-use-shader-program(null-pointer(<c-void*>));
    end;
    if (shader)
      cinder-gl-use-shader-program(shader.prog-ptr);
      for (value keyed-by name in shader.uniforms)
        %set-uniform(shader, name, value);
      end;
    end;
    ren.%shader := shader;
  end;

  shader
end;

define method render-to-texture (ren :: <cinder-gl-renderer>)
 => (target :: false-or(<cinder-render-texture>))
  ren.%render-to-texture
end;

define method render-to-texture-setter (target :: false-or(<cinder-render-texture>),
                                        ren :: <cinder-gl-renderer>)
 => (target :: false-or(<cinder-render-texture>))
  if (ren.render-to-texture ~== target)
    ren.%render-to-texture := target;
    if (target)
      cinder-gl-bind-framebuffer(target.framebuffer-ptr);
    else
      cinder-gl-unbind-framebuffer();
    end;
  end;
  target
end;

define method transform-2d (ren :: <cinder-gl-renderer>)
 => (trans :: <affine-transform-2d>)
  shallow-copy(ren.%transform-2d)
end;

define method transform-2d-setter (trans :: <affine-transform-2d>,
                                   ren :: <cinder-gl-renderer>)
 => (trans :: <affine-transform-2d>)
  ren.%transform-2d := shallow-copy(trans);
end;


define sealed method viewport (ren :: <cinder-gl-renderer>)
 => (v :: <rect>)
  // return a copy because we don't want clients to mutate it piecewise
  // (need to call viewport-setter to replace the whole thing)
  shallow-copy(ren.%viewport)
end;

define sealed method viewport-setter (new :: <rect>,
                                      ren :: <cinder-gl-renderer>)
 => (new :: <rect>)
  ren.%viewport := shallow-copy(new);
  cinder-gl-set-viewport(round(new.left), round(new.top),
                         round(new.width), round(new.height));
  new
end;

define sealed method logical-size (ren :: <cinder-gl-renderer>)
 => (sz :: <vec2>)
  ren.%logical-size.xy // return copy (see note above for viewport)
end;

define sealed method logical-size-setter (new-size :: <vec2>,
                                          ren :: <cinder-gl-renderer>)
 => (new-size :: <vec2>)
  ren.%logical-size := new-size.xy;
  cinder-gl-set-matrices-window(round(new-size.vx), round(new-size.vy));
  new-size
end;

define sealed method blend-mode (ren :: <cinder-gl-renderer>)
 => (mode :: <blend-mode>)
  ren.%blend-mode
end;

define sealed method blend-mode-setter (new-blend :: <blend-mode>,
                                        ren :: <cinder-gl-renderer>)
 => (new-blend :: <blend-mode>)
  if (ren.%blend-mode ~== new-blend)
    ren.%blend-mode := new-blend;
    select (new-blend)
      $blend-normal   => cinder-gl-set-blend(0);
      $blend-additive => cinder-gl-set-blend(1);
    end;
  end;
  new-blend
end;

define sealed method render-color (ren :: <cinder-gl-renderer>)
 => (color :: <color>)
  ren.%render-color
end;

define sealed method render-color-setter (new :: <color>,
                                          ren :: <cinder-gl-renderer>)
 => (new :: <color>)
  if (new ~= ren.render-color)
    ren.%render-color := new;
    cinder-gl-set-color(new.red, new.green, new.blue, new.alpha);
  end;
  new
end;

//---------------------------------------------------------------------------
// Other functions on <renderer>
//---------------------------------------------------------------------------


define sealed method translate! (ren :: <cinder-gl-renderer>,
                                 t :: <vec2>)
 => (ren :: <cinder-gl-renderer>)
  translate!(ren.%transform-2d, t);
  ren
end;

define sealed method rotate! (ren :: <cinder-gl-renderer>,
                              r :: <single-float>)
 => (ren :: <cinder-gl-renderer>)
  rotate!(ren.%transform-2d, r);
  ren
end;

define sealed method scale! (ren :: <cinder-gl-renderer>,
                             s :: <single-float>)
 => (ren :: <cinder-gl-renderer>)
  scale!(ren.%transform-2d, s);
  ren
end;

define method clear (ren :: <cinder-gl-renderer>,
                     color :: <color>) => ()
  // note: not clearing depth buffer
  cinder-gl-clear(color.red, color.green, color.blue, color.alpha, #f);
end;

define function update-renderer-transform (ren :: <cinder-gl-renderer>) => ()
  // TODO: Optimize: Only call out to cinder if transform has actually changed?
  // Profile to make sure it matters!
  let (sx, shy, shx, sy, tx, ty) = transform-components(ren.transform-2d);
  cinder-gl-update-transform(sx, shy, shx, sy, tx, ty);
end;

define method draw-rect (ren :: <cinder-gl-renderer>,
                         rect :: <rect>,
                         #key at :: <vec2> = vec2(0, 0),
                              align :: <alignment> = $left-top,
                              texture: tex :: false-or(<texture>) = #f,
                              texture-rect: tex-rect :: false-or(<rect>) = #f,
                              shader: sh :: false-or(<shader>) = #f,
                              color :: false-or(<color>) = #f) => ()
  with-saved-state (ren.texture, ren.shader)
    let (dx, dy) = alignment-offset(rect, align);
    let v = at - vec2(dx, dy);
    translate!(ren.transform-2d, v);

    // Note: Color takes precedence over shader (for no particular reason).
    if (color & sh)
      orlok-warning("color and shader both specified in draw-rect: using color and ignoring shader");
    end;

    if (color & tex)
      ren.shader := *alpha-color-shader*;
      ren.texture := tex;
      set-uniform(ren.shader, "tex0", 0); // assumes only one texture unit
      set-uniform(ren.shader, "color", color);
    elseif (color)
      ren.texture := #f;
      ren.shader := *solid-color-shader*;
      set-uniform(ren.shader, "tex0", 0); // assumes only one texture unit
      set-uniform(ren.shader, "color", color);
    else
      if (tex)
        ren.texture := tex;
      end;

      if (sh)
        ren.shader := sh;
      end;
    end;

    let (u1, v1, u2, v2) = values(0.0, 0.0, 1.0, 1.0);

    if (ren.texture)
      // We need to flip <render-texture>s.
      let flip-y? = ren.texture & instance?(ren.texture, <render-texture>);

      // Convert texture rectangle to normalized coordinates.
      if (tex-rect)
        u1 := tex-rect.left / ren.texture.width;
        v1 := if (~flip-y?) tex-rect.top else tex-rect.bottom end / ren.texture.height;
        u2 := tex-rect.right / ren.texture.width;
        v2 := if (~flip-y?) tex-rect.bottom else tex-rect.top end / ren.texture.height;
      elseif (flip-y?)
        v1 := 1.0;
        v2 := 0.0;
      end;
    end;

    cinder-gl-push-modelview-matrix();
    update-renderer-transform(ren);
    cinder-gl-draw-rect(rect.left, rect.top, rect.right, rect.bottom,
                        u1, v1, u2, v2);
    cinder-gl-pop-modelview-matrix();
  end with-saved-state;
end;

define function text-alignment-offset (text :: <string>,
                                       font :: <font>,
                                       align :: <alignment>)
 => (offset :: <vec2>)
  let rect = font-extents(font, text);

  let (dx, dy) = alignment-offset(rect, align);

  // TODO: Why do I not have to do this? At least for the OpenGL version.
  //       Probably the cairo version is now broken?
  // Compensate for the fact that cinder/cairo render relative to the
  // text reference point (left of first character, on baseline).
  //dx := dx + rect.left;
  //dy := dy + rect.top;

  vec2(-dx, -dy);

/*
  if (align ~== $left-bottom) // optimize for common case
    let rect = font-extents(font, text);

    // adjust rect so that $left-bottom is at 0,0 (text reference point)
    rect.left := 0.0;
    rect.bottom := 0.0;

    let (dx, dy) = alignment-offset(rect, align);

    // also adjust for the fact that cinder/cairo already use the text reference
    // point as the origin (subtract height)
    vec2(dx, dy - rect.height);
  else
    vec2(0.0, 0.0)
  end;
*/
end;

define method draw-text (ren :: <cinder-gl-renderer>,
                         text :: <string>,
                         font :: <font>,
                         #key at :: <vec2> = vec2(0, 0),
                              align :: <alignment> = $left-bottom, 
                              color :: false-or(<color>) = #f,
                              shader: sh :: false-or(<shader>) = #f) => ()
  with-saved-state (ren.shader)
    let v = at + text-alignment-offset(text, font, align);

    // Note: Color takes precedence over shader (for no particular reason).
    if (color & sh)
      orlok-warning("color and shader both specified in draw-text: using color and ignoring shader");
    end;

    if (color)
      ren.shader := *alpha-color-shader*;
      set-uniform(ren.shader, "color", color);
    elseif (sh)
      ren.shader := sh;
    end;

    cinder-gl-push-modelview-matrix();
    update-renderer-transform(ren);
    cinder-gl-draw-text(text, color.red, color.green, color.blue, color.alpha,
                        v.vx, v.vy, font.font-ptr);
    cinder-gl-pop-modelview-matrix();
  end;
end;

define method draw-line (ren :: <cinder-gl-renderer>,
                         from :: <vec2>,
                         to :: <vec2>,
                         color :: <color>,
                         width :: <single-float>) => ()
  cinder-gl-push-modelview-matrix();
  update-renderer-transform(ren);
  let saved-color = ren.render-color;
  ren.render-color := color;
  cinder-gl-draw-line(from.vx, from.vy, to.vx, to.vy, width);
  ren.render-color := saved-color;
  cinder-gl-pop-modelview-matrix();
end;


//============================================================================
// Vector Graphics
//============================================================================

define class <cinder-vg-context> (<vg-context>)
  slot ctx-ptr :: <c-void*>,
    required-init-keyword: context-pointer:;
end;

// Create a <cinder-vg-context> when making a <vg-context>.
define sealed method make (type == <vg-context>, #rest init-args,
                           #key bitmap-target :: <cinder-bitmap>)
 => (ctx :: <cinder-vg-context>)
  let ctx-ptr = cinder-vg-make-context(bitmap-target.surface-ptr);
  apply(make, <cinder-vg-context>, context-pointer: ctx-ptr, init-args);
end;

define sealed method dispose (ctx :: <cinder-vg-context>) => ()
  next-method();
  cinder-vg-free-context(ctx.ctx-ptr);
  ctx.ctx-ptr := null-pointer(<c-void*>);
end;

define generic apply-paint (ctx :: <cinder-vg-context>, p :: <paint>) => ();
define generic prepare-brush (ctx :: <cinder-vg-context>, b :: <brush>) => ();
define generic apply-brush (ctx :: <cinder-vg-context>, b :: <brush>) => ();

define inline function as-cairo-pattern-extend (p :: <paint-extend>)
 => (_ :: <integer>)
  select (p)
    $paint-extend-none => 0;
    $paint-extend-repeat => 1;
    $paint-extend-reflect => 2;
    $paint-extend-pad => 3;
  end;
end;

define method apply-paint (ctx :: <cinder-vg-context>, c :: <color>) => ()
  cinder-vg-set-solid-paint(ctx.ctx-ptr, c.red, c.green, c.blue, c.alpha);
end;

define function apply-gradient-color-stops (g :: <gradient>) => ()
  for (stop in g.color-stops)
    let c = stop[0];
    let offset = stop[1];
    cinder-vg-gradient-add-color-stop(offset, c.red, c.green, c.blue, c.alpha);
  end;
end;

define method apply-paint (ctx :: <cinder-vg-context>,
                           l :: <linear-gradient>) => ()
  cinder-vg-set-linear-gradient(l.gradient-start.vx, l.gradient-start.vy,
                                l.gradient-end.vx, l.gradient-end.vy,
                                as-cairo-pattern-extend(l.gradient-extend));
  apply-gradient-color-stops(l);
  cinder-vg-apply-gradient(ctx.ctx-ptr);
end;

define method apply-paint (ctx :: <cinder-vg-context>,
                           r :: <radial-gradient>) => ()
  cinder-vg-set-radial-gradient(r.gradient-start.center.vx,
                                r.gradient-start.center.vy,
                                r.gradient-start.radius,
                                r.gradient-end.center.vx,
                                r.gradient-end.center.vy,
                                r.gradient-end.radius,
                                as-cairo-pattern-extend(r.gradient-extend));
  apply-gradient-color-stops(r);
  cinder-vg-apply-gradient(ctx.ctx-ptr);
end;

define method apply-paint (ctx :: <cinder-vg-context>,
                           bmp :: <cinder-bitmap>) => ()
  cinder-vg-set-surface-paint(ctx.ctx-ptr, bmp.surface-ptr);
end;

define method prepare-brush (ctx :: <cinder-vg-context>, fill :: <fill>) => ()
  apply-paint(ctx, fill.fill-paint);
end;

define method prepare-brush (ctx :: <cinder-vg-context>,
                             stroke :: <stroke>) => ()
  apply-paint(ctx, stroke.stroke-paint);

  let cap = select (stroke.line-cap)
              $line-cap-butt => 0;
              $line-cap-round => 1;
              $line-cap-square => 2;
            end;
  let join = select (stroke.line-join)
               $line-join-miter => 0;
               $line-join-round => 1;
               $line-join-bevel => 2;
             end;

  // TODO: dash-sequence
  cinder-vg-set-stroke-parameters(ctx.ctx-ptr, cap, join, stroke.line-width);
end;

define method apply-brush (ctx :: <cinder-vg-context>,
                           fill :: <fill>) => ()
  cinder-vg-fill-path(ctx.ctx-ptr);
end;

define method apply-brush (ctx :: <cinder-vg-context>,
                           stroke :: <stroke>) => ()
  cinder-vg-stroke-path(ctx.ctx-ptr);
end;

define method clear (ctx :: <cinder-vg-context>,
                     brush :: <brush>) => ()
  prepare-brush(ctx, brush);
  cinder-vg-clear-with-brush(ctx.ctx-ptr);
end;

define inline function update-matrix (ctx :: <cinder-vg-context>) => ()
  // TODO: Only do this if matrix has actually changed!
  let (xx, yx, xy, yy, x0, y0) = ctx.current-transform.transform-components;
  cinder-vg-set-matrix(ctx.ctx-ptr, xx, yx, xy, yy, x0, y0);
end;

define method vg-draw-shape (ctx :: <cinder-vg-context>,
                             rect :: <rect>,
                             brush :: <brush>) => ()
  update-matrix(ctx);
  prepare-brush(ctx, brush);
  cinder-vg-clear-path(ctx.ctx-ptr);
  cinder-vg-draw-rect(ctx.ctx-ptr, rect.left, rect.top, rect.width, rect.height);
  apply-brush(ctx, brush);
end;

define method vg-draw-shape (ctx :: <cinder-vg-context>,
                             circle :: <circle>,
                             brush ::  <brush>) => ()
  update-matrix(ctx);
  prepare-brush(ctx, brush);
  cinder-vg-clear-path(ctx.ctx-ptr);
  cinder-vg-draw-circle(ctx.ctx-ptr,
                        circle.center.vx, circle.center.vy, circle.radius);
  apply-brush(ctx, brush);
end;

define method vg-draw-shape (ctx :: <cinder-vg-context>,
                             p :: <path>,
                             brush :: <brush>) => ()
  update-matrix(ctx);
  prepare-brush(ctx, brush);
  cinder-vg-clear-path(ctx.ctx-ptr);

  // first point is start point (no command)
  cinder-vg-path-move-to(ctx.ctx-ptr, p.path-points[0].vx, p.path-points[0].vy);
  
  let i = 1;
  for (cmd in p.path-commands)
    select (cmd)
      $path-move-to =>
        cinder-vg-path-move-to(ctx.ctx-ptr,
                               p.path-points[i].vx, p.path-points[i].vy);
        i := i + 1;
      $path-line-to =>
        cinder-vg-path-line-to(ctx.ctx-ptr,
                               p.path-points[i].vx, p.path-points[i].vy);
        i := i + 1;
      $path-quad-to =>
        cinder-vg-path-quad-to(ctx.ctx-ptr,
                               p.path-points[i].vx, p.path-points[i].vy,
                               p.path-points[i + 1].vx, p.path-points[i + 1].vy);
        i := i + 2;
      $path-curve-to =>
        cinder-vg-path-curve-to(ctx.ctx-ptr,
                                p.path-points[i].vx, p.path-points[i].vy,
                                p.path-points[i + 1].vx, p.path-points[i + 1].vy,
                                p.path-points[i + 2].vx, p.path-points[i + 2].vy);
        i := i + 3;
      $path-close =>
        cinder-vg-path-close(ctx.ctx-ptr);
    end;
  end;

  apply-brush(ctx, brush);
end;

define method vg-draw-text (ctx :: <cinder-vg-context>,
                            text :: <string>,
                            font :: <cinder-font>,
                            #key brush :: <brush>,
                                 at :: <vec2> = vec2(0, 0),
                                 align :: <alignment> = $left-bottom) => ()
  let v = at + text-alignment-offset(text, font, align);
  update-matrix(ctx);
  %draw-vg-text(ctx, text, font, brush, v);
end;

define method %draw-vg-text (ctx :: <cinder-vg-context>,
                             text :: <string>,
                             font :: <cinder-font>,
                             stroke :: <stroke>,
                             pos :: <vec2>) => ()
  update-matrix(ctx);
  prepare-brush(ctx, stroke);
  cinder-vg-draw-text(ctx.ctx-ptr, font.font-ptr, text, pos.vx, pos.vy, #f);
  apply-brush(ctx, stroke);
end;

define method %draw-vg-text (ctx :: <cinder-vg-context>,
                             text :: <string>,
                             font :: <cinder-font>,
                             fill :: <fill>,
                             pos :: <vec2>) => ()
  update-matrix(ctx);
  prepare-brush(ctx, fill);
  cinder-vg-draw-text(ctx.ctx-ptr, font.font-ptr, text, pos.vx, pos.vy, #t);
end;


//============================================================================
// Audio
//============================================================================


define method get-master-volume () => (volume :: <single-float>)
  cinder-audio-get-master-volume()
end;

define method set-master-volume (volume :: <single-float>) => ();
  cinder-audio-set-master-volume(volume)
end;

define class <cinder-sound> (<sound>)
  constant slot sound-ptr :: <c-void*>, required-init-keyword: sound-ptr:;
end;

define sealed method dispose (snd :: <sound>) => ()
  next-method();
  cinder-audio-free-sound(snd.sound-ptr);
end;

define method load-sound (resource-name :: <string>) => (snd :: <cinder-sound>)
  let ptr = cinder-audio-load-sound(resource-name);
  if (null-pointer?(ptr))
    orlok-error("error loading sound: %=", resource-name);
  end; 

  make(<cinder-sound>, resource-name: resource-name, sound-ptr: ptr)
end;

define method play-sound (snd :: <cinder-sound>, #key volume = 1.0) => ()
  cinder-audio-play-sound(snd.sound-ptr, as(<single-float>, volume));
end;

define class <cinder-music> (<music>)
  constant slot music-ptr :: <c-void*>, required-init-keyword: music-ptr:;
end;

define sealed method dispose (m :: <cinder-music>) => ()
  next-method();
  cinder-audio-free-music(m.music-ptr);
end;

define method volume (m :: <cinder-music>) => (v :: <single-float>)
  cinder-audio-get-music-volume(m.music-ptr)
end;

define method volume-setter (new-volume :: <single-float>, m :: <cinder-music>)
 => (new-volume-clamped :: <single-float>)
  let v = max(0.0, min(new-volume, 1.0));
  cinder-audio-set-music-volume(m.music-ptr, v);
  v
end;

define method load-music (resource-name :: <string>) => (mus :: <music>)
  let ptr = cinder-audio-load-music(resource-name);
  if (null-pointer?(ptr))
    orlok-error("error loading music: %=", resource-name);
  end;

  make(<cinder-music>, resource-name: resource-name, music-ptr: ptr)
end;

define method play-music (mus :: <music>,
                           #key loop? :: <boolean> = #t,
                                restart? :: <boolean> = #f) => ()
  cinder-audio-play-music(mus.music-ptr, loop?, restart?);
end;

define method stop-music (mus :: <music>) => ();
  cinder-audio-stop-music(mus.music-ptr);
end;

//============================================================================
// Dylan-callable C functions
//============================================================================

define c-pointer-type <c-void**> => <c-void*>;

define C-function cinder-run
  input parameter width_ :: <C-signed-int>;
  input parameter height_ :: <C-signed-int>;
  input parameter appWidth_ :: <C-signed-int>;
  input parameter appHeight_ :: <C-signed-int>;
  input parameter forceAppAspectRatio_ :: <c-boolean>;
  input parameter fullscreen_ :: <c-boolean>;
  input parameter frames-per-second_ :: <C-signed-int>;
  c-name: "cinder_run";
end;

define C-function cinder-quit
  c-name: "cinder_quit";
end;

define C-function cinder-set-full-screen
  input parameter fullscreen_ :: <c-boolean>;
  c-name: "cinder_set_full_screen";
end;

define C-function cinder-get-average-fps
  result res :: <C-float>;
  c-name: "cinder_get_average_fps";
end;

define C-function cinder-audio-get-master-volume
  result res :: <C-float>;
  c-name: "cinder_audio_get_master_volume";
end;

define C-function cinder-audio-set-master-volume
  input parameter v_ :: <C-float>;
  c-name: "cinder_audio_set_master_volume";
end;

define C-function cinder-audio-load-sound
  input parameter resourceName_ :: <c-string>;
  result res :: <C-void*>;
  c-name: "cinder_audio_load_sound";
end;

define C-function cinder-audio-free-sound
  input parameter soundPtr_ :: <C-void*>;
  c-name: "cinder_audio_free_sound";
end;

define C-function cinder-audio-play-sound
  input parameter soundPtr_ :: <C-void*>;
  input parameter volume_ :: <C-float>;
  c-name: "cinder_audio_play_sound";
end;

define C-function cinder-audio-load-music
  input parameter resourceName_ :: <c-string>;
  result res :: <C-void*>;
  c-name: "cinder_audio_load_music";
end;

define C-function cinder-audio-free-music
  input parameter musicPtr_ :: <C-void*>;
  c-name: "cinder_audio_free_music";
end;

define C-function cinder-audio-play-music
  input parameter musicPtr_ :: <C-void*>;
  input parameter loop_ :: <c-boolean>;
  input parameter restart_ :: <c-boolean>;
  c-name: "cinder_audio_play_music";
end;

define C-function cinder-audio-stop-music
  input parameter musicPtr_ :: <C-void*>;
  c-name: "cinder_audio_stop_music";
end;

define C-function cinder-audio-set-music-volume
  input parameter musicPtr_ :: <C-void*>;
  input parameter volume_ :: <C-float>;
  c-name: "cinder_audio_set_music_volume";
end;

define C-function cinder-audio-get-music-volume
  input parameter musicPtr_ :: <C-void*>;
  result res :: <C-float>;
  c-name: "cinder_audio_get_music_volume";
end;

define C-function cinder-surface-create
  input parameter width_ :: <C-signed-int>;
  input parameter height_ :: <C-signed-int>;
  result res :: <C-void*>;
  c-name: "cinder_surface_create";
end;

define C-pointer-type <int*> => <C-signed-int>;
define C-function cinder-load-surface
  input parameter resourceName_ :: <c-string>;
  output parameter width_ :: <int*>;
  output parameter height_ :: <int*>;
  result res :: <C-void*>;
  c-name: "cinder_load_surface";
end;

define C-function cinder-surface-free
  input parameter surfacePtr_ :: <C-void*>;
  c-name: "cinder_surface_free";
end;

define C-function cinder-surface-copy-pixels
  input parameter srcPtr_ :: <C-void*>;
  input parameter srcX_ :: <C-signed-int>;
  input parameter srcY_ :: <C-signed-int>;
  input parameter w_ :: <C-signed-int>;
  input parameter h_ :: <C-signed-int>;
  input parameter destPtr_ :: <C-void*>;
  input parameter destX_ :: <C-signed-int>;
  input parameter destY_ :: <C-signed-int>;
  c-name: "cinder_surface_copy_pixels";
end;

define C-function cinder-surface-fill
  input parameter ptr_ :: <C-void*>;
  input parameter r_ :: <C-float>;
  input parameter g_ :: <C-float>;
  input parameter b_ :: <C-float>;
  input parameter a_ :: <C-float>;
  input parameter x_ :: <C-signed-int>;
  input parameter y_ :: <C-signed-int>;
  input parameter w_ :: <C-signed-int>;
  input parameter h_ :: <C-signed-int>;
  c-name: "cinder_surface_fill";
end;

define C-function cinder-surface-premultiply
  input parameter ptr_ :: <C-void*>;
  c-name: "cinder_surface_premultiply";
end;

define C-function cinder-surface-unpremultiply
  input parameter ptr_ :: <C-void*>;
  c-name: "cinder_surface_unpremultiply";
end;

define C-function cinder-surface-flip-vertical
  input parameter ptr_ :: <C-void*>;
  c-name: "cinder_surface_flip_vertical";
end;

define C-function cinder-surface-resize
  input parameter ptr_ :: <C-void*>;
  input parameter width_ :: <C-signed-int>;
  input parameter height_ :: <C-signed-int>;
  input parameter filter_ :: <C-signed-int>;
  result res :: <C-void*>;
  c-name: "cinder_surface_resize";
end;

define C-function cinder-gl-set-viewport
  input parameter x_ :: <C-signed-int>;
  input parameter y_ :: <C-signed-int>;
  input parameter width_ :: <C-signed-int>;
  input parameter height_ :: <C-signed-int>;
  c-name: "cinder_gl_set_viewport";
end;

define C-function cinder-gl-set-matrices-window
  input parameter width_ :: <C-signed-int>;
  input parameter height_ :: <C-signed-int>;
  c-name: "cinder_gl_set_matrices_window";
end;

define C-function cinder-gl-set-color
  input parameter r_ :: <C-float>;
  input parameter g_ :: <C-float>;
  input parameter b_ :: <C-float>;
  input parameter a_ :: <C-float>;
  c-name: "cinder_gl_set_color";
end;

define C-function cinder-gl-set-blend
  input parameter mode_ :: <C-signed-int>;
  c-name: "cinder_gl_set_blend";
end;

define C-function cinder-gl-create-texture
  input parameter width_ :: <C-signed-int>;
  input parameter height_ :: <C-signed-int>;
  result res :: <C-void*>;
  c-name: "cinder_gl_create_texture";
end;

define C-function cinder-gl-free-texture
  input parameter texPtr_ :: <C-void*>;
  c-name: "cinder_gl_free_texture";
end;

define C-function cinder-gl-update-texture
  input parameter texPtr_ :: <C-void*>;
  input parameter surfPtr_ :: <C-void*>;
  input parameter x1_ :: <C-signed-int>;
  input parameter y1_ :: <C-signed-int>;
  input parameter x2_ :: <C-signed-int>;
  input parameter y2_ :: <C-signed-int>;
  c-name: "cinder_gl_update_texture";
end;

define C-function cinder-gl-create-texture-from-surface
  input parameter surfPtr_ :: <C-void*>;
  input parameter x_ :: <C-signed-int>;
  input parameter y_ :: <C-signed-int>;
  input parameter w_ :: <C-signed-int>;
  input parameter h_ :: <C-signed-int>;
  result res :: <C-void*>;
  c-name: "cinder_gl_create_texture_from_surface";
end;

define C-function cinder-gl-bind-texture
  input parameter texPtr_ :: <C-void*>;
  c-name: "cinder_gl_bind_texture";
end;

define C-function cinder-gl-unbind-texture
  input parameter texPtr_ :: <C-void*>;
  c-name: "cinder_gl_unbind_texture";
end;

define C-function cinder-gl-push-modelview-matrix
  c-name: "cinder_gl_push_modelview_matrix";
end;

define C-function cinder-gl-pop-modelview-matrix
  c-name: "cinder_gl_pop_modelview_matrix";
end;

define C-function cinder-gl-update-transform
  input parameter sx_ :: <C-float>;
  input parameter shy_ :: <C-float>;
  input parameter shx_ :: <C-float>;
  input parameter sy_ :: <C-float>;
  input parameter tx_ :: <C-float>;
  input parameter ty_ :: <C-float>;
  c-name: "cinder_gl_update_transform";
end;

define C-function cinder-gl-clear
  input parameter r_ :: <C-float>;
  input parameter g_ :: <C-float>;
  input parameter b_ :: <C-float>;
  input parameter a_ :: <C-float>;
  input parameter depth_ :: <c-boolean>;
  c-name: "cinder_gl_clear";
end;

define C-function cinder-gl-draw-rect
  input parameter x1_ :: <C-float>;
  input parameter y1_ :: <C-float>;
  input parameter x2_ :: <C-float>;
  input parameter y2_ :: <C-float>;
  input parameter u1_ :: <C-float>;
  input parameter v1_ :: <C-float>;
  input parameter u2_ :: <C-float>;
  input parameter v2_ :: <C-float>;
  c-name: "cinder_gl_draw_rect";
end;

define C-function cinder-gl-draw-text
  input parameter text_ :: <c-string>;
  input parameter r_ :: <C-float>;
  input parameter g_ :: <C-float>;
  input parameter b_ :: <C-float>;
  input parameter a_ :: <C-float>;
  input parameter x_ :: <C-float>;
  input parameter y_ :: <C-float>;
  input parameter fontPtr_ :: <C-void*>;
  c-name: "cinder_gl_draw_text";
end;

define C-function cinder-gl-draw-line
  input parameter x1_ :: <C-float>;
  input parameter y1_ :: <C-float>;
  input parameter x2_ :: <C-float>;
  input parameter y2_ :: <C-float>;
  input parameter width_ :: <C-float>;
  c-name: "cinder_gl_draw_line";
end;

define C-function cinder-gl-load-shader-program
  input parameter vertShader_ :: <c-string>;
  input parameter fragShader_ :: <c-string>;
  output parameter outErrorMsg_ :: <c-string*>;
  result res :: <C-void*>;
  c-name: "cinder_gl_load_shader_program";
end;

define C-function cinder-gl-create-shader-program
  input parameter vertShaderSource_ :: <c-string>;
  input parameter fragShaderSource_ :: <c-string>;
  output parameter outErrorMsg_ :: <c-string*>;
  result res :: <C-void*>;
  c-name: "cinder_gl_create_shader_program";
end;

define C-function cinder-gl-free-shader-program
  input parameter progPtr_ :: <C-void*>;
  c-name: "cinder_gl_free_shader_program";
end;

define C-function cinder-gl-set-uniform-1i
  input parameter progPtr_ :: <C-void*>;
  input parameter name_ :: <c-string>;
  input parameter value_ :: <C-signed-int>;
  c-name: "cinder_gl_set_uniform_1i";
end;

define C-function cinder-gl-set-uniform-1f
  input parameter progPtr_ :: <C-void*>;
  input parameter name_ :: <c-string>;
  input parameter value_ :: <C-float>;
  c-name: "cinder_gl_set_uniform_1f";
end;

define C-function cinder-gl-set-uniform-2f
  input parameter progPtr_ :: <C-void*>;
  input parameter name_ :: <c-string>;
  input parameter v1_ :: <C-float>;
  input parameter v2_ :: <C-float>;
  c-name: "cinder_gl_set_uniform_2f";
end;

define C-function cinder-gl-set-uniform-4f
  input parameter progPtr_ :: <C-void*>;
  input parameter name_ :: <c-string>;
  input parameter v1_ :: <C-float>;
  input parameter v2_ :: <C-float>;
  input parameter v3_ :: <C-float>;
  input parameter v4_ :: <C-float>;
  c-name: "cinder_gl_set_uniform_4f";
end;

define C-function cinder-gl-use-shader-program
  input parameter progPtr_ :: <C-void*>;
  c-name: "cinder_gl_use_shader_program";
end;

define C-function cinder-gl-create-framebuffer
  input parameter width_ :: <C-signed-int>;
  input parameter height_ :: <C-signed-int>;
  output parameter texturePtr_ :: <c-void**>;
  output parameter outErrorMsg_ :: <c-string*>;
  result res :: <C-void*>;
  c-name: "cinder_gl_create_framebuffer";
end;

define C-function cinder-gl-free-framebuffer
  input parameter ptr_ :: <C-void*>;
  c-name: "cinder_gl_free_framebuffer";
end;

define C-function cinder-gl-bind-framebuffer
  input parameter ptr_ :: <C-void*>;
  c-name: "cinder_gl_bind_framebuffer";
end;

define C-function cinder-gl-unbind-framebuffer
  c-name: "cinder_gl_unbind_framebuffer";
end;

define C-function cinder-vg-make-context
  input parameter surfPtr_ :: <C-void*>;
  result res :: <C-void*>;
  c-name: "cinder_vg_make_context";
end;

define C-function cinder-vg-free-context
  input parameter ctxPtr_ :: <C-void*>;
  c-name: "cinder_vg_free_context";
end;

define C-function cinder-vg-set-matrix
  input parameter ptr_ :: <C-void*>;
  input parameter xx_ :: <C-float>;
  input parameter yx_ :: <C-float>;
  input parameter xy_ :: <C-float>;
  input parameter yy_ :: <C-float>;
  input parameter x0_ :: <C-float>;
  input parameter y0_ :: <C-float>;
  c-name: "cinder_vg_set_matrix";
end;

define C-function cinder-vg-set-solid-paint
  input parameter ptr_ :: <C-void*>;
  input parameter r_ :: <C-float>;
  input parameter g_ :: <C-float>;
  input parameter b_ :: <C-float>;
  input parameter a_ :: <C-float>;
  c-name: "cinder_vg_set_solid_paint";
end;

define C-function cinder-vg-set-linear-gradient
  input parameter startX_ :: <C-float>;
  input parameter startY_ :: <C-float>;
  input parameter endX_ :: <C-float>;
  input parameter endY_ :: <C-float>;
  input parameter extend_ :: <C-signed-int>;
  c-name: "cinder_vg_set_linear_gradient";
end;

define C-function cinder-vg-set-radial-gradient
  input parameter startCenterX_ :: <C-float>;
  input parameter startCenterY_ :: <C-float>;
  input parameter startRadius_ :: <C-float>;
  input parameter endCenterX_ :: <C-float>;
  input parameter endCenterY_ :: <C-float>;
  input parameter endRadius_ :: <C-float>;
  input parameter extend_ :: <C-signed-int>;
  c-name: "cinder_vg_set_radial_gradient";
end;

define C-function cinder-vg-gradient-add-color-stop
  input parameter offset_ :: <C-float>;
  input parameter r_ :: <C-float>;
  input parameter g_ :: <C-float>;
  input parameter b_ :: <C-float>;
  input parameter a_ :: <C-float>;
  c-name: "cinder_vg_gradient_add_color_stop";
end;

define C-function cinder-vg-apply-gradient
  input parameter ptr_ :: <C-void*>;
  c-name: "cinder_vg_apply_gradient";
end;

define C-function cinder-vg-set-surface-paint
  input parameter ptr_ :: <C-void*>;
  input parameter surface_ :: <C-void*>;
  c-name: "cinder_vg_set_surface_paint";
end;

define C-function cinder-vg-set-stroke-parameters
  input parameter ptr_ :: <C-void*>;
  input parameter lineCap_ :: <C-signed-int>;
  input parameter lineJoin_ :: <C-signed-int>;
  input parameter lineWidth_ :: <C-float>;
  c-name: "cinder_vg_set_stroke_parameters";
end;

define C-function cinder-vg-clear-with-brush
  input parameter ptr_ :: <C-void*>;
  c-name: "cinder_vg_clear_with_brush";
end;

define C-function cinder-vg-draw-rect
  input parameter ptr_ :: <C-void*>;
  input parameter left_ :: <C-float>;
  input parameter top_ :: <C-float>;
  input parameter width_ :: <C-float>;
  input parameter height_ :: <C-float>;
  c-name: "cinder_vg_draw_rect";
end;

define C-function cinder-vg-draw-circle
  input parameter ptr_ :: <C-void*>;
  input parameter centerX_ :: <C-float>;
  input parameter centerY_ :: <C-float>;
  input parameter radius_ :: <C-float>;
  c-name: "cinder_vg_draw_circle";
end;

define C-function cinder-vg-clear-path
  input parameter ptr_ :: <C-void*>;
  c-name: "cinder_vg_clear_path";
end;

define C-function cinder-vg-path-move-to
  input parameter ptr_ :: <C-void*>;
  input parameter x_ :: <C-float>;
  input parameter y_ :: <C-float>;
  c-name: "cinder_vg_path_move_to";
end;

define C-function cinder-vg-path-line-to
  input parameter ptr_ :: <C-void*>;
  input parameter x_ :: <C-float>;
  input parameter y_ :: <C-float>;
  c-name: "cinder_vg_path_line_to";
end;

define C-function cinder-vg-path-quad-to
  input parameter ptr_ :: <C-void*>;
  input parameter x1_ :: <C-float>;
  input parameter y1_ :: <C-float>;
  input parameter x2_ :: <C-float>;
  input parameter y2_ :: <C-float>;
  c-name: "cinder_vg_path_quad_to";
end;

define C-function cinder-vg-path-curve-to
  input parameter ptr_ :: <C-void*>;
  input parameter x1_ :: <C-float>;
  input parameter y1_ :: <C-float>;
  input parameter x2_ :: <C-float>;
  input parameter y2_ :: <C-float>;
  input parameter x3_ :: <C-float>;
  input parameter y3_ :: <C-float>;
  c-name: "cinder_vg_path_curve_to";
end;

define C-function cinder-vg-path-close
  input parameter ptr_ :: <C-void*>;
  c-name: "cinder_vg_path_close";
end;

define C-function cinder-vg-stroke-path
  input parameter ptr_ :: <C-void*>;
  c-name: "cinder_vg_stroke_path";
end;

define C-function cinder-vg-fill-path
  input parameter ptr_ :: <C-void*>;
  c-name: "cinder_vg_fill_path";
end;

define C-function cinder-vg-draw-text
  input parameter ptr_ :: <C-void*>;
  input parameter fontPtr_ :: <C-void*>;
  input parameter text_ :: <c-string>;
  input parameter x_ :: <C-float>;
  input parameter y_ :: <C-float>;
  input parameter isFill_ :: <c-boolean>;
  c-name: "cinder_vg_draw_text";
end;

define C-function cinder-load-font
  input parameter resourceName_ :: <c-string>;
  input parameter size_ :: <C-float>;
  result res :: <C-void*>;
  c-name: "cinder_load_font";
end;

define C-function cinder-free-font
  input parameter fontPtr_ :: <C-void*>;
  c-name: "cinder_free_font";
end;

define C-pointer-type <float*> => <C-float>;
define C-function cinder-get-font-info
  input parameter fontPtr_ :: <C-void*>;
  output parameter name_ :: <c-string*>;
  output parameter size_ :: <float*>;
  output parameter ascent_ :: <float*>;
  output parameter descent_ :: <float*>;
  output parameter leading_ :: <float*>;
  c-name: "cinder_get_font_info";
end;

define C-function cinder-get-font-extents
  input parameter fontPtr_ :: <C-void*>;
  input parameter text_ :: <c-string>;
  output parameter x_ :: <float*>;
  output parameter y_ :: <float*>;
  output parameter w_ :: <float*>;
  output parameter h_ :: <float*>;
  c-name: "cinder_get_font_extents";
end;

