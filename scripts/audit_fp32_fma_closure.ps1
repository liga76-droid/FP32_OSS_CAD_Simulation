[CmdletBinding()]
param(
    [string]$ProjectRoot = (Get-Location).Path,
    [string]$YosysExe = "yosys",
    [switch]$SkipSimulation
)

$ErrorActionPreference = "Stop"
$ProjectRoot = (Resolve-Path $ProjectRoot).Path
$ReportDir = Join-Path $ProjectRoot "reports\closure"
New-Item -ItemType Directory -Force -Path $ReportDir | Out-Null

$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$report = Join-Path $ReportDir "closure_audit_$stamp.txt"
$yosysLog = Join-Path $ReportDir "yosys_full_$stamp.log"
$warnLog = Join-Path $ReportDir "yosys_warnings_$stamp.log"
$source = Join-Path $ProjectRoot "rtl\fp32_fma_ieee.sv"
$ys = Join-Path $ProjectRoot "scripts\yosys_ieee_check_corrected.ys"

function Log([string]$s) {
    $s | Tee-Object -FilePath $report -Append
}

"FP32 FMA closure audit - $stamp" | Set-Content $report
Log "Project root: $ProjectRoot"
Log "This script audits and gates the run; it does not silently patch RTL."

if (!(Test-Path $source)) { throw "Missing RTL: $source" }
if (!(Test-Path $ys)) { throw "Missing Yosys script: $ys" }

Log "`n=== 1. Source context around reported latch warnings ==="
$lines = Get-Content $source
$start = [Math]::Max(1, 148 - 12)
$end = [Math]::Min($lines.Count, 245 + 12)
for ($n = $start; $n -le $end; $n++) {
    ("{0,4}: {1}" -f $n, $lines[$n-1]) | Tee-Object -FilePath $report -Append
}

if (-not $SkipSimulation) {
    Log "`n=== 2. Existing simulation regression ==="
    $runner = Join-Path $ProjectRoot "run_iverilog_all.bat"
    if (!(Test-Path $runner)) {
        Log "NOT RUN: run_iverilog_all.bat not found at project root."
        Log "Run this script from the project root or pass -ProjectRoot."
    } else {
        Push-Location $ProjectRoot
        try {
            cmd /c "`"$runner`" 2>&1" | Tee-Object -FilePath $report -Append
            if ($LASTEXITCODE -ne 0) { throw "Existing Icarus regression failed with exit code $LASTEXITCODE" }
        } finally { Pop-Location }
    }
}

Log "`n=== 3. Yosys run with full diagnostics ==="
$yosysCmd = "read_verilog -sv rtl/alu_mul_reconfig.sv rtl/fp32_sigmul_linear4.sv rtl/fp32_fma_ieee.sv; " +
            "hierarchy -check -top fp32_fma_ieee; proc; check -assert; stat; write_json reports/closure/fp32_fma_ieee_audit.json"
$fullScript = Join-Path $ReportDir "yosys_audit_$stamp.ys"
$yosysCmd | Set-Content -Encoding ASCII $fullScript

Push-Location $ProjectRoot
try {
    & $YosysExe -Q -T -l $yosysLog -s $fullScript 2>&1 | Tee-Object -FilePath $report -Append
    $yosysExit = $LASTEXITCODE
} catch {
    Log "Yosys invocation error: $_"
    $yosysExit = 999
} finally { Pop-Location }

if (Test-Path $yosysLog) {
    Select-String -Path $yosysLog -Pattern 'Warning:|ERROR:|Latch inferred|Warnings:' |
        ForEach-Object { $_.Line } | Set-Content $warnLog
}
Log "`n=== 4. Warning gate ==="
if (Test-Path $warnLog) {
    Get-Content $warnLog | Tee-Object -FilePath $report -Append
}
$warnText = if (Test-Path $warnLog) { Get-Content $warnLog -Raw } else { "" }
$latchCount = ([regex]::Matches($warnText, '(?im)Warning:\s*Latch inferred')).Count
$errorCount = ([regex]::Matches($warnText, '(?im)ERROR:')).Count

Log "Latch warning count: $latchCount"
Log "Error count: $errorCount"
if ($yosysExit -ne 0) {
    Log "FAIL: Yosys failed (exit $yosysExit)."
} elseif ($errorCount -gt 0) {
    Log "FAIL: Yosys emitted errors."
} elseif ($latchCount -gt 0) {
    Log "NOT CLOSED: inferred latch warning(s) remain. Inspect the source context above and yosys_warnings log."
} else {
    Log "PASS: no 'Latch inferred' warning detected by this audit."
    Log "NOTE: zero latch warnings is not the same as IEEE-754 conformance."
}

Log "`n=== 5. IEEE-754 closure status ==="
Log "Current baseline in the supplied 2026-10-26 log has 13 directed IEEE FMA vectors only."
Log "A randomized differential run against an independent IEEE-754 FMA oracle is still required."
Log "Required coverage: all rounding modes supported by the RTL; normal/subnormal boundaries; signed zero;"
Log "NaNs and signaling-NaN policy; infinities; invalid operations; overflow/underflow; inexact; tie cases;"
Log "input backpressure and output ordering if the interface is pipelined."
Log "Do not mark IEEE-754 closure PASS until the oracle comparison and coverage counters pass."
Log "`nAudit files:"
Log "  Report: $report"
Log "  Yosys full log: $yosysLog"
Log "  Warning extract: $warnLog"
Log "`nIMPORTANT: This tool deliberately does not rewrite RTL or suppress warnings. The source and complete interface are needed to make a justified patch and add a matching differential testbench."

if ($yosysExit -ne 0 -or $errorCount -gt 0 -or $latchCount -gt 0) { exit 2 }
exit 0
