import assert from "node:assert/strict";
import fs from "node:fs";
import test from "node:test";

const root = new URL("../../", import.meta.url);
const read = file => fs.readFileSync(new URL(file, root), "utf8");
const bar = read("Bar/Bar.qml");
const state = read("Services/DesktopState.qml");
const appearance = read("Bar/modules/Appearance.qml");
const shell = read("shell.qml");
const commands = read("Services/Commands.qml");

test("bar auto-hide is persisted, revealed from the edge, and user-toggleable", () => {
  assert.match(state, /property bool barAutoHide: false/);
  assert.match(state, /function setBarAutoHide\(on\)/);
  assert.match(state, /function toggleBarAutoHide\(\)/);
  assert.match(state, /barAutoHide/);
  assert.match(bar, /mask: Region \{ item: root\.autoHide && !root\.revealed \? revealRegion : barContent \}/);
  assert.match(bar, /exclusiveZone: autoHide && !revealed \? 0 : Theme\.barHeight \+ Theme\.barMargin/);
  assert.match(bar, /HoverHandler/);
  assert.match(appearance, /DesktopState\.toggleBarAutoHide\(\)/);
  assert.match(shell, /function toggleBarAutoHide\(\)/);
  assert.match(commands, /name: "Auto-hide bar"/);
});
