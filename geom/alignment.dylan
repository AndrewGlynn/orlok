module: alignment
author: Andrew Glynn
copyright: See LICENSE file in this distribution.

// 2D alignment (horizontal and vertical).
define class <alignment> (<object>)
  // 0=left, .5=center, 1=right, etc.
  constant slot h-align-amount :: <single-float>,
    required-init-keyword: h-align:;
  // 0=top, .5=center, 1=bottom, etc.
  constant slot v-align-amount :: <single-float>,
    required-init-keyword: v-align:;
end;

define constant $left-top      = make(<alignment>, h-align: 0.0, v-align: 0.0);
define constant $left-bottom   = make(<alignment>, h-align: 0.0, v-align: 1.0);
define constant $left-center   = make(<alignment>, h-align: 0.0, v-align: 0.5);
define constant $right-top     = make(<alignment>, h-align: 1.0, v-align: 0.0);
define constant $right-bottom  = make(<alignment>, h-align: 1.0, v-align: 1.0);
define constant $right-center  = make(<alignment>, h-align: 1.0, v-align: 0.5);
define constant $center-top    = make(<alignment>, h-align: 0.5, v-align: 0.0);
define constant $center-bottom = make(<alignment>, h-align: 0.5, v-align: 1.0);
define constant $center        = make(<alignment>, h-align: 0.5, v-align: 0.5);

// Horizontal alignment only.
define class <h-alignment> (<object>)
  constant slot h-align-amount :: <single-float>,
    required-init-keyword: h-align:;
end;

define constant $left     = make(<h-alignment>, h-align: 0.0);
define constant $right    = make(<h-alignment>, h-align: 1.0);
define constant $h-center = make(<h-alignment>, h-align: 0.5);

// Vertical alignment only.
define class <v-alignment> (<object>)
  constant slot v-align-amount :: <single-float>,
    required-init-keyword: v-align:;
end;

define constant $top      = make(<v-alignment>, v-align: 0.0);
define constant $bottom   = make(<v-alignment>, v-align: 1.0);
define constant $v-center = make(<v-alignment>, v-align: 0.5);


// Move an object such that it's point specified by alignment coincides with
// another point. Eg: align($left-top, of: my-object, to: rect.right-bottom).
define function align (alignment :: <alignment>,
                       #key of :: <object>,
                            to :: <vec2>) => ()
  align-object(of, alignment.h-align-amount, alignment.v-align-amount, to);
end;

// Move an object horizontally such that it's x-coordinate specified by
// alignment is equal to a specified value.
define function h-align (alignment :: <h-alignment>,
		         #key of :: <object>,
                  to :: <real>) => ()
  align-object(of, alignment.h-align-amount, #f, vec2(to, 0.0));
end;

// Move an object vertically such that it's y-coordinate specified by
// alignment is equal to a specified value.
define function v-align (alignment :: <v-alignment>,
		         #key of :: <object>,
                  to :: <real>) => ()
  align-object(of, #f, alignment.v-align-amount, vec2(0.0, to));
end;

// Return x and y values indicating the offset from object's origin to
// the given alignment point on that same object.
define generic alignment-offset (object, alignment)
 => (x-offset :: <single-float>, y-offset :: <single-float>);

define method alignment-offset (object, align :: <alignment>)
 => (x-offset :: <single-float>, y-offset :: <single-float>)
  object-alignment-offset(object, align.h-align-amount, align.v-align-amount)
end;

define method alignment-offset (object, align :: <h-alignment>)
 => (x-offset :: <single-float>, y-offset :: <single-float>)
  object-alignment-offset(object, align.h-align-amount, 0.0)
end;

define method alignment-offset (object, align :: <v-alignment>)
 => (x-offset :: <single-float>, y-offset :: <single-float>)
  object-alignment-offset(object, 0.0, align.v-align-amount)
end;


// Move object such that its point h-align-amount along its width and
// v-align-amount down its height is aligned with the point align-to.
// If h-align-amount is #f, only move object vertically (i.e., only v-align).
// If v-align-amount is #f, only move object horizontally (i.e., only h-align).
// Note that this generic is mainly for implementers of methods. Clients will
// generally use the ‘align’ function, which is simpler and nicer looking, and
// calls align-object internally.
define open generic align-object (object,
                                  h-align-amount :: false-or(<single-float>),
                                  v-align-amount :: false-or(<single-float>),
                                  align-to :: <vec2>) => ();

// Called by alignment-offset.
// Clients should generally use alignment-offset. This generic is
// for types that wish to support the alignment-offset API.
define open generic object-alignment-offset (object,
                                             h-align-amount :: <single-float>,
                                             v-align-amoutn :: <single-float>)
 => (x-offset :: <single-float>, y-offset :: <single-float>);

