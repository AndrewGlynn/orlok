module: sampler 
author: Andrew Glynn
copyright: See LICENSE file in this distribution.

//  Samples to do:
//   - More/better tween examples (tween alpha, multi-tweens, etc.)
//   - Visual transform graph (parents and children, etc). Demonstrate
//     scaling, rotation, translation, including children. Show bounding
//     rects.
//   - Some standard behaviors: event listeners, button behavior,
//     draggable behavior, debug-bounding-rect behavior (add wireframe mode),
//     tooltip behavior, tween-group-behavior.
//   - Render-to-texture.
//   - more???


define class <full-screen-effect-behavior> (<behavior>)
  constant slot effect :: <full-screen-effect>,
    required-init-keyword: effect:;
end;

define method on-event (e :: <pre-render-event>,
                        b :: <full-screen-effect-behavior>) => ()
  // first render without the effect
  on-event(make(<render-event>, renderer: e.renderer), b.behavior-owner);
  // now prepare to render with the glow on top
  begin-effect(b.effect, e.renderer);
end;

define method on-event (e :: <post-render-event>,
                        b :: <full-screen-effect-behavior>) => ()
  end-effect(b.effect, e.renderer);
end;



define class <sampler-app> (<visual-app>)
  constant slot pages = make(<table>);
  constant slot effects = make(<table>);
end;

