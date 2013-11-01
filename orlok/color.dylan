module: color
author: Andrew Glynn
copyright: copyright: See LICENSE file in this distribution.

// These are defined as open so other classes can use them directly, without
// needing to embed a <color>.
// Note: I use the term "brightness" rather than "value" simply because
// the latter seemed too general, especially given Dylan's module-wide
// namespace.

define open generic red        (obj) => (_ :: <single-float>);
define open generic green      (obj) => (_ :: <single-float>);
define open generic blue       (obj) => (_ :: <single-float>);
define open generic alpha      (obj) => (_ :: <single-float>);
define open generic hue        (obj) => (_ :: <single-float>);
define open generic saturation (obj) => (_ :: <single-float>);
define open generic brightness (obj) => (_ :: <single-float>);

define open generic red-setter
    (new-value :: <single-float>, obj) => (_ :: <single-float>);
define open generic green-setter
    (new-value :: <single-float>, obj) => (_ :: <single-float>);
define open generic blue-setter
    (new-value :: <single-float>, obj) => (_ :: <single-float>);
define open generic alpha-setter
    (new-value :: <single-float>, obj) => (_ :: <single-float>);
define open generic hue-setter
    (new-value :: <single-float>, obj) => (_ :: <single-float>);
define open generic saturation-setter
    (new-value :: <single-float>, obj) => (_ :: <single-float>);
define open generic brightness-setter
    (new-value :: <single-float>, obj) => (_ :: <single-float>);

// Simple color class. Mainly geared toward the RGB color space, with token
// support for the Hue/Saturation/Value model (where we call "value"
// "brightness").
// All slots are automatically clamped to the range 0..1 (except for hue,
// which goes 0..360).
// An alpha channel is included (also in the range 0..1).
define class <color> (<object>)
  virtual constant slot red   :: <single-float>;
  virtual constant slot green :: <single-float>;
  virtual constant slot blue  :: <single-float>;
  virtual constant slot alpha :: <single-float>;

  virtual constant slot hue        :: <single-float>;
  virtual constant slot saturation :: <single-float>;
  virtual constant slot brightness :: <single-float>;

  constant slot %r :: <single-float> = 0.0, init-keyword: red:;
  constant slot %g :: <single-float> = 0.0, init-keyword: green:;
  constant slot %b :: <single-float> = 0.0, init-keyword: blue:;
  constant slot %a :: <single-float> = 1.0, init-keyword: alpha:;
end;

define sealed domain make (singleton(<color>));

// Create a new <color> with the given RGB values.
// Alpha defaults to 1.
define function make-rgb (r :: <single-float>,
                          g :: <single-float>,
                          b :: <single-float>) => (c :: <color>)
  make(<color>, red: r, green: g, blue: b, alpha: 1.0)
end;

// Create a new <color> with the given RGBA values.
define function make-rgba (r :: <single-float>,
                           g :: <single-float>,
                           b :: <single-float>,
                           a :: <single-float>) => (c :: <color>)
  make(<color>, red: r, green: g, blue: b, alpha: a)
end;

// Create a new <color> with the given Hue/Saturation/Brightness values.
// Alpha defaults to 1.
define function make-hsb (h :: <single-float>,
                          s :: <single-float>,
                          b :: <single-float>) => (c :: <color>)
  let (r, g, bb) = hsv->rgb(h, s, b);
  make-rgb(r, g, bb)
end function;

// Create a new <color> with the given Hue/Saturation/Brightness and Alpha.
define function make-hsba (h :: <single-float>,
                           s :: <single-float>,
                           b :: <single-float>,
                           a :: <single-float>) => (c :: <color>)
  let (r, g, bb) = hsv->rgb(h, s, b);
  make-rgba(r, g, bb, a);
end function;

