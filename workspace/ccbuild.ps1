param(
  [ValidateSet("env", "hooks", "gen", "build")]
  [string]$Command = "build",

  [ValidateSet("Default", "FastDev")]
  [string]$Config = "FastDev",

  [string]$Target = "chrome"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$workspaceRoot = Split-Path -Parent $PSCommandPath
$srcRoot = Join-Path $workspaceRoot "src"
$depotTools = Join-Path $workspaceRoot "depot_tools"
$vsInstall = Join-Path $workspaceRoot "vs_buildtools"
$outDir = Join-Path $srcRoot ("out\" + $Config)

function Set-ChromiumBuildEnv {
  $env:PATH = "$depotTools;$env:PATH"
  $env:DEPOT_TOOLS_UPDATE = "0"
  $env:DEPOT_TOOLS_WIN_TOOLCHAIN = "0"
  $env:vs2026_install = $vsInstall
}

function Invoke-Step {
  param(
    [string]$Label,
    [scriptblock]$Body
  )

  Write-Host ("==> " + $Label)
  & $Body
  if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
  }
}

function Ensure-ArgsFile {
  $argsFile = Join-Path $outDir "args.gn"
  if (-not (Test-Path $argsFile)) {
    throw "Missing args.gn for $Config at $argsFile"
  }
}

Set-ChromiumBuildEnv

switch ($Command) {
  "env" {
    Write-Host ("Workspace : " + $workspaceRoot)
    Write-Host ("Source    : " + $srcRoot)
    Write-Host ("Config    : " + $Config)
    Write-Host ("Out Dir   : " + $outDir)
    Write-Host ("depot     : " + $depotTools)
    Write-Host ("vs2026    : " + $vsInstall)
    Write-Host ("toolchain : DEPOT_TOOLS_WIN_TOOLCHAIN=" + $env:DEPOT_TOOLS_WIN_TOOLCHAIN)
    exit 0
  }

  "hooks" {
    Push-Location $workspaceRoot
    try {
      Invoke-Step "gclient runhooks" {
        & (Join-Path $depotTools "gclient.bat") runhooks
      }
    } finally {
      Pop-Location
    }
    exit 0
  }

  "gen" {
    Ensure-ArgsFile
    Push-Location $srcRoot
    try {
      Invoke-Step ("gn gen " + $outDir) {
        & (Join-Path $depotTools "gn.bat") gen $outDir
      }
    } finally {
      Pop-Location
    }
    exit 0
  }

  "build" {
    Ensure-ArgsFile
    Push-Location $srcRoot
    try {
      if (-not (Test-Path (Join-Path $outDir "build.ninja"))) {
        Invoke-Step ("gn gen " + $outDir) {
          & (Join-Path $depotTools "gn.bat") gen $outDir
        }
      }

      Invoke-Step ("autoninja -C " + $outDir + " " + $Target) {
        & (Join-Path $depotTools "autoninja.bat") -C $outDir $Target
      }
    } finally {
      Pop-Location
    }
    exit 0
  }
}
