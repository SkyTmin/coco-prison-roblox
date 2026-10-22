const sharp=require('C:/Users/user/AppData/Local/Temp/claude/C--Users-user-Desktop--------claud/5519c892-7982-41f2-b081-ec30cc78a89a/scratchpad/imgtools/node_modules/sharp');
const [d,out,...names]=process.argv.slice(2);
(async()=>{const imgs=await Promise.all(names.map(n=>sharp(d+'preview-'+n+'.png').resize(450,300).toBuffer()));
await sharp({create:{width:900,height:300*Math.ceil(names.length/2),channels:3,background:'#fff'}}).composite(imgs.map((b,i)=>({input:b,left:(i%2)*450,top:Math.floor(i/2)*300}))).png().toFile(out);})();
