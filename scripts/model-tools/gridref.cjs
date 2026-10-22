// crop a region of an image and draw a labelled grid every `step` source pixels
const sharp=require('C:/Users/user/AppData/Local/Temp/claude/C--Users-user-Desktop--------claud/5519c892-7982-41f2-b081-ec30cc78a89a/scratchpad/imgtools/node_modules/sharp');
const [src,out,l,t,w,h,step,scale]=process.argv.slice(2);const L=+l,T=+t,W=+w,H=+h,S=+step,K=+(scale||1);
(async()=>{let lines='';
for(let x=Math.ceil(L/S)*S;x<L+W;x+=S){const X=(x-L)*K;lines+=`<line x1="${X}" y1="0" x2="${X}" y2="${H*K}" stroke="${x%(S*5)?'#00f8':'#f00c'}" stroke-width="1"/><text x="${X+2}" y="12" font-size="11" fill="#f00">${x}</text>`}
for(let y=Math.ceil(T/S)*S;y<T+H;y+=S){const Y=(y-T)*K;lines+=`<line x1="0" y1="${Y}" x2="${W*K}" y2="${Y}" stroke="${y%(S*5)?'#00f8':'#f00c'}" stroke-width="1"/><text x="2" y="${Y-2}" font-size="11" fill="#f00">${y}</text>`}
const svg=Buffer.from(`<svg xmlns="http://www.w3.org/2000/svg" width="${W*K}" height="${H*K}">${lines}</svg>`);
await sharp(src).extract({left:L,top:T,width:W,height:H}).resize(W*K,H*K,{kernel:'nearest'}).composite([{input:svg}]).png().toFile(out);})();
