#!/usr/bin/env node
// Builds the Studio plugin file: tools/studio-relay/StudioRelay.rbxmx (one Script, relay URL baked in).
// Usage: node tools/studio-relay/build-plugin.mjs [relayUrl]   (default: relay.json url)
import { readFileSync, writeFileSync, existsSync } from "node:fs";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
let url = process.argv[2];
if (!url && existsSync(join(here, "relay.json"))) url = JSON.parse(readFileSync(join(here, "relay.json"), "utf8")).url;
if (!url) throw new Error("relay url required");
// inline --#include files (the approved-update path runs only the main source), keep Font as a child module
let src = readFileSync(join(here, "plugin", "StudioRelay.server.luau"), "utf8").replace("__RELAY_URL__", url.replace(/\/$/, ""));
src = src.replace(/^--#include (\S+)$/m, (_, f) => {
	const body = readFileSync(join(here, "plugin", f), "utf8").replace(/^--!\w+\n/gm, "");
	return `local ${f.replace(/\.luau$/, "")} = (function()\n${body}\nend)()`;
});
const font = readFileSync(join(here, "plugin", "Font.luau"), "utf8");
for (const s of [src, font]) {
	if (s.includes("]]>")) throw new Error("source contains ]]>");
	if (s.length > 199000) throw new Error("a script exceeds 199000 characters: " + s.length);
}
writeFileSync(join(here, "plugin", ".build.luau"), src);
const xml = `<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">
	<Item class="Script" referent="RBX0">
		<Properties>
			<string name="Name">StudioRelay</string>
			<ProtectedString name="Source"><![CDATA[${src}]]></ProtectedString>
		</Properties>
		<Item class="ModuleScript" referent="RBX1">
			<Properties>
				<string name="Name">Font</string>
				<ProtectedString name="Source"><![CDATA[${font}]]></ProtectedString>
			</Properties>
		</Item>
	</Item>
</roblox>
`;
writeFileSync(join(here, "StudioRelay.rbxmx"), xml);
console.log("wrote StudioRelay.rbxmx for " + url);
