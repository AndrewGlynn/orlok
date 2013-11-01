module: dylan-user
author: Andrew Glynn
copyright: See LICENSE file in this distribution.

define library orlok-utils
  use common-dylan;
  export utils;
end;

define module utils
  use common-dylan;
  //use simple-io; // TODO: for testing only

  export
    has-key?,
    clamp,

    if-debug,

    <enum>,
    enum-value-name,
    enum-values,
    enum-definer;
end;

