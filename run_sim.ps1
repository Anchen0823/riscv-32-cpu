$ErrorActionPreference = "Stop"

$ProjectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $ProjectRoot

$OutputExe = "simv"
$ResultFile = "results.txt"

$Sources = @(
    "sccomp_tb.v",
    "sccomp.v",
    "SCPU.v",
    "ctrl.v",
    "alu.v",
    "RF.v",
    "im.v",
    "dm.v"
)

Write-Host "[1/2] Compiling with iverilog..."
& iverilog -o $OutputExe @Sources

Write-Host "[2/2] Running simulation with vvp..."
& vvp -n $OutputExe

if (Test-Path $ResultFile) {
    $file = Get-Item $ResultFile
    Write-Host ""
    Write-Host "Simulation finished."
    Write-Host "Result file: $($file.FullName)"
    Write-Host "Size: $($file.Length) bytes"
    Write-Host "Updated: $($file.LastWriteTime)"
    exit 0
}

Write-Error "Simulation finished but '$ResultFile' was not generated."
