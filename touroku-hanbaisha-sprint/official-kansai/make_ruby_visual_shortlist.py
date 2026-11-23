"""Prepare readable source-vs-new-ruby contact strips for exact zero-issue candidates."""
import json
from PIL import Image,ImageDraw
from pathlib import Path
B=Path(__file__).resolve().parent
d=json.loads((B/'RUBY_REBUILT_COMPARISON_120_20261124.json').read_text())
clean=[r for r in d['records'] if r['rubyDomCount']>0 and not r['issues']]
assert len(clean)==32,len(clean)
out=[]
for i in range(0,len(clean),4):
    pieces=[]
    for x in clean[i:i+4]:
        official=Image.open(B/x['officialSourceImage']).convert('RGB')
        candidate=Image.open(B/x['repairedCandidateScreenshot']).convert('RGB')
        mw=650
        for im in (official,candidate):
            if im.width>mw:im.thumbnail((mw,10000))
        h=min(max(official.height,candidate.height)+32,2300)
        canvas=Image.new('RGB',(mw*2+22,h),'white')
        canvas.paste(official,(0,32));canvas.paste(candidate,(mw+22,32))
        draw=ImageDraw.Draw(canvas)
        draw.text((10,8),x['id']+' OFFICIAL',fill='black')
        draw.text((mw+32,8),'APP CANDIDATE '+str(x['rubyDomCount'])+' ruby/rt',fill='black')
        pieces.append(canvas)
    contact=Image.new('RGB',(1322,sum(p.height for p in pieces)+12*(len(pieces)-1)),'#e7e7e7')
    y=0
    for piece in pieces:
        contact.paste(piece,(0,y));y+=piece.height+12
    name=f'ruby-font-review/SHORTLIST_REVIEW_{i//4+1:02d}.jpg'
    contact.save(B/name,quality=85,optimize=True)
    out.append(name)
result={'totalCandidates':120,'cleanRubyPreview':len(clean),
        'contactSheets':out,'candidateIds':[x['id'] for x in clean],
        'visualApprovalCount':0,'note':'Shortlist requires direct original-and-candidate image inspection; no automatic PASS.'}
(B/'RUBY_VISUAL_SHORTLIST_V2.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({'shortlist':len(clean),'sheets':len(out)}))
