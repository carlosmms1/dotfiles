#!/bin/bash

set -e

readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color

cd "$(dirname "$0")/../stow"

for dir in */; do
	echo -e "${CYAN}[]${NC} Stowing ${CYAN}${dir%/}${NC}"
	stow -t "$HOME" --restow "${dir%/}"
done
