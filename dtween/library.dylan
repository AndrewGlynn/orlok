module: dylan-user
author: Andrew Glynn
copyright: See LICENSE file in this distribution.

define library dtween
  use common-dylan;

  export
    easing,
    interpolation,
    dtween;
end;

define module utils
  use common-dylan;

  export
    map-reduce;
end;

define module easing
  use common-dylan;
  use transcendentals;

  export
    ease-linear,
    ease-snap-in, ease-snap-out,
    ease-in-quad, ease-out-quad, ease-in-out-quad,
    ease-in-cubic, ease-out-cubic, ease-in-out-cubic,
    ease-in-quartic, ease-out-quartic, ease-in-out-quartic,
    ease-in-quintic, ease-out-quintic, ease-in-out-quintic,
    ease-in-sine, ease-out-sine, ease-in-out-sine;
end;

define module interpolation
  use common-dylan;

  export
    interpolate;
end;

define module tween
  use common-dylan;
  use easing;

  export
    <tween>,
    duration,
    paused?, paused?-setter,
    expired?,
    start-tween,
    finish-tween,
    update-tween,
    on-start, on-start-setter,
    on-finish, on-finish-setter,
    start-delay, start-delay-setter,
    time-scale, time-scale-setter;
end;

define module tween-base
  use common-dylan;
  use tween;

  export
    <tween-base>,
    local-duration, local-duration-setter,
    current-time;
end;

define module tween-group
  use common-dylan;
  use utils;
  use tween;

  export
    <tween-group>,
    add-tween-to-group,
    remove-tween-from-group,
    clear-tween-group,
    update-tween-group,
    remove-expired-tweens?, remove-expired-tweens?-setter;
end;

define module basic-tweens
  use common-dylan;
  use easing;
  use interpolation;
  use tween;
  use tween-base;
  use tween-group;

  export
    <object-tween>,
    <expression-tween>;
end;

define module multi-tween
  use common-dylan;
  use utils;
  use tween;
  use tween-base;
  use tween-group, import: { add-tween-to-group };
  use basic-tweens, import: { action, pause-for };

  export
    <multi-tween>,
    add-tween,
    compute-duration;
end;

define module macros
  use common-dylan;
  use easing;
  use tween;
  use basic-tweens;
  use multi-tween;
  use tween-group;

  export
    tween-to,
    tween-object-to,
    pause-for,
    action,
//    tween-from,
    sequentially,
    concurrently,
    delay;
end;

define module dtween
  use common-dylan;

  use easing, export: all;
  use interpolation, export: all;
  use tween, export: all;
  use tween-group, export: all;
  use macros, export: all;
end;


