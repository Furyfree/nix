# Every shortcut in System Settings → Keyboard → Keyboard Shortcuts on macOS
# 27.0.1, off so none takes keys that Tinycast or another app needs. Caps Lock's
# Hyper (⌃⌥⌘) turns Mission Control and Switch to Desktop 1–9 back on, since
# Tinycast cannot switch Spaces by number. Each switch writes the whole list, so
# change shortcuts here, not in System Settings.
{ lib, ... }:

let
  # ID, the keys as macOS stores them (character, key code and modifier flags,
  # 65535 for none), then the name with its default keys on a Danish keyboard;
  # 🌐 is the Globe key. Off entries keep Apple's keys, so turning one back on
  # in System Settings restores them.
  table = ''
    # Dock
     52   100     2 1572864  Turn Dock hiding on/off (⌥⌘D)
    # Display
     53 65535   107       0  Decrease display brightness (F14)
     55 65535   107  524288  Open Displays settings (⌥F14)
     54 65535   113       0  Increase display brightness (F15)
     56 65535   113  524288  Open Displays settings (⌥F15)
    # Mission Control
     32 65535   126  262144  Mission Control (⌃↑)
     34 65535   126  393216  Mission Control, slowly (⌃⇧↑)
    163 65535 65535       0  Show Notification Center
    175 65535 65535       0  Turn Do Not Disturb on/off
     33 65535   125  262144  Application windows (⌃↓)
     35 65535   125  393216  Application windows, slowly (⌃⇧↓)
     36 65535   103       0  Show Desktop (F11)
     37 65535   103  131072  Show Desktop, slowly (⇧F11)
    222 65535 65535       0  Turn Stage Manager on/off
     79 65535   123  262144  Move left a Space (⌃←)
     80 65535   123  393216  Move left a Space, slowly (⌃⇧←)
     81 65535   124  262144  Move right a Space (⌃→)
     82 65535   124  393216  Move right a Space, slowly (⌃⇧→)
    190   113    12 8388608  Quick Note (🌐Q)
    260 65535    53 1048576  Game Overlay (⌘Esc)
    118 65535    18  262144  Switch to Desktop 1 (⌃1)
    119 65535    19  262144  Switch to Desktop 2 (⌃2)
    120 65535    20  262144  Switch to Desktop 3 (⌃3)
    121 65535    21  262144  Switch to Desktop 4 (⌃4)
    122 65535    23  262144  Switch to Desktop 5 (⌃5)
    123 65535    22  262144  Switch to Desktop 6 (⌃6)
    124 65535    26  262144  Switch to Desktop 7 (⌃7)
    125 65535    28  262144  Switch to Desktop 8 (⌃8)
    126 65535    25  262144  Switch to Desktop 9 (⌃9)
    127 65535    29  262144  Switch to Desktop 10 (⌃0)
    128 65535    18  786432  Switch to Desktop 11 (⌃⌥1)
    129 65535    19  786432  Switch to Desktop 12 (⌃⌥2)
    130 65535    20  786432  Switch to Desktop 13 (⌃⌥3)
    131 65535    21  786432  Switch to Desktop 14 (⌃⌥4)
    132 65535    23  786432  Switch to Desktop 15 (⌃⌥5)
    133 65535    22  786432  Switch to Desktop 16 (⌃⌥6)
    # Windows
    233   109    46 1048576  Minimize (⌘M)
    235 65535 65535       0  Zoom
    237   102     3 8650752  Fill (🌐⌃F)
    238    99     8 8650752  Center (🌐⌃C)
    239   114    15 8650752  Return to Previous Size (🌐⌃R)
    240 65535   123 8650752  Tile Left Half (🌐⌃←)
    241 65535   124 8650752  Tile Right Half (🌐⌃→)
    242 65535   126 8650752  Tile Top Half (🌐⌃↑)
    243 65535   125 8650752  Tile Bottom Half (🌐⌃↓)
    244 65535 65535       0  Tile Top Left Quarter
    245 65535 65535       0  Tile Top Right Quarter
    246 65535 65535       0  Tile Bottom Left Quarter
    247 65535 65535       0  Tile Bottom Right Quarter
    248 65535   123 8781824  Arrange Left and Right (🌐⌃⇧←)
    249 65535   124 8781824  Arrange Right and Left (🌐⌃⇧→)
    250 65535   126 8781824  Arrange Top and Bottom (🌐⌃⇧↑)
    251 65535   125 8781824  Arrange Bottom and Top (🌐⌃⇧↓)
    256 65535 65535       0  Arrange in Quarters
    257 65535 65535       0  Full Screen Tile Left
    258 65535 65535       0  Full Screen Tile Right
    # Keyboard
     13 65535    98  262144  Change the way Tab moves focus (⌃F7)
     12 65535   122  262144  Turn keyboard access on or off (⌃F1)
      7 65535   120  262144  Move focus to the menu bar (⌃F2)
      8 65535    99  262144  Move focus to the Dock (⌃F3)
      9 65535   118  262144  Move focus to active or next window (⌃F4)
     10 65535    96  262144  Move focus to the window toolbar (⌃F5)
     11 65535    97  262144  Move focus to the floating window (⌃F6)
     27    96    50 1048576  Move focus to next window (⌘<)
     57 65535   100  262144  Move focus to status menus (⌃F8)
    159 65535    36  262144  Show contextual menu (⌃Return)
    156 65535    49  393216  Show/Hide Trackpad Handwriting (⌃⇧Space)
    # Input Sources
     60    32    49  262144  Select the previous input source (⌃Space)
     61    32    49  786432  Select next source in Input menu (⌃⌥Space)
    # Screenshots
     28    51    20 1179648  Save picture of screen as a file (⇧⌘3)
     29    51    20 1441792  Copy picture of screen to the clipboard (⌃⇧⌘3)
     30    52    21 1179648  Save picture of selected area as a file (⇧⌘4)
     31    52    21 1441792  Copy picture of selected area to the clipboard (⌃⇧⌘4)
    184    53    23 1179648  Screenshot and recording options (⇧⌘5)
    261    54    22 1179648  Ask Siri about selected area (⇧⌘6)
    263    32    49 1179648  Ask Siri about active window (⇧⌘Space)
    181    55    26 1179648  Save picture of the Touch Bar as a file (⇧⌘7)
    182    55    26 1441792  Copy picture of the Touch Bar to the clipboard (⌃⇧⌘7)
    # Presenter Overlay
    224 65535 65535       0  Turn Presenter Overlay (small) on or off
    223 65535 65535       0  Turn Presenter Overlay (large) on or off
    # Spotlight
     64    32    49 1048576  Show Spotlight search (⌘Space)
     65    32    49 1572864  Show Finder search window (⌥⌘Space)
    160 65535 65535       0  Show Apps
    # Accessibility
     25    46    47 1835008  Increase contrast (⌃⌥⌘.)
     26    44    43 1835008  Decrease contrast (⌃⌥⌘,)
     21    56    28 1835008  Invert colors (⌃⌥⌘8)
    215 65535 65535       0  Turn Live Captions on or off
    217 65535 65535       0  Turn type to speak on or off
    219 65535 65535       0  Turn keep onscreen on or off
    218 65535 65535       0  Switch between transcribing computer audio and microphone
    216 65535 65535       0  Pause or resume transcription
    225 65535 65535       0  Turn Live Speech on or off
    226 65535 65535       0  Toggle visibility
    227 65535 65535       0  Pause or resume speech
    228 65535 65535       0  Cancel speech
    229 65535 65535       0  Hide or show phrases
    162 65535    96 1572864  Show Accessibility controls (⌥⌘F5)
    231 65535 65535       0  Turn speak item under the pointer on or off
    230 65535 65535       0  Turn speak selection on or off
    232 65535 65535       0  Turn typing feedback on or off
     59 65535    96 1048576  Turn VoiceOver on or off (⌘F5)
     15    56    28 1572864  Turn zoom on or off (⌥⌘8)
     23    92 65535 1572864  Turn image smoothing on or off (⌥⌘\\)
     19    45    27 1572864  Zoom out (⌥⌘+)
     17    61    24 1572864  Zoom in (⌥⌘´)
    179 65535 65535       0  Turn focus following on or off
    # App Shortcuts
     98    47    44 1179648  Show Help menu (⇧⌘-)
  '';

  # Key codes on Hyper: M for Mission Control, 1–9 for Desktops 1–9.
  hyper = {
    "32" = 46;
    "118" = 18;
    "119" = 19;
    "120" = 20;
    "121" = 21;
    "122" = 23;
    "123" = 22;
    "124" = 26;
    "125" = 28;
    "126" = 25;
  };
  hyperFlags = 1835008;

  shortcut =
    line:
    let
      fields = map lib.toInt (builtins.match " *([0-9]+) +([0-9]+) +([0-9]+) +([0-9]+) .*" line);
      id = toString (builtins.head fields);
      keyCode = hyper.${id} or null;
    in
    lib.nameValuePair id {
      enabled = keyCode != null;
      value = {
        parameters =
          if keyCode == null then
            builtins.tail fields
          else
            [
              65535
              keyCode
              hyperFlags
            ];
        type = "standard";
      };
    };
in
{
  system.defaults.CustomUserPreferences."com.apple.symbolichotkeys".AppleSymbolicHotKeys =
    lib.listToAttrs
      (
        map shortcut (
          builtins.filter (line: builtins.match " *[0-9].*" line != null) (lib.splitString "\n" table)
        )
      );
}
