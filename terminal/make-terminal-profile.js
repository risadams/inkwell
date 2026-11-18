// Builds a macOS Terminal.app profile (.terminal) from one scheme in schemes.json.
// Runs with the JavaScript-for-Automation runtime that ships with macOS, so it needs
// nothing installed:
//
//   osascript -l JavaScript make-terminal-profile.js schemes.json "Ink Parchment" out.terminal
//
// Colours are archived by AppKit itself as sRGB, so they match Windows Terminal exactly.

// Scheme key (Windows Terminal naming) -> Terminal.app profile key(s).
var COLOR_KEYS = {
  background: ['BackgroundColor'],
  foreground: ['TextColor', 'TextBoldColor'],
  cursorColor: ['CursorColor'],
  selectionBackground: ['SelectionColor'],
  black: ['ANSIBlackColor'],
  red: ['ANSIRedColor'],
  green: ['ANSIGreenColor'],
  yellow: ['ANSIYellowColor'],
  blue: ['ANSIBlueColor'],
  purple: ['ANSIMagentaColor'],
  cyan: ['ANSICyanColor'],
  white: ['ANSIWhiteColor'],
  brightBlack: ['ANSIBrightBlackColor'],
  brightRed: ['ANSIBrightRedColor'],
  brightGreen: ['ANSIBrightGreenColor'],
  brightYellow: ['ANSIBrightYellowColor'],
  brightBlue: ['ANSIBrightBlueColor'],
  brightPurple: ['ANSIBrightMagentaColor'],
  brightCyan: ['ANSIBrightCyanColor'],
  brightWhite: ['ANSIBrightWhiteColor']
};

// First installed family wins. The prompt's segment joins need a Nerd Font.
var FONT_FAMILIES = [
  'CaskaydiaCove Nerd Font Mono',
  'CaskaydiaCove NFM',
  'JetBrainsMono Nerd Font Mono',
  'JetBrainsMono NFM'
];
var FONT_SIZE = 13;

function hexToRgb(hex) {
  var match = /^#([0-9a-f]{6})$/i.exec(hex);
  if (!match) { throw new Error('not a #rrggbb colour: ' + hex); }
  var n = parseInt(match[1], 16);
  return [((n >> 16) & 255) / 255, ((n >> 8) & 255) / 255, (n & 255) / 255];
}

function escapeXml(text) {
  return String(text).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
}

// entries: [key, plist type, value]
function plistXml(entries) {
  var lines = [
    '<?xml version="1.0" encoding="UTF-8"?>',
    '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">',
    '<plist version="1.0">',
    '<dict>'
  ];
  entries.forEach(function (entry) {
    lines.push('\t<key>' + escapeXml(entry[0]) + '</key>');
    if (entry[1] === 'true' || entry[1] === 'false') {
      lines.push('\t<' + entry[1] + '/>');
    } else {
      lines.push('\t<' + entry[1] + '>' + escapeXml(entry[2]) + '</' + entry[1] + '>');
    }
  });
  lines.push('</dict>', '</plist>', '');
  return lines.join('\n');
}

function archive(object) {
  var data = $.NSKeyedArchiver.archivedDataWithRootObjectRequiringSecureCodingError(object, false, null);
  if (data.isNil()) { throw new Error('could not archive an AppKit object'); }
  return ObjC.unwrap(data.base64EncodedStringWithOptions(0));
}

function findFont() {
  var manager = $.NSFontManager.sharedFontManager;
  for (var i = 0; i < FONT_FAMILIES.length; i++) {
    var font = manager.fontWithFamilyTraitsWeightSize(FONT_FAMILIES[i], 0, 5, FONT_SIZE);
    if (!font.isNil()) { return { family: FONT_FAMILIES[i], font: font }; }
  }
  return null;
}

function run(argv) {
  if (argv.length !== 3) {
    throw new Error('usage: make-terminal-profile.js <schemes.json> <scheme name> <out.terminal>');
  }
  ObjC.import('AppKit');
  var text = $.NSString.stringWithContentsOfFileEncodingError(argv[0], $.NSUTF8StringEncoding, null);
  if (text.isNil()) { throw new Error('cannot read ' + argv[0]); }
  var scheme = JSON.parse(ObjC.unwrap(text)).filter(function (s) { return s.name === argv[1]; })[0];
  if (!scheme) { throw new Error('no scheme named "' + argv[1] + '" in ' + argv[0]); }

  var entries = [
    ['name', 'string', scheme.name],
    ['type', 'string', 'Window Settings'],
    ['ProfileCurrentVersion', 'real', '2.07'],
    ['FontAntialias', 'true'],
    ['UseBrightBold', 'false']
  ];
  Object.keys(COLOR_KEYS).forEach(function (key) {
    var rgb = hexToRgb(scheme[key]);
    var data = archive($.NSColor.colorWithSRGBRedGreenBlueAlpha(rgb[0], rgb[1], rgb[2], 1));
    COLOR_KEYS[key].forEach(function (profileKey) { entries.push([profileKey, 'data', data]); });
  });
  var found = findFont();
  if (found) { entries.push(['Font', 'data', archive(found.font)]); }

  var ok = $(plistXml(entries)).writeToFileAtomicallyEncodingError(argv[2], true, $.NSUTF8StringEncoding, null);
  if (!ok) { throw new Error('cannot write ' + argv[2]); }
  return '  built   ' + scheme.name + (found
    ? ' (font: ' + found.family + ')'
    : ' (no Nerd Font installed, so the font is unchanged and the prompt joins will show as boxes)');
}
