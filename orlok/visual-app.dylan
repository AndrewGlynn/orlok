module: visual
author: Andrew Glynn
copyright: copyright: See LICENSE file in this distribution.


// Convenience class for creating apps using the "visual" library.
// Provides a root for the visual tree, simple font management, etc.
define open abstract class <visual-app> (<app>)
  slot background-color :: <color> = make-rgb(0.5, 0.5, 0.5);
  constant slot root-visual = make(<root-visual>);
  constant slot fonts = make(<table>);
end;


define method on-event (e :: <startup-event>, app :: <visual-app>) => ()
  // Make the root a tween-group, for convenience.
  attach-behavior(app.root-visual, make(<tween-group-behavior>));
end;

define method on-event (e :: <shutdown-event>, app :: <visual-app>) => ()
  dispose(app.root-visual);
  do(dispose, app.fonts);
end;

define method on-event (e :: <render-event>, app :: <visual-app>) => ()
  clear(e.renderer, app.background-color);
  on-event(e, app.root-visual);
end;

define method on-event (e :: <update-event>, app :: <visual-app>) => ()
  on-event(e, app.root-visual);
end;

define method on-event (e :: <input-event>, app :: <visual-app>) => ()
  on-event(e, app.root-visual);
end;

define function register-font (app  :: <visual-app>,
                               id   :: <symbol>,
                               font :: <font>) => ()
  if (has-key?(app.fonts, id))
    orlok-error("a font is already registered with id '%s'", as(<string>, id));
  end;

  app.fonts[id] := font;
end;

