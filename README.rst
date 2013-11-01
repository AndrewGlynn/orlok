Orlok
=====

A simple game library for Dylan.

Disclaimer
----------

Orlok is buggy. Orlok is inefficient. Orlok only works on Mac OS X
(10.7.5 - I'm not sure about other versions). Caveat emptor.

Setup
-----

You'll need to download libcinder from:
  http://libcinder.org/releases/cinder_0.8.4_mac.zip

Extract into orlok/backend/cinder (this should create a cinder_0.8.4_mac
directory under orlok/backend/cinder).

Building
--------
You should just be able to run 'make' from the top-level orlok directory.

Note that the orlok_cinder_backend library compiles for me with llvm-g++ 4.2.
Hopefully it works ok with other compilers, too.

Running the Examples
--------------------
To run the simple-app example, just run:

    ``open examples/simple-app/simple-app.app``

(Or double-click that file from a Finder window.)

Other examples work analogously.

Creating your own Orlok App
---------------------------
The easiest method is probably to start by copying an existing app (the
simple-app example is provided largely for this purpose).

The app bundle structure is created manually. I haven't actually bothered to
learn much about this format, so I have just thrown together enough stuff to
make it work. In particular, note that required libraries and executable must
be copied into the bundle (see the top-level Makefile for examples).

Structure
---------

orlok-utils
...........
Just a handful of useful macros and functions.
The ``enum-definer`` macro in particular is used throughout orlok.

geom
....
Basic geometry classes and functions (2D only for now). Includes the
ubiquitous ``<vec2>`` (used for points as well as vectors) and axis-aligned
``<rect>`` classes, as well as ``<affine-transform-2d>`` for constructing
more complicated transformations.

dtween
......
A simple "tweening" library inspired by Grant Skinner's gtween
(http://www.gskinner.com/libraries/gtween/), and with similarities to other
tween libraries such as TweenLite/Max and Actuate.

Tween arbitrary numeric values using a variety of easing functions, construct
complicated animations using a handful of combinator macros and functions such
as ``sequentially``, ``concurrently``, ``pause-for``, and ``action``.

orlok
.....
The main library itself. Discussed below.

examples
........
Contains a couple of example applications.


Concepts
--------

Apps
....

Every orlok application must define a subclass of ``<app>``. This class is then
instantiated (passing in an ``<app-config>`` describing basic configuration
info like window size and so on).

Passing this instance to ``run-app`` will open a window (or go into full-screen
mode, as specified by the ``<app-config>``) and then begin the main game loop.
It will not return until the app has completed.

Before the first loop iteration, a ``<startup-event>`` will be sent to the
``<app>``. Loading of resources such as images and sounds should not be done
before this event is received, since the subsystems responsible for loading
them may not be initialized.

During each iteration of the game loop, orlok will send a series of ``<event>``
objects to the ``<app>`` instance via the ``on-event`` generic function.
First, it will send zero or more ``<input-event>`` in response to user input.
Next, it sends an ``<update-event>``. Finally, it will send a ``<render-event>``.

Finally, a ``<shutdown-event>`` will be sent after the final game loop
iteration.

It is assumed that apps will perform essential game simulation in response to
the ``<update-event>``, and will render itself in response to the
``<render-event>``.


Audio
.....

Orlok currently provides limited audio functionality. A single <music>
track can be played (with optional looping), and multiple <sound>s may be
triggered. Only wav and mp3 formats seem to work at the moment (and not all
variations of those formats, either).

Master volume and music volume may be modified independently, but there is
presently no control over the volume of individual <sound> instances (nor
control for pan, frequency changes, etc).

Bitmaps and Textures
....................

The ``<bitmap>`` class represents 2-dimensional arrays of colored pixels that
may be created or loaded from image files. Current support for modifying
bitmaps is only through the ``vector-graphics`` module. I hope to add a
pixel-based API when I figure out how to do that efficiently.

Because orlok uses OpenGL for rendering, a ``<bitmap>`` cannot be rendered
directly. Instead, you must create a ``<texture>`` from a ``<bitmap>`` first.
See below on "Rendering" for more details. For our purposes, a ``<texture>``
is essentially just a copy of a ``<bitmap>`` that has been made available to
the video card.

Orlok also supports a ``<texture>`` subclass, ``<render-texture>``, that can be
used for render-to-texture effects.

Fonts
.....

Orlok can load and render text using TrueType and OpenType fonts.

Rendering
.........

The rendering API is currently quite minimal, consisting of just four
functions:

* ``clear`` - Clear the display to a single color.
* ``draw-line`` - Draw line segment with a specified color and width.
* ``draw-rect`` - Draw an axis-aligned rectangle.
* ``draw-text`` - Draw text with in a specified font.

However, ``draw-rect`` can specify a color, or a ``<texture>`` to use, as well
as an optional custom ``<shader>``. Thus ``draw-rect`` is used for drawing
images in addition to plain rectangles.

Each of the rendering functions also takes a ``<renderer>`` as an argument.
This object is attached to the ``<render-event>`` via the ``renderer`` slot.

The ``<renderer>`` contains additional state affecting rendering. Rendering
output can be translated, scaled, and rotated via the ``transform-2d`` slot;
textures and shaders can be set; blend modes chosen; etc.


Vector Graphics
...............

In addition to its basic rendering API, orlok supports drawing scalable
vector graphics directly to a ``<bitmap>`` (which can then be turned into 
a ``<texture>`` and drawn to the display).

The vector graphics API includes standard features like gradients, variable
width strokes with join and cap styles, complex curved paths, and font
rendering.


Disposing
.........

One idiosyncrasy worth mentioning in this brief introduction is the mechanism
for the disposal of resources.

While the Dylan language uses garbage collection to handle memory deallocation,
orlok requires manual deallocation for a number of its classes, for reasons
largely pragmatic but partly philosophical (namely, I think finalizers are
evil).

To this end, orlok includes the ``dispose`` generic function. Resources of
types such as ``<bitmap>``, ``<texture>``, ``<sound>``, and so on, will not
be freed until and unless dispose is called on them.

As with memory-unsafe languages such as C, the effects of interacting with an
object after it has been disposed are undefined. (Probably the program will
crash, if you're lucky.) Similar warnings apply to attempting to dispose an
object more than once.

As a convenience, the ``dispose-on-shutdown`` function is provided. Register
disposable objects with this function to ensure they are properly disposed
when the app shuts down. But note that you must *not* manually dispose any
such registered objects before shutdown without first un-registering them
via ``remove-from-dispose-on-shutdown``.


Visuals
-------

Although not an intrinsic part of orlok, a simple 2D scene graph module is
provided as a convenience.

Modeled somewhat after Flash's DisplayObject system (for better or worse),
this module is based on a tree of ``<visual>`` objects. [Question: Any better
ideas for a name?]

* ``<visual>`` - Defines 2D transform, some flags (for visibility, etc.) and
  other basic features.

  * ``<group-visual>`` - Base class of <visual>s with children.

    * ``<root-visual>`` - The root of a scene graph.

    * ``<box>`` - Displays a colored rectangle before rendering children.

  * ``<image>`` - Displays an image (created from a ``<texture>``,
    ``<bitmap>``, or image file.

  * ``<text-field>`` - Display a line of text.

In addition, ``<visual>`` supports a few extra event types (
``<mouse-in-event>``, ``<mouse-out-event>``, ``<pre-render-event>``,
``<post-render-event>``), and a system for attaching ``<behavior>`` objects
to customize the ``<visual>`` without needing to subclass. Event listeners,
buttons, dragging, tooltips, and more are provided via standard behavior
classes.

