export function parseScanLabFeedAssetPolicy(searchParams){
  const raw=searchParams.get("includeModel");
  if(raw===null||raw==="1")return{includeModel:true};
  if(raw==="0")return{includeModel:false};
  return{includeModel:true,error:"invalid_include_model"};
}
