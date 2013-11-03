module: visual
author: Andrew Glynn
copyright: See LICENSE file in this distribution.


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
