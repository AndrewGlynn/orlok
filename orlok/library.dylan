module: dylan-user
author: Andrew Glynn
copyright: See LICENSE file in this distribution.

define library orlok
  use common-dylan;
  use c-ffi;
  use geom;
  use orlok-utils;
  use dtween;

  export orlok;
  export vector-graphics;
  export full-screen-effects;

  export spatial-2d;
  export visual;
end library;

define module color
  use common-dylan;
  use utils;

  export
    <color>,

    make-rgb,
    make-rgba,
    make-hsb,
    make-hsba,
    hex-color,
    copy-color,
    red, red-setter,
    green, green-setter,
    blue, blue-setter,
    alpha, alpha-setter,
    hue, hue-setter,
    saturation, saturation-setter,
    brightness, brightness-setter,

    brighter,
    darker,

    $black,
    $white,
    $gray,
    $red,
    $green,
    $blue,
    $cyan,
    $magenta,
    $yellow;
end module;

define module orlok-core
  use common-dylan;
  use utils;
  use color;
  use geom2;
  use interpolation;

  export

    // Errors and stuff

    <orlok-error>,
    orlok-error,
    orlok-error-format,
    orlok-error-args,

    <orlok-warning>,
    orlok-warning,
    orlok-warning-format,
    orlok-warning-args,

    // Applications

    <app>,
    config,
    cursor-visible?, cursor-visible?-setter,

    <app-config>,
    window-width,
    window-height,
    app-width,
    app-height,
    force-app-aspect-ratio?,
    full-screen?,
    frames-per-second,

    the-app,
    run-app,
    quit-app,

    app-time,
    average-frames-per-second,
    set-full-screen,
    set-app-size,
    set-force-app-aspect-ratio,

    // Events

    <event>,
    on-event,

    <startup-event>,
    <shutdown-event>,

    <update-event>,
    delta-time,

    <resize-event>,

    // Input

    <input-event>,

    key-down?,
    key-up?,
    <key-id>,
    <key-event>,
    key-id,
    <key-up-event>,
    <key-down-event>,

    mouse-x,
    mouse-y,
    mouse-vector,
    mouse-left-button?,
    mouse-right-button?,
    mouse-middle-button?,
    <mouse-event>,

    <mouse-move-event>,
    <mouse-button-event>,
    <mouse-button-up-event>,
    <mouse-button-down-event>,
    <mouse-left-button-event>,
    <mouse-right-button-event>,
    <mouse-middle-button-event>,
    <mouse-left-button-up-event>,
    <mouse-left-button-down-event>,
    <mouse-right-button-up-event>,
    <mouse-right-button-down-event>,
    <mouse-middle-button-up-event>,
    <mouse-middle-button-down-event>,

    // Disposal

    dispose,
    <disposable>,
    already-disposed?,

    dispose-on-shutdown,
    remove-from-dispose-on-shutdown,

    // Resources

    <resource>,
    resource-name,

    // Audio

    get-master-volume,
    set-master-volume,

    <sound>,
    load-sound,
    play-sound,

    <music>,
    volume, volume-setter,
    load-music,
    play-music,
    stop-music,

    // Misc

    bounding-rect,

    // Bitmaps

    <bitmap>,
    create-bitmap,
    create-bitmap-from,
    load-bitmap,

    copy-pixels,
    clear-bitmap,
    bitmap-premultiply,
    bitmap-unpremultiply,
    bitmap-flip-vertical,
    <bitmap-filter>,
    $bitmap-filter-box,
    $bitmap-filter-triangle,
    $bitmap-filter-gaussian,
    resize-bitmap,

    // Textures

    <texture-error>,

    <texture-filter>,
    $texture-filter-nearest-neighbor,
    $texture-filter-bilinear,

    <texture-wrap>,
    $texture-wrap-clamp,
    $texture-wrap-repeat,

    <texture>,
    texture-filter,
    texture-wrap,

    <render-texture>,

    create-texture,
    create-texture-from,
    create-render-texture,
    
    update-texture,

    // Shaders

    <shader-error>,

    <shader>,
    load-shader,
    create-shader,
    set-uniform,

    // Fonts

    <font>,
    font-name,
    font-size,
    font-ascent,
    font-descent,
    font-leading,
    font-extents,

    load-font,

    // Renderer

    <blend-mode>,
    $blend-normal,
    $blend-additive,

    <renderer>,
    texture, texture-setter,
    shader, shader-setter,
    render-to-texture, render-to-texture-setter,
    transform-2d, transform-2d-setter,
    viewport, viewport-setter,
    logical-size, logical-size-setter,
    blend-mode, blend-mode-setter,
    render-color, render-color-setter,

    clear,
    draw-rect,
    draw-text,
    draw-line,

    <render-event>,
    renderer,

    // Saving/restoring

    with-saved-state;
