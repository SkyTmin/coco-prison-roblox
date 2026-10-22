// the owner's comparison: reference sheet on the left, our four renders in the same layout on the right
const sharp=require('C:/Users/user/AppData/Local/Temp/claude/C--Users-user-Desktop--------claud/5519c892-7982-41f2-b081-ec30cc78a89a/scratchpad/imgtools/node_modules/sharp');
const d='assets/models/rat/';
(async()=>{const pos={side:[0,0],front:[768,0],top:[0,512],'34':[768,512]};const comps=[{input:d+'rat-reference.png',left:0,top:0}];
for(const [v,[l,t]] of Object.entries(pos))comps.push({input:await sharp(d+'compare-'+v+'.png').resize(768,512).toBuffer(),left:1536+l+16,top:t});
const big=await sharp({create:{width:3088,height:1024,channels:3,background:'#fff'}}).composite(comps).png().toBuffer();
await sharp(big).resize(1800).png().toFile(d+'compare-views.png');})();
