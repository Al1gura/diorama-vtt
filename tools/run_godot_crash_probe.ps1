param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("minimal", "isolated", "original_recovery", "original_direct")]
    [string]$Case,

    [ValidateSet("window", "import", "runtime", "runtime_window")]
    [string]$ProbeMode = "window",

    [ValidateSet("none", "procdump")]
    [string]$CaptureMode = "procdump",

    [string]$RuntimeScene = "res://tests/p3_1_module_manifest_regressions.tscn",

    [switch]$UseCleanUserData,

    [ValidateRange(10, 60)]
    [int]$TimeoutSeconds = 30
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"
Set-StrictMode -Version Latest

# PowerShell Start-Process rejects inherited Windows environment blocks that
# contain both Path and PATH, even when their values are identical.
$processPath = $env:Path
[System.Environment]::SetEnvironmentVariable(
    "PATH", $null, [System.EnvironmentVariableTarget]::Process
)
[System.Environment]::SetEnvironmentVariable(
    "Path", $processPath, [System.EnvironmentVariableTarget]::Process
)

$projectRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$godotExe = "C:\Program Files\Godot_v4.7-stable_win64.exe"
$procDumpExe = Join-Path $projectRoot "build\diagnostics\sysinternals\procdump\procdump64.exe"
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$resultRoot = Join-Path $projectRoot ("build\crash_matrix\{0}_{1}" -f $timestamp, $Case)
$dumpDir = Join-Path $resultRoot "dumps"
$godotLog = Join-Path $resultRoot "godot.log"
$procDumpOut = Join-Path $resultRoot "procdump_stdout.log"
$procDumpErr = Join-Path $resultRoot "procdump_stderr.log"
$resultFile = Join-Path $resultRoot "result.json"

if (-not (Test-Path -LiteralPath $godotExe)) {
    throw "Godot executable not found: $godotExe"
}
if ($CaptureMode -eq "procdump" -and -not (Test-Path -LiteralPath $procDumpExe)) {
    throw "ProcDump executable not found: $procDumpExe"
}

$existingGodot = @(Get-Process -Name "Godot_v4.7-stable_win64" -ErrorAction SilentlyContinue)
if ($existingGodot.Count -gt 0) {
    $ids = ($existingGodot | ForEach-Object { $_.Id }) -join ", "
    throw "Refusing concurrent Godot launch. Existing PID(s): $ids"
}

New-Item -ItemType Directory -Force -Path $dumpDir | Out-Null

$projectPath = ""
$cleanUserData = $UseCleanUserData.IsPresent
$recoveryMode = $false
switch ($Case) {
    "minimal" {
        $projectPath = Join-Path $projectRoot "build\diagnostics\minimal_4_7"
        $cleanUserData = $true
    }
    "isolated" {
        $projectPath = Join-Path $projectRoot "build\test_runs\p3_1_incremental_current"
        $cleanUserData = $true
        $recoveryMode = $true
    }
    "original_recovery" {
        $projectPath = $projectRoot
        $recoveryMode = $true
    }
    "original_direct" {
        $projectPath = $projectRoot
    }
}

if (-not (Test-Path -LiteralPath (Join-Path $projectPath "project.godot"))) {
    throw "Project not found: $projectPath"
}

$originalAppData = $env:APPDATA
$originalLocalAppData = $env:LOCALAPPDATA
if ($cleanUserData) {
    $env:APPDATA = Join-Path $resultRoot "user_data\Roaming"
    $env:LOCALAPPDATA = Join-Path $resultRoot "user_data\Local"
    New-Item -ItemType Directory -Force -Path $env:APPDATA | Out-Null
    New-Item -ItemType Directory -Force -Path $env:LOCALAPPDATA | Out-Null
}

if (-not ("NativeErrorMode" -as [type])) {
    Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public static class NativeErrorMode {
    [DllImport("kernel32.dll")]
    public static extern uint SetErrorMode(uint mode);
}
"@
}

