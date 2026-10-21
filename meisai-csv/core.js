/* 明細CSV直し — 外部依存なし。入力プリセットの列名・符号は推定。
 * 出力仕様と根拠は SOURCES.md。金額は円の整数のみ。 */
(function(root){
'use strict';
const LIMITS=Object.freeze({bytes:10*1024*1024,records:20000,columns:200,cell:10000});
function fail(message){const e=new Error(message);e.publicMessage=true;return e;}
function publicError(e){return e&&e.publicMessage?e.message:'処理できませんでした。入力形式と設定を確認してください。';}
function validateFile(file){if(!file||!/\.csv$/i.test(file.name))throw fail('CSVを選択してください。PDFは未対応です');if(file.size>LIMITS.bytes)throw fail('ファイルサイズの上限10MiBを超えています');}
// 全セルに適用。純粋な数値（任意の先頭マイナス、正しい3桁区切り、小数点）だけを除外。
// trimや数値への型変換で判定しない。末尾改行・演算子・命令を数値と誤認しない。
function neutralize(value){if(typeof value==='number'&&!Number.isSafeInteger(value))throw fail('出力数値が不正です');const s=String(value??'');const numeric=/^-?(?:(?:[0-9]+|[0-9]{1,3}(?:,[0-9]{3})+)(?:\.[0-9]*)?|\.[0-9]+)$/.exec(s);if(numeric&&numeric[0]===s)return s;return /^[=+\-@\t\r]/.test(s)||/^\s+[=+\-@]/.test(s)?"'"+s:s;}
const norm=s=>String(s??'').normalize('NFKC').trim();
function decode(bytes,encoding='auto'){
 bytes=new Uint8Array(bytes); if(bytes.byteLength>LIMITS.bytes)throw fail('ファイルサイズの上限10MiBを超えています'); if(bytes[0]===255&&bytes[1]===254||bytes[0]===254&&bytes[1]===255)throw fail('UTF-16は未対応です。UTF-8またはShift_JISに変換してください。');
 const bom=bytes[0]===239&&bytes[1]===187&&bytes[2]===191;
 if(encoding==='auto'){try{return {text:new TextDecoder('utf-8',{fatal:true}).decode(bytes),encoding:bom?'UTF-8 (BOM)':'UTF-8',note:'自動判定。ASCIIだけのファイルはUTF-8として扱います。'};}catch{encoding='shift_jis';}}
 try{return {text:new TextDecoder(encoding,{fatal:true}).decode(bytes),encoding,note:'判定が違う場合は文字コードを選び直してください。'};}catch{throw fail('指定文字コードで読めません。UTF-8 / Shift_JISを選び直してください。');}
}
function parseCSV(text){
 if(new TextEncoder().encode(text).length>LIMITS.bytes)throw fail('展開後テキストの上限10MiBを超えています');
 text=text.replace(/^\uFEFF/,''); const out=[];let row=[],cell='',quoted=false,closed=false,start=1,line=1;
 let recordCount=0;const push=()=>{if(cell.length>LIMITS.cell)throw fail('1セルの文字数上限10000を超えています');if(row.length>=LIMITS.columns)throw fail('列数の上限200を超えています');row.push(cell);cell='';closed=false;};
 const pushRow=()=>{if(++recordCount>LIMITS.records)throw fail('CSVレコード数の上限20000を超えています');if(row.some(x=>x.trim()))out.push({cells:row,line:start});};
 for(let i=0;i<text.length;i++){
  const c=text[i];if(cell.length>LIMITS.cell)throw fail('1セルの文字数上限10000を超えています');if(quoted){if(c==='"'){if(text[i+1]==='"'){cell+='"';i++;}else{quoted=false;closed=true;}}else{cell+=c;if(c==='\n')line++;}continue;}
  if(c==='"'){if(cell||closed)throw fail(`${line}行目: 引用符の位置が不正です`);quoted=true;}
  else if(c===','){push();}
  else if(c==='\n'||c==='\r'){push();pushRow();row=[];if(c==='\r'&&text[i+1]==='\n')i++;line++;start=line;}
  else{if(closed)throw fail(`${line}行目: 引用符の後に不正な文字があります`);cell+=c;}
 }
 if(quoted)throw fail('CSVの引用符が閉じていません');push();if(row.length>1||row[0]!==''||!text.endsWith('\n')&&!text.endsWith('\r'))pushRow();return out;
}
function money(v,blank=null){
 let s=norm(v).replace(/[\s¥￥円]/g,'').replace(/[−‐‑‒–—―﹣]/g,'-').replace(/[▲△]/g,'-');
 if(s==='')return blank;
 if(/^\(.*\)$/.test(s))s='-'+s.slice(1,-1);
 if(!/^[+-]?(?:\d+|\d{1,3}(?:,\d{3})+)$/.test(s))throw fail('金額の形式が不正です');
 const n=Number(s.replace(/,/g,''));if(!Number.isSafeInteger(n))throw fail('金額が整数の安全範囲を超えています');return n;
}
const eras={令和:[2018,'2019/05/01',null],平成:[1988,'1989/01/08','2019/04/30'],昭和:[1925,'1926/12/25','1989/01/07'],大正:[1911,'1912/07/30','1926/12/24'],明治:[1867,'1868/01/25','1912/07/29']};
function date(v){
 let s=norm(v).replace(/\s/g,'').replace(/元年/,'1年').replace(/^[Rr]/,'令和').replace(/^[Hh]/,'平成').replace(/^[Ss]/,'昭和').replace(/^[Tt]/,'大正').replace(/^[Mm]/,'明治');let era=null;
 for(const k of Object.keys(eras))if(s.startsWith(k)){era=eras[k];s=s.slice(k.length);break;}
 s=s.replace(/[年.\-]/g,'/').replace(/月/g,'/').replace(/日$/,'');
 let m=s.match(/^(\d{1,4})\/(\d{1,2})\/(\d{1,2})$/);if(!m&&/^\d{8}$/.test(s)&&!era)m=[s,s.slice(0,4),s.slice(4,6),s.slice(6,8)];
 if(!m&&era&&/^\d{6}$/.test(s))m=[s,s.slice(0,2),s.slice(2,4),s.slice(4,6)];
 if(!m||(!era&&m[1].length!==4)||era&&+m[1]<1)throw fail('日付の形式が不正、または年が不明です');
 const y=+m[1]+(era?era[0]:0),mo=+m[2],d=+m[3];const dt=new Date(Date.UTC(y,mo-1,d));
 if(y<1000||y>9999||dt.getUTCFullYear()!==y||dt.getUTCMonth()+1!==mo||dt.getUTCDate()!==d)throw fail('存在しない日付です');
 const result=[y,String(mo).padStart(2,'0'),String(d).padStart(2,'0')].join('/');
 if(era&&(result<era[1]||era[2]&&result>era[2]))throw fail('元号の期間外の日付です');return result;
}
// 推定: 個人/法人、ダウンロード画面、更新時期で列名が変わり得るため、固定位置ではなく見出し候補を照合。
const presets=[['generic','汎用（列を指定）'],['yucho','ゆうちょ'],['rakuten','楽天銀行'],['sbi','住信SBI'],['paypay','PayPay銀行'],['card','楽天カード']];
const aliases={date:['取引日','取引年月日','年月日','日付','お取扱日','お取扱年月日','利用日','利用年月日'],description:['取引内容','摘要','内容','お取扱内容','入出金先内容','利用店名・商品名','利用店舗名・商品名','利用店舗名･商品名','利用店名','ご利用先','お取扱店'],amount:['入出金(円)','入出金額','取引金額','金額','利用金額','利用金額(円)'],income:['入金','入金額','お預り金額','お預り金額(円)','お預かり金額','お預入金額','お預入れ','お預り','預入金額','入金金額(円)'],expense:['出金','出金額','お支払金額','お支払金額(円)','お引出金額','お引出し','お支払い','支払金額','出金金額(円)'],balance:['残高','残高(円)','取引後残高','差引残高','お取引後残高','現在高']};
const key=s=>norm(s).replace(/\s/g,'');
function suggest(headers){const m={};for(const [field,options]of Object.entries(aliases))m[field]=headers.findIndex(h=>options.map(key).includes(key(h)));return m;}
function headerIndex(rows){let best=0,score=-1;rows.slice(0,50).forEach((r,i)=>{const m=suggest(r.cells);let n=Object.values(m).filter(v=>v>=0).length;if(m.date<0)n=-1;if(n>score){score=n;best=i;}});return best;}
function convert(records,header,mapping,opts={}){
 const used=Object.values(mapping).filter(x=>x>=0);if(new Set(used).size!==used.length)throw fail('同じ列を複数の項目に割り当てないでください');
 if(mapping.date<0)throw fail('日付列を指定してください');const single=mapping.amount>=0;
 if(!single&&mapping.income<0&&mapping.expense<0)throw fail('入出金額、または入金・出金列を指定してください');
 if(single&&(mapping.income>=0||mapping.expense>=0))throw fail('1列方式と2列方式は併用できません。不要な列を「なし」にしてください');
 let source=records.slice(header+1);if(opts.reverse)source=source.slice().reverse();
 let prev=opts.initial===undefined||opts.initial===''?null:money(opts.initial);let blocked=false,lastDate=null;const seen=new Set();
 return source.map(rec=>{
  const r={line:rec.line,date:'',description:'',delta:null,balance:null,expected:null,status:'未検証',errors:[],warnings:[]};const get=k=>mapping[k]>=0?rec.cells[mapping[k]]:undefined;
  try{
   if(rec.cells.length!==records[header].cells.length)throw fail('列数が見出しと一致しません（補足行・合計行も自動除外しません）');
   r.date=date(get('date'));r.description=String(get('description')??'');
   if(single){const n=money(get('amount'));if(n===null)throw fail('金額が空白です');r.delta=n*(opts.positiveExpense?-1:1);}
   else{const inc=money(get('income'),0),exp=money(get('expense'),0);if(inc<0||exp<0)throw fail('入金・出金の別列は正数で指定してください');if(inc&&exp)throw fail('入金と出金が両方入力されています');r.delta=inc-exp;}
   if(!r.delta)throw fail('金額0円の行です。元CSVから除いてください');
   r.balance=money(get('balance'));
   if(prev!==null&&!blocked){r.expected=prev+r.delta;if(!Number.isSafeInteger(r.expected))throw fail('計算残高が安全範囲を超えました');r.status=r.balance===null?'再計算のみ':r.balance===r.expected?'一致':'不一致';prev=r.expected;}
   else if(r.balance!==null&&!blocked){prev=r.balance;r.status='基準行（検証不可）';}else r.status=blocked?'前行エラーで検証不可':'残高なし（検証不可）';
   if(lastDate&&r.date<lastDate)r.warnings.push('日付が逆順です。入力の並び順を確認');lastDate=r.date;
   const id=JSON.stringify([r.date,r.delta,r.description]);if(seen.has(id))r.warnings.push('重複候補（自動削除しません）');seen.add(id);
  }catch(e){r.errors.push(publicError(e));r.status='エラー';blocked=true;}
  return r;
 });
}
function csv(rows){return rows.map(row=>row.map(v=>'"'+neutralize(v).replace(/"/g,'""')+'"').join(',')).join('\r\n')+'\r\n';}
// 推定ではなく公式「仕訳帳」27列仕様。相手科目・税区分は利用者が明示し、税判定はしない。
const mfHeader=['取引No','取引日','借方勘定科目','借方補助科目','借方部門','借方取引先','借方税区分','借方インボイス','借方金額(円)','借方税額','貸方勘定科目','貸方補助科目','貸方部門','貸方取引先','貸方税区分','貸方インボイス','貸方金額(円)','貸方税額','摘要','仕訳メモ','タグ','MF仕訳タイプ','決算整理仕訳','作成日時','作成者','最終更新日時','最終更新者'];
function exportRows(rows,target,opts={}){
 if(!rows.length||rows.some(r=>r.errors.length))throw fail('エラー行があります。元CSVまたは列割り当てを修正してください');
 const safe=s=>neutralize(String(s??'')).replace(/[\r\n]+/g,' '); // CSV組立の最終段で全セルの数式先頭を無害化する。

 if(target==='freee-card')return [['取引日','取引金額','取引内容','カードラベル'],...rows.map(r=>[r.date,-r.delta,safe(r.description),safe(opts.cardLabel??'')])];
 if(target==='freee')return [['取引日','出金額','入金額','残高','取引内容'],...rows.map(r=>[r.date,r.delta<0?-r.delta:'',r.delta>0?r.delta:'',r.balance??'',safe(r.description)])];
 if(target==='yayoi')return [['日付','入金','出金','摘要','軽減税率','部門','請求書区分'],...rows.map(r=>{if(Math.abs(r.delta)>999999999)throw fail('弥生の金額は9桁以内です');const s=safe(r.description);if([...s].length>80)throw fail('弥生の摘要80文字制限を超えています。元CSVを修正してください');return [r.date,r.delta>0?r.delta:'',r.delta<0?-r.delta:'',s,'','',''];})];
 if(target==='mf'){
  const account=safe(opts.account||''),other=safe(opts.other||''),tax=safe(opts.tax||'');
  if(!account||!other||!tax)throw fail('MF用の口座科目・相手科目・税区分を入力してください');
  return [mfHeader,...rows.map((r,i)=>{if([...r.description].length>200)throw fail('MFの摘要は200文字以内です');const a=Array(27).fill('');a[0]=i+1;a[1]=r.date;a[2]=r.delta>0?account:other;a[6]=tax;a[8]=Math.abs(r.delta);a[10]=r.delta>0?other:account;a[14]=tax;a[16]=Math.abs(r.delta);a[18]=safe(r.description);return a;})];
 }
 throw fail('不明な出力先');
}
let sjisMap;
function encodeSJIS(text){
 if(!sjisMap){sjisMap=new Map();const d=new TextDecoder('shift_jis',{fatal:true});const add=b=>{try{let s=d.decode(new Uint8Array(b));if([...s].length===1&&!sjisMap.has(s))sjisMap.set(s,b);}catch{}};for(let b=0;b<256;b++)add([b]);for(let h=0x81;h<=0xfc;h++)if(h<=0x9f||h>=0xe0)for(let l=0x40;l<=0xfc;l++)if(l!==0x7f)add([h,l]);}
 const out=[];for(const c of text){const b=sjisMap.get(c);if(!b)throw fail('Shift_JISに変換できない文字があります。元データを修正してください（置換しません）。');out.push(...b);}return new Uint8Array(out);
}
function files(rows,target,opts={}){
 const data=exportRows(rows,target,opts),enc=s=>target==='yayoi'?encodeSJIS(s):new TextEncoder().encode('\uFEFF'+s);
 if(target!=='yayoi')return [enc(csv(data))];
 const result=[];let part=[data[0]],size=encodeSJIS(csv(part)).length;for(const row of data.slice(1)){const n=encodeSJIS(csv([row])).length;if(size+n>=190000){if(part.length===1)throw fail('1行が大きすぎます');result.push(enc(csv(part)));part=[data[0]];size=encodeSJIS(csv(part)).length;}part.push(row);size+=n;}result.push(enc(csv(part)));return result;
}
const api={LIMITS,validateFile,publicError,neutralize,norm,decode,parseCSV,money,date,presets,suggest,headerIndex,convert,csv,exportRows,files,encodeSJIS,mfHeader};
if(typeof module!=='undefined'&&module.exports)module.exports=api;else root.Meisai=api;
})(typeof globalThis!=='undefined'?globalThis:this);