define function unregister-font (app :: <visual-app>,
                                 id  :: <symbol>,
                                 #key dispose? :: <boolean> = #t) => ()
  let font = element(app.fonts, id, default: #f);
  if (font)
    remove-key!(app.fonts, id);
    if (dispose?)
      dispose(font);
    end;
  end;
end;

//============================================================================

// TODO: These don't really belong here, but it's convenient for now.

// TODO: I keep copying this everywhere. Find a better way to share.
define constant $vertex-pass-thru-shader =
  "void main ()                                 "
  "{                                            "
  "    gl_TexCoord[0] = gl_MultiTexCoord0;      "
  "    gl_Position = ftransform();              "
  "}                                            ";


// horizontal blur
define constant $horz-glow-shader =
  "#version 110\n                                                                  "
  "uniform sampler2D tex0;                                                         "
  "uniform vec2 sampleOffset;                                                      "
  "                                                                                "
  "void main()                                                                     "
  "{                                                                               "
  "    vec4 sum  = vec4(0.0, 0.0, 0.0, 0.0);                                       "
  "    vec2 v_uv = gl_TexCoord[0].xy;                                              "
  "                                                                                "
  "    sum += texture2D( tex0, vec2(v_uv.x + -10.0 * sampleOffset.x, v_uv.y)) * 0.009167927656011385;"
  "    sum += texture2D( tex0, vec2(v_uv.x +  -9.0 * sampleOffset.x, v_uv.y)) * 0.014053461291849008;"
  "    sum += texture2D( tex0, vec2(v_uv.x +  -8.0 * sampleOffset.x, v_uv.y)) * 0.020595286319257878;"
  "    sum += texture2D( tex0, vec2(v_uv.x +  -7.0 * sampleOffset.x, v_uv.y)) * 0.028855245532226279;"
  "    sum += texture2D( tex0, vec2(v_uv.x +  -6.0 * sampleOffset.x, v_uv.y)) * 0.038650411513543079;"
  "    sum += texture2D( tex0, vec2(v_uv.x +  -5.0 * sampleOffset.x, v_uv.y)) * 0.049494378859311142;"
  "    sum += texture2D( tex0, vec2(v_uv.x +  -4.0 * sampleOffset.x, v_uv.y)) * 0.060594058578763078;"
  "    sum += texture2D( tex0, vec2(v_uv.x +  -3.0 * sampleOffset.x, v_uv.y)) * 0.070921288047096992;"
  "    sum += texture2D( tex0, vec2(v_uv.x +  -2.0 * sampleOffset.x, v_uv.y)) * 0.079358891804948081;"
  "    sum += texture2D( tex0, vec2(v_uv.x +  -1.0 * sampleOffset.x, v_uv.y)) * 0.084895951965930902;"
  "    sum += texture2D( tex0, vec2(v_uv.x +   0.0 * sampleOffset.x, v_uv.y)) * 0.086826196862124602;"
  "    sum += texture2D( tex0, vec2(v_uv.x +  +1.0 * sampleOffset.x, v_uv.y)) * 0.084895951965930902;"
  "    sum += texture2D( tex0, vec2(v_uv.x +  +2.0 * sampleOffset.x, v_uv.y)) * 0.079358891804948081;"
  "    sum += texture2D( tex0, vec2(v_uv.x +  +3.0 * sampleOffset.x, v_uv.y)) * 0.070921288047096992;"
  "    sum += texture2D( tex0, vec2(v_uv.x +  +4.0 * sampleOffset.x, v_uv.y)) * 0.060594058578763078;"
  "    sum += texture2D( tex0, vec2(v_uv.x +  +5.0 * sampleOffset.x, v_uv.y)) * 0.049494378859311142;"
  "    sum += texture2D( tex0, vec2(v_uv.x +  +6.0 * sampleOffset.x, v_uv.y)) * 0.038650411513543079;"
  "    sum += texture2D( tex0, vec2(v_uv.x +  +7.0 * sampleOffset.x, v_uv.y)) * 0.028855245532226279;"
  "    sum += texture2D( tex0, vec2(v_uv.x +  +8.0 * sampleOffset.x, v_uv.y)) * 0.020595286319257878;"
  "    sum += texture2D( tex0, vec2(v_uv.x +  +9.0 * sampleOffset.x, v_uv.y)) * 0.014053461291849008;"
  "    sum += texture2D( tex0, vec2(v_uv.x + +10.0 * sampleOffset.x, v_uv.y)) * 0.009167927656011385;"

//  "    sum += texture2D(tex0, vec2(v_uv.x - 4.0 * sampleOffset.x, v_uv.y)) * 0.05; "
//  "    sum += texture2D(tex0, vec2(v_uv.x - 3.0 * sampleOffset.x, v_uv.y)) * 0.09; "
//  "    sum += texture2D(tex0, vec2(v_uv.x - 2.0 * sampleOffset.x, v_uv.y)) * 0.12; "
//  "    sum += texture2D(tex0, vec2(v_uv.x - sampleOffset.x,       v_uv.y)) * 0.15; "
//  "    sum += texture2D(tex0, vec2(v_uv.x,                        v_uv.y)) * 0.16; "
//  "    sum += texture2D(tex0, vec2(v_uv.x + sampleOffset.x,       v_uv.y)) * 0.15; "
//  "    sum += texture2D(tex0, vec2(v_uv.x + 2.0 * sampleOffset.x, v_uv.y)) * 0.12; "
//  "    sum += texture2D(tex0, vec2(v_uv.x + 3.0 * sampleOffset.x, v_uv.y)) * 0.09; "
//  "    sum += texture2D(tex0, vec2(v_uv.x + 4.0 * sampleOffset.x, v_uv.y)) * 0.05; "
  "                                                                                "
  "    gl_FragColor.rgb = sum.rgb; gl_FragColor.a = 1.0;                               "
  "}";


// vertical blur
define constant $vert-glow-shader =
  "#version 110\n                                                                  "
  "uniform sampler2D tex0;                                                         "
  "uniform vec2 sampleOffset;                                                      "
  "                                                                                "
  "void main()                                                                     "
  "{                                                                               "
  "    vec4 sum  = vec4(0.0, 0.0, 0.0, 0.0);                                       "
  "    vec2 v_uv = gl_TexCoord[0].xy;                                              "
  "                                                                                "
  "    sum += texture2D( tex0, vec2(v_uv.x, v_uv.y + -10.0 * sampleOffset.y )) * 0.009167927656011385;"
  "    sum += texture2D( tex0, vec2(v_uv.x, v_uv.y +  -9.0 * sampleOffset.y )) * 0.014053461291849008;"
  "    sum += texture2D( tex0, vec2(v_uv.x, v_uv.y +  -8.0 * sampleOffset.y )) * 0.020595286319257878;"
  "    sum += texture2D( tex0, vec2(v_uv.x, v_uv.y +  -7.0 * sampleOffset.y )) * 0.028855245532226279;"
  "    sum += texture2D( tex0, vec2(v_uv.x, v_uv.y +  -6.0 * sampleOffset.y )) * 0.038650411513543079;"
  "    sum += texture2D( tex0, vec2(v_uv.x, v_uv.y +  -5.0 * sampleOffset.y )) * 0.049494378859311142;"
  "    sum += texture2D( tex0, vec2(v_uv.x, v_uv.y +  -4.0 * sampleOffset.y )) * 0.060594058578763078;"
  "    sum += texture2D( tex0, vec2(v_uv.x, v_uv.y +  -3.0 * sampleOffset.y )) * 0.070921288047096992;"
  "    sum += texture2D( tex0, vec2(v_uv.x, v_uv.y +  -2.0 * sampleOffset.y )) * 0.079358891804948081;"
  "    sum += texture2D( tex0, vec2(v_uv.x, v_uv.y +  -1.0 * sampleOffset.y )) * 0.084895951965930902;"
  "    sum += texture2D( tex0, vec2(v_uv.x, v_uv.y +   0.0 * sampleOffset.y )) * 0.086826196862124602;"
  "    sum += texture2D( tex0, vec2(v_uv.x, v_uv.y +  +1.0 * sampleOffset.y )) * 0.084895951965930902;"
  "    sum += texture2D( tex0, vec2(v_uv.x, v_uv.y +  +2.0 * sampleOffset.y )) * 0.079358891804948081;"
  "    sum += texture2D( tex0, vec2(v_uv.x, v_uv.y +  +3.0 * sampleOffset.y )) * 0.070921288047096992;"
  "    sum += texture2D( tex0, vec2(v_uv.x, v_uv.y +  +4.0 * sampleOffset.y )) * 0.060594058578763078;"
  "    sum += texture2D( tex0, vec2(v_uv.x, v_uv.y +  +5.0 * sampleOffset.y )) * 0.049494378859311142;"
  "    sum += texture2D( tex0, vec2(v_uv.x, v_uv.y +  +6.0 * sampleOffset.y )) * 0.038650411513543079;"
  "    sum += texture2D( tex0, vec2(v_uv.x, v_uv.y +  +7.0 * sampleOffset.y )) * 0.028855245532226279;"
  "    sum += texture2D( tex0, vec2(v_uv.x, v_uv.y +  +8.0 * sampleOffset.y )) * 0.020595286319257878;"
  "    sum += texture2D( tex0, vec2(v_uv.x, v_uv.y +  +9.0 * sampleOffset.y )) * 0.014053461291849008;"
  "    sum += texture2D( tex0, vec2(v_uv.x, v_uv.y + +10.0 * sampleOffset.y )) * 0.009167927656011385;"

//  "    sum += texture2D(tex0, vec2(v_uv.x, v_uv.y - 4.0 * sampleOffset.y)) * 0.05; "
//  "    sum += texture2D(tex0, vec2(v_uv.x, v_uv.y - 3.0 * sampleOffset.y)) * 0.09; "
//  "    sum += texture2D(tex0, vec2(v_uv.x, v_uv.y - 2.0 * sampleOffset.y)) * 0.12; "
//  "    sum += texture2D(tex0, vec2(v_uv.x, v_uv.y - sampleOffset.y      )) * 0.15; "
//  "    sum += texture2D(tex0, vec2(v_uv.x, v_uv.y                       )) * 0.16; "
//  "    sum += texture2D(tex0, vec2(v_uv.x, v_uv.y + sampleOffset.y      )) * 0.15; "
//  "    sum += texture2D(tex0, vec2(v_uv.x, v_uv.y + 2.0 * sampleOffset.y)) * 0.12; "
//  "    sum += texture2D(tex0, vec2(v_uv.x, v_uv.y + 3.0 * sampleOffset.y)) * 0.09; "
//  "    sum += texture2D(tex0, vec2(v_uv.x, v_uv.y + 4.0 * sampleOffset.y)) * 0.05; "
  "                                                                                "
  "    gl_FragColor.rgb = sum.rgb; gl_FragColor.a = 1.0;                               "
  "}";
 


define class <full-screen-glow-effect> (<full-screen-effect>)
  constant slot render-tex-width :: <integer> = 512,
    init-keyword: render-texture-width:;
  constant slot render-tex-height :: <integer> = 512,
    init-keyword: render-texture-height:;

  slot render-tex-0         :: <render-texture>;
  slot render-tex-1         :: <render-texture>;
  slot saved-viewport       :: <rect>;
  slot saved-render-texture :: false-or(<render-texture>);
end;

define variable *h-glow-shader* :: false-or(<shader>) = #f;
define variable *v-glow-shader* :: false-or(<shader>) = #f;


define method initialize (b :: <full-screen-glow-effect>, #key)
  next-method();

  b.render-tex-0 := create-render-texture(b.render-tex-width,
                                          b.render-tex-height);
  b.render-tex-1 := create-render-texture(b.render-tex-width,
                                          b.render-tex-height);
end;

define method dispose (b :: <full-screen-glow-effect>) => ()
  next-method();
  dispose(b.render-tex-0);
  dispose(b.render-tex-1);
end;

define method install-effect (app :: <app>, type == <full-screen-glow-effect>)
 => ()
  *h-glow-shader* := create-shader($vertex-pass-thru-shader,$horz-glow-shader);
  *v-glow-shader* := create-shader($vertex-pass-thru-shader, $vert-glow-shader);

  // Prepare to clean up automatically at shutdown (in case uninstall-effect
  // is not called).
  dispose-on-shutdown(app, *h-glow-shader*);
  dispose-on-shutdown(app, *v-glow-shader*);
end;

define method uninstall-effect (app :: <app>, b == <full-screen-glow-effect>)
 => ()
  remove-from-dispose-on-shutdown(app, *h-glow-shader*);
  remove-from-dispose-on-shutdown(app, *v-glow-shader*);
  dispose(*h-glow-shader*);
  dispose(*v-glow-shader*);
  *h-glow-shader* := #f;
  *v-glow-shader* := #f;
end;

define method begin-effect (b :: <full-screen-glow-effect>, ren :: <renderer>)
 => ()
  b.saved-render-texture := ren.render-to-texture;
  b.saved-viewport       := ren.viewport;

  ren.render-to-texture  := b.render-tex-0;
  ren.viewport           := b.render-tex-0.bounding-rect;

  clear(ren, make-rgba(0.0, 0.0, 0.0, 0.0));
end;

define method end-effect (b :: <full-screen-glow-effect>, ren :: <renderer>)
 => ()
  if (~*h-glow-shader* & ~*v-glow-shader*)
    orlok-error("<full-screen-glow-effect> not installed");
  end;

  with-saved-state (ren.transform-2d)
    // clear to identity transform while we are just copying <render-texture>s
    ren.transform-2d := make(<affine-transform-2d>);

    // TODO: Make this more flexible (not just full-screen, etc, etc)
    with-saved-state (ren.shader, ren.texture, ren.render-to-texture,
                      ren.logical-size)
      ren.logical-size      := vec2(b.render-tex-width, b.render-tex-height);

      // horizontal blur of tex-0 onto tex-1
      set-uniform(*h-glow-shader*, "sampleOffset", vec2(1.0 / b.render-tex-width, 0.0));
      ren.shader            := *h-glow-shader*;
      ren.texture           := b.render-tex-0;
      ren.render-to-texture := b.render-tex-1;
      clear(ren, make-rgba(0.0, 0.0, 0.0, 0.0));
      draw-rect(ren, ren.viewport);

      // vertical blur of tex-1 back to tex-0
      set-uniform(*v-glow-shader*, "sampleOffset", vec2(0.0, 1.0 / b.render-tex-height));
      ren.shader            := *v-glow-shader*;
      ren.texture           := b.render-tex-1;
      ren.render-to-texture := b.render-tex-0;
      clear(ren, make-rgba(0.0, 0.0, 0.0, 0.0));
      draw-rect(ren, ren.viewport);
    end;

    with-saved-state (ren.texture, ren.blend-mode)
      // copy final blur back to screen
      ren.texture           := b.render-tex-0;
      ren.render-to-texture := b.saved-render-texture; // usually #f
      ren.viewport          := b.saved-viewport;
      ren.blend-mode        := $blend-additive;
      draw-rect(ren, make(<rect>, left: 0.0, top: 0.0, size: ren.logical-size));
    end;
  end;
end;