$previousErrorMode = [NativeErrorMode]::SetErrorMode(0x8003)
$godotArguments = @()
if ($ProbeMode -eq "import") {
    $godotArguments += @("--headless", "--import", "--quit")
} elseif ($ProbeMode -eq "runtime") {
    $godotArguments += "--headless"
} elseif ($ProbeMode -eq "window") {
    $godotArguments += "--editor"
}
if ($recoveryMode -and $ProbeMode -in @("window", "import")) {
    $godotArguments += "--recovery-mode"
}
$godotArguments += @("--path", $projectPath)
if ($CaptureMode -eq "procdump") {
    $godotArguments += "--disable-crash-handler"
}
if ($ProbeMode -eq "window") {
    $godotArguments += @("--quit-after", "300")
} elseif ($ProbeMode -in @("runtime", "runtime_window")) {
    $godotArguments += @("--scene", $RuntimeScene)
}
$godotArguments += @("--log-file", $godotLog)

function Quote-Argument([string]$Value) {
    return '"' + $Value.Replace('"', '\"') + '"'
}

$procDumpArguments = @(
    "-accepteula",
    "-nobanner",
    "-ma",
    "-n", "1",
    "-e",
    "-x", (Quote-Argument $dumpDir),
    (Quote-Argument $godotExe)
)
foreach ($argument in $godotArguments) {
    $procDumpArguments += Quote-Argument ([string]$argument)
}

$startedAt = Get-Date
$procDumpProcess = $null
$godotProcess = $null
$windowObserved = $false
$windowProbeComplete = $false
$windowFirstObservedAt = $null
$gracefulCloseRequested = $false
$gracefulCloseSucceeded = $false
$timedOut = $false
$forcedCleanup = $false
$exitCode = $null
$errorText = ""

try {
    if ($CaptureMode -eq "procdump") {
        $procDumpProcess = Start-Process `
            -FilePath $procDumpExe `
            -ArgumentList ($procDumpArguments -join " ") `
            -PassThru `
            -WindowStyle Hidden `
            -RedirectStandardOutput $procDumpOut `
            -RedirectStandardError $procDumpErr

        $discoverDeadline = (Get-Date).AddSeconds(10)
        while ((Get-Date) -lt $discoverDeadline -and $null -eq $godotProcess) {
            Start-Sleep -Milliseconds 100
            $candidates = @(
                Get-Process -Name "Godot_v4.7-stable_win64" -ErrorAction SilentlyContinue |
                    Where-Object { $_.StartTime -ge $startedAt.AddSeconds(-1) }
            )
            if ($candidates.Count -gt 1) {
                throw "Probe created more than one Godot process."
            }
            if ($candidates.Count -eq 1) {
                $godotProcess = $candidates[0]
            }
        }

        if ($null -eq $godotProcess) {
            throw "ProcDump did not create a detectable Godot process within 10 seconds."
        }
    } else {
        $directArguments = @()
        foreach ($argument in $godotArguments) {
            $directArguments += Quote-Argument ([string]$argument)
        }
        $godotProcess = Start-Process `
            -FilePath $godotExe `
            -ArgumentList ($directArguments -join " ") `
            -PassThru
    }

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    while (-not $godotProcess.HasExited -and (Get-Date) -lt $deadline) {
        $godotProcess.Refresh()
        if ($godotProcess.MainWindowHandle -ne 0) {
            $windowObserved = $true
            if ($null -eq $windowFirstObservedAt) {
                $windowFirstObservedAt = Get-Date
            }
            if (
                $ProbeMode -eq "window" `
                -and ((Get-Date) - $windowFirstObservedAt).TotalSeconds -ge 5
            ) {
                $windowProbeComplete = $true
                break
            }
        }
        Start-Sleep -Milliseconds 100
    }

    if (-not $godotProcess.HasExited) {
        if ($ProbeMode -eq "window" -and $windowProbeComplete) {
            $gracefulCloseRequested = $true
            $null = $godotProcess.CloseMainWindow()
            $gracefulCloseSucceeded = $godotProcess.WaitForExit(10000)
        } else {
            $timedOut = $true
        }
        if (-not $godotProcess.HasExited) {
            Stop-Process -Id $godotProcess.Id -Force
            $forcedCleanup = $true
            $null = $godotProcess.WaitForExit(3000)
        }
    }

    if ($godotProcess.HasExited) {
        $exitCode = $godotProcess.ExitCode
    }
} catch {
    $errorText = $_.Exception.Message
} finally {
    if ($null -ne $godotProcess -and -not $godotProcess.HasExited) {
        Stop-Process -Id $godotProcess.Id -Force -ErrorAction SilentlyContinue
        $forcedCleanup = $true
    }

    if ($CaptureMode -eq "procdump" -and $null -ne $godotProcess) {
        & $procDumpExe -accepteula -nobanner -cancel $godotProcess.Id 2>$null | Out-Null
    }
    if ($null -ne $procDumpProcess) {
        $null = $procDumpProcess.WaitForExit(10000)
        if (-not $procDumpProcess.HasExited) {
            Stop-Process -Id $procDumpProcess.Id -Force -ErrorAction SilentlyContinue
        }
    }

    $null = [NativeErrorMode]::SetErrorMode($previousErrorMode)
    $env:APPDATA = $originalAppData
    $env:LOCALAPPDATA = $originalLocalAppData
}

