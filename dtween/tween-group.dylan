module: tween-group
synopsis: A <tween-group> manages a set of tweens, updating them and removing
          them when they expire.
author: Andrew Glynn
copyright: copyright: See LICENSE file in this distribution.

define class <tween-group> (<object>)
  slot tweens :: limited(<stretchy-vector>, of: <tween>)
    = make(limited(<stretchy-vector>, of: <tween>));
  slot paused? :: <boolean> = #f;
  slot time-scale :: <single-float> = 1.0;
  slot remove-expired-tweens? :: <boolean> = #t;
end;

// Note that the 'group' parameter is not typed in the generic. This
// allows other types to act as <tween-groups> (presumably forwarding the
// call to a real <tween-group>). This is just a syntactic convenience,
// especially for the macros exported by this library.
define open generic add-tween-to-group (group,
                                        tw :: <tween>) => ();

define method add-tween-to-group (group :: <tween-group>,
                                  tw    :: <tween>) => ()
  start-tween(tw);
  group.tweens := add!(group.tweens, tw);
end;

define method remove-tween-from-group (group :: <tween-group>,
                                       tw    :: <tween>) => ()
  group.tweens := remove!(group.tweens, tw)
end;

define method clear-tween-group (group :: <tween-group>) => ()
  group.tweens.size := 0;
end;

define method update-tween-group (group :: <tween-group>,
                                  dt    :: <single-float>) => ()
  if (~group.paused? & group.time-scale > 0.0)
    for (tw in group.tweens)
      if (~tw.expired?)
        update-tween(tw, dt * group.time-scale);
      end;
    end;

    if (group.remove-expired-tweens? & any?(expired?, group.tweens))
      group.tweens := choose(complement(expired?), group.tweens);
    end;
  end
end;

