module: utils
author: Andrew Glynn
copyright: copyright: See LICENSE file in this distribution.

// Base class for all enum values.
define open abstract class <enum> (<object>)
  // provided for debugging purposes
  constant slot enum-value-name :: <symbol>,
    required-init-keyword: enum-value-name:;
end;

// Return a <sequence> containing all the values of the given enum
// type, in order.
// Just to be safe, don't modify the return value!
define open generic enum-values (enum-type :: <type>)
 => (all-values :: <sequence>);

define macro enum-definer
  {
    define enum ?type:name (?slots)
      ?enum-values:*
    end
  }
 =>
  {
    // Every enum type has a unique <enum> subclass for its values.
    define class ?type ## "-class" (<enum>)
      ?slots
    end;

    declare-enum-values (?type, ?enum-values);

    // The actual type of the enum.
    define constant ?type = ?type ## "-class";

    // TODO: I wanted to define the type as the union of all of the actual
    // values (that's what the macro below does), but unfortunately the
    // type union cannot be computed at compile time.
    //define constant ?type = declare-enum-type(?enum-values);

    define sealed method enum-values (e == ?type)
     => (all-values :: <sequence>)
      generate-enum-values-vector(?enum-values)
    end;
  }

slots:
  {} => {}
  {
    ?slot-name:name :: ?slot-type:expression, ...
  }
 =>
  {
    constant sealed slot ?slot-name :: ?slot-type,
      required-init-keyword: ?#"slot-name"; ...
  }
end;

// helper macros (not exported)

// Create a vector containing all values of an enum type by stripping all
// but the enum value names from the list of enum value descriptors.
define macro generate-enum-values-vector
  {
    generate-enum-values-vector (?enum-values)
  }
 =>
  {
    vector(?enum-values)
  }

enum-values:
  {} => {}
  { ?:name, #rest ?init-keywords:*; ... } => { ?name, ... }
end;

// Recursively generate declarations for all values in an enum type.
define macro declare-enum-values
  // base case
  { declare-enum-values (?enum-type:expression) } => {}

  // recursively define values
  {
    declare-enum-values (?enum-type:expression, ?enum-value;
                         ?more:*)
  }
 =>
  {
    declare-enum-value(?enum-type, ?enum-value);
    declare-enum-values(?enum-type, ?more);
  }

enum-value:
  {
    ?value-name:name, #rest ?init-keywords:*
  }
 =>
  {
    ?value-name, ?init-keywords
  }
end;

// Generate a declaration for a single enum value.
// Any init keywords provided will be passed directly to make, in
// addition to the inherited #"enum-value-name" keyword.
define macro declare-enum-value
  {
    declare-enum-value (?enum-type:expression, ?value-name:name,
                        ?init-keywords:*)
  }
 =>
  {
    define constant ?value-name :: ?enum-type ## "-class" =
      make(?enum-type ## "-class",
           enum-value-name: ?#"value-name",
           ?init-keywords);
  }
end;

/*

// Examples:

// A simple enum without extra data.
define enum <weekday> ()
  $monday;
  $tuesday;
  $wednesday;
  $thursday;
  $friday;
end;

// A more complicated enum, with associated (constant) data.
define enum <element>
    (atomic-symbol :: <string>,
     atomic-number :: <integer>,
     atomic-weight :: <single-float>)
  $hydrogen,
    atomic-symbol: "H",
    atomic-number: 1,
    atomic-weight: 1.008;
  $helium,
    atomic-symbol: "He",
    atomic-number: 2,
    atomic-weight: 4.002602;
  $lithium,
    atomic-symbol: "Li",
    atomic-number: 3,
    atomic-weight: 6.94;
  // etc.
end;

define function test ()
  for (val in enum-values(<weekday>))
    format-out("weekday: %s\n", val.enum-value-name);
  end;

  for (val in enum-values(<element>))
    format-out("element: %s, number: %d, weight: %=\n",
               val.atomic-symbol,
               val.atomic-number,
               val.atomic-weight);
  end;
end;

begin
  test();
end;

*/



