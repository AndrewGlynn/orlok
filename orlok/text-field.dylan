module: visual
author: Andrew Glynn
copyright: See LICENSE file in this distribution.

define class <text-field> (<visual>)
  slot text-string    :: <string> = "", init-keyword: text:;
  slot text-font      :: <font>, required-init-keyword: font:;
  slot text-color     :: <color> = $black, init-keyword: color:;
  slot text-alignment :: <alignment> = $left-bottom, init-keyword: align:;
end;

define sealed method bounding-rect (txt :: <text-field>)
 => (bounds :: <rect>)
  let bounds = font-extents(txt.text-font, txt.text-string);

  // trim off area to left and below text reference point
  let clipped-bounds = shallow-copy(bounds);
  clipped-bounds.left   := 0.0;
  clipped-bounds.bottom := 0.0;
  let (dx, dy) = alignment-offset(clipped-bounds, txt.text-alignment);

  move-rect(bounds, vec2(-dx, -dy));

  bounds
end;

define method on-event (e :: <render-event>, txt :: <text-field>)
 => ()
  next-method();

  draw-text(e.renderer, txt.text-string, txt.text-font,
            align: txt.text-alignment,
            color: txt.text-color);
end;
  
