module: visual
author: Andrew Glynn
copyright: See LICENSE file in this distribution.

define class <text-field> (<visual>)
  slot text-string    :: <string> = "", init-keyword: text:;
  slot text-font      :: <font>, required-init-keyword: font:;
  slot text-color     :: <color> = $black, init-keyword: color:;
  slot text-alignment :: <alignment> = $left-bottom, init-keyword: alignment:;
end;

define sealed method bounding-rect (txt :: <text-field>)
 => (bounds :: <rect>)
  let bounds = font-extents(txt.text-font, txt.text-string);
  align(txt.text-alignment, of: bounds, to: bounds.left-top);
  bounds
end;

define method on-event (e :: <render-event>, txt :: <text-field>)
 => ()
  next-method();

  draw-text(e.renderer, txt.text-string, txt.text-font,
            align: txt.text-alignment,
            color: txt.text-color);
end;
  
