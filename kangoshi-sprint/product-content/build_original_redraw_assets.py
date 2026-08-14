#!/usr/bin/env python3
from pathlib import Path
import json, math

ROOT=Path(__file__).resolve().parent
APP=ROOT.parent
OUT=APP/'media'/'redraw'
OUT.mkdir(parents=True,exist_ok=True)
PACKET=json.loads((ROOT/'media-redraw-packet.json').read_text(encoding='utf-8'))
INDEX={x['id']:x for x in PACKET['items']}
IDS=[
'K115-AM013','K115-AM016','K115-AM022','K115-AM034','K115-AM063','K115-PM020',
'K114-AM013','K114-AM030','K114-AM039','K114-AM041','K114-AM051','K114-AM054','K114-AM107','K114-PM019','K114-PM045',
'K113-AM023','K113-AM027','K113-AM034','K113-AM035','K113-AM046','K113-AM110','K113-PM054','K113-PM066']
if set(IDS)!=set(INDEX):
    raise SystemExit(f'redraw packet mismatch missing={sorted(set(IDS)-set(INDEX))} extra={sorted(set(INDEX)-set(IDS))}')

INK='#243447'; MUTED='#708090'; SOFT='#eef2f5'; ACC='#315f86'; WARM='#f5efe6'; YELLOW='#f4d64e'; RED='#d85b58'; GREEN='#4d9a69'; BLACK='#272727'

def esc(s):
    return str(s).replace('&','&amp;').replace('<','&lt;').replace('>','&gt;').replace('"','&quot;')
def line(x1,y1,x2,y2,sw=3,c=INK,dash=None):
    d=f' stroke-dasharray="{dash}"' if dash else ''
    return f'<line x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}" stroke="{c}" stroke-width="{sw}" stroke-linecap="round"{d}/>'
def path(d,sw=3,c=INK,fill='none'):
    return f'<path d="{d}" stroke="{c}" stroke-width="{sw}" fill="{fill}" stroke-linecap="round" stroke-linejoin="round"/>'
def circle(cx,cy,r,fill='white',sw=3,c=INK):
    return f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="{fill}" stroke="{c}" stroke-width="{sw}"/>'
def rect(x,y,w,h,fill='white',sw=3,c=INK,rx=12):
    return f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{rx}" fill="{fill}" stroke="{c}" stroke-width="{sw}"/>'
def txt(x,y,s,size=24,anchor='middle',weight=500,c=INK):
    return f'<text x="{x}" y="{y}" text-anchor="{anchor}" font-family="system-ui,-apple-system,\'Noto Sans JP\',sans-serif" font-size="{size}" font-weight="{weight}" fill="{c}">{esc(s)}</text>'
def panel(x,y,w,h,n):
    return rect(x,y,w,h,SOFT,2,'#c7d1da',18)+circle(x+28,y+28,18,'white',2,ACC)+txt(x+28,y+36,str(n),20,weight=700,c=ACC)
def svg(qid,body,h=620,title='独自再作図'):
    return f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 900 {h}" role="img" aria-labelledby="t d" data-original-redraw="{qid}">
