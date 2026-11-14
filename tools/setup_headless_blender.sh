#!/usr/bin/env bash
#
# Build a headless Blender (bpy) environment so tools/build_soul_blender.py can
# run on a machine with no display.
#
# The sandbox this project is developed in has no X11/GL libraries installed and
# loses /tmp between restarts, so this has to be re-run whenever the container
# is recycled. Everything it creates lives under /tmp on purpose.
#
# Usage:  bash tools/setup_headless_blender.sh
# Then:   LD_LIBRARY_PATH=/tmp/x11stubs /tmp/bvenv/bin/python tools/build_soul_blender.py

set -euo pipefail

VENV=/tmp/bvenv
STUBS=/tmp/x11stubs
BPY_VERSION=5.0.1

echo "==> creating venv at $VENV"
python3 -m venv "$VENV"
"$VENV/bin/pip" install --quiet --no-cache-dir "bpy==${BPY_VERSION}" numpy pillow

echo "==> building X11/GL stubs at $STUBS"
mkdir -p "$STUBS"
cd "$STUBS"

# Seed empty shims so the DT_NEEDED entries resolve at all. Symbol resolution is
# lazy, so an empty .so is enough until something actually calls into it.
printf '/* headless stub */\n' > seed.c
for lib in libGL.so.1 libGLX.so.0 libOpenGL.so.0 libX11.so.6 libXi.so.6 \
           libXrender.so.1 libXext.so.6 libxkbcommon.so.0 libICE.so.6 \
           libSM.so.6 libXt.so.6 libXfixes.so.3; do
    gcc -shared -fPIC -o "$lib" seed.c
done

# Blender's own libs reference real GL/X11 entry points. Stub only the symbols
# that look like GL/X11 and that nothing else in the system provides -- stubbing
# everything shadows real libc symbols and segfaults the interpreter.
echo "==> resolving missing symbols (iterative)"
python3 - "$VENV" "$STUBS" <<'PY'
import subprocess, glob, re, os, sys

venv, stubs = sys.argv[1], sys.argv[2]
py = os.path.join(venv, "bin", "python")
libs = glob.glob(os.path.join(venv, "lib", "python3.*", "site-packages", "bpy", "lib", "*.so*")) + \
       glob.glob(os.path.join(venv, "lib", "python3.*", "site-packages", "bpy", "__init__.so"))
base = os.path.join(stubs, "glstub.c")
extra_file = os.path.join(stubs, "extra.txt")
extra = set(open(extra_file).read().split()) if os.path.exists(extra_file) else set()

PAT = re.compile(r"^(gl[A-Z]|glX|GL_|EGL|egl|X[A-Z]|xcb_|Xkb)")
NAMES = ["libGL.so.1", "libGLX.so.0", "libOpenGL.so.0", "libX11.so.6", "libXi.so.6",
         "libXrender.so.1", "libXext.so.6", "libxkbcommon.so.0", "libICE.so.6",
         "libSM.so.6", "libXt.so.6", "libXfixes.so.3"]

for it in range(90):
    syms = set(extra)
    for f in libs:
        out = subprocess.run(["nm", "-D", "--undefined-only", f],
                             capture_output=True, text=True).stdout
        for line in out.splitlines():
            p = line.split()
            if len(p) >= 2 and p[0] == "U" and PAT.match(p[-1]):
                syms.add(p[-1])
    with open(base, "w") as fh:
        fh.write("/* auto-generated headless stub */\n#include <stddef.h>\n")
        for s in sorted(syms):
            fh.write(f"void {s}(void) {{ }}\n")
    for n in NAMES:
        subprocess.run(["gcc", "-shared", "-fPIC", "-o", os.path.join(stubs, n), base], check=True)

    r = subprocess.run([py, "-c", "import bpy; print('OK', bpy.app.version_string)"],
                       capture_output=True, text=True,
                       env={**os.environ, "LD_LIBRARY_PATH": stubs})
    if "OK" in r.stdout:
        open(extra_file, "w").write("\n".join(sorted(extra)))
        print(f"    iteration {it}: {r.stdout.strip()} ({len(syms)} symbols stubbed)")
        sys.exit(0)
    m = re.search(r"undefined symbol: (\w+)", r.stderr)
    if not m:
        sys.stderr.write("gave up; last stderr:\n" + r.stderr[-800:] + "\n")
        sys.exit(1)
    extra.add(m.group(1))

sys.stderr.write("gave up after 90 iterations\n")
sys.exit(1)
PY

echo "==> verifying"
LD_LIBRARY_PATH="$STUBS" "$VENV/bin/python" -c "import bpy; print('bpy', bpy.app.version_string, '-- headless OK')"

echo
echo "Ready. Build the Soul with:"
echo "  LD_LIBRARY_PATH=$STUBS $VENV/bin/python tools/build_soul_blender.py"
