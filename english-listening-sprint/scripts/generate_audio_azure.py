#!/usr/bin/env python3
"""Generate all lesson MP3 files with Azure Speech REST API.
Required environment variables: AZURE_SPEECH_KEY, AZURE_SPEECH_REGION
Usage: pip install requests && python scripts/generate_audio_azure.py
"""
import json, os, pathlib, sys, time
import requests
ROOT=pathlib.Path(__file__).resolve().parents[1]
KEY=os.getenv('AZURE_SPEECH_KEY')
REGION=os.getenv('AZURE_SPEECH_REGION')
FORCE=os.getenv('FORCE_REGEN')=='1'
REGION_FILTER=os.getenv('REGION_FILTER')
SLOT_FILTER=os.getenv('SLOT_FILTER')  # e.g. '03,04,05,06'
if not KEY or not REGION:
    sys.exit('AZURE_SPEECH_KEY と AZURE_SPEECH_REGION を環境変数に設定してください。')
lessons=json.loads((ROOT/'data'/'lessons.json').read_text(encoding='utf-8'))
if REGION_FILTER:
    lessons=[l for l in lessons if l['region']==REGION_FILTER]
if SLOT_FILTER:
    slots=set(SLOT_FILTER.split(','))
    lessons=[l for l in lessons if l['id'][2:]in slots]
url=f'https://{REGION}.tts.speech.microsoft.com/cognitiveservices/v1'
headers={'Ocp-Apim-Subscription-Key':KEY,'Content-Type':'application/ssml+xml','X-Microsoft-OutputFormat':'audio-24khz-96kbitrate-mono-mp3','User-Agent':'manabi-sprint-audio-builder'}
errors=[]
audio_maps=[]
for lesson in lessons:
    audio_maps.append(lesson['audio'])
    if 'short' in lesson and 'audio' in lesson['short']:
        audio_maps.append(lesson['short']['audio'])
total=0
for audio_map in audio_maps:
    for voice_id,a in audio_map.items():
        total+=1
        out=ROOT/a['path']; out.parent.mkdir(parents=True,exist_ok=True)
        if not FORCE and out.exists() and out.stat().st_size>1000:
            print('skip',out.relative_to(ROOT)); continue
        for attempt in range(3):
            try:
                r=requests.post(url,headers=headers,data=a['ssml'].encode('utf-8'),timeout=60)
                if r.status_code==200 and len(r.content)>1000:
                    out.write_bytes(r.content); print('ok  ',out.relative_to(ROOT),len(r.content)); break
                raise RuntimeError(f'HTTP {r.status_code}: {r.text[:300]}')
            except Exception as e:
                if attempt==2: errors.append((str(out),str(e)))
                else: time.sleep(2**attempt)
if errors:
    print('\n失敗:'); [print(p,e) for p,e in errors]; sys.exit(1)
print(f'\n{total}本の英語音声生成が完了しました（標準+短尺の両方を含む）。')
