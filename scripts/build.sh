#!/bin/sh
# Build only. Never install or load a module, and never modify boot files.
set -eu

mode=${1:-embedded}
case "$mode" in
    embedded|module) ;;
    *) echo "Usage: $0 [embedded|module]" >&2; exit 2 ;;
esac

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
build="$root/.build/kernel"
swiftc=${SWIFTC:-swiftc}
swift=${SWIFT:-swift}
cc=${CC:-cc}

if [ "$(uname -m)" != aarch64 ]; then
    echo "This prototype and its executable ABI test require an AArch64 host." >&2
    exit 1
fi
mkdir -p "$build"

# No heap, OS runtime, SIMD/FP, TLS, or reserved x18 use is permitted.
# Disabling runtime linking is paired with a strict unresolved-symbol audit.
"$swiftc" "$root/Sources/ANECore/ANECore.swift" \
    -module-name ANECore -swift-version 6 \
    -enable-experimental-feature Embedded -whole-module-optimization \
    -parse-as-library -Osize -no-allocations -warnings-as-errors \
    -target aarch64-none-none-elf \
    -Xfrontend -disable-stack-protector -Xfrontend -function-sections \
    -Xllvm -link-embedded-runtime=0 \
    -Xcc -mgeneral-regs-only -Xcc -ffixed-x18 \
    -Xcc -mbranch-protection=standard \
    -Xcc -ffreestanding -Xcc -fno-pic -Xcc -fno-pie \
    -Xcc -fno-unwind-tables -Xcc -fno-asynchronous-unwind-tables \
    -c -o "$build/ane_core.o"

# Swift emits these even for freestanding code. Refuse nonempty autolinking
# metadata before removing the empty markers that Linux modpost rejects.
"$swift" build --package-path "$root" --product audit-object
bin_path=$("$swift" build --package-path "$root" --show-bin-path)
"$bin_path/audit-object" "$build/ane_core.o"
"${OBJCOPY:-objcopy}" --remove-section=.swift1_autolink_entries \
    --remove-section=.linker-options "$build/ane_core.o"
"$bin_path/audit-object" "$build/ane_core.o"
"$cc" -std=c11 -Wall -Wextra -Werror -no-pie \
    "$root/Tests/ABISmoke/main.c" "$build/ane_core.o" -o "$build/abi-smoke"
"$build/abi-smoke"

if [ "$mode" = embedded ]; then
    exit 0
fi

release=$(uname -r)
headers=${KDIR:-/lib/modules/$release/build}
if [ -z "${KDIR:-}" ] && [ ! -d "$headers" ]; then
    headers="$root/.build/headers/usr/lib/modules/$release/build"
fi
if [ ! -r "$headers/include/config/kernel.release" ]; then
    echo "Matching kernel headers missing. Set KDIR to a prepared header tree for $release." >&2
    exit 1
fi
headers=$(CDPATH= cd -- "$headers" && pwd)
if [ "$(cat "$headers/include/config/kernel.release")" != "$release" ]; then
    echo "Header release does not match running kernel $release; refusing module build." >&2
    exit 1
fi
# These need integration beyond this uninstrumented Swift prototype.
if grep -Eq '^CONFIG_(CFI|CFI_CLANG|SHADOW_CALL_STACK)=y$' "$headers/.config"; then
    echo "CFI/Shadow Call Stack kernels are not supported by this prototype." >&2
    exit 1
fi

# A matching pahole is needed when the kernel enables module BTF metadata.
if ! command -v pahole >/dev/null 2>&1 && [ -x "$root/.build/tools/usr/bin/pahole" ]; then
    PATH="$root/.build/tools/usr/bin:$PATH"
    LD_LIBRARY_PATH="$root/.build/tools/usr/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
    export PATH LD_LIBRARY_PATH
fi
if grep -q '^CONFIG_DEBUG_INFO_BTF_MODULES=y$' "$headers/.config"; then
    if ! command -v pahole >/dev/null 2>&1; then
        echo "Module BTF requires pahole. Put it on PATH; no module was installed." >&2
        exit 1
    fi
fi

cp "$root/Kernel/module.c" "$root/Kernel/ane_core.h" "$root/Kernel/Kbuild" "$build/"
make -C "$headers" M="$build" W=1 modules
printf '\nBuilt (NOT loaded): %s/swift_ane_probe.ko\n' "$build"
modinfo "$build/swift_ane_probe.ko"
