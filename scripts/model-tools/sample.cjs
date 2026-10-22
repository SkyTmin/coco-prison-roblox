const sharp=require('C:/Users/user/AppData/Local/Temp/claude/C--Users-user-Desktop--------claud/5519c892-7982-41f2-b081-ec30cc78a89a/scratchpad/imgtools/node_modules/sharp');
const [src,...pts]=process.argv.slice(2);
(async()=>{const {data,info}=await sharp(src).raw().toBuffer({resolveWithObject:true});
for(const p of pts){const [name,x0,y0,x1,y1]=p.split(',');let r=0,g=0,b=0,n=0,mn=1e9,mx=0;
for(let y=+y0;y<+y1;y++)for(let x=+x0;x<+x1;x++){const i=(y*info.width+x)*info.channels;r+=data[i];g+=data[i+1];b+=data[i+2];n++;const l=data[i]+data[i+1]+data[i+2];mn=Math.min(mn,l);mx=Math.max(mx,l)}
const h=v=>Math.round(v/n).toString(16).padStart(2,'0');console.log(name,'#'+h(r)+h(g)+h(b),'lum range',Math.round(mn/3),Math.round(mx/3))}})();
