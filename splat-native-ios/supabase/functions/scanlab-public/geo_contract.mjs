export function locationForPublicResponse(scan){
  if(scan.visibility!=="public")return null;
  if(typeof scan.latitude!=="number"||!Number.isFinite(scan.latitude))return null;
  if(typeof scan.longitude!=="number"||!Number.isFinite(scan.longitude))return null;
  if(scan.latitude< -90||scan.latitude>90||scan.longitude< -180||scan.longitude>180)return null;
  return{latitude:scan.latitude,longitude:scan.longitude,label:typeof scan.location_label==="string"?scan.location_label:null};
}