define method on-event (e :: <startup-event>, app :: <sampler-app>) => ()
  next-method();

  register-font(app, #"droid-sans-40", load-font("fonts/DroidSans.ttf", 40));
  register-font(app, #"droid-sans-14", load-font("fonts/DroidSans.ttf", 14));
  register-font(app, #"inconsolata", load-font("fonts/Inconsolata.otf", 11));
  register-font(app, #"open-baskerville", load-font("fonts/OpenBaskerville-0.0.75.otf", 12));

  app.background-color := hex-color(#x333333);

  install-effect(app, <full-screen-glow-effect>);

  let glow = make(<full-screen-glow-effect>);
  app.effects[#"glow"] := dispose-on-shutdown(app, glow);

  add-page(app, #"title", create-title-page(app));
  add-page(app, #"tweens", create-tweens-page(app));
  add-page(app, #"vg", create-vg-page(app));
  add-page(app, #"images", create-images-page(app));
  add-page(app, #"alignment", create-alignment-page(app));
  add-page(app, #"shaders", create-shaders-page(app));
  add-page(app, #"audio", create-audio-page(app));
  // TODO: create other pages

  activate-page(app, #"title");
end;

define method on-event (e :: <render-event>, app :: <sampler-app>) => ()
  next-method();

  draw-text(e.renderer,
            format-to-string("fps: %=", app.average-frames-per-second),
            app.fonts[#"inconsolata"],
            color: $white,
            at: vec2(app.config.app-width - 80, 2),
            align: $left-top);
end;

define method on-event (e :: <shutdown-event>, app :: <sampler-app>) => ()
  next-method();
end;


define function add-page (app :: <sampler-app>,
                          page-id :: <symbol>,
                          page :: <visual>) => ()
  app.pages[page-id] := page;
  add-child(app.root-visual, page);
  deactivate-page(app, page);
end;

define function deactivate-page (app :: <sampler-app>, page :: <visual>) => ()
  page.visible? := #f;
  page.interactive? := #f;
  page.running? := #f;
end;

define function activate-page (app :: <sampler-app>, page-id :: <symbol>) => ()
  for (p in app.pages)
    deactivate-page(app, p);
  end;

  let page = app.pages[page-id];
  page.visible? := #t;
  page.interactive? := #t;
  page.running? := #t;

  // Fake a mouse move event in order to un-highlight the last clicked
  // button.
  // TODO: Come up with a better solution.
  on-event(make(<mouse-move-event>,
                x: app.mouse-x,
                y: app.mouse-y,
                left-button?: app.mouse-left-button?,
                right-button?: app.mouse-right-button?,
                middle-button?: app.mouse-middle-button?),
           page);
end;

define function create-title-page (app :: <sampler-app>) => (page :: <visual>)
  let page = make(<group-visual>);

  // This allows us to add tweens to the page.
  attach-behavior(page, make(<tween-group-behavior>));

  let title = make(<text-field>,
                   text: "Sampler",
                   font: app.fonts[#"droid-sans-40"],
                   color: hex-color(#xbbbbbb),
                   align: $center);

  title.pos-x := app.config.app-width / 2.0;
  title.pos-y := 50;

  add-child(page, title);

  // animated dylan logo thingy

  let cyan = darker(hex-color(#x00abad));
  let purple = darker(hex-color(#x844399));
  let red = darker(hex-color(#xff1020));
  let orange = darker(hex-color(#xff4a21));

  let colors = vector(cyan, purple, red, orange,
                      purple, cyan, orange, red,
                      orange, red, cyan, purple,
                      red, orange, purple, cyan);

  let grid = make(<group-visual>);
  let w = 80;
  let gap = 20;
  for (i from 0 below 4)
    for (j from 0 below 4)
      let box = make(<box>,
                     color: colors[j * 4 + i],
                     rect: make(<rect>,
                                left: - w / 2.0, top: - w / 2.0,
                                width: w, height: w));
      box.pos-x := (w + gap) * (i - 2);
      box.pos-y := (w + gap) * (j - 2);
      box.parent := grid;

      // pop in boxes
      box.scale := vec2(0.0, 0.0);
      tween-to (1.0, group: page, ease: ease-out-sine, delay: (j * 4 + i) / 16.0)
        box.scale => vec2(1.0, 1.0)
      end;

      // TODO: Why does the first box get activated every time? See debug output.
      if (#f)
        listen-for (box, e :: <mouse-in-event>)
          if (box.scale-x == 1.0)
            debug-message("box (%=) type (%=)", box, box.object-class);
            debug-message("intersects? %=", intersects?(box.bounding-rect, e.mouse-vector));
            debug-message("rect(%=,%=)-(%=,%=), mouse(%=,%=)",
                          box.bounding-rect.left, box.bounding-rect.top,
                          box.bounding-rect.right, box.bounding-rect.bottom,
                          e.mouse-vector.vx, e.mouse-vector.vy);
            sequentially (group: page)
              tween-to (0.25, ease: ease-in-out-sine) box.scale => vec2(1.2, 1.2) end;
              tween-to (0.25, ease: ease-in-out-sine) box.scale => vec2(1.0, 1.0) end;
            end;
          end;
        end;
      end;
    end;
  end;

  grid.parent := page;
  align($center, of: grid, to: app.bounding-rect.center);
  grid.pos-x := grid.pos-x + 50;

  // randomly "blink" a grid square, then set up to do it again
  local method blink ()
          let b = grid.child-visuals[random(16)];
          if (b.scale-x = 1.0)
            sequentially (group: page)
              tween-to (0.25, ease: ease-in-out-sine) b.scale => vec2(1.2, 1.2) end;
              tween-to (0.25, ease: ease-in-out-sine) b.scale => vec2(1.0, 1.0) end;
            end;
          end;
          delay (random(10) / 20.0 + 0.15, group: page)
            blink();
          end;
        end;

  local method twirl ()
          let b = grid.child-visuals[random(16)];
          if (b.rotation = 0.0)
            let dir = if (random(10) > 5) 1.0 else -1.0 end;
            sequentially (group: page)
              tween-to (0.5, ease: ease-in-out-sine) b.rotation => 3.1415926 * dir end;
              action b.rotation := 0.0 end;
            end;
          end;
          delay (random(10) / 5.0 + 0.5, group: page)
            twirl();
          end;
        end;

  // wait a couple seconds to start blinking
  delay(2.0, group: page)
    blink();
    twirl();
  end;

  attach-behavior(grid, make(<full-screen-effect-behavior>,
                             effect: app.effects[#"glow"]));

  // buttons

  let btn-tweens  = add-button(page, "Tweens", 10, 100);
  let btn-vg      = add-button(page, "Vector Graphics", 10, 150);
  let btn-images  = add-button(page, "Images", 10, 200);
  let btn-align   = add-button(page, "Alignment", 10, 250);
  let btn-shaders = add-button(page, "Shaders", 10, 300);
  let btn-audio   = add-button(page, "Audio", 10, 350);
  let btn-quit    = add-button(page, "Quit", 10, 500);

  listen-for (btn-tweens, e :: <button-click-event>)
    activate-page(app, #"tweens");
  end;

  listen-for (btn-vg, e :: <button-click-event>)
    activate-page(app, #"vg");
  end;

  listen-for (btn-images, e :: <button-click-event>)
    activate-page(app, #"images");
  end;

  listen-for (btn-align, e :: <button-click-event>)
    activate-page(app, #"alignment");
  end;

  listen-for (btn-shaders, e :: <button-click-event>)
    activate-page(app, #"shaders");
  end;

  listen-for (btn-audio, e :: <button-click-event>)
    activate-page(app, #"audio");
  end;

  listen-for (btn-quit, e :: <button-click-event>)
    quit-app(the-app());
  end;

  page
end;

define function create-tweens-page (app :: <sampler-app>) => (page :: <visual>)
  // TODO: Add a time-scale slider so user can experiment with changing the
  //       time scale (in some reasonable range).

  let page = make(<group-visual>);

  let tween-owner = make(<group-visual>);

  tween-owner.parent := page;
  
  let behavior = make(<tween-group-behavior>);
  behavior.tween-group.remove-expired-tweens? := #f;
  attach-behavior(tween-owner, behavior);

  tween-owner.running? := #f;

  local method make-tween (x, y, ease-func, name)
          let txt = make(<text-field>,
                         text: name, 
                         font: app.fonts[#"droid-sans-40"],
                         color: hex-color(#xddbbdd),
                         align: $right-center);
          txt.parent := page;
          txt.scale := vec2(.4, .4);
          align($right-center, of: txt, to: vec2(x - 30, y));
          let r = make(<rect>, left: -20, top: -20, width: 40, height: 40);
          let b = make(<box>, color: $cyan, rect: r);
          b.parent := page;
          align($left-center, of: b, to: vec2(x, y));
          let tw = tween-to (1.0, ease: ease-func)
                     b.pos-x => b.pos-x + 500
                   end;
          tw
        end;

  let all-tweens = concurrently (group: tween-owner)
                     make-tween(250, 100, ease-linear, "linear");
                     make-tween(250, 150, ease-in-out-sine, "sine in/out");
                     make-tween(250, 200, ease-in-out-quad, "quad in/out");
                     make-tween(250, 250, ease-in-out-cubic,"cubic in/out");
                     make-tween(250, 300, ease-in-out-quartic, "quartic in/out");
                     make-tween(250, 350, ease-in-out-quintic,"quintic in/out");
                     make-tween(250, 400, ease-in-sine, "sine in");
                     make-tween(250, 450, ease-out-sine, "sine out");
                   end;
 
  let btn-play = add-button(page, "Play", 10, 520);
  listen-for (btn-play, e :: <button-click-event>)
    tween-owner.running? := #t;
    start-tween(all-tweens);
  end;

  let btn-back = add-button(page, "back", 10, 10);
  listen-for (btn-back, e :: <button-click-event>)
    activate-page(app, #"title");
  end;

  page
end;

define function create-alignment-page (app :: <sampler-app>) => (page :: <visual>)
  let page = make(<group-visual>);

  local method label-box (b :: <box>, txt :: <string>)
          let txt-field = make(<text-field>,
                               text: txt,
                               font: app.fonts[#"droid-sans-40"],
                               color: $black,
                               align: $center);
          txt-field.scale := vec2(.5, .5);
          add-child(b, txt-field);
          align-visual(txt-field, $center, b, $center);
        end;

  let r = make(<rect>, left: -100, top: -50, width: 200, height: 100);

  let b = make(<box>,
               color: make-hsb(0.0, 0.7, 1.0),
               rect: shallow-copy(r));

  let b-lt = make(<box>, color: make-hsb(40.0, 0.7, 1.0), rect: shallow-copy(r));
  let b-rt = make(<box>, color: make-hsb(80.0, 0.7, 1.0), rect: shallow-copy(r));
  let b-lb = make(<box>, color: make-hsb(120.0, 0.7, 1.0), rect: shallow-copy(r));
  let b-rb = make(<box>, color: make-hsb(160.0, 0.7, 1.0), rect: shallow-copy(r));
  let b-lc = make(<box>, color: make-hsb(200.0, 0.7, 1.0), rect: shallow-copy(r));
  let b-rc = make(<box>, color: make-hsb(240.0, 0.7, 1.0), rect: shallow-copy(r));
  let b-ct = make(<box>, color: make-hsb(280.0, 0.7, 1.0), rect: shallow-copy(r));
  let b-cb = make(<box>, color: make-hsb(320.0, 0.7, 1.0), rect: shallow-copy(r));

  // Note that we root all boxes under a common ancestor in order to align them.
  add-child(page, b);
  add-child(page, b-lt);
  add-child(page, b-rt);
  add-child(page, b-lb);
  add-child(page, b-rb);
  add-child(page, b-lc);
  add-child(page, b-rc);
  add-child(page, b-ct);
  add-child(page, b-cb);

  align($center, of: b, to: app.bounding-rect.center);
  label-box(b, "center");

  align-visual(b-lt, $right-bottom, b, $left-top);
  align-visual(b-rt, $left-bottom, b, $right-top);
  align-visual(b-lb, $right-top, b, $left-bottom);
  align-visual(b-rb, $left-top, b, $right-bottom);
  align-visual(b-lc, $right-center, b, $left-center);
  align-visual(b-rc, $left-center, b, $right-center);
  align-visual(b-ct, $center-bottom, b, $center-top);
  align-visual(b-cb, $center-top, b, $center-bottom);
  label-box(b-lt, "left-top");
  label-box(b-rt, "right-top");
  label-box(b-lb, "left-bottom");
  label-box(b-rb, "right-bottom");
  label-box(b-lc, "left-center");
  label-box(b-rc, "right-center");
  label-box(b-ct, "center-top");
  label-box(b-cb, "center-bottom");

  let btn-back = add-button(page, "back", 10, 10);

  listen-for (btn-back, e :: <button-click-event>)
    activate-page(app, #"title");
  end;

  page
end;

define function create-images-page (app :: <sampler-app>) => (page :: <visual>)
  let page = make(<group-visual>);
  let btn-back = add-button(page, "back", 10, 10);

  // This allows us to add tweens to the page.
  attach-behavior(page, make(<tween-group-behavior>));

  let img-1 = load-image("images/chick.png");
  let img-2 = create-image-from(img-1, anchor-pt: img-1.bounding-rect.center);

  img-1.pos := vec2(200, 100);
  align-visual(img-2, $center, img-1, $center);
  img-2.pos-x := img-2.pos-x + 250;

  add-child(page, img-1);
  add-child(page, img-2);

  let txt-1 = make(<text-field>,
                   text: "default anchor point (top-left)",
                   font: app.fonts[#"droid-sans-14"],
                   color: hex-color(#xcccccc),
                   align: $center-bottom);
  add-child(page, txt-1);
  align-visual(txt-1, $center-bottom, img-1, $center-top);

  let txt-2 = make(<text-field>,
                   text: "anchor point centered",
                   font: app.fonts[#"droid-sans-14"],
                   color: hex-color(#xcccccc),
                   align: $center-bottom);
  add-child(page, txt-2);
  align-visual(txt-2, $center-bottom, img-2, $center-top);

  listen-for (page, e :: <update-event>)
    img-1.rotation := img-1.rotation + (1.0 * e.delta-time);
    img-2.rotation := img-2.rotation + (1.0 * e.delta-time);
  end;


  let imgs = make(<stretchy-vector>);

  for (i from 0 below 50)
    let img = create-image-from(img-1, anchor-pt: img-1.bounding-rect.center);
    img.pos := vec2(0 + random(800), 300 + random(300));
    add-child(page, img);
    add!(imgs, img);
  end;


  listen-for (page, e :: <render-event>)
    for (img in imgs)
      img.pos := vec2(0 + random(800), 300 + random(300));
    end;
  end;

  listen-for (btn-back, e :: <button-click-event>)
    activate-page(app, #"title");
  end;

  page
end;

define method create-vg-page (app :: <sampler-app>) => (page :: <visual>)
  let page = make(<group-visual>);
  let btn-back = add-button(page, "back", 10, 10);

  // This allows us to add tweens to the page.
  attach-behavior(page, make(<tween-group-behavior>));

  let bmp = create-bitmap(400, 400);
  let ctx = make(<vg-context>, bitmap-target: bmp);
  let path = make(<path>);

  clear-bitmap(bmp, $white);

  begin-path(path, vec2(0, 0));
  line-to(path, vec2(0, 250));
  quad-to(path, vec2(10, 300), vec2(100, 350));
  quad-to(path, vec2(150, 380), vec2(200, 250));
  line-to(path, vec2(200, 100));
  end-path(path, close?: #t);

  let gradient = make(<radial-gradient>,
                      start: make(<circle>, center: vec2(0, 0), radius: 20.0),
                      end: make(<circle>, center: vec2(50, 50), radius: 100.0));
  gradient.gradient-extend := $paint-extend-reflect;

  add-color-stop(gradient, 0.0, make-hsb(0.0, 1.0, 1.0));
  add-color-stop(gradient, 0.5, make-hsba(90.0, 0.7, 1.0, 0.3));
  add-color-stop(gradient, 1.0, make-hsb(200.0, 0.6, 0.7));

  let fill = make(<fill>, paint: gradient);
  let stroke = make(<stroke>,
                    paint: $black,
                    line-join: $line-join-round,
                    line-cap: $line-cap-butt,
                    line-width: 20.0);

  with-context-state (ctx)
    scale!(ctx.current-transform, vec2(6.5, 7));
    rotate!(ctx.current-transform, -0.3);
    let fill2 = make(<fill>, paint: $yellow);
    let stroke2 = make(<stroke>, paint: $black, line-width: 0.5);
    vg-draw-text(ctx, "Hello world", app.fonts[#"open-baskerville"], brush: fill2,
                 at: vec2(-9, 35));
    vg-draw-text(ctx, "Hello world", app.fonts[#"open-baskerville"], brush: stroke2,
                 at: vec2(-9, 35));
  end;

  with-context-state (ctx)
    translate!(ctx.current-transform, vec2(50, 30));
    vg-draw-shape(ctx, path, fill);
    vg-draw-shape(ctx, path, stroke);
  end;

  let img = create-image-from(bmp);
  dispose(bmp);

  img.pos := vec2(100, 100);
  add-child(page, img);

  listen-for (btn-back, e :: <button-click-event>)
    activate-page(app, #"title");
  end;

  page
end;

// TODO: Make this actually demonstrate various shaders, rather than just the
//       full-screen glow effect.
define method create-shaders-page (app :: <sampler-app>) => (page :: <visual>)
  let page = make(<group-visual>);
  let btn-back = add-button(page, "back", 10, 10);

  // This allows us to add tweens to the page.
  attach-behavior(page, make(<tween-group-behavior>));

  let g = make(<group-visual>);
  add-child(page, g);

  attach-behavior(g, make(<full-screen-effect-behavior>,
                          effect: app.effects[#"glow"]));

  let imgs = make(<vector>, size: 4);

  imgs[0] := load-image("images/chick.png");
  imgs[0].pos := vec2(100, 100);
  add-child(g, imgs[0]);
  for (i from 1 below imgs.size)
    imgs[i] := create-image-from(imgs[0]);
    imgs[i].pos := imgs[0].pos + vec2(i * 150, 0);
    add-child(g, imgs[i]);
  end;

  add-child(g, make(<box>, color: $red, rect: make(<rect>,
                                                   left: 100, top: 180,
                                                   width: 80, height: 100)));
  add-child(g, make(<box>, color: $cyan, rect: make(<rect>,
                                                    left: 150, top: 250,
                                                    width: 80, height: 100)));
  add-child(g, make(<box>, color: $yellow, rect: make(<rect>,
                                                    left: 200, top: 300,
                                                    width: 80, height: 100)));

  listen-for (imgs[0], e :: <render-event>)
    draw-line(e.renderer, vec2(300, 300), vec2(350, 400), $magenta, 0.1);
  end;

  let txt = make(<text-field>,
                 text: "original",
                 color: hex-color(#xcccccc),
                 font: app.fonts[#"droid-sans-14"]);
  add-child(g, txt);
  align-visual(txt, $center-bottom, imgs[0], $center-top);

  listen-for (btn-back, e :: <button-click-event>)
    activate-page(app, #"title");
  end;

  page
end;

define function create-audio-page (app :: <sampler-app>) => (page :: <visual>)
  let page = make(<group-visual>);
  let btn-back = add-button(page, "back", 10, 10);

  // This allows us to add tweens to the page.
  attach-behavior(page, make(<tween-group-behavior>));

  // music

  let mus = dispose-on-shutdown(app, load-music("audio/music2.mp3"));

  let btn-play = add-button(page, "play", 10, 100);
  let btn-pause = add-button(page, "pause", 10, 150);
  let btn-stop = add-button(page, "stop", 10, 200);
  let btn-fadein = add-button(page, "fade in", 10, 250);
  let btn-fadeout = add-button(page, "fade out", 10, 300);

  listen-for (btn-play, e :: <button-click-event>)
    play-music(mus);
  end;
  listen-for (btn-pause, e :: <button-click-event>)
    stop-music(mus);
  end;
  listen-for (btn-stop, e :: <button-click-event>)
    play-music(mus, restart?: #t);
    stop-music(mus);
  end;
  listen-for (btn-fadein, e :: <button-click-event>)
    tween-to (1.5, group: page) mus.volume => 1.0 end;
  end;
  listen-for (btn-fadeout, e :: <button-click-event>)
    tween-to (1.5, group: page) mus.volume => 0.0 end;
  end;

  // sounds

  let snd-1 = dispose-on-shutdown(app, load-sound("audio/Pickup_Coin8.wav"));
  let snd-2 = dispose-on-shutdown(app, load-sound("audio/Jump12.wav"));

  let btn-pickup = add-button(page, "pickup", 10, 400);
  let btn-jump = add-button(page, "jump", 10, 450);

  listen-for (btn-pickup, e :: <button-click-event>)
    play-sound(snd-1);
  end;

  listen-for (btn-jump, e :: <button-click-event>)
    play-sound(snd-2);
  end;


  listen-for (btn-back, e :: <button-click-event>)
    activate-page(app, #"title");
  end;

  page
end;


//------

define function make-button (txt :: <string>,
                             x :: <real>,
                             y :: <real>,
                             alignment :: <alignment>)
  local method make-state (dx, dy, color)
          let txt-field = make(<text-field>,
                               text: txt,
                               font: the-app().fonts[#"droid-sans-40"],
                               color: color,
                               align: alignment);
          txt-field.pos := txt-field.pos + vec2(dx, dy);
          txt-field;
        end;

  let btn = make(<group-visual>);
  let up = make-state(0, 0, hex-color(#xaaaaaa));
  let over = make-state(0, 0, $yellow);
  let down = make-state(1, 1, $yellow);
  add-child(btn, up);
  add-child(btn, over);
  add-child(btn, down);
  attach-button-behavior(btn, up, over, down);
  btn.pos := vec2(x, y);
  btn.scale := vec2(.75, .75);
  btn
end;

define function add-button (owner :: <group-visual>,
                            text :: <string>,
                            x :: <real>,
                            y :: <real>,
                            #key alignment :: <alignment> = $left-top)
 => (btn :: <visual>)
  let btn = make-button(text, x, y, alignment);
  add-child(owner, btn);
end;
                            

//------

define function main (name, arguments)
  block ()
    let cfg = make(<app-config>,
                   window-width: 800,
                   window-height: 600,
                   full-screen?: #f,
                   frames-per-second: 60,
                   force-app-aspect-ratio?: #t);
    let app = make(<sampler-app>, config: cfg);

    run-app(app);
  exception (e :: <orlok-error>)
    apply(debug-message, e.orlok-error-format, e.orlok-error-args);
    exit-application(1);
  end;

  exit-application(0);
end;

main(application-name(), application-arguments());

