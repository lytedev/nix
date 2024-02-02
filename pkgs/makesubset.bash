#!/usr/bin/env bash

echo "out: $out"
echo "src: $src"
echo "BASE_FONTS: $BASE_FONTS"
echo "srcs: $srcs"
mkdir -p "$out/share/fonts/truetype"
for f in "$src"/dist/iosevkalyteweb/woff2/*.woff2; do
	if [[ $f == *".subset.woff2"* ]]; then
		pyftsubset "$f" --name-IDs+=0,4,6 --text-file=./subset-glyphs.txt --flavor=woff2 &
	fi
done
wait
mv ./dist/iosevkalyteweb/woff2/*.subset.woff2 ./dist/iosevkalyteweb/woff2-subset/
touch ./dist/iosevkalyteweb/woff2-subset/
