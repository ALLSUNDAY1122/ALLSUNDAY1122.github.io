#!/usr/bin/env python3
"""Build 38 source PDF vs in-repo media side-by-side evidence; no automatic rights clearance."""
import fitz, json, pathlib, io, collections, hashlib
from PIL import Image, ImageOps, ImageDraw, ImageFont
import cairosvg
ROOT=pathlib.Path(__file__).resolve().parents[1]
RIGHTS=json.loads((ROOT/"product-content/media-rights-audit.json").read_text())
OUT=ROOT/"audit/runs/media-visual-20261124";OUT.mkdir(parents=True,exist_ok=True)
W=900;H=1160
fontpath="/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
font=ImageFont.truetype(fontpath,20) if pathlib.Path(fontpath).is_file() else ImageFont.load_default()
def fit(image):
    image=image.convert("RGB")
    image.thumbnail((W,H-90))
    canvas=Image.new("RGB",(W,H),"white")
    canvas.paste(image,((W-image.width)//2,54))
    return canvas
rows=[];right_tiles={"official":[],"redraw":[]}
for q in RIGHTS["items"]:
    ex=q["sourceExam"];session=q["session"];id=q["id"]
    pdf=pathlib.Path("/tmp/kangoshi-official")/f"{ex}-{session}.pdf"
    doc=fitz.open(pdf)
    pg=int(q["questionPageIndex"]);page=doc[pg]
    source=Image.open(io.BytesIO(page.get_pixmap(matrix=fitz.Matrix(1.7,1.7),alpha=False).tobytes("png")))
    kind="redraw" if q["status"]=="needs_redraw" else "official"
    path=ROOT/"media"/kind/(id+(".svg" if kind=="redraw" else ".jpg"))
    if kind=="redraw":
        raster=cairosvg.svg2png(url=str(path),output_width=900)
        asset=Image.open(io.BytesIO(raster))
    else:asset=Image.open(path)
    canv=Image.new("RGB",(W*2,H+50),"white")
    a=fit(source);b=fit(asset)
    canv.paste(a,(0,45));canv.paste(b,(W,45))
    draw=ImageDraw.Draw(canv)
    draw.text((10,10),f"{id} official PDF page {pg+1} (unverified region)",font=font,fill="black")
    draw.text((W+10,10),f"{kind.upper()} / {path.name}",font=font,fill="black")
    file=OUT/f"{id}-comparison.jpg";canv.save(file,quality=76,optimize=True)
    tile=asset.convert("RGB");tile.thumbnail((295,245))
    cell=Image.new("RGB",(330,290),"white");cell.paste(tile,((330-tile.width)//2,30))
    ImageDraw.Draw(cell).text((8,6),id,font=font,fill="black")
    right_tiles[kind].append(cell)
    rows.append({"id":id,"type":kind,"sourcePdf":q["questionPdf"],"sourcePdfPageOneBased":pg+1,
         "asset":str(path.relative_to(ROOT)),"comparisonFile":file.name,"assetSha256":hashlib.sha256(path.read_bytes()).hexdigest(),
         "visualComparisonStatus":"PENDING_INDEPENDENT_HUMAN_OR_MODEL_INSPECTION",
         "thirdPartyRights":"UNDETERMINED"})
for kind,tiles in right_tiles.items():
    cols=3;rows_count=(len(tiles)+cols-1)//cols
    sheet=Image.new("RGB",(cols*330,rows_count*290),"#ddd")
    for i,t in enumerate(tiles):sheet.paste(t,((i%cols)*330,(i//cols)*290))
    sheet.save(OUT/f"{kind}-asset-contact-sheet.jpg",quality=85)
doc={"items":rows,"count":len(rows),"officialJpgCount":len(right_tiles["official"]),"svgRedrawCount":len(right_tiles["redraw"]),
     "rightsCleared":0,"note":"Comparison page is full official question PDF; user must verify page correspondences and third party notices. Original question-image asset is not proof of copyright."}
(OUT/"comparison-index.json").write_text(json.dumps(doc,ensure_ascii=False,indent=2)+"\n")
print(json.dumps({"pairs":len(rows),"jpg":doc["officialJpgCount"],"svg":doc["svgRedrawCount"]},ensure_ascii=False))
