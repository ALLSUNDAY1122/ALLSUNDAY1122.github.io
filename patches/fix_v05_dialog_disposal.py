#!/usr/bin/env python3
from pathlib import Path
import os
import runpy
import traceback

log_path = Path(os.environ.get('RUNNER_TEMP', '/tmp')) / 'logs' / 'v05-disposal-wrapper.log'
log_path.parent.mkdir(parents=True, exist_ok=True)
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
