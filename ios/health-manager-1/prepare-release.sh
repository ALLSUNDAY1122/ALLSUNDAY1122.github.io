#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# The release AppIcon must always be materialized from the user-approved
# First-class Health Manager artwork before Xcode compiles Assets.xcassets.
bash "$SCRIPT_DIR/prepare-approved-icon.sh"

# Then prepare and audit the 264-question web bundle. prepare-ios.sh also
# validates the resulting AppIcon slot dimensions.
bash "$SCRIPT_DIR/prepare-ios.sh"

echo "PASS: HM1 release preparation used checksum-verified approved AppIcon source"
