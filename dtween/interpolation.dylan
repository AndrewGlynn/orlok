module: interpolation
synopsis: A set of functions for linearly interpolating values of various types.
          To achieve non-linear interpolation, feed a t value into an easing
          function first, then pass the result onto interpolate.
author: Andrew Glynn
copyright: copyright: See LICENSE file in this distribution.

// t is between 0.0 and 1.0 inclusive
// It is assumed that initial, final, and result have the same type.
define open generic interpolate (initial, final, t :: <single-float>) => (result);

define sealed method interpolate (initial :: <single-float>,
                                  final   :: <single-float>,
                                  t       :: <single-float>)
 => (result :: <single-float>)
  initial + (final - initial) * t
end;

define sealed method interpolate (initial :: <double-float>,
                                  final   :: <double-float>,
                                  t       :: <single-float>)
 => (result :: <double-float>)
  initial + (final - initial) * t
end;

// Convert integers to <single-float>, then round the result.
// This can probably lead to problems with precision and so on.
define sealed method interpolate (initial :: <integer>,
                                  final   :: <integer>,
                                  t       :: <single-float>)
 => (result :: <integer>)
  round(interpolate(as(<double-float>, initial),
                    as(<double-float>, final),
                    t))
end;

// This one is a bit iffy. Treat t < .5 as the initial value, otherwise
// the final value.
define sealed method interpolate (initial :: <boolean>,
                                  final   :: <boolean>,
                                  t       :: <single-float>)
 => (result :: <boolean>)
  if (t < 0.5)
    initial
  else
    final
  end
end;

