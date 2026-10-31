# Catppuccin Mocha palette and accent helpers (pure Nix, no arguments).
# Values from nusku-arch theme/palette.conf. Licence: MIT, (c) Catppuccin
# source: https://github.com/catppuccin/palette/blob/main/palette.json@07d02aa110ef9eb7e7427afca5c73ba9cf7f8ebd
#
#   mocha                 { rosewater = "f5e0dc"; … }  hex without '#'
#   accents               the 14 accent names
#   accentHex name        hex of an accent (or any palette colour)
#   rgb hex               "r, g, b"
#   papirusFolder accent  Papirus folder colour closest to the accent (nusku-arch lib/system.sh)
#   render accent text    nusku-arch template syntax: {{name}} hex, {{name_rgb}} "r, g, b",
#                         {{accent}} / {{accent_rgb}}, {{accent_name}}; an unknown {{x}} throws.
#   renderFile accent path
let
  mocha = {
    rosewater = "f5e0dc";
    flamingo = "f2cdcd";
    pink = "f5c2e7";
    mauve = "cba6f7";
    red = "f38ba8";
    maroon = "eba0ac";
    peach = "fab387";
    yellow = "f9e2af";
    green = "a6e3a1";
    teal = "94e2d5";
    sky = "89dceb";
    sapphire = "74c7ec";
    blue = "89b4fa";
    lavender = "b4befe";
    text = "cdd6f4";
    subtext1 = "bac2de";
    subtext0 = "a6adc8";
    overlay2 = "9399b2";
    overlay1 = "7f849c";
    overlay0 = "6c7086";
    surface2 = "585b70";
    surface1 = "45475a";
    surface0 = "313244";
    base = "1e1e2e";
    mantle = "181825";
    crust = "11111b";
  };

  accents = [
    "rosewater" "flamingo" "pink" "mauve" "red" "maroon" "peach"
    "yellow" "green" "teal" "sky" "sapphire" "blue" "lavender"
  ];

  accentHex = name:
    mocha.${name} or (throw "palette: unknown colour \"${name}\"");

  hexDigits = {
    "0" = 0; "1" = 1; "2" = 2; "3" = 3; "4" = 4; "5" = 5; "6" = 6; "7" = 7; "8" = 8; "9" = 9;
    a = 10; b = 11; c = 12; d = 13; e = 14; f = 15;
  };
  byte = hex: i:
    hexDigits.${builtins.substring i 1 hex} * 16 + hexDigits.${builtins.substring (i + 1) 1 hex};
  rgb = hex: "${toString (byte hex 0)}, ${toString (byte hex 2)}, ${toString (byte hex 4)}";

  papirusFolders = {
    rosewater = "paleorange";
    flamingo = "pink";
    pink = "magenta";
    mauve = "violet";
    red = "red";
    maroon = "red";
    peach = "orange";
    yellow = "yellow";
    green = "green";
    teal = "teal";
    sky = "cyan";
    lavender = "indigo";
    sapphire = "blue";
    blue = "blue";
  };
  papirusFolder = accent: papirusFolders.${accent};

  render = accent: text:
    let
      colours = mocha // { accent = accentHex accent; };
      names = builtins.attrNames colours;
      from = map (n: "{{${n}}}") names ++ map (n: "{{${n}_rgb}}") names ++ [ "{{accent_name}}" ];
      to = map (n: colours.${n}) names ++ map (n: rgb colours.${n}) names ++ [ accent ];
      out = builtins.replaceStrings from to text;
      # builtins.split puts each match in a list; no lists means no placeholder is left.
      left = builtins.filter builtins.isList (builtins.split "(\\{\\{[A-Za-z0-9_]+}})" out);
    in
    if !(builtins.elem accent accents) then throw "palette: unknown accent \"${accent}\""
    else if left != [ ] then throw "palette: unknown placeholder ${builtins.head (builtins.head left)}"
    else out;

  renderFile = accent: path: render accent (builtins.readFile path);
in
{
  inherit mocha accents accentHex rgb papirusFolder render renderFile;
}