if (
    $null -eq $exitCode `
    -and $CaptureMode -eq "procdump" `
    -and (Test-Path -LiteralPath $procDumpOut)
) {
    $procDumpText = [System.IO.File]::ReadAllText(
        $procDumpOut, [System.Text.Encoding]::Unicode
    )
    $exitCodeMatch = [regex]::Match(
        $procDumpText, "Exit Code 0x([0-9A-Fa-f]{8})"
    )
    if ($exitCodeMatch.Success) {
        $exitCode = [Convert]::ToUInt32($exitCodeMatch.Groups[1].Value, 16)
    }
}

$dumps = @(
    Get-ChildItem -LiteralPath $dumpDir -File -Filter "*.dmp" -ErrorAction SilentlyContinue |
        Select-Object Name, Length, LastWriteTime
)
$remainingGodot = @(Get-Process -Name "Godot_v4.7-stable_win64" -ErrorAction SilentlyContinue)

$result = [ordered]@{
    case = $Case
    probe_mode = $ProbeMode
    capture_mode = $CaptureMode
    project_path = $projectPath
    runtime_scene = if ($ProbeMode -in @("runtime", "runtime_window")) { $RuntimeScene } else { $null }
    clean_user_data = $cleanUserData
    started_at = $startedAt.ToString("o")
    timeout_seconds = $TimeoutSeconds
    godot_pid = if ($null -ne $godotProcess) { $godotProcess.Id } else { $null }
    window_observed = $windowObserved
    window_probe_complete = $windowProbeComplete
    graceful_close_requested = $gracefulCloseRequested
    graceful_close_succeeded = $gracefulCloseSucceeded
    timed_out = $timedOut
    forced_cleanup = $forcedCleanup
    exit_code = $exitCode
    dump_count = $dumps.Count
    dumps = $dumps
    remaining_godot_pids = @($remainingGodot | ForEach-Object { $_.Id })
    error = $errorText
    godot_log = $godotLog
    procdump_stdout = $procDumpOut
    procdump_stderr = $procDumpErr
}

$result | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $resultFile -Encoding UTF8
$result | ConvertTo-Json -Depth 5

if ($remainingGodot.Count -gt 0) {
    exit 3
}
if (-not [string]::IsNullOrEmpty($errorText)) {
    exit 2
}
exit 0
