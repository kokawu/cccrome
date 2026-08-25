# Local Chromium Build Workflow

This workspace now has two build directories:

- `src/out/Default`: stable build that already completed end-to-end
- `src/out/FastDev`: daily development build tuned for faster iteration

Use the wrapper from `d:\ccchrome`:

```powershell
.\ccbuild.ps1 env
.\ccbuild.ps1 hooks
.\ccbuild.ps1 gen FastDev
.\ccbuild.ps1 build FastDev chrome
.\ccbuild.ps1 build Default chrome
```

Or from `cmd.exe`:

```bat
ccbuild.cmd env
ccbuild.cmd hooks
ccbuild.cmd gen FastDev
ccbuild.cmd build FastDev chrome
ccbuild.cmd build Default chrome
```

What the wrapper fixes for you every time:

- prepends `D:\ccchrome\depot_tools` to `PATH`
- sets `DEPOT_TOOLS_UPDATE=0`
- sets `DEPOT_TOOLS_WIN_TOOLCHAIN=0`
- sets `vs2026_install=D:\ccchrome\vs_buildtools`

Recommended workflow after a source update:

1. `gclient sync`
2. `.\ccbuild.ps1 hooks`
3. `.\ccbuild.ps1 gen FastDev`
4. `.\ccbuild.ps1 build FastDev chrome`

`FastDev` is tuned for iteration speed and uses lower symbol levels for
Chromium/Blink/V8 while keeping component build enabled.
