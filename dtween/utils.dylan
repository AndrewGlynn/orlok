module: utils
author: Andrew Glynn
copyright: copyright: See LICENSE file in this distribution.

// A more optimizable version of:
//    reduce(reduce-fn, init, map(map-fn, seq))
define inline function map-reduce (reduce-fn :: <function>,
                                   map-fn :: <function>,
                                   init,
                                   seq :: <sequence>)
  let v = init;
  for (elem in seq)
    v := reduce-fn(v, map-fn(elem))
  end;
  v
end;

