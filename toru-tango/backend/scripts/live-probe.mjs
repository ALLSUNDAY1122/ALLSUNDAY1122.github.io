import { deflateSync } from 'node:zlib';
const host=process.env.TORU_WORKER_URL || 'https://toru-tango-ai.kohei3615.workers.dev';
const id='build15-smoke-'+(process.env.GITHUB_RUN_ID||'manual');
const headers={'Content-Type':'application/json','X-Toru-Tango-Anonymous-Id':id};
const patterns={
 A:['01110','10001','10001','11111','10001','10001','10001'],
 I:['11111','00100','00100','00100','00100','00100','11111'],
 '2':['11110','00001','00001','01110','10000','10000','11111'],
 '0':['01110','10001','10011','10101','11001','10001','01110'],
 '6':['01111','10000','10000','11110','10001','10001','01110'],
 ' ':['00000','00000','00000','00000','00000','00000','00000']
};
function crc32(bytes){let crc=-1;for(const b of bytes){crc^=b;for(let i=0;i<8;i++)crc=(crc>>>1)^((crc&1)?0xedb88320:0);}return(crc^(-1))>>>0;}
function chunk(type,data){const n=Buffer.alloc(4);n.writeUInt32BE(data.length);const t=Buffer.from(type);const c=Buffer.alloc(4);c.writeUInt32BE(crc32(Buffer.concat([t,data])));return Buffer.concat([n,t,data,c]);}
function demoPng(){
 const w=320,h=100,pixels=Buffer.alloc(h*(w*3+1),255);
 for(let y=0;y<h;y++)pixels[y*(w*3+1)]=0;
 const message='AI 2026',scale=7,offsetX=25,offsetY=23;
 for(let i=0;i<message.length;i++)for(let y=0;y<7;y++)for(let x=0;x<5;x++)if(patterns[message[i]][y][x]==='1')
  for(let dy=0;dy<scale;dy++)for(let dx=0;dx<scale;dx++){
   const xx=offsetX+i*6*scale+x*scale+dx,yy=offsetY+y*scale+dy;
   const at=yy*(w*3+1)+1+xx*3;pixels[at]=pixels[at+1]=pixels[at+2]=0;
  }
 const ihdr=Buffer.alloc(13);ihdr.writeUInt32BE(w,0);ihdr.writeUInt32BE(h,4);ihdr[8]=8;ihdr[9]=2;
 return Buffer.concat([Buffer.from('89504e470d0a1a0a','hex'),chunk('IHDR',ihdr),chunk('IDAT',deflateSync(pixels)),chunk('IEND',Buffer.alloc(0))]).toString('base64');
}
async function probe(path,body){
 const res=await fetch(host+path,{method:'POST',headers,body:JSON.stringify(body),signal:AbortSignal.timeout(50000)});
 const raw=await res.text();let payload;try{payload=JSON.parse(raw);}catch{payload={error:'Non JSON response'};}
 const details={endpoint:path,status:res.status,code:payload.code||null,
 upstreamStatus:payload.upstreamStatus||null,upstreamCode:payload.upstreamCode||null,
 count:path==='/generate'?(payload.questions?.length||0):(payload.text?.trim()?.length||0),
 error:payload.error||null};
 console.log(JSON.stringify(details));
 if(res.status!==200 || !details.count)throw Error('LIVE_PROBE_FAILED '+path+' status='+res.status+' code='+(details.code||'none'));
}
await probe('/generate',{text:'AIの教材として、東京は日本の首都です。日本国憲法は1947年5月3日に施行されました。北海道の道庁所在地は札幌市です。',count:2,type:'qa',difficulty:'normal'});
await probe('/ocr',{images:[{mimeType:'image/png',data:demoPng()}]});
console.log('LIVE_WORKER_GENERATE_AND_OCR_200');
