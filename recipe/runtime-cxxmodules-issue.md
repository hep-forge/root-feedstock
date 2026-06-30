# Known issue: runtime C++ modules load failures (native Linux, 6.38.04)

On native Linux, `runtime_cxxmodules` defaults to **ON** — it is only forced
`OFF` for cross-compilation in `build.sh` (under the
`target_platform != build_platform` guard). The C++ modules / PCH produced by
this build are not consistent with the runtime cling for a handful of
dictionaries, leaving the interpreter in a degraded state.

## Symptoms (clean conda env, native Linux package)

- `root -l -b -q` prints several `Failed to load module <X>` lines for the
  legacy 32-bit / split dictionary variants — observed:
  `complexDict`, `GenVector32`, `listDict`, `Smatrix32`.
- Those dictionaries' rootmap *forward-declaration* payloads fail to parse, e.g.
  `<.../libGenVector32.rootmap>:N: error: unknown type name 'line'`
  and `... unknown type name 'define'` — i.e. cling is receiving `#line` /
  `#define` lines without preprocessing them.
- The interpreter then mis-parses `#include`: a macro run (`root file.C`, which
  internally does `#include "file.C"`) yields
  `error: unknown type name 'include'`. As a result macros fail to load and
  TFile plugin registration (`etc/plugins/.../*.C`) errors out, so opening files
  through the interpreter breaks.

## Minimal reproduction

```sh
conda create -n roottest -c <channel> root=6.38.04
conda activate roottest

# nonzero count of failed modules:
root -l -b -q 2>&1 | grep -c "Failed to load module"

# interpreter mis-parses #include:
printf 'void m(){}\n' > /tmp/m.C
root -l -b -q /tmp/m.C 2>&1 | grep "unknown type name 'include'"
```

## Candidate fixes (evaluate on next rebuild)

- **Short term / most reliable:** drop the cross-compilation guard around
  `-Druntime_cxxmodules=OFF` so native Linux builds also disable runtime
  modules. ROOT then uses the traditional rootmap/header-parsing path, which
  does not exhibit these failures.
- **Proper fix:** investigate why the `*32` / split-dictionary pcms and their
  rootmap forward declarations are emitted with raw preprocessor directives that
  the runtime cling rejects (toolchain / clang resource-dir / PCH mismatch
  between build and run time).

## Scope

Compiled consumers that only use ROOT I/O are unaffected. This impacts the
**interpreter** (macros, plugin autoloading, cxxmodules-dependent workflows).