// Allows for defining colors like: hex-color(#xff00ff) 
// Note that it must be six hex digits - no alpha is specified (defaults
// to 1.0). (Due to limited precision of dylan <integer>.)
define inline function hex-color (c :: <integer>) => (color :: <color>)
    let r = ash(c, -16) / 255.0;
    let g = ash(logand(#x00ff00, c), -8) / 255.0;
    let b = logand(#x0000ff, c) / 255.0;
    make-rgb(r, g, b)
end;

// Convenience to make a differential copy of a <color>.
// The keywords indicate components of the original color to replace in the
// copy. Note that the RGBA components are replaced first, and then any
// of the HSB components.
define function copy-color (c :: <color>,
                            #key red:        rr = #f,
                                 green:      gg = #f,
                                 blue:       bb = #f,
                                 alpha:      aa = #f,
                                 hue:        hh = #f,
                                 saturation: ss = #f,
                                 brightness: vv = #f)
 => (new-color :: <color>)
  let r = c.red;
  let g = c.green;
  let b = c.blue;
  let a = c.alpha;

  if (rr) r := rr; end;
  if (gg) g := gg; end;
  if (bb) b := bb; end;
  if (aa) a := aa; end;

  if (hh | ss | vv) // avoid expensive hsv conversions if possible
    let (h, s, v) = rgb->hsv(r, g, b);
    if (hh) h := hh; end;
    if (ss) s := ss; end;
    if (vv) v := vv; end;

    make-hsba(h, s, v, a)
  else
    make-rgba(r, g, b, a)
  end;
end;

define sealed method make (type == <color>,
                           #key red:   r :: <single-float>,
                                green: g :: <single-float>,
                                blue:  b :: <single-float>,
                                alpha: a :: <single-float>)
 => (c :: <color>)
  next-method(type,
              red:   clamp(r, 0.0, 1.0),
              green: clamp(g, 0.0, 1.0),
              blue:  clamp(b, 0.0, 1.0),
              alpha: clamp(a, 0.0, 1.0))
end;


define sealed inline method red (c :: <color>) => (r :: <single-float>)
  c.%r
end;

define sealed inline method green (c :: <color>) => (g :: <single-float>)
  c.%g
end;

define sealed inline method blue (c :: <color>) => (b :: <single-float>)
  c.%b
end;

define sealed inline method alpha (c :: <color>) => (a :: <single-float>)
  c.%a
end;

define sealed method hue (c :: <color>) => (h :: <single-float>)
  let (h, s, v) = rgb->hsv(c.red, c.green, c.blue);
  h
end;

define sealed method saturation (c :: <color>) => (s :: <single-float>)
  let (h, s, v) = rgb->hsv(c.red, c.green, c.blue);
  s
end;

define sealed method brightness (c :: <color>) => (b :: <single-float>)
  let (h, s, v) = rgb->hsv(c.red, c.green, c.blue);
  v
end;

define inline function hsv->rgb
    (h :: <single-float>, s :: <single-float>, v :: <single-float>)
 => (r :: <single-float>, g :: <single-float>, b :: <single-float>)
  h := clamp(h, 0.0, 360.0);
  s := clamp(s, 0.0, 1.0);
  v := clamp(v, 0.0, 1.0);

  if (s = 0.0)
    // achromatic
    values(v, v, v);
  else
    h := h / 60.0;
    let c = v * s; // chroma
    let x = c * (1.0 - abs(modulo(h, 2) - 1));
    let m = v - c;
    let sector = floor(h);

    c := c + m;
    x := x + m;

    select (sector)
      0 => values(c, x, m);
      1 => values(x, c, m);
      2 => values(m, c, x);
      3 => values(m, x, c);
      4 => values(x, m, c);
      5 => values(c, m, x);
    end;
  end;
end;

define inline function rgb->hsv
    (r :: <single-float>, g :: <single-float>, b :: <single-float>)
 => (h :: <single-float>, s :: <single-float>, v :: <single-float>)
  r := clamp(r, 0.0, 1.0);
  g := clamp(g, 0.0, 1.0);
  b := clamp(b, 0.0, 1.0);

  let ma = max(r, g, b);
  let mi = min(r, g, b);
  let c = ma - mi; // chroma

  let h = 0.0;

  if (ma ~== mi)
    select (ma)
     r => h := (g - b) / c;
     g => h := (b - r) / c + 2.0;
     b => h := (r - g) / c + 4.0;
    end;

    if (h < 0.0)
      h := h + 6.0;
    end;
  end;

  let v = ma;
  let s = if (ma == mi) 0.0 else c / v end;

  values(h * 60.0, s, v)
end;

// Create a new <color> that is the same as c only brighter by the given
// amount. (But note that total brightness is clamped to 1.0.)
define function brighter (c :: <color>, #key amount :: <single-float> = .25)
 => (bright :: <color>)
  let (h, s, b) = rgb->hsv(c.red, c.green, c.blue);
  make-hsba(h, s, b + amount, c.alpha)
end;

// Create a new <color> that is the same as c only brighter by the given
// amount. (But note that total brightness is clamped to 0.0 at the bottom.)
define function darker (c :: <color>, #key amount :: <single-float> = .25)
 => (dark :: <color>)
  brighter(c, amount: -amount)
end;

// Define a few constant colors for convenience.
define constant $black   = make-rgb(0.0, 0.0, 0.0);
define constant $white   = make-rgb(1.0, 1.0, 1.0);
define constant $gray    = make-rgb(0.5, 0.5, 0.5);
define constant $red     = make-rgb(1.0, 0.0, 0.0);
define constant $green   = make-rgb(0.0, 1.0, 0.0);
define constant $blue    = make-rgb(0.0, 0.0, 1.0);
define constant $cyan    = make-rgb(0.0, 1.0, 1.0);
define constant $magenta = make-rgb(1.0, 0.0, 1.0);
define constant $yellow  = make-rgb(1.0, 1.0, 0.0);