<title id="t">{esc(qid)} {esc(title)}</title><desc id="d">公式設問の学習上必要な情報だけを独自の線画で再構成した図版</desc>
<rect width="900" height="{h}" fill="white"/>{body}</svg>\n'''
def stick(cx,cy,pose='stand',scale=1):
    s=[]; r=16*scale
    if pose=='supine':
        s+=[circle(cx-80*scale,cy,r,'white',2),line(cx-62*scale,cy,cx+55*scale,cy,6),line(cx-5*scale,cy,cx+45*scale,cy-22*scale,5),line(cx+45*scale,cy-22*scale,cx+90*scale,cy-22*scale,5),line(cx-10*scale,cy,cx+42*scale,cy+22*scale,5),line(cx+42*scale,cy+22*scale,cx+90*scale,cy+22*scale,5)]
    elif pose=='sidecurl':
        s+=[circle(cx-60*scale,cy-20*scale,r,'white',2),path(f'M {cx-44*scale} {cy-12*scale} Q {cx} {cy+10*scale} {cx+25*scale} {cy}',6),line(cx+10*scale,cy,cx+55*scale,cy+30*scale,5),line(cx+55*scale,cy+30*scale,cx+28*scale,cy+56*scale,5),line(cx+12*scale,cy+2*scale,cx+50*scale,cy+18*scale,5),line(cx-10*scale,cy,cx+28*scale,cy-30*scale,5)]
    elif pose=='side':
        s+=[circle(cx-55*scale,cy-15*scale,r,'white',2),line(cx-38*scale,cy,cx+35*scale,cy+15*scale,6),line(cx+30*scale,cy+15*scale,cx+75*scale,cy+30*scale,5),line(cx+25*scale,cy+15*scale,cx+55*scale,cy+55*scale,5),line(cx-5*scale,cy+4*scale,cx-35*scale,cy+32*scale,5)]
    else:
        s+=[circle(cx,cy-75*scale,r,'white',2),line(cx,cy-58*scale,cx,cy+20*scale,6),line(cx,cy-35*scale,cx-42*scale,cy,5),line(cx,cy-35*scale,cx+42*scale,cy,5),line(cx,cy+20*scale,cx-30*scale,cy+75*scale,5),line(cx,cy+20*scale,cx+30*scale,cy+75*scale,5)]
    return ''.join(s)
def option_grid(draws,h=620):
    b=[]; coords=[(45,70),(465,70),(45,340),(465,340)]
    for i,((x,y),d) in enumerate(zip(coords,draws),1):
        b.append(panel(x,y,390,230,i)); b.append(d(x,y,390,230))
    return ''.join(b)

def q115_013():
    b=txt(450,42,'腹部の4部位（正面）',26,weight=700)
    b+=path('M330 100 Q300 180 320 290 L350 500 L550 500 L580 290 Q600 180 570 100',4)
    pts=[(390,220),(510,220),(510,420),(390,420)]
    # patient right is viewer left; answer 1 is viewer-left upper quadrant
    for i,(x,y) in enumerate(pts,1): b+=circle(x,y,18,WARM,3,ACC)+txt(x,y+7,str(i),18,weight=700,c=ACC)
    b+=txt(450,555,'左右は患者本人を基準にする',19,c=MUTED)
    return svg('K115-AM013',b)
def q115_016():
    def d1(x,y,w,h):return stick(x+195,y+125,'supine',.75)
    def d2(x,y,w,h):return stick(x+195,y+115,'sidecurl',.9)
    def d3(x,y,w,h):return stick(x+195,y+125,'side',.8)
    def d4(x,y,w,h):return stick(x+195,y+115,'side',.8)+line(x+205,y+125,x+250,y+75,4)
    return svg('K115-AM016',txt(450,42,'腰椎穿刺の体位',26,weight=700)+option_grid([d1,d2,d3,d4]))
def q115_022():
    def cann(x,y,w,h):return path(f'M{x+90} {y+120} Q{x+150} {y+70} {x+210} {y+120} M{x+150} {y+70} L{x+150} {y+45}',5)+txt(x+195,y+205,'鼻カニューレ',18)
    def mask(x,y,w,h):return path(f'M{x+150} {y+55} Q{x+110} {y+95} {x+135} {y+150} Q{x+195} {y+180} {x+250} {y+145} Q{x+270} {y+90} {x+230} {y+55} Z',4,ACC,SOFT)+line(x+250,y+110,x+320,y+140,4)+txt(x+195,y+205,'簡易酸素マスク',18)
    def vent(x,y,w,h):return mask(x,y,w,h)+rect(x+178,y+138,35,50,WARM,2,ACC,6)+txt(x+195,y+205,'ベンチュリーマスク',17)
    def reservoir(x,y,w,h):return mask(x,y,w,h)+path(f'M{x+165} {y+155} Q{x+135} {y+205} {x+195} {y+215} Q{x+255} {y+205} {x+225} {y+155} Z',3,ACC,WARM)+txt(x+195,y+220,'リザーバー付き',17)
    return svg('K115-AM022',txt(450,42,'酸素投与器具',26,weight=700)+option_grid([cann,mask,vent,reservoir]))
def q115_034():
    b=txt(450,42,'右股関節を90°屈曲した状態',26,weight=700)
    b+=txt(260,110,'A',30,weight=700)+circle(260,175,25,SOFT,3)+line(260,200,260,330,12)+line(260,330,260,455,12)
    b+=txt(640,110,'B',30,weight=700)+circle(640,175,25,SOFT,3)+line(640,200,640,330,12)+line(640,330,555,410,12)
    b+=path('M610 445 Q560 470 520 435',7,ACC)+path('M520 435 l18 -2 l-7 17',5,ACC,ACC)
    b+=txt(450,535,'下腿が外側へ動き、股関節は内旋する',18,c=MUTED)
    return svg('K115-AM034',b)
def q115_063():
    def diaper(x,y,w,h):return path(f'M{x+95} {y+70} L{x+295} {y+70} L{x+250} {y+180} L{x+140} {y+180} Z',4,ACC,SOFT)
    def cup(x,y,w,h):return path(f'M{x+145} {y+75} L{x+245} {y+75} L{x+225} {y+180} L{x+165} {y+180} Z',4,ACC,WARM)+line(x+165,y+130,x+225,y+130,2,MUTED)
    def pad(x,y,w,h):return rect(x+110,y+75,170,100,SOFT,3,ACC,45)+path(f'M{x+130} {y+125} Q{x+195} {y+80} {x+260} {y+125}',2,MUTED)
    def bag(x,y,w,h):return path(f'M{x+130} {y+65} L{x+260} {y+65} L{x+280} {y+190} L{x+110} {y+190} Z',4,ACC,'#f7fbff')+circle(x+195,y+95,35,'white',3,ACC)+line(x+195,y+190,x+195,y+210,4,ACC)
    return svg('K115-AM063',txt(450,42,'乳児の採尿に使う用具',26,weight=700)+option_grid([diaper,cup,pad,bag]))
def q115_pm020():
    def wave(kind):
        if kind==1:return 'M70 105 '+ ' '.join(f'Q {90+i*45} {75 if i%2==0 else 135} {110+i*45} 105' for i in range(7))
        if kind==2:return 'M70 105 L120 105 q8 -50 16 0 q8 50 16 0 q8 -50 16 0 L250 105 q8 -50 16 0 q8 50 16 0 q8 -50 16 0 L330 105'
        if kind==3:return 'M70 105 '+ ' '.join(f'L {80+i*10} {105-(i if i<10 else 20-i)*5} L {85+i*10} {105+(i if i<10 else 20-i)*5}' for i in range(20))+' L300 105'
        return 'M70 105 '+ ' '.join(f'Q {82+i*42} 35 {100+i*42} 105 Q {118+i*42} 175 {136+i*42} 105' for i in range(6))
    draws=[]
    for k in range(1,5):
        draws.append(lambda x,y,w,h,k=k:path(wave(k).replace('M70',f'M{x+70}').replace(' 105',f' {y+115}'),3,ACC))
    return svg('K115-PM020',txt(450,42,'呼吸パターン',26,weight=700)+option_grid(draws))
def q114_013():
    def ecg(kind):
        pts=[]
        for i in range(12):
            x=70+i*24
            if kind==4: pts += [(x,130),(x+7,55),(x+15,165),(x+24,130)]
            elif kind==2 and i%4==0: pts += [(x,130),(x+8,55),(x+16,175),(x+24,130)]
            else: pts += [(x,130),(x+8,120),(x+12,65),(x+16,140),(x+24,130)]
        return 'M'+' L'.join(f'{x} {y}' for x,y in pts)
    def mk(k):return lambda x,y,w,h:path(ecg(k).replace('M70',f'M{x+70}').replace(' 130',f' {y+130}').replace(' 55',f' {y+55}').replace(' 165',f' {y+165}').replace(' 175',f' {y+175}').replace(' 120',f' {y+120}').replace(' 65',f' {y+65}').replace(' 140',f' {y+140}'),3,ACC)
    return svg('K114-AM013',txt(450,42,'心電図波形（模式）',26,weight=700)+option_grid([mk(1),mk(2),mk(3),mk(4)]))
def q114_030():
    b=txt(450,42,'胎生3週ごろの胚子横断面（模式）',26,weight=700)
    xs=[160,350,540,730]
    for i,x in enumerate(xs):
        b+=circle(x,260,105,SOFT,3,ACC)+path(f'M{x-70} 260 Q{x} {180+i*8} {x+70} 260',3,INK)
        if i>=1:b+=circle(x,215,18,WARM,2,ACC)
    b+=path('M700 115 L730 200',3,ACC)+path('M730 200 l-12 -10 l18 -3',3,ACC,ACC)+txt(690,105,'A',28,weight=700,c=ACC)
    b+=txt(450,470,'A：背側の神経管',21,c=MUTED)
    return svg('K114-AM030',b)
def q114_039():
    def tri(pos):
        def d(x,y,w,h):
            z=stick(x+195,y+135,'stand',.55)
            if pos==1:z+=path(f'M{x+110} {y+55} L{x+270} {y+195} L{x+110} {y+195} Z',3,ACC,'#fff')
            elif pos==2:z+=path(f'M{x+95} {y+105} L{x+295} {y+105} L{x+195} {y+200} Z',3,ACC,'#fff')
            elif pos==3:z+=path(f'M{x+95} {y+185} L{x+295} {y+185} L{x+295} {y+60} Z',3,ACC,'#fff')
            else:z+=path(f'M{x+155} {y+65} L{x+305} {y+105} L{x+155} {y+205} Z',3,ACC,'#fff')
            return z
        return d
    return svg('K114-AM039',txt(450,42,'左肘を支持する三角巾の置き方',26,weight=700)+option_grid([tri(1),tri(2),tri(3),tri(4)]))
def q114_041():
    def pose(p):return lambda x,y,w,h:stick(x+195,y+125,p,.8)+(rect(x+250,y+135,70,45,WARM,2,MUTED,10) if p=='supine' and x<100 else '')
    return svg('K114-AM041',txt(450,42,'BLSにおける体位',26,weight=700)+option_grid([pose('supine'),pose('side'),pose('supine'),pose('supine')]))
def q114_051():
    b=txt(450,42,'胸部横断面（独自模式図）',26,weight=700)
    b+=path('M180 320 Q220 115 450 100 Q680 115 720 320 Q680 510 450 525 Q220 510 180 320 Z',4,INK,SOFT)
    b+=path('M235 315 Q255 165 400 155 Q410 310 385 450 Q260 445 235 315 Z',3,ACC,'#dce8ef')
    b+=path('M500 165 Q650 170 675 315 Q650 450 510 450 Q485 315 500 165 Z',3,ACC,'#dce8ef')
    # right lung (viewer left) is collapsed medially; pleural air area around it
    b+=path('M235 315 Q250 165 400 155',7,'#7da3bd')+txt(300,250,'胸腔内の空気',20,c=ACC)+txt(330,365,'縮小した右肺',20,c=INK)
    b+=txt(205,115,'患者の右',18,c=MUTED)+txt(695,115,'患者の左',18,c=MUTED)
    return svg('K114-AM051',b)
def q114_054():
    b=txt(450,42,'成人の骨髄穿刺部位',26,weight=700)
    b+=stick(270,270,'stand',1.05)+txt(270,515,'前面',18,c=MUTED)+stick(630,270,'stand',1.05)+txt(630,515,'背面',18,c=MUTED)
    pts=[(270,245),(630,275),(610,350),(650,395)]
    for i,(x,y) in enumerate(pts,1):b+=circle(x,y,16,WARM,3,ACC)+txt(x,y+6,str(i),16,weight=700,c=ACC)
    b+=path('M590 345 Q630 325 670 345',4,INK)+txt(630,565,'③：後腸骨稜付近',18,c=MUTED)
    return svg('K114-AM054',b)
def q114_107():
    b=txt(450,42,'小児ベッド周辺の状況（独自模式図）',26,weight=700)
    b+=rect(170,190,470,270,'#fafafa',5,INK,6)
    for x in range(190,640,45):b+=line(x,195,x,455,4,MUTED)
    b+=stick(430,330,'stand',.72)+circle(300,385,46,WARM,3,ACC)+txt(300,393,'ぬいぐるみ',14,c=ACC)
    b+=line(650,170,650,470,6,MUTED)+circle(650,480,8,MUTED,1,MUTED)+rect(625,120,50,55,SOFT,2,ACC,4)
    b+=path('M650 170 C620 250 560 235 500 300',4,ACC)+txt(735,235,'点滴ルート',17,c=ACC)
    b+=txt(450,555,'児は柵越しに手を伸ばしている',18,c=MUTED)
    return svg('K114-AM107',b)
def q114_pm019():
    b=txt(450,42,'長期臥床時の足部ポジショニング',26,weight=700)
    b+=stick(410,280,'supine',1.25)+rect(650,250,95,150,WARM,3,ACC,22)+txt(760,330,'A',30,weight=700,c=ACC)+path('M745 330 L700 330',4,ACC)+path('M700 330 l15 -10 l0 20',3,ACC,ACC)
    b+=txt(450,530,'足底側から支えて足関節を中間位に保つ',19,c=MUTED)
    return svg('K114-PM019',b)
def q114_pm045():
    b=txt(450,42,'成人胸骨圧迫の位置',26,weight=700)
    b+=path('M330 115 Q280 160 300 450 M570 115 Q620 160 600 450 M450 105 L450 420',4,INK)
    b+=line(400,135,500,135,6,MUTED)+path('M390 210 Q450 235 510 210',3,MUTED)
    pts=[(400,210),(520,265),(450,395),(450,310)]
    for i,(x,y) in enumerate(pts,1):b+=circle(x,y,17,WARM,3,ACC)+txt(x,y+6,str(i),16,weight=700,c=ACC)
    b+=txt(450,520,'④：胸部中央・胸骨下半分',18,c=MUTED)
    return svg('K114-PM045',b)
def q113_023():
    colors=[BLACK,RED,YELLOW,GREEN]
    b=txt(450,42,'トリアージ区分（独自カード）',26,weight=700)
    for i,(x,c) in enumerate(zip([95,305,515,725],colors),1):
        b+=rect(x-75,150,150,280,'white',3,INK,10)+rect(x-75,340,150,90,c,0,c,0)+txt(x,120,str(i),25,weight=700,c=ACC)
        b+=txt(x,390,['0','I','II','III'][i-1],24,weight=700,c='white' if c!=YELLOW else INK)
    b+=txt(450,510,'待機的治療群は黄色（II）',20,c=MUTED)
    return svg('K113-AM023',b)
def q113_027():
    b=txt(450,42,'舌背の模式図',26,weight=700)
    b+=path('M300 130 Q450 70 600 130 Q620 390 450 515 Q280 390 300 130 Z',4,INK,SOFT)
    # circumvallate back row, fungiform tip, foliate sides, filiform central
    for i in range(7):b+=circle(360+i*30,170,8,WARM,2,ACC)
    for i in range(8):b+=circle(380+i*20,440+(i%2)*8,5,WARM,1,ACC)
    for y in range(235,370,30):
        for x in range(365,545,35):b+=line(x,y,x+8,y-12,2,MUTED)
    pts=[(450,450),(450,300),(575,255),(320,280)]
    for i,(x,y) in enumerate(pts,1):b+=circle(x,y,15,'white',3,ACC)+txt(x,y+6,str(i),16,weight=700,c=ACC)
    return svg('K113-AM027',b)
def q113_034():
    b=txt(450,42,'心音の代表的聴取部位',26,weight=700)
    b+=path('M320 100 Q270 160 300 500 M580 100 Q630 160 600 500',4,INK)
    pts=[(385,205),(515,205),(525,370),(390,315)]
    for i,(x,y) in enumerate(pts,1):b+=circle(x,y,16,WARM,3,ACC)+txt(x,y+6,str(i),16,weight=700,c=ACC)
    b+=txt(450,545,'③：左第5肋間・心尖部',18,c=MUTED)
    return svg('K113-AM034',b)
def q113_035():
    b=txt(450,42,'滅菌手袋を素手で持ち上げる位置',26,weight=700)
    # two glove silhouettes, numbered palm/cuff regions
    for cx in (330,570):
        b+=path(f'M{cx-65} 170 Q{cx-80} 90 {cx-35} 115 L{cx-20} 70 Q{cx} 55 {cx+10} 85 L{cx+30} 75 Q{cx+50} 75 {cx+45} 110 Q{cx+90} 120 {cx+65} 190 L{cx+70} 365 L{cx-70} 365 Z',4,INK,SOFT)
    pts=[(330,210),(570,210),(330,325),(570,325)]
    for i,(x,y) in enumerate(pts,1):b+=circle(x,y,18,'white',3,ACC)+txt(x,y+7,str(i),18,weight=700,c=ACC)
    b+=txt(450,535,'素手が触れるのは折り返したカフの内面',18,c=MUTED)
    return svg('K113-AM035',b)
def q113_046():
    def spoon(x,y,w,h):return circle(x+140,y+115,32,'white',3,ACC)+line(x+165,y+135,x+270,y+185,14,MUTED)+rect(x+95,y+70,90,75,WARM,3,ACC,22)+txt(x+195,y+218,'万能カフ',17)
    def brush(x,y,w,h):return line(x+105,y+180,x+270,y+60,20,MUTED)+rect(x+250,y+45,65,45,WARM,3,ACC,10)+txt(x+195,y+218,'長柄ブラシ',17)
    def cup(x,y,w,h):return rect(x+130,y+75,120,105,'white',3,ACC,20)+path(f'M{x+250} {y+100} Q{x+310} {y+120} {x+250} {y+155}',6,ACC)+txt(x+195,y+218,'コップホルダー',17)
    def button(x,y,w,h):return rect(x+110,y+125,170,30,WARM,3,ACC,14)+line(x+280,y+140,x+320,y+85,5,ACC)+txt(x+195,y+218,'ボタンエイド',17)
    return svg('K113-AM046',txt(450,42,'関節保護に使う自助具',26,weight=700)+option_grid([spoon,brush,cup,button]))
def q113_110():
    def feed(kind):
        def d(x,y,w,h):
            z=stick(x+195,y+110,'stand',.55)+circle(x+220,y+145,18,WARM,2,ACC)
            if kind==1:z+=rect(x+80,y+145,190,35,SOFT,2,MUTED,16)
            elif kind==2:z+=path(f'M{x+120} {y+165} Q{x+195} {y+120} {x+270} {y+165}',8,MUTED)
            elif kind==3:z+=line(x+210,y+145,x+300,y+150,9,ACC)+circle(x+315,y+150,15,WARM,2,ACC)
            else:z+=line(x+165,y+145,x+245,y+170,8,ACC)
            return z
        return d
    return svg('K113-AM110',txt(450,42,'授乳姿勢（独自模式図）',26,weight=700)+option_grid([feed(1),feed(2),feed(3),feed(4)]))
def q113_pm054():
    def tri(x,y,w,h):return circle(x+150,y+150,45,'white',4,ACC)+circle(x+250,y+150,45,'white',4,ACC)+circle(x+195,y+90,45,'white',4,ACC)+line(x+195,y+65,x+195,y+155,6,INK)
    def rattle(x,y,w,h):return circle(x+195,y+100,38,WARM,3,ACC)+line(x+195,y+138,x+195,y+190,14,MUTED)+circle(x+195,y+205,24,'white',3,ACC)
    def mobile(x,y,w,h):return line(x+195,y+55,x+195,y+100,4)+line(x+105,y+100,x+285,y+100,4)+circle(x+125,y+150,20,WARM,2,ACC)+circle(x+195,y+175,20,WARM,2,ACC)+circle(x+265,y+150,20,WARM,2,ACC)
    def push(x,y,w,h):return rect(x+115,y+125,160,80,WARM,4,ACC,10)+circle(x+140,y+210,26,'white',4,ACC)+circle(x+250,y+210,26,'white',4,ACC)+line(x+250,y+125,x+290,y+55,8,INK)+line(x+290,y+55,x+335,y+55,8,INK)
    return svg('K113-PM054',txt(450,42,'1歳4か月頃の遊具',26,weight=700)+option_grid([tri,rattle,mobile,push]))
def q113_pm066():
    def cane(x,y,w,h):return line(x+195,y+55,x+195,y+185,8,INK)+line(x+155,y+185,x+235,y+185,7,INK)+line(x+155,y+185,x+140,y+205,6)+line(x+195,y+185,x+195,y+210,6)+line(x+235,y+185,x+250,y+205,6)
    def crutch(x,y,w,h):return line(x+150,y+55,x+170,y+200,7)+line(x+240,y+55,x+220,y+200,7)+line(x+150,y+70,x+240,y+70,7)+line(x+195,y+200,x+195,y+215,6)
    def chair(x,y,w,h):return circle(x+150,y+175,55,'white',5,ACC)+circle(x+260,y+195,25,'white',4,ACC)+rect(x+150,y+95,110,70,SOFT,4,INK,6)+line(x+260,y+110,x+290,y+70,6)
    def walker(x,y,w,h):return line(x+125,y+65,x+105,y+190,8,INK)+line(x+265,y+65,x+285,y+190,8,INK)+line(x+125,y+65,x+265,y+65,8,INK)+line(x+115,y+145,x+275,y+145,7,INK)+circle(x+105,y+205,20,'white',4,ACC)+circle(x+285,y+205,20,'white',4,ACC)+rect(x+145,y+115,100,55,WARM,3,ACC,8)
    return svg('K113-PM066',txt(450,42,'屋外歩行を支える福祉用具',26,weight=700)+option_grid([cane,crutch,chair,walker]))

BUILDERS={
'K115-AM013':q115_013,'K115-AM016':q115_016,'K115-AM022':q115_022,'K115-AM034':q115_034,'K115-AM063':q115_063,'K115-PM020':q115_pm020,
'K114-AM013':q114_013,'K114-AM030':q114_030,'K114-AM039':q114_039,'K114-AM041':q114_041,'K114-AM051':q114_051,'K114-AM054':q114_054,'K114-AM107':q114_107,'K114-PM019':q114_pm019,'K114-PM045':q114_pm045,
'K113-AM023':q113_023,'K113-AM027':q113_027,'K113-AM034':q113_034,'K113-AM035':q113_035,'K113-AM046':q113_046,'K113-AM110':q113_110,'K113-PM054':q113_pm054,'K113-PM066':q113_pm066}

rows=[]; audit=[]
for qid in IDS:
    content=BUILDERS[qid]()
    if '<image' in content.lower() or 'data:image' in content.lower() or 'http://' in content.lower() or 'https://' in content.lower():
        raise SystemExit(f'{qid}: SVG must be self-contained original vectors')
    p=OUT/f'{qid}.svg'; p.write_text(content,encoding='utf-8')
    q=INDEX[qid]
    rows.append({
        'id':qid,'mediaReleaseStatus':'resolved','mediaRightsStatus':'original_authored',
        'mediaAssets':[f'media/redraw/{qid}.svg'],
        'mediaAttribution':'学びスプリント独自再作図（公式設問の学習上必要な情報を独自の線画・模式図で再構成）',
        'mediaSourceUrl':q.get('questionPdf'),'mediaProcessed':True,'mediaResolutionMethod':'original_redraw'
    })
    audit.append({'id':qid,'answer':q.get('answer'),'asset':f'media/redraw/{qid}.svg','selfContainedSvg':True,'sourceExam':q.get('sourceExam'),'questionNo':q.get('questionNo')})

resolution={'schemaVersion':1,'generatedBy':'build_original_redraw_assets.py','items':rows}
(ROOT/'media-redraw-resolutions.json').write_text(json.dumps(resolution,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
report={'schemaVersion':1,'target':23,'generated':len(rows),'ids':IDS,'items':audit,'pass':len(rows)==23 and len({r['id'] for r in rows})==23}
(ROOT/'media-redraw-audit.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'generated':len(rows),'pass':report['pass']},ensure_ascii=False))
