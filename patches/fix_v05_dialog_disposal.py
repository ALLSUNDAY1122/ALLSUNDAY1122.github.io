#!/usr/bin/env python3
from pathlib import Path
import os
import runpy
import sys
import traceback

log_path = Path(os.environ.get('RUNNER_TEMP', '/tmp')) / 'logs' / 'v05-disposal-wrapper.log'
log_path.parent.mkdir(parents=True, exist_ok=True)
source_root = Path(sys.argv[1])
dialogs = source_root / 'lib/widgets/edit_dialogs.dart'
text = dialogs.read_text(encoding='utf-8')

if '_disposeControllersAfterRoute' in text:
    log_path.write_text('result=already_applied\n', encoding='utf-8')
    print('deferred dialog controller disposal already applied')
    raise SystemExit(0)

try:
    target = Path(__file__).with_name('fix_v05_dialog_controller_disposal.py')
    log_path.write_text(f'target={target}\nexists={target.exists()}\n', encoding='utf-8')
    runpy.run_path(str(target), run_name='__main__')
    with log_path.open('a', encoding='utf-8') as handle:
        handle.write('result=success\n')
except BaseException:
    with log_path.open('a', encoding='utf-8') as handle:
        handle.write('result=failure\n')
        handle.write(traceback.format_exc())
    raise
