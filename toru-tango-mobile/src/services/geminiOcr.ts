import * as ImageManipulator from 'expo-image-manipulator';
import { getAnonymousId } from './anonymousId';
import { getTransactionJws } from './iap';
import { cloudAiErrorMessage } from './cloudAiErrors';

export type SelectedStudyImage = {
  uri: string;
  mimeType?: string | null;
  width?: number;
  height?: number;
};

const MAX_IMAGES = 10;
const MAX_BASE64_CHARS = 1_300_000;
const COMPRESSION = [
  { edge: 1280, quality: 0.6 },
  { edge: 1024, quality: 0.5 },
  { edge: 800, quality: 0.4 }
] as const;

function ocrEndpoint() {
  const configured = process.env.EXPO_PUBLIC_AI_API_URL?.trim();
  if (!configured?.startsWith('https://')) throw new Error('OCR接続先の設定を確認してください。');
  return configured.replace(/\/generate\/?$/, '/ocr');
}

function xhrPost(url: string, body: string, headers: Record<string,string>): Promise<{status:number;payload:Record<string,unknown>}> {
  // Explicit XMLHttpRequest avoids Expo's fetch wrapper and its Promise.swift
  // transport exception. RN uses NSURLSession-backed native networking.
  return new Promise((resolve, reject) => {
    const xhr = new XMLHttpRequest();
    xhr.open('POST', url, true);
    xhr.timeout = 45000;
    Object.entries(headers).forEach(([key, value]) => xhr.setRequestHeader(key,value));
    xhr.onerror = () => reject(new Error('NATIVE_XHR_NETWORK_ERROR'));
    xhr.ontimeout = () => reject(new Error('NATIVE_XHR_TIMEOUT'));
    xhr.onabort = () => reject(new Error('NATIVE_XHR_ABORT'));
    xhr.onload = () => {
      try {
        resolve({status:xhr.status,payload:JSON.parse(xhr.responseText) as Record<string,unknown>});
      } catch { reject(new Error('OCR_RESPONSE_JSON_INVALID')); }
    };
    xhr.send(body);
  });
}

async function compressedJpeg(image: SelectedStudyImage) {
  const width = image.width ?? 0, height = image.height ?? 0;
  for (const {edge, quality} of COMPRESSION) {
    const longest = Math.max(width, height);
    const action = !longest || longest > edge
      ? [{resize: width >= height ? {width:edge} : {height:edge}}]
      : [];
    const result = await ImageManipulator.manipulateAsync(image.uri,action,{
      format: ImageManipulator.SaveFormat.JPEG, compress:quality, base64:true
    });
    if (result.base64 && result.base64.length <= MAX_BASE64_CHARS) {
      return {data: result.base64, mimeType:'image/jpeg'};
    }
  }
  throw new Error('写真が大きすぎます。もう一度撮影してください。（OCR_IMAGE_TOO_LARGE）');
}
function isTransport(error: unknown) {
  return error instanceof Error && /^NATIVE_XHR_(NETWORK_ERROR|TIMEOUT|ABORT)$/.test(error.message);
}
function sleep(ms:number) {return new Promise<void>(resolve=>setTimeout(resolve,ms));}

export async function recognizeWithGemini(images:SelectedStudyImage[]):Promise<string> {
  if (!images.length || images.length > MAX_IMAGES)throw new Error('写真は1～10枚選んでください。');
  const anonymousId=await getAnonymousId();
  const jws=await getTransactionJws();
  const url=ocrEndpoint();
  const headers:Record<string,string>={
    'Content-Type':'application/json',
    'X-Toru-Tango-Anonymous-Id':anonymousId,
    ...(jws?{'X-Toru-Tango-Transaction-JWS':jws}:{})
  };
  const results:string[]=[];
  for(let i=0;i<images.length;i++) {
    const jpeg=await compressedJpeg(images[i]);
    const body=JSON.stringify({images:[jpeg]});
    const bodyBytes=body.length;
    let completed=false;
    for(let attempt=1;attempt<=3;attempt++) {
      try {
        const {status,payload}=await xhrPost(url,body,headers);
        if(status!==200)throw new Error(cloudAiErrorMessage(status,payload));
        const text=typeof payload.text==='string'?payload.text.trim():'';
        if(!text)throw new Error('写真から文字を認識できませんでした。');
        results.push(text);
        completed=true;
        break;
      } catch(error) {
        if(!isTransport(error)) throw error;
        if(attempt===3) {
          throw new Error(`写真${i+1}/${images.length}の通信に失敗しました。電波状況を確認してください。（OCR_XHR_NETWORK attempts=3 bodyBytes=${bodyBytes} detail=${(error as Error).message}）`);
        }
        await sleep(500*2**(attempt-1));
      }
    }
    if(!completed)throw new Error('通信を完了できませんでした。');
  }
  return results.join('\n\n');
}
