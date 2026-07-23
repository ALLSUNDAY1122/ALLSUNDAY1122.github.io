#!/usr/bin/env python3
from pathlib import Path
import runpy

runpy.run_path(
    str(Path(__file__).with_name('fix_v05_dialog_controller_disposal.py')),
    run_name='__main__',
)
