// Rebuild: node scripts/make-settings-icons.mjs, then Blender -b -t 2 -P assets/models/items/items.py -- icons <ABSOLUTE output dir> menu_settings_controls menu_settings_display menu_settings_sound menu_settings_game menu_settings_social menu_settings_language
// Original voxel pictograms. Render with assets/models/items/items.py; no letters or flags.
import fs from "node:fs";
const path = "assets/models/items/grids.json";
const grids = JSON.parse(fs.readFileSync(path, "utf8"));
const N = 32, dark = "1e2b3d", white = "dfeaf2", light = "ffffff", blue = "58b7eb", shade = "317bb4", gold = "edbf62";
function grid(draw) {
  const px = Array(N * N).fill("");
  const set = (x, y, c) => { if (x >= 0 && y >= 0 && x < N && y < N) px[Math.round(y) * N + Math.round(x)] = c; };
  const rect = (x, y, w, h, c) => { for (let j=y;j<y+h;j++) for(let i=x;i<x+w;i++) set(i,j,c); };
  const ellipse = (x, y, rx, ry, c) => { for(let j=0;j<N;j++) for(let i=0;i<N;i++) if(((i-x)/rx)**2+((j-y)/ry)**2<=1) set(i,j,c); };
  const line = (x1,y1,x2,y2,w,c) => { const steps=Math.max(Math.abs(x2-x1),Math.abs(y2-y1))*2;for(let i=0;i<=steps;i++) rect(Math.round(x1+(x2-x1)*i/steps),Math.round(y1+(y2-y1)*i/steps),w,w,c); };
  draw({rect,ellipse,line,set});
  return {w:N,h:N,cell:1,px};
}
grids.menu_settings_controls = grid(({rect,ellipse})=>{
  ellipse(15.5,16,10,14,dark);ellipse(15.5,16,8,12,white);
  rect(15,5,2,10,dark);rect(8,14,16,2,dark);rect(14,7,4,6,shade);rect(15,7,2,4,blue);
  rect(10,19,2,7,light);rect(20,18,2,7,"9db6c8");
});
grids.menu_settings_display = grid(({rect,line})=>{
  rect(2,4,28,21,dark);rect(4,6,24,15,shade);rect(5,7,22,12,blue);rect(6,8,18,2,"a0e4fa");
  line(7,17,13,11,2,"bcecf6");rect(14,25,4,3,dark);rect(9,28,14,2,white);rect(14,22,4,1,white);
});
grids.menu_settings_sound = grid(({rect,line})=>{
  rect(3,12,7,10,dark);line(8,12,15,5,3,dark);line(8,20,15,27,3,dark);rect(14,5,4,25,dark);
  rect(5,14,5,6,gold);line(9,14,14,9,2,gold);line(9,18,14,23,2,gold);rect(14,9,2,15,gold);
  line(20,11,23,14,2,white);rect(23,14,2,6,white);line(23,20,20,23,2,white);
  line(24,6,28,11,2,blue);rect(28,11,2,13,blue);line(28,23,24,28,2,blue);
});
grids.menu_settings_game = grid(({rect,ellipse})=>{
  rect(7,7,18,17,dark);ellipse(7,19,5,9,dark);ellipse(24,19,5,9,dark);
  rect(8,9,16,12,white);ellipse(7,18,3,7,white);ellipse(24,18,3,7,white);
  rect(6,12,3,9,dark);rect(3,15,9,3,dark);rect(15,12,3,2,shade);
  rect(23,11,3,3,"73c68b");rect(26,15,3,3,"e8bd5c");rect(20,15,3,3,blue);rect(23,19,3,3,"df7183");
});
grids.menu_settings_social = grid(({rect,line})=>{
  rect(10,11,20,15,dark);line(23,24,27,28,2,dark);rect(12,13,16,11,"73b896");rect(24,24,3,2,"73b896");
  rect(1,3,24,17,dark);line(4,18,4,24,3,dark);line(4,22,10,17,3,dark);
  rect(3,5,20,13,blue);line(6,17,6,21,2,blue);rect(6,10,3,3,light);rect(11,10,3,3,light);rect(16,10,3,3,light);
});
grids.menu_settings_language = grid(({rect,ellipse})=>{
  ellipse(15.5,15.5,14.5,14.5,dark);ellipse(15.5,15.5,12.5,12.5,shade);ellipse(15.5,15.5,10.5,12.5,blue);
  ellipse(15.5,15.5,6.8,12.5,white);ellipse(15.5,15.5,4.8,11.5,blue);
  rect(3,14,26,3,white);rect(6,7,20,2,white);rect(6,22,20,2,white);
});
fs.writeFileSync(path, "{\n" + Object.entries(grids).map(([key,value]) => JSON.stringify(key) + ":" + JSON.stringify(value)).join(",\n") + "\n}\n");
console.log("Created 6 original settings voxel models");
