#!/usr/bin/env python3
from pathlib import Path
import sys

path = Path(sys.argv[1]) / 'lib/widgets/edit_dialogs.dart'
text = path.read_text(encoding='utf-8')
text = text.replace(
    "import 'package:flutter/material.dart';",
    "import 'dart:async';\n\nimport 'package:flutter/material.dart';",
    1,
)
replacements = {
    "  name.dispose();\n  objective.dispose();\n  nextAction.dispose();\n":
        "  _disposeControllersAfterRoute([name, objective, nextAction]);\n",
    "  name.dispose();\n  role.dispose();\n  limitNote.dispose();\n":
        "  _disposeControllersAfterRoute([name, role, limitNote]);\n",
    "  title.dispose();\n  notes.dispose();\n":
        "  _disposeControllersAfterRoute([title, notes]);\n",
    "  summary.dispose();\n  decisions.dispose();\n  output.dispose();\n  nextAction.dispose();\n":
        "  _disposeControllersAfterRoute([summary, decisions, output, nextAction]);\n",
    "  title.dispose();\n  version.dispose();\n  content.dispose();\n":
        "  _disposeControllersAfterRoute([title, version, content]);\n",
    "  title.dispose();\n  mitigation.dispose();\n":
        "  _disposeControllersAfterRoute([title, mitigation]);\n",
    "  name.dispose();\n  location.dispose();\n  notes.dispose();\n":
        "  _disposeControllersAfterRoute([name, location, notes]);\n",
}
for old, new in replacements.items():
    if old not in text:
        raise SystemExit(f'controller disposal block not found: {old!r}')
    text = text.replace(old, new, 1)
helper = '''void _disposeControllersAfterRoute(\n  List<TextEditingController> controllers,\n) {\n  Timer(const Duration(milliseconds: 350), () {\n    for (final controller in controllers) {\n      controller.dispose();\n    }\n  });\n}\n\n'''
marker = 'String _projectStatus(ProjectStatus value) => switch (value) {'
if marker not in text:
    raise SystemExit('dialog helper insertion point not found')
text = text.replace(marker, helper + marker, 1)
path.write_text(text, encoding='utf-8')
print('deferred dialog controller disposal until route animation completes')
