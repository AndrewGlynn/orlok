module: bricks
author: Andrew Glynn
copyright: See LICENSE file in this distribution.

define constant $world-width   = 800;
define constant $world-height  = 600;

define constant $wall-width    = 10.0;
define constant $left-edge     = $wall-width;
define constant $right-edge    = $world-width - $wall-width;
define constant $top-edge      = $wall-width;
define constant $bottom-edge   = $world-height;
define constant $killzone      = $bottom-edge + 100;

define constant $ball-size     = 10.0;
define constant $ball-speed    = $world-width / 2.0;

define constant $paddle-width  = 100.0;
define constant $paddle-height = 10.0;

define constant $brick-cols    = 12;
define constant $brick-rows    = 5;

// mostly fill the width, with a little gap on either side
define constant $brick-width   = ($world-width - 2 * $wall-width) /
                                 ($brick-cols + 2);
define constant $brick-height  = $brick-width * 0.35;

define constant $wall-color    = $gray;

define constant $initial-lives = 3;

define class <ball> (<object>)
  constant slot shape :: <rect>, required-init-keyword: rect:;
  slot velocity :: <vec2> = vec2(0, 0);
end;

define class <paddle> (<object>)
  constant slot shape :: <rect>, required-init-keyword: rect:;
end;

define class <brick> (<object>)
  constant slot shape :: <rect>, required-init-keyword: rect:;
  constant slot color :: <color>, required-init-keyword: color:;
  slot alive? :: <boolean> = #t;

  // We keep track of "active" edges (ie, edges that are exposed).
  slot left-active?   :: <boolean> = #t;
  slot right-active?  :: <boolean> = #t;
  slot top-active?    :: <boolean> = #t;
  slot bottom-active? :: <boolean> = #t;
end;

define enum <game-state> ()
  $game-state-start;   // beginning game
  $game-state-run;     // normal play
  $game-state-respawn; // died and waiting to respawn next ball
  $game-state-over;    // game over
  $game-state-win;     // hooray!
end;

define class <bricks-app> (<visual-app>)
  // actual game state
  slot ball    :: <ball>;
  slot paddle  :: <paddle>;
  slot bricks  :: <array>;
  slot state   :: <game-state> = $game-state-start;
  slot paused? :: <boolean> = #f;
  slot lives   :: <integer> = $initial-lives;

  // effects
  slot tween-group :: <tween-group> = make(<tween-group>);
  slot sounds :: <table> = make(<table>);
  slot textures :: <table> = make(<table>);
  slot glow-effect :: <full-screen-glow-effect>;

  // UI
  slot pause-screen :: <group-visual>;
  slot win-screen :: <group-visual>;
  slot game-over-screen :: <group-visual>;
  slot game-screen :: <group-visual>;
  slot glow-layer :: <group-visual>;
  slot instructions :: <text-field>;
end;

//----------------------------------------------------------------------------
// Event Handling
//----------------------------------------------------------------------------

