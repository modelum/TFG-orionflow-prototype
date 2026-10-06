[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string]$GroundTruthCsv,
    [Parameter(Mandatory)] [string[]]$VersionSarif,
    [string]$OutputCsv = 'target/evaluation/metrics.csv'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Normalize-Path([string]$Value) {
    return $Value.Replace('\', '/').TrimStart([char[]]@('.', '/')).ToLowerInvariant()
}

function New-Key([string]$RuleId, [string]$File, [int]$Line) {
    return "$RuleId|$(Normalize-Path $File)|$Line"
}

function Get-Ratio([int]$Numerator, [int]$Denominator) {
    if ($Denominator -eq 0) { return 0.0 }
    return [math]::Round($Numerator / $Denominator, 6)
}

$groundTruth = Import-Csv -LiteralPath $GroundTruthCsv
$gtByKey = @{}
foreach ($item in $groundTruth) {
    $key = New-Key $item.rule_id $item.file ([int]$item.start_line)
    $gtByKey[$key] = $item
}

$rows = [System.Collections.Generic.List[object]]::new()
foreach ($entry in $VersionSarif) {
    $separator = $entry.IndexOf('=')
    if ($separator -lt 1) {
        throw "Expected VERSION=path, received '$entry'"
    }

    $version = $entry.Substring(0, $separator)
    $sarifPath = $entry.Substring($separator + 1)
    $document = Get-Content -Raw -LiteralPath $sarifPath | ConvertFrom-Json
    $predictedByKey = @{}

    foreach ($run in $document.runs) {
        if ('results' -notin $run.PSObject.Properties.Name) { continue }
        foreach ($result in @($run.results)) {
            if (@($result.locations).Count -eq 0) { continue }
            $location = $result.locations[0].physicalLocation
            $key = New-Key $result.ruleId $location.artifactLocation.uri ([int]$location.region.startLine)
            $predictedByKey[$key] = $true
        }
    }

    $ruleIds = @(
        @($groundTruth | ForEach-Object rule_id) +
        @($predictedByKey.Keys | ForEach-Object { ($_ -split '\|', 2)[0] })
    ) | Sort-Object -Unique

    foreach ($ruleId in @($ruleIds) + '__ALL__') {
        $gtKeys = @($gtByKey.Keys | Where-Object {
            $ruleId -eq '__ALL__' -or $_.StartsWith("$ruleId|")
        })
        $predictedKeys = @($predictedByKey.Keys | Where-Object {
            $ruleId -eq '__ALL__' -or $_.StartsWith("$ruleId|")
        })
        $tp = @($predictedKeys | Where-Object { $gtByKey.ContainsKey($_) }).Count
        $fp = $predictedKeys.Count - $tp
        $fn = $gtKeys.Count - $tp
        $precision = Get-Ratio $tp ($tp + $fp)
        $recall = Get-Ratio $tp ($tp + $fn)
        $f1 = if (($precision + $recall) -eq 0) {
            0.0
        } else {
            [math]::Round((2 * $precision * $recall) / ($precision + $recall), 6)
        }

        $rows.Add([pscustomobject]@{
            version = $version
            rule_id = $ruleId
            TP = $tp
            FP = $fp
            FN = $fn
            precision = $precision
            recall = $recall
            F1 = $f1
        })
    }
}

$resolvedOutput = [IO.Path]::GetFullPath($OutputCsv)
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $resolvedOutput) | Out-Null
$rows | Export-Csv -NoTypeInformation -Encoding utf8 -LiteralPath $resolvedOutput
$rows | Format-Table -AutoSize
Write-Host "Metrics written to $resolvedOutput"