end module;

define module key-ids
  use common-dylan;
  use orlok-core;

  export
     $key-unknown,
     $key-first,
     $key-backspace,
     $key-tab,

     $key-clear,
     $key-return,
     $key-pause,
     $key-escape,

     $key-space,
     $key-exclaim,
     $key-quotedbl,
     $key-hash,

     $key-dollar,
     $key-ampersand,
     $key-quote,
     $key-leftparen,

     $key-rightparen,
     $key-asterisk,
     $key-plus,
     $key-comma,

     $key-minus,
     $key-period,
     $key-slash,
     $key-0,

     $key-1,
     $key-2,
     $key-3,
     $key-4,

     $key-5,
     $key-6,
     $key-7,
     $key-8,

     $key-9,
     $key-colon,
     $key-semicolon,
     $key-less,

     $key-equals,
     $key-greater,
     $key-question,
     $key-at,

     $key-leftbracket,
     $key-backslash,
     $key-rightbracket,
     $key-caret,

     $key-underscore,
     $key-backquote,
     $key-a,
     $key-b,

     $key-c,
     $key-d,
     $key-e,
     $key-f,

     $key-g,
     $key-h,
     $key-i,
     $key-j,

     $key-k,
     $key-l,
     $key-m,
     $key-n,

     $key-o,
     $key-p,
     $key-q,
     $key-r,

     $key-s,
     $key-t,
     $key-u,
     $key-v,

     $key-w,
     $key-x,
     $key-y,
     $key-z,

     $key-delete,
     $key-kp0,
     $key-kp1,
     $key-kp2,

     $key-kp3,
     $key-kp4,
     $key-kp5,
     $key-kp6,

     $key-kp7,
     $key-kp8,
     $key-kp9,
     $key-kp-period,

     $key-kp-divide,
     $key-kp-multiply,
     $key-kp-minus,
     $key-kp-plus,

     $key-kp-enter,
     $key-kp-equals,
     $key-up,
     $key-down,

     $key-right,
     $key-left,
     $key-insert,
     $key-home,

     $key-end,
     $key-pageup,
     $key-pagedown,
     $key-f1,

     $key-f2,
     $key-f3,
     $key-f4,
     $key-f5,

     $key-f6,
     $key-f7,
     $key-f8,
     $key-f9,

     $key-f10,
     $key-f11,
     $key-f12,
     $key-f13,

     $key-f14,
     $key-f15,
     $key-numlock,
     $key-capslock,

     $key-scrollock,
     $key-rshift,
     $key-lshift,
     $key-rctrl,

     $key-lctrl,
     $key-ralt,
     $key-lalt,
     $key-rmeta,

     $key-lmeta,
     $key-lsuper,
     $key-rsuper,
     $key-mode,

     $key-compose,
     $key-help,
     $key-print,
     $key-sysreq,

     $key-break,
     $key-menu,
     $key-power,
     $key-euro,

     $key-undo;
end module;

define module orlok
  use common-dylan;
  use utils, export: all;
  use geom2, export: all;
  use dtween, export: all;
  use color, export: all;
  use orlok-core, export: all;
  use key-ids, export: all;
end module;

define module full-screen-effects
  use common-dylan;
  use geom2;
  use color;
  use orlok-core;

  export
    <full-screen-effect>,
    install-effect,
    uninstall-effect,
    begin-effect,
    end-effect;

  // standard effects
  export
    <full-screen-glow-effect>;
end;