define method on-event (e :: <startup-event>, app :: <bricks-app>) => ()
  next-method();

  app.background-color := $black;

  app.sounds[#"bounce-paddle"] := load-sound("audio/bounce_paddle.mp3");
  app.sounds[#"bounce-wall"] := load-sound("audio/bounce_wall.mp3");
  app.sounds[#"break-brick"] := load-sound("audio/break_brick.mp3");
  app.sounds[#"die"] := load-sound("audio/die.mp3");
  app.sounds[#"respawn"] := load-sound("audio/respawn.mp3");
  app.sounds[#"win"] := load-sound("audio/win.mp3");

  let ball-bmp = load-bitmap("images/ball.png");
  let paddle-bmp = load-bitmap("images/paddle.png");

  app.textures[#"ball"] := create-texture-from(ball-bmp);
  app.textures[#"paddle"] := create-texture-from(paddle-bmp);

  dispose(ball-bmp);
  dispose(paddle-bmp);

  register-font(app, #"small", load-font("fonts/Orbitron Medium.otf", 9));
  register-font(app, #"medium", load-font("fonts/Orbitron Medium.otf", 24));
  register-font(app, #"large", load-font("fonts/Orbitron Medium.otf", 60));

  install-effect(app, <full-screen-glow-effect>);
  app.glow-effect := make(<full-screen-glow-effect>);

  // We need to render the level before rendering the root visual.
  // TODO: Find a cleaner way to do this?
  listen-for (app.root-visual, e :: <pre-render-event>)
    render-level(app, e.renderer);
  end;

  // game <visual>s go under this
  app.game-screen := make(<group-visual>, parent: app.root-visual);
  app.glow-layer := make(<group-visual>, parent: app.game-screen);

  // set up glow-layer to use a full-screen glow effect
  listen-for (app.glow-layer, e :: <pre-render-event>)
    // first render without the effect
    on-event(make(<render-event>, renderer: e.renderer), app.glow-layer);
    // now prepare to render with the glow on top
    begin-effect(app.glow-effect, e.renderer);
  end;

  listen-for (app.glow-layer, e :: <post-render-event>)
    // put a glow on the ball, too
    draw-rect(e.renderer, app.ball.shape, texture: app.textures[#"ball"]);
    end-effect(app.glow-effect, e.renderer);
  end;

  create-ui-screens(app);
  init-level(app);
end;

define method on-event (e :: <shutdown-event>, app :: <bricks-app>) => ()
  dispose(app.glow-effect);
  do(dispose, app.sounds);
  do(dispose, app.textures);
  next-method();
end;

define method on-event (e :: <update-event>, app :: <bricks-app>) => ()
  next-method();

  if (~app.paused?)
    // updates various effects
    update-tween-group(app.tween-group, e.delta-time);

    select (app.state)
      $game-state-start =>
        // keep ball attached to paddle when in start state
        align($center-bottom,
              of: app.ball.shape,
              to: app.paddle.shape.center-top + vec2(0, -5));
      $game-state-run =>
        update-brick-edges(app);
        move-rect(app.ball.shape, app.ball.velocity * e.delta-time);
        check-collisions(app);
      otherwise => #f; // nothing to do
    end;
  end;
end;

define method on-event (e :: <mouse-move-event>, app :: <bricks-app>) => ()
  next-method();

  if (~app.paused?)
    // paddle follows mouse...
    if (app.state == $game-state-start |
        app.state == $game-state-run |
        app.state == $game-state-respawn)
      h-align($h-center, of: app.paddle.shape, to: e.mouse-x);
    end;

    // ...but is constrained by walls
    if (app.paddle.shape.left < $left-edge)
      h-align($left, of: app.paddle.shape, to: $left-edge);
    end;
    if (app.paddle.shape.right > $right-edge)
      h-align($right, of: app.paddle.shape, to: $right-edge);
    end;
  end;
end;

define method on-event (e :: <mouse-button-down-event>, app :: <bricks-app>)
 => ()
  next-method();

  if (~app.paused?)
    if (app.state == $game-state-start)
      // fade out instructions if necessary
      if (app.instructions.visible?)
        fade-out(app.instructions, 0.25, app.tween-group);
      end;

      // launch the ball at an arbitrary angle
      app.ball.velocity := rotate-vec(vec2(0, -$ball-speed), $single-pi / 6);
      app.state := $game-state-run;
    end;
  end;
end;

define method on-event (e :: <key-down-event>, app :: <bricks-app>) => ()
  if (e.key-id == $key-escape &
      ~app.paused? &
      ~app.win-screen.visible? &
      ~app.game-over-screen.visible?)
    app.paused? := #t;
    fade-in(app.pause-screen, 0.25, app.root-visual);
  end;
end;

//----------------------------------------------------------------------------
// Helpers
//----------------------------------------------------------------------------

define function render-level (app :: <bricks-app>, ren :: <renderer>) => ()
  // walls
  draw-rect(ren,
            make(<rect>,
            left: 0, right: $left-edge,
            top: 0, bottom: $world-height),
            color: $wall-color);
  draw-rect(ren,
            make(<rect>,
            left: $right-edge, right: $world-width,
            top: 0, bottom: $world-height),
            color: $wall-color);
  draw-rect(ren,
            make(<rect>,
            left: $left-edge, right: $right-edge,
            top: 0, bottom: $top-edge),
            color: $wall-color);

  // bright border on walls
  draw-line(ren, vec2($left-edge, $top-edge), vec2($left-edge, $bottom-edge),
            hex-color(#xbbffff), 2.0);
  draw-line(ren, vec2($right-edge, $top-edge), vec2($right-edge, $bottom-edge),
            hex-color(#xbbffff), 2.0);
  draw-line(ren, vec2($left-edge, $top-edge), vec2($right-edge, $top-edge),
            hex-color(#xbbffff), 2.0);

  // draw each brick in its own color, with a gray border
  for (b in app.bricks)
    if (b.alive?)
      draw-rect(ren, b.shape, color: $gray);
      draw-rect(ren,
                expand-rect(b.shape,
                            horizontal-amount: -5,
                            vertical-amount: -5),
                color: b.color);
    end;
  end;

  draw-rect(ren, app.paddle.shape, texture: app.textures[#"paddle"]);
  draw-rect(ren, app.ball.shape, texture: app.textures[#"ball"]);

  draw-text(ren,
            format-to-string("fps: %=", app.average-frames-per-second),
            app.fonts[#"small"],
            color: $black,
            at: vec2(app.config.app-width - 80, 0),
            align: $left-top);
end;

define function update-brick-edges (app :: <bricks-app>) => ()
  // make exposed brick edges active
  for (i from 0 below $brick-cols)
    for (j from 0 below $brick-rows)
      let b = app.bricks[i, j];
      b.left-active?   := (i == 0 | ~app.bricks[i - 1, j].alive?);
      b.right-active?  := (i == $brick-cols - 1 | ~app.bricks[i + 1, j].alive?);
      b.top-active?    := (j == 0 | ~app.bricks[i, j - 1].alive?);
      b.bottom-active? := (j == $brick-rows - 1 | ~app.bricks[i, j + 1].alive?);
    end;
  end;
end;

define function check-collisions (app :: <bricks-app>) => ()
  // bounce off of paddle
  if (intersects?(app.ball.shape, app.paddle.shape))
    deflect-ball(app.ball, app.paddle);
    play-sound(app.sounds[#"bounce-paddle"]);
  end;

  // break and bounce off of bricks
  for (brick in app.bricks)
    if (brick.alive? & intersects?(app.ball.shape, brick.shape))
      deflect-ball(app.ball, brick);
      hit-brick(app, brick);
      play-sound(app.sounds[#"break-brick"]);
    end;
  end;

  // bounce off of walls
  if (app.ball.shape.top < $bottom-edge)
    if (app.ball.shape.left < $left-edge & app.ball.velocity.vx < 0)
      app.ball.velocity.vx := - app.ball.velocity.vx;
      hit-wall(app, app.ball);
    elseif (app.ball.shape.right > $right-edge & app.ball.velocity.vx > 0)
      app.ball.velocity.vx := - app.ball.velocity.vx;
      hit-wall(app, app.ball);
    end;
  end;
  if (app.ball.shape.top < $top-edge & app.ball.velocity.vy < 0)
    app.ball.velocity.vy := - app.ball.velocity.vy;
    hit-wall(app, app.ball);
  end;

  // die if we fall into the kill zone (off screen)
  if (app.ball.shape.top > $killzone)
    die(app);
  end;

  if (~any?(alive?, app.bricks))
    win(app);
  end;
end;

define method deflect-ball (ball :: <ball>, brick :: <brick>) => ()
  let a = ball.shape;
  let b = brick.shape;

  let over-left?   = (a.right > b.left & a.left < b.left);
  let over-right?  = (a.left < b.right & a.right > b.right);
  let over-top?    = (a.bottom > b.top & a.top < b.top);
  let over-bottom? = (a.top < b.bottom & a.bottom > b.top);

  // bounce off of vertical edges
  if ((brick.left-active? & over-left? & ball.velocity.vx > 0) |
      (brick.right-active? & over-right? & ball.velocity.vx < 0))
    ball.velocity.vx := -ball.velocity.vx;
  end;

  // bounce off of horizontal edges
  if ((brick.top-active? & over-top? & ball.velocity.vy > 0) |
      (brick.bottom-active? & over-bottom? & ball.velocity.vy < 0))
    ball.velocity.vy := -ball.velocity.vy;
  end;
end;

define method deflect-ball (ball :: <ball>, paddle :: <paddle>) => ()
  // Deflect the ball based on where it hit the paddle (kind of as if the
  // paddle were a semicircle rather than a rectangle).
  let offset = ball.shape.center-x - paddle.shape.center-x;
  offset := clamp(offset / paddle.shape.width, -1.0, 1.0);

  let angle = offset * $single-pi * 0.75; // not quite a semicircle

  ball.velocity := rotate-vec(vec2(0.0, -$ball-speed), angle);
end;

define function hit-brick (app :: <bricks-app>, brick :: <brick>) => ()
  brick.alive? := #f;

  // "explosion" effect
  let b = make(<box>,
               rect: shallow-copy(brick.shape) - brick.shape.center,
               color: brick.color,
               pos: brick.shape.center,
               parent: app.glow-layer);

  sequentially (group: app.tween-group)
    tween-to (0.5, ease: ease-out-sine)
      b.scale => vec2(2, 2);
      b.alpha => 0.0;
    end;
    action
      b.parent := #f;
    end;
  end;
end;

define function hit-wall (app :: <bricks-app>, ball :: <ball>) => ()
  play-sound(app.sounds[#"bounce-wall"]);

  // "bounce" effect
  let tex = app.textures[#"ball"];
  let bounce = create-image-from(tex, align: $center);
  bounce.parent := app.glow-layer;
  bounce.pos := ball.shape.center;
  let s = ball.shape.width / tex.width;
  bounce.scale := vec2(s, s);
  bounce.alpha := 0.35;

  sequentially (group: app.tween-group)
    tween-to (0.3, ease: ease-out-sine)
      bounce.scale => vec2(s * 4, s * 4);
      bounce.alpha => 0.0;
    end;
    action
      bounce.parent := #f;
    end;
  end;
end;

define function die (app :: <bricks-app>) => ()
  app.lives := app.lives - 1;
  play-sound(app.sounds[#"die"]);
  if (app.lives > 0)
    respawn(app);
  else
    game-over(app);
  end;
end;

//----------------------------------------------------------------------------
// Game Flow
//----------------------------------------------------------------------------

define function init-level (app :: <bricks-app>) => ()
  app.ball := make(<ball>,
                   rect: make(<rect>,
                              center: vec2(0, 0),
                              size: vec2($ball-size, $ball-size)));
  app.paddle := make(<paddle>,
                     rect: make(<rect>,
                                center-x: $world-width / 2.0,
                                center-y: $world-height - 20,
                                size: vec2($paddle-width, $paddle-height)));

  app.bricks := make(<array>, dimensions: vector($brick-cols, $brick-rows));

  let h = 0.0;
  let sat = 0.65;
  // center bricks
  let x-offset = ($world-width / 2.0) + (1 - $brick-cols) * $brick-width / 2.0;

  for (i from 0 below $brick-cols)
    for (j from 0 below $brick-rows)
      let r = make(<rect>,
                   center-x: x-offset + (i * $brick-width),
                   center-y: ($world-height / 4.0) + j * $brick-height,
                   width: $brick-width, height: $brick-height);
      let brick = make(<brick>, rect: r, color: make-hsb(h, sat, 1.0));
      h := remainder(h + 30.0, 360.0);
      app.bricks[i,j] := brick;
    end;
  end;

  // initial instructions
  app.instructions := make(<text-field>,
                           text: "Click the mouse to launch the ball.",
                           font: app.fonts[#"medium"],
                           align: $center,
                           color: $white,
                           alpha: 0.0,
                           pos: app.bounding-rect.center + vec2(0, 100),
                           parent: app.game-screen);

  prepare-game(app);
end;

define function prepare-game (app :: <bricks-app>) => ()
  fade-in(app.instructions, 0.75, app.tween-group);

  app.lives := $initial-lives;

  for (brick in app.bricks)
    brick.alive? := #t;
  end;

  start-game(app);
end;

define function start-game (app :: <bricks-app>) => ()
  app.state := $game-state-start;
  play-sound(app.sounds[#"respawn"]);

  // We create a new <text-field> each time. This is wasteful, but oh well.
  let txt = make(<text-field>,
                 text: format-to-string("Lives: %=", app.lives),
                 font: app.fonts[#"large"],
                 align: $center,
                 color: $white,
                 alpha: 0.0,
                 scale-y: 0.5,
                 parent: app.game-screen);
  align($center, of: txt, to: app.bounding-rect.center);

  sequentially (group: app.tween-group)
    tween-to (1.0, ease: ease-out-cubic)
      txt.alpha => 1.0; txt.scale-y => 1.0
    end;
    pause-for(1.0);
    tween-to (0.25, ease: ease-in-cubic)
      txt.alpha => 0.0; txt.scale-x => 2.0; txt.scale-y => 0.0
    end;
    action
      txt.parent := #f;
    end;
  end;
end;

define function respawn (app :: <bricks-app>) => ()
  app.state := $game-state-respawn;
  delay (1.0, group: app.tween-group)
    start-game(app);
  end;
end;

define function game-over (app :: <bricks-app>) => ()
  app.state := $game-state-over;
  fade-in(app.game-over-screen, 0.25, app.root-visual);
end;

define function win (app :: <bricks-app>) => ()
  app.state := $game-state-win;
  fade-in(app.win-screen, 0.25, app.root-visual);
  app.ball.velocity := vec2(0, 0);
  play-sound(app.sounds[#"win"]);
end;

//----------------------------------------------------------------------------
// UI
//----------------------------------------------------------------------------

define function create-ui-screens (app :: <bricks-app>) => ()
  // pause screen
  begin
    let (s, btn-continue, btn-quit)
      = make-menu-screen(app, "Paused", "Continue", "Quit");
    app.pause-screen := s;

    listen-for (btn-continue, e :: <button-click-event>)
      sequentially (group: app.root-visual)
        tween-to (0.25) app.pause-screen.alpha => 0.0 end;
        action
          app.pause-screen.visible? := #f;
          app.paused? := #f;
        end;
      end;
    end;

    listen-for (btn-quit, e :: <button-click-event>)
      quit-app(app);
    end;
  end;

  // game over screen
  begin
    let (s, btn-replay, btn-quit)
      = make-menu-screen(app, "Game Over!", "Play Again", "Quit");
    app.game-over-screen := s;

    listen-for (btn-replay, e :: <button-click-event>)
      fade-out(app.game-over-screen, 0.25, app.root-visual);
      prepare-game(app);
    end;

    listen-for (btn-quit, e :: <button-click-event>)
      quit-app(app);
    end;
  end;

  // win screen
  begin
    let (s, btn-replay, btn-quit)
      = make-menu-screen(app, "You Win!", "Play Again", "Quit");
    app.win-screen := s;

    listen-for (btn-replay, e :: <button-click-event>)
      fade-out(app.win-screen, 0.25, app.root-visual);
      prepare-game(app);
    end;

    listen-for (btn-quit, e :: <button-click-event>)
      quit-app(app);
    end;
  end;
end;

define function make-menu-screen (app :: <bricks-app>,
                                  title :: <string>,
                                  btn-1-label :: <string>,
                                  btn-2-label :: <string>)
=> (screen :: <box>, btn-1 :: <visual>, btn-2 :: <visual>)
  let screen = make(<box>,
                    rect: app.bounding-rect,
                    color: make-rgba(0.0, 0.0, 0.0, 0.75),
                    parent: app.root-visual);
  screen.visible? := #f;

  let txt = make(<text-field>,
                 text: title,
                 font: app.fonts[#"large"],
                 color: $white,
                 align: $center-bottom,
                 parent: screen);
  align($center-bottom, of: txt, to: app.bounding-rect.center);

  let btn-1 = make-button(btn-1-label, 0, 0, $center, screen);
  let btn-2 = make-button(btn-2-label, 0, 0, $center, screen);

  align-visual(btn-1, $center-top, txt, $center-bottom);
  align-visual(btn-2, $center-top, btn-1, $center-bottom);

  // TODO: should support offsets like this in align-visual somehow...
  btn-1.pos-y := btn-1.pos-y + 40;
  btn-2.pos-y := btn-2.pos-y + 60;

  values(screen, btn-1, btn-2)
end;

define function fade-in (v :: <visual>,
                         duration :: <single-float>,
                         tween-group) => ()
  v.visible? := #t;
  v.alpha := 0.0;
  tween-to (duration, group: tween-group) v.alpha => 1.0 end;
end;


define function make-button (txt :: <string>,
                            x :: <real>,
                            y :: <real>,
                            alignment :: <alignment>,
                            the-parent :: <visual-container>)
  let btn = make(<group-visual>, parent: the-parent, pos: vec2(x, y));

  local method make-state (dx, dy, color)
          make(<text-field>,
               text: txt,
               font: the-app().fonts[#"medium"],
               color: color,
               align: alignment,
               pos: vec2(dx, dy),
               parent: btn);
        end;

  let up = make-state(0, 0, hex-color(#xaaaaaa));
  let over = make-state(0, 0, $white);
  let down = make-state(1, 1, $white);
  attach-button-behavior(btn, up, over, down);
  btn
end;


define function fade-out (v :: <visual>,
                          duration :: <single-float>,
                          tween-group) => ()
  sequentially (group: tween-group)
    tween-to (duration) v.alpha => 0.0 end;
    action v.visible? := #f; end;
  end;
end;

//----------------------------------------------------------------------------
// Entry Point
//----------------------------------------------------------------------------

define function main (name, arguments)
  let cfg = make(<app-config>,
                 window-width: $world-width,
                 window-height: $world-height,
                 full-screen?: #f,
                 force-app-aspect-ratio?: #t,
                 frames-per-second: 60);
  let app = make(<bricks-app>, config: cfg);

  run-app(app);
  exit-application(0);
end;

main(application-name(), application-arguments());
