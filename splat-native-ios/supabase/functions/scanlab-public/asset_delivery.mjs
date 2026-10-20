const UUID_PATTERN=/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
export function parseScanLabAssetPath(path,ownerId,scanId){
  if(typeof path!=="string"||!UUID_PATTERN.test(ownerId??"")||!UUID_PATTERN.test(scanId??""))return null;
  const expected=`${ownerId}/${scanId}/scene.spz`;
  return path===expected?{ownerId,scanId,path}:null;
}
export function assetContentType(){return"application/octet-stream";}
