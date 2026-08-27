from pathlib import Path

p = Path('codemagic.yaml')
text = p.read_text(encoding='utf-8')
start = text.index('  health-manager-1-testflight:')
end = text.index('\n  health-manager-2-ios:', start)
block = text[start:end]

internal = "xcode-project use-profiles --custom-export-options='{\"testFlightInternalTestingOnly\": true}'"
release = 'xcode-project use-profiles'

if internal in block:
    block = block.replace(internal, release, 1)

if 'testFlightInternalTestingOnly' in block:
    raise SystemExit('HM1 still contains TestFlight Internal Only export option')
if release not in block:
    raise SystemExit('HM1 App Store signing command missing')
if 'submit_to_testflight: true' not in block:
    raise SystemExit('HM1 TestFlight publishing must remain enabled')
if 'submit_to_app_store: false' not in block:
    raise SystemExit('HM1 automatic App Store submission must remain disabled')

p.write_text(text[:start] + block + text[end:], encoding='utf-8')
print('PASS: HM1 build is TestFlight + App Store eligible; automatic App Store submission remains disabled')
