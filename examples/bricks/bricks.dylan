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

define constant $ball-size     = 10.0;
define constant $ball-speed    = $world-width / 2.0;

define constant $paddle-width  = 100.0;
define constant $paddle-height = 10.0;

define constant $brick-cols    = 12;
// mostly fill the width, with a little gap on either side
define constant $brick-width   = ($world-width - 2 * $wall-width) /
                                 ($brick-cols + 2);
define constant $brick-height  = $brick-width * 0.35;
define constant $brick-rows    = 5;

define constant $wall-color    = $gray;
define constant $paddle-color  = $gray;
define constant $ball-color    = $white;

define constant $initial-lives = 3;

define class <ball> (<object>)
  constant slot shape :: <rect>, required-init-keyword: rect:;
  slot velocity :: <vec2>, required-init-keyword: velocity:;
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
end;

define class <bricks-app> (<app>)
  slot ball   :: <ball>;
  slot paddle :: <paddle>;
  slot bricks :: <array>;
  slot state  :: <game-state> = $game-state-start;
  slot lives  :: <integer> = $initial-lives;
end;

define function update-brick-edges (app :: <bricks-app>) => ()
  // Make exposed brick edges active.
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
  end;

  // break and bounce off of bricks
  for (brick in app.bricks)
    if (brick.alive? & intersects?(app.ball.shape, brick.shape))
      deflect-ball(app.ball, brick);
      hit-brick(brick);
    end;
  end;

  // bounce off of walls
  if (app.ball.shape.left < $left-edge & app.ball.velocity.vx < 0)
    app.ball.velocity.vx := - app.ball.velocity.vx;
  elseif (app.ball.shape.right > $right-edge & app.ball.velocity.vx > 0)
    app.ball.velocity.vx := - app.ball.velocity.vx;
  end;
  if (app.ball.shape.top < $top-edge & app.ball.velocity.vy < 0)
    app.ball.velocity.vy := - app.ball.velocity.vy;
  end;

  // die if we fall into the kill zone (off screen)
  if (app.ball.shape.top > $bottom-edge)
    die(app);
  end;
end;

// dirty little approximation
define method deflect-ball (ball :: <ball>, brick :: <brick>) => ()
  let a = ball.shape;
  let b = brick.shape;

  let over-left?   = (a.right > b.left & a.left < b.left);
  let over-right?  = (a.left < b.right & a.right > b.right);
  let over-top?    = (a.bottom > b.top & a.top < b.top);
  let over-bottom? = (a.top < b.bottom & a.bottom > b.top);

  if ((brick.left-active? & over-left? & ball.velocity.vx > 0) |
      (brick.right-active? & over-right? & ball.velocity.vx < 0))
    ball.velocity.vx := -ball.velocity.vx;
  end;

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

define function init-level (app :: <bricks-app>) => ()
  app.ball := make(<ball>,
                   velocity: vec2(0, $ball-speed),
                   rect: make(<rect>,
                              center-x: $world-width / 2.0,
                              center-y: $world-height - 200,
                              size: vec2($ball-size, $ball-size)));
  app.paddle := make(<paddle>,
                     rect: make(<rect>,
                                center-x: $world-width / 2.0,
                                center-y: $world-height - 20,
                                size: vec2($paddle-width, $paddle-height)));

  app.bricks := make(<array>, dimensions: vector($brick-cols, $brick-rows));

  let h = 0.0;
  let sat = 0.5;
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
end;

define function die (app :: <bricks-app>) => ()
  // TODO
end;

define function hit-brick (brick :: <brick>) => ()
  brick.alive? := #f;
end;

define method on-event (e :: <startup-event>, app :: <bricks-app>) => ()
  next-method();
  init-level(app);
end;

define method on-event (e :: <shutdown-event>, app :: <bricks-app>) => ()
  next-method();
end;

define method on-event (e :: <update-event>, app :: <bricks-app>) => ()
  next-method();
  update-brick-edges(app);
  move-rect(app.ball.shape, app.ball.velocity * e.delta-time);
  check-collisions(app);
end;

define method on-event (e :: <render-event>, app :: <bricks-app>) => ()
  next-method();
  clear(e.renderer, $black);

  draw-rect(e.renderer,
            make(<rect>,
                 left: 0, right: $left-edge,
                 top: 0, bottom: $world-height),
            color: $wall-color);
  draw-rect(e.renderer,
            make(<rect>,
                 left: $right-edge, right: $world-width,
                 top: 0, bottom: $world-height),
            color: $wall-color);
  draw-rect(e.renderer,
            make(<rect>,
                 left: $left-edge, right: $right-edge,
                 top: 0, bottom: $top-edge),
            color: $wall-color);

  for (b in app.bricks)
    if (b.alive?)
      draw-rect(e.renderer, b.shape, color: b.color);
    end;
  end;

  draw-rect(e.renderer, app.paddle.shape, color: $paddle-color);
  draw-rect(e.renderer, app.ball.shape, color: $ball-color);
end;

define method on-event (e :: <mouse-move-event>, app :: <bricks-app>) => ()
  // paddle follows mouse
  h-align($h-center, of: app.paddle.shape, to: e.mouse-x);

  // but is constrained by walls
  if (app.paddle.shape.left < $left-edge)
    h-align($left, of: app.paddle.shape, to: $left-edge);
  end;
  if (app.paddle.shape.right > $right-edge)
    h-align($right, of: app.paddle.shape, to: $right-edge);
  end;
end;

define method on-event (e :: <key-down-event>, app :: <bricks-app>) => ()
  if (e.key-id == $key-escape)
    quit-app(app);
  end;
end;


define function main (name, arguments)
  let cfg = make(<app-config>,
                 window-width: $world-width,
                 window-height: $world-height,
                 full-screen?: #f,
                 frames-per-second: 60);
  let app = make(<bricks-app>, config: cfg);

  run-app(app);

  exit-application(0);
end;

main(application-name(), application-arguments());
