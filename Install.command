#!/bin/bash
DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$DIR"
./install.sh
echo ""
read -p "Press [Enter] to close..."
