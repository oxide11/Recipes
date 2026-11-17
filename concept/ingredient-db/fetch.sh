#!/bin/sh
# Fetch the source data into raw/. The official downloads are listed in README.md; these GitHub
# mirrors were used for the first build because the official sites were not reachable from the build machine.
set -e
mkdir -p raw && cd raw
[ -d USDA-SR28 ] || git clone --depth 1 https://github.com/maxsu/USDA-SR28.git
[ -d cnf ] || git clone --depth 1 https://github.com/lovictor/cnf.git
[ -d food-shelflife-db ] || git clone --depth 1 https://github.com/jelera/food-shelflife-db.git
mkdir -p cnfx && (cd cnfx && unzip -oq ../cnf/cnf-fcen-csv.zip)
echo "ok. Now: python3 -I build.py && python3 -I validate.py"
