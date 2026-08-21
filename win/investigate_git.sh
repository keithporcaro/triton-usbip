#!/bin/bash
cd /home/keith/dev/steamcontroller-test || exit 1
echo "=== root .gitignore fork entries ==="
grep -nE 'Voidlink|SDL|Vibepollo' .gitignore 2>/dev/null || echo "(none in .gitignore)"
echo "=== .gitmodules ==="
cat .gitmodules 2>/dev/null || echo "(no .gitmodules)"
echo "=== Voidlink own git repo? ==="
if [ -e Voidlink/.git ]; then echo "YES Voidlink/.git"; else echo "NO Voidlink/.git"; fi
echo "=== root git tracks Voidlink/? ==="
n=$(git ls-files Voidlink/ 2>/dev/null | wc -l); echo "root-tracked files under Voidlink/: $n"
echo "=== Triton dir exists? ==="
ls -ld Voidlink/VoidLink/Triton 2>/dev/null || echo "(none)"
echo "=== libSDL2.a iOS hid_ symbols ==="
LIB=$(find Voidlink -name 'libSDL2.a' -path '*iOS*' 2>/dev/null | head -1)
echo "lib: ${LIB:-not found}"
if [ -n "$LIB" ]; then nm "$LIB" 2>/dev/null | grep -iE ' T _?hid_(open_path|read_timeout|enumerate|send_feature|write|init)' | head -12 || echo "(no hid_ T symbols found)"; fi
echo "=== VoidLink subdir layout (top) ==="
ls Voidlink/VoidLink 2>/dev/null | head -30
