module: simple-app

// Define our concrete <app> subclass. For this simple example we have no
// need to define any slots for the class.
define class <simple-app> (<app>)
end;


// Called after run-app is called, but before the first frame.
// This is a good place to load images and sounds, etc.
// It's not actually used in this simple example program.
define method on-event (e :: <startup-event>, app :: <simple-app>) => ()
  next-method();
end;

// Called after the last frame finishes, but before run-app returns.
// This is the spot to do any last-minute cleanup (disposing images, sounds,
// and other resources, etc.).
// It's not actually used in this simple example program.
define method on-event (e :: <shutdown-event>, app :: <simple-app>) => ()
  next-method();
end;

// Called at the beginning of each frame, before rendering.
// Normally this is where we would update various animations, simulations,
// etc. For this simple app, we have nothing to do here.
define method on-event (e :: <update-event>, app :: <simple-app>) => ()
  next-method();
end;

// Called each frame immediately after sending the <update-event>.
// This is where we actually draw stuff to the screen.
define method on-event (e :: <render-event>, app :: <simple-app>) => ()
  next-method();

  // Usually we want to clear the renderer as the first step of renderering.
  clear(e.renderer, $black);

  // Next we do any app-specific rendering. For this simple example we just
  // display a square whose color slowly changes.

  let color = make-hsb(remainder(app.app-time * 30.0, 360.0), 0.7, 1.0);
  let rect = make(<rect>, left: 200, top: 100, width: 400, height: 400);

  draw-rect(e.renderer, rect, color: color);
end;

define method on-event (e :: <key-down-event>, app :: <simple-app>) => ()
  // Allow the user to quit the app by pressing the ESC key.
  // This is not required, but here it serves as an example of keyboard input
  // handling.
  if (e.key-id == $key-escape)
    quit-app(app);
  end;
end;


define function main (name, arguments)
  // Create an object specifying some basic configuration info for the app.
  let cfg = make(<app-config>,
                 window-width: 800,
                 window-height: 600,
                 full-screen?: #f,
                 frames-per-second: 60);

  // Creating the app itself just requires the config object.
  let app = make(<simple-app>, config: cfg);

  // Run the app. This function won't return until the app has finished
  // running. More robust programs may wish to set up exception handlers
  // to deal with <orlok-error>s or other errors that might occur while
  // the app is running.
  run-app(app);

  exit-application(0);
end;

main(application-name(), application-arguments());

