#!/bin/sh
SHORT=$(echo "$GITHUB_SHA" | cut -c1-7)
printf 'const BUILD := "%s"\n' "${GITHUB_RUN_NUMBER}-${SHORT}" > build_info.gd
cat build_info.gd
