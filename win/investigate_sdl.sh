#!/bin/bash
cd /home/keith/dev/steamcontroller-test || exit 1
echo "=== SDL submodule version (the reference we read) ==="
grep -rhE '#define SDL_(MAJOR|MINOR|MICRO|PATCHLEVEL)_VERSION ' SDL/include 2>/dev/null | head -6
echo "=== Triton driver present in SDL submodule? ==="
[ -f SDL/src/joystick/hidapi/SDL_hidapi_steam_triton.c ] && echo "  -> SDL_hidapi_steam_triton.c EXISTS"
echo "=== Voidlink linked SDL lib files ==="
ls Voidlink/libs/SDL2/lib/iOS/ 2>/dev/null
echo "--- Voidlink SDL include version ---"
grep -rhE '#define SDL_(MAJOR|MINOR|MICRO|PATCHLEVEL)_VERSION ' Voidlink/libs/SDL2/include 2>/dev/null | head -6
echo "=== Voidlink libSDL2 exported hid symbols? ==="
nm Voidlink/libs/SDL2/lib/iOS/libSDL2.a 2>/dev/null | grep -iE ' (T|t) _?(SDL_)?hid_(init|open_path|read_timeout|enumerate|send_feature_report|write)' | head -16
echo "(end hid symbols)"
echo "=== does the Voidlink SDL even ship the iOS BLE hid.m / steam hidapi? ==="
nm Voidlink/libs/SDL2/lib/iOS/libSDL2.a 2>/dev/null | grep -iE 'steam|100f6c|CoreBluetooth|HIDBLE' | head -8
echo "(end steam/ble symbols)"
echo "=== hid.m top 45 lines (includes + SDL-internal deps) ==="
sed -n '1,45p' SDL/src/hidapi/ios/hid.m
echo "=== hid.m: which SDL_ internal APIs does it call? ==="
grep -oE 'SDL_[A-Za-z_]+' SDL/src/hidapi/ios/hid.m 2>/dev/null | sort -u | head -40
