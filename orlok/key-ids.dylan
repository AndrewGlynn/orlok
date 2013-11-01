module: key-ids
author: Andrew Glynn
copyright: copyright: See LICENSE file in this distribution.

// definitions (and names) from Cinder

define constant $key-unknown :: <integer> = 0;
define constant $key-first :: <integer> = 0;
define constant $key-backspace :: <integer> = 8;
define constant $key-tab :: <integer> = 9;

define constant $key-clear :: <integer> = 12;
define constant $key-return :: <integer> = 13;
define constant $key-pause :: <integer> = 19;
define constant $key-escape :: <integer> = 27;

define constant $key-space :: <integer> = 32;
define constant $key-exclaim :: <integer> = 33;
define constant $key-quotedbl :: <integer> = 34;
define constant $key-hash :: <integer> = 35;

define constant $key-dollar :: <integer> = 36;
define constant $key-ampersand :: <integer> = 38;
define constant $key-quote :: <integer> = 39;
define constant $key-leftparen :: <integer> = 40;

define constant $key-rightparen :: <integer> = 41;
define constant $key-asterisk :: <integer> = 42;
define constant $key-plus :: <integer> = 43;
define constant $key-comma :: <integer> = 44;

define constant $key-minus :: <integer> = 45;
define constant $key-period :: <integer> = 46;
define constant $key-slash :: <integer> = 47;
define constant $key-0 :: <integer> = 48;

define constant $key-1 :: <integer> = 49;
define constant $key-2 :: <integer> = 50;
define constant $key-3 :: <integer> = 51;
define constant $key-4 :: <integer> = 52;

define constant $key-5 :: <integer> = 53;
define constant $key-6 :: <integer> = 54;
define constant $key-7 :: <integer> = 55;
define constant $key-8 :: <integer> = 56;

define constant $key-9 :: <integer> = 57;
define constant $key-colon :: <integer> = 58;
define constant $key-semicolon :: <integer> = 59;
define constant $key-less :: <integer> = 60;

define constant $key-equals :: <integer> = 61;
define constant $key-greater :: <integer> = 62;
define constant $key-question :: <integer> = 63;
define constant $key-at :: <integer> = 64;

define constant $key-leftbracket :: <integer> = 91;
define constant $key-backslash :: <integer> = 92;
define constant $key-rightbracket :: <integer> = 93;
define constant $key-caret :: <integer> = 94;

define constant $key-underscore :: <integer> = 95;
define constant $key-backquote :: <integer> = 96;
define constant $key-a :: <integer> = 97;
define constant $key-b :: <integer> = 98;

define constant $key-c :: <integer> = 99;
define constant $key-d :: <integer> = 100;
define constant $key-e :: <integer> = 101;
define constant $key-f :: <integer> = 102;

define constant $key-g :: <integer> = 103;
define constant $key-h :: <integer> = 104;
define constant $key-i :: <integer> = 105;
define constant $key-j :: <integer> = 106;

define constant $key-k :: <integer> = 107;
define constant $key-l :: <integer> = 108;
define constant $key-m :: <integer> = 109;
define constant $key-n :: <integer> = 110;

define constant $key-o :: <integer> = 111;
define constant $key-p :: <integer> = 112;
define constant $key-q :: <integer> = 113;
define constant $key-r :: <integer> = 114;

define constant $key-s :: <integer> = 115;
define constant $key-t :: <integer> = 116;
define constant $key-u :: <integer> = 117;
define constant $key-v :: <integer> = 118;

define constant $key-w :: <integer> = 119;
define constant $key-x :: <integer> = 120;
define constant $key-y :: <integer> = 121;
define constant $key-z :: <integer> = 122;

define constant $key-delete :: <integer> = 127;
define constant $key-kp0 :: <integer> = 256;
define constant $key-kp1 :: <integer> = 257;
define constant $key-kp2 :: <integer> = 258;

define constant $key-kp3 :: <integer> = 259;
define constant $key-kp4 :: <integer> = 260;
define constant $key-kp5 :: <integer> = 261;
define constant $key-kp6 :: <integer> = 262;

define constant $key-kp7 :: <integer> = 263;
define constant $key-kp8 :: <integer> = 264;
define constant $key-kp9 :: <integer> = 265;
define constant $key-kp-period :: <integer> = 266;

define constant $key-kp-divide :: <integer> = 267;
define constant $key-kp-multiply :: <integer> = 268;
define constant $key-kp-minus :: <integer> = 269;
define constant $key-kp-plus :: <integer> = 270;

define constant $key-kp-enter :: <integer> = 271;
define constant $key-kp-equals :: <integer> = 272;
define constant $key-up :: <integer> = 273;
define constant $key-down :: <integer> = 274;

define constant $key-right :: <integer> = 275;
define constant $key-left :: <integer> = 276;
define constant $key-insert :: <integer> = 277;
define constant $key-home :: <integer> = 278;

define constant $key-end :: <integer> = 279;
define constant $key-pageup :: <integer> = 280;
define constant $key-pagedown :: <integer> = 281;
define constant $key-f1 :: <integer> = 282;

define constant $key-f2 :: <integer> = 283;
define constant $key-f3 :: <integer> = 284;
define constant $key-f4 :: <integer> = 285;
define constant $key-f5 :: <integer> = 286;

define constant $key-f6 :: <integer> = 287;
define constant $key-f7 :: <integer> = 288;
define constant $key-f8 :: <integer> = 289;
define constant $key-f9 :: <integer> = 290;

define constant $key-f10 :: <integer> = 291;
define constant $key-f11 :: <integer> = 292;
define constant $key-f12 :: <integer> = 293;
define constant $key-f13 :: <integer> = 294;

define constant $key-f14 :: <integer> = 295;
define constant $key-f15 :: <integer> = 296;
define constant $key-numlock :: <integer> = 300;
define constant $key-capslock :: <integer> = 301;

define constant $key-scrollock :: <integer> = 302;
define constant $key-rshift :: <integer> = 303;
define constant $key-lshift :: <integer> = 304;
define constant $key-rctrl :: <integer> = 305;

define constant $key-lctrl :: <integer> = 306;
define constant $key-ralt :: <integer> = 307;
define constant $key-lalt :: <integer> = 308;
define constant $key-rmeta :: <integer> = 309;

define constant $key-lmeta :: <integer> = 310;
define constant $key-lsuper :: <integer> = 311;
define constant $key-rsuper :: <integer> = 312;
define constant $key-mode :: <integer> = 313;

define constant $key-compose :: <integer> = 314;
define constant $key-help :: <integer> = 315;
define constant $key-print :: <integer> = 316;
define constant $key-sysreq :: <integer> = 317;

define constant $key-break :: <integer> = 318;
define constant $key-menu :: <integer> = 319;
define constant $key-power :: <integer> = 320;
define constant $key-euro :: <integer> = 321;

define constant $key-undo :: <integer> = 322;
