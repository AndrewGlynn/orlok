module: visual
author: Andrew Glynn
copyright: See LICENSE file in this distribution.


define class <image-source> (<object>)
  constant slot image-texture :: <texture>,
    required-init-keyword: texture:;
  constant slot auto-dispose-texture? :: <boolean>,
    required-init-keyword: auto-dispose-texture?:;
  slot reference-count :: <integer> = 1;
end;

define function add-ref (source :: <image-source>) => ()
  source.reference-count := source.reference-count + 1;
end;

define function un-ref (source :: <image-source>)
 => (texture-disposed? :: <boolean>)
  source.reference-count := source.reference-count - 1;

  debug-assert (source.reference-count >= 0);

  if (source.reference-count <= 0 & source.auto-dispose-texture?)
    dispose(source.image-texture);
    #t
  else
    #f
  end;
end;

// <image> is abstract to prevent clients from instantiating it directly.
// See <image-impl> for the real thing.
define abstract class <image> (<visual>)
  constant slot image-source :: <image-source>,
    required-init-keyword: source:;
  constant slot image-sub-rectangle :: <rect>,
    required-init-keyword: sub-rectangle:;
  // Anchor point (origin), relative to sub-rectangle.
  slot anchor-pt :: <vec2>,
    required-init-keyword: anchor-pt:;
end;

define class <image-impl> (<image>)
end;

define method dispose (img :: <image>) => ()
  next-method();
  un-ref(img.image-source);
end;

// Create a new image from an existing source.
// If sub-rectangle is not #f, the resulting <image> will only consist of the
// specified portion of the source.
// The anchor-pt keyword specifies the pixel in the image (or sub-rectangle
// of the image) that will be treated as the local origin. If align is not #f,
// the anchor-pt will be set based on the given alignment, overriding the
// passed in anchor-pt, if any.
define generic create-image-from (source-to-copy,
                                  #key sub-rectangle :: false-or(<rect>),
                                       anchor-pt :: false-or(<vec2>),
                                       align :: false-or(<alignment>))
 => (img :: <image>);

// Create a new <image> from another <image>.
// The new <image> will share the same <texture> as the old one.
define method create-image-from (img-to-copy :: <image>,
                                 #key sub-rectangle :: false-or(<rect>) = #f,
                                      anchor-pt: anchor :: false-or(<vec2>) = #f,
                                      align :: false-or(<alignment>) = #f)
 => (img :: <image>)
  add-ref(img-to-copy.image-source);
  // TODO: sub-rectangle here means a sub-rectangle of the (shared) source's
  //       texture, *not* a sub-rectangle of the copied image's sub-rectangle!
  //       Is this what we want?
  %create-image(img-to-copy.image-source,
                sub-rectangle | shallow-copy(img-to-copy.image-sub-rectangle),
                anchor | img-to-copy.anchor-pt,
                align);
end;

// Create a new <image> from a <texture>.
// The <texture> will *not* be automatically disposed when the <image> is
// disposed.
define method create-image-from (tex :: <texture>,
                                 #key sub-rectangle :: false-or(<rect>) = #f,
                                      anchor-pt :: <vec2> = vec2(0, 0),
                                      align :: false-or(<alignment>) = #f)
 => (img :: <image>)
  let source = make(<image-source>,
                  texture: tex,
                  auto-dispose-texture?: #f);

  %create-image(source, sub-rectangle | tex.bounding-rect, anchor-pt, align);
end;

// Creates a new <texture> from bmp and then creates a new <image>
// using that.
// The new <texture> will be automatically disposed when the last
// <image> referring to it is disposed.
define method create-image-from (bmp :: <bitmap>,
                                 #key sub-rectangle :: false-or(<rect>) = #f,
                                      anchor-pt :: <vec2> = vec2(0, 0),
                                      align :: false-or(<alignment>) = #f)
 => (img :: <image>)
  let source = make(<image-source>,
                  texture: create-texture-from(bmp),
                  auto-dispose-texture?: #t);

  %create-image(source, sub-rectangle | bmp.bounding-rect, anchor-pt, align);
end;

define function %create-image (source :: <image-source>,
                               sub-rect :: <rect>,
                               anchor-pt :: <vec2>,
                               align :: false-or(<alignment>))
 => (img :: <image-impl>)
  if (align)
    // derive anchor-pt from alignment (note that anchor-pt is relative to the
    // sub-rect)
    let (dx, dy) = alignment-offset(sub-rect, align);
    anchor-pt := vec2(dx - sub-rect.left, dy - sub-rect.top);
  end;

  make(<image-impl>,
       source: source,
       sub-rectangle: sub-rect,
       anchor-pt: anchor-pt)
end;

// Create an <image> from a resource image file.
// The new <image> will refer to a new <texture> that will be
// automatically disposed when the last <image> referring to it
// is disposed.
define function load-image (filename :: <string>,
                            #key sub-rectangle :: false-or(<rect>) = #f,
                                 anchor-pt: anchor :: <vec2> = vec2(0, 0))
 => (img :: <image>)
  let bmp = load-bitmap(filename);
  let img = create-image-from(bmp,
                              sub-rectangle: sub-rectangle,
                              anchor-pt: anchor);

  // The bitmap was just used to create the texture for the image.
  dispose(bmp);

  img
end;

define sealed method bounding-rect (img :: <image>)
 => (bounds :: <rect>)
  let r = img.image-sub-rectangle;

  make(<rect>,
       left: - img.anchor-pt.vx,
       right: r.width - img.anchor-pt.vx,
       top: - img.anchor-pt.vy,
       bottom: r.height - img.anchor-pt.vy)
end;

define method image-texture (img :: <image>) => (tex :: <texture>)
  img.image-source.image-texture
end;

define sealed method on-event (e :: <render-event>, img :: <image>) => ()
  next-method();

  with-saved-state (e.renderer.transform-2d)
    // TODO: handle alpha...
    draw-rect(e.renderer, img.bounding-rect,
              texture: img.image-source.image-texture,
              texture-rect: img.image-sub-rectangle);
  end;
end;

