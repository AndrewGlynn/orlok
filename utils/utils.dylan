module: utils
author: Andrew Glynn
copyright: copyright: See LICENSE file in this distribution.

define constant $no-such-key = list(#t);

define generic has-key? (coll :: <collection>, key) => (_ :: <boolean>);

define method has-key? (coll :: <collection>, key) => (_ :: <boolean>)
  element(coll, key, default: $no-such-key) ~== $no-such-key
end;

define method has-key? (seq :: <sequence>, key :: <integer>)
 => (_ :: <boolean>)
  key >= 0 & key < seq.size
end;

define macro clamp
  { clamp (?x:expression, ?min:expression, ?max:expression) }
    => { max(?min, min(?x, ?max)) }
end;


// Ugh...this doesn't work. Why doesn't debug-assert seem to work at all?
define macro if-debug
  {
    if-debug
      ?:body
    end
  }
 =>
  {
    // We piggyback on debug-assert's ability to be compiled out in
    // release builds (including "& #t" to make sure the assertion never
    // actually fails).
    // Note: We break hygiene here to ensure that debug-assert is evaluated
    // in the caller's context, and will therefore be compiled in or out
    // based on the compilation mode of the caller rather than that of the
    // library that defines this if-debug macro.
    // This implies that debug-assert must be visible in the caller's scope,
    // which should be the case if it uses common-dylan.
    // TODO: Ensure that this works, and that it is necessary.
    ?=debug-assert(begin ?body end & #t)
  }
end;

// Example:
/*
begin
  format-out("here\n");
  debug-assert(#f);
  if-debug
    format-out("we're in debug mode!\n");
  end;
  format-out("there\n");
end;
*/

