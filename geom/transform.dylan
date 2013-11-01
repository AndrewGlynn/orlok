module: transform
author: Andrew Glynn
copyright: copyright: See LICENSE file in this distribution.

define open generic identity? (transform) => (id? :: <boolean>);

// The assumption is that these functions will mutate obj.
define open generic translate! (obj, translation) => (obj);
define open generic rotate!    (obj, rotation)    => (obj);
define open generic scale!     (obj, scale)       => (obj);
define open generic shear!     (obj, shear)       => (obj);