define module vector-graphics
  use common-dylan;
  use orlok-core;

  create
    <paint-extend>,
    $paint-extend-none,
    $paint-extend-repeat,
    $paint-extend-reflect,
    $paint-extend-pad,

    <gradient>,
    gradient-extend, gradient-extend-setter,
    gradient-start, gradient-start-setter,
    gradient-end, gradient-end-setter,
    add-color-stop,
    <linear-gradient>,
    <radial-gradient>,
    
    <paint>,

    <brush>,

    <fill>,
    fill-paint, fill-paint-setter,

    <line-join>,
    $line-join-miter,
    $line-join-round,
    $line-join-bevel,

    <line-cap>,
    $line-cap-butt,
    $line-cap-round,
    $line-cap-square,

    <stroke>,
    line-join, line-join-setter,
    line-cap, line-cap-setter,
    line-width, line-width-setter,
    dash-pattern, dash-pattern-setter,
    stroke-paint, stroke-paint-setter,

    <path>,
    begin-path,
    end-path,
    empty-path?,
    move-to,
    line-to,
    quad-to,
    curve-to,
    
    <vg-context>,
    bitmap-target,
    vg-draw-shape,
    vg-draw-text,
    current-transform,
    apply-transform,
    save-state,
    restore-state,
    with-context-state;
end;

define module vector-graphics-implementation
  use common-dylan;
  use geom2;
  use utils;
  use color;
  use orlok-core;
  use vector-graphics, export: all;

  export
    color-stops,
    path-points,
    path-commands,
    $path-move-to,
    $path-line-to,
    $path-quad-to,
    $path-curve-to,
    $path-close;
end;


// backend

define module cinder-backend
  use common-dylan;
  use geom2;
  use utils;
  use color;
  use orlok-core;
  use full-screen-effects;
  use vector-graphics-implementation;
  use c-ffi;
end module;

// note: independent of backend: should these be their own library?

define module spatial-2d
  use common-dylan;
  use geom2;
  use orlok-core, export: { transform-2d };

  export
    <spatial-2d>,
    pos-x, pos-x-setter,
    pos-y, pos-y-setter,
    pos, pos-setter,
    scale-x, scale-x-setter,
    scale-y, scale-y-setter,
    scale, scale-setter,
    rotation, rotation-setter,  // TODO: rename to 'angle'?

    has-identity-transform?,
    has-invertible-transform?,
    inverse-transform-2d;
end;

define module visual
  use common-dylan;
  use utils;
  use geom2;
  use dtween;
  use color, export: { alpha, alpha-setter };
  use spatial-2d, export: all;
  use orlok-core;

  export
    <mouse-in-event>,
    <mouse-out-event>,
    <pre-render-event>,
    <post-render-event>,

    <behavior>,
    behavior-owner,

    <visual>,
    visible?, visible?-setter,
    running?, running?-setter,
    interactive?, interactive?-setter,
    parent, parent-setter,
    
    should-render?,

    attach-behavior,
    remove-behavior,
    remove-behavior-by-type,
    remove-all-behaviors,
    find-behavior-by-type,
    do-behaviors,

    <visual-container>,
    child-visuals,
    add-child,
    remove-child,
    remove-child-at,

    <group-visual>,

    local-to-global-transform,
    global-to-local-transform,
    local-to-global,
    global-to-local,
    change-coordinate-space,

    relative-bounding-rect,
    align-visual,

    capture-mouse,
    mouse-capture-visual,
    focus-keyboard,
    keyboard-focus-visual,

    <root-visual>,

    <box>,
    box-color, box-color-setter,
    box-rect, box-rect-setter,

    <image>,
    create-image-from,
    load-image, 
    anchor-pt, anchor-pt-setter,
    image-texture,

    <text-field>,
    text-string, text-string-setter,
    text-font, text-font-setter,
    text-color, text-color-setter,
    text-alignment, text-alignment-setter;

  // standard behaviors

  export
    <debug-bounding-rect-behavior>,

    <draggable-behavior>,

    <event-listener-behavior>,
    listen-for,

    <button-behavior>,
    attach-button-behavior,
    <button-click-event>,
    button-click-source-event,
    button-click-button,

    <tween-group-behavior>,
    tween-group,

    <tooltip-behavior>,
    add-tooltip,
    show-tooltip,
    hide-tooltip;


  // visual apps

  export
    <visual-app>,
    root-visual,
    fonts,
    background-color, background-color-setter,
    register-font,
    unregister-font;
end;

