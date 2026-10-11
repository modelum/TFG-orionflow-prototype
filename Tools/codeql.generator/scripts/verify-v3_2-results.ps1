[CmdletBinding()]
param(
    [string]$JpaSarif = 'target/v3_2-results/jpa.sarif',
    [string]$MongoSarif = 'target/v3_2-results/mongo.sarif',
    [string]$BothSarif = 'target/v3_2-results/both.sarif'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Read-SarifResults([string]$Path) {
    $document = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
    return @($document.runs | ForEach-Object { @($_.results) })
}

function Get-ResultKey($Result) {
    $location = $Result.locations[0].physicalLocation
    return @(
        $Result.ruleId,
        $location.artifactLocation.uri,
        $location.region.startLine,
        $Result.message.text
    ) -join '|'
}

function Get-ResultLine($Result) {
    return [int]$Result.locations[0].physicalLocation.region.startLine
}

function Get-ResultFile($Result) {
    return [IO.Path]::GetFileName($Result.locations[0].physicalLocation.artifactLocation.uri)
}

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Assert-Finding(
    [object[]]$Results,
    [string]$RuleId,
    [string]$File,
    [int]$Line,
    [string]$Marker
) {
    $matches = @($Results | Where-Object {
        $_.ruleId -eq $RuleId -and
        (Get-ResultFile $_) -eq $File -and
        (Get-ResultLine $_) -eq $Line -and
        $_.message.text.Contains($Marker)
    })
    Assert-True ($matches.Count -gt 0) "Missing expected finding: $RuleId, ${File}:$Line, $Marker"
}

function Assert-NoMethodFinding(
    [object[]]$Results,
    [string]$RuleId,
    [string]$MethodName,
    [string]$Marker
) {
    $matches = @($Results | Where-Object {
        $_.ruleId -eq $RuleId -and
        $_.message.text.Contains($Marker) -and
        $_.message.text.Contains("'$MethodName'")
    })
    Assert-True ($matches.Count -eq 0) "Unexpected finding for negative method '$MethodName' in $RuleId"
}

$jpa = Read-SarifResults $JpaSarif
$mongo = Read-SarifResults $MongoSarif
$both = Read-SarifResults $BothSarif

$jpaKeys = @($jpa | ForEach-Object { Get-ResultKey $_ } | Sort-Object -Unique)
$mongoKeys = @($mongo | ForEach-Object { Get-ResultKey $_ } | Sort-Object -Unique)
$bothKeys = @($both | ForEach-Object { Get-ResultKey $_ } | Sort-Object -Unique)
$expectedBoth = @($jpaKeys + $mongoKeys | Sort-Object -Unique)

$missing = @($expectedBoth | Where-Object { $_ -notin $bothKeys })
$extra = @($bothKeys | Where-Object { $_ -notin $expectedBoth })
Assert-True ($missing.Count -eq 0) "The both profile is missing $($missing.Count) unique JPA/Mongo findings"
Assert-True ($extra.Count -eq 0) "The both profile has $($extra.Count) findings outside the JPA/Mongo union"

$deleteFeatureRule = 'java/orion/feature-deleted/2/0'
$moveFeatureRule = 'java/orion/feature-moved/5'
$castAttributeRule = 'java/orion/attribute-casted/3/0'
$castReferenceRule = 'java/orion/reference-casted/4/0'
$deleteRelationshipRule = 'java/orion/relationship-deleted/8'
$callGraphMarker = '\[CallGraph'
$globalMarker = '\[Global\]'

# Call Graph: resolved direct calls, depth one/two, mutations and virtual dispatch.
Assert-Finding $jpa $deleteFeatureRule 'FeatureImpact.java' 28 $callGraphMarker
Assert-Finding $jpa $deleteFeatureRule 'FeatureImpact.java' 29 $callGraphMarker
Assert-Finding $jpa $moveFeatureRule 'CastImpact.java' 12 $callGraphMarker
Assert-Finding $jpa $moveFeatureRule 'CastImpact.java' 13 $callGraphMarker
Assert-Finding $jpa $deleteRelationshipRule 'RelationshipImpact.java' 28 $callGraphMarker
Assert-Finding $jpa $deleteRelationshipRule 'RelationshipImpact.java' 32 $callGraphMarker
Assert-Finding $jpa $deleteRelationshipRule 'RelationshipImpact.java' 50 $callGraphMarker

# Call Graph negatives: discarded values and unrelated overloads must not propagate.
Assert-NoMethodFinding $jpa $deleteFeatureRule 'discardedBirthDate' $callGraphMarker
Assert-NoMethodFinding $jpa $deleteFeatureRule 'unrelatedBirthDateOverload' $callGraphMarker
Assert-NoMethodFinding $jpa $moveFeatureRule 'discardedDate' $callGraphMarker
Assert-NoMethodFinding $jpa $deleteRelationshipRule 'discardedAffectedValue' $callGraphMarker
Assert-NoMethodFinding $jpa $deleteRelationshipRule 'unrelatedOverload' $callGraphMarker

# CAST-only global flow reaches old-type consumers across method boundaries.
Assert-Finding $jpa $castAttributeRule 'CastImpact.java' 65 $globalMarker
Assert-Finding $jpa $castAttributeRule 'CastImpact.java' 69 $globalMarker
Assert-Finding $jpa $castReferenceRule 'RelationshipImpact.java' 66 $globalMarker

$jpaGlobal = @($jpa | Where-Object { $_.message.text.Contains($globalMarker) })
Assert-True (@($jpaGlobal | Where-Object {
    $_.ruleId -notin @($castAttributeRule, $castReferenceRule)
}).Count -eq 0) 'Global DataFlow was emitted by a non-CAST rule'

# Unrelated sources and replacement-compatible consumers remain negative.
Assert-True (@($jpaGlobal | Where-Object {
    (Get-ResultFile $_) -eq 'CastImpact.java' -and (Get-ResultLine $_) -in @(49, 73)
}).Count -eq 0) 'Unexpected global attribute flow from an unrelated/compatible consumer'
Assert-True (@($jpaGlobal | Where-Object {
    (Get-ResultFile $_) -eq 'RelationshipImpact.java' -and (Get-ResultLine $_) -eq 60
}).Count -eq 0) 'Unexpected global reference flow from an unrelated source'

$mongoCallGraph = @($mongo | Where-Object { $_.message.text.Contains($callGraphMarker) })
Assert-True ($mongoCallGraph.Count -eq 3) "Expected 3 Mongo Call Graph findings, found $($mongoCallGraph.Count)"
Assert-True (@($mongo | Where-Object { $_.message.text.Contains($globalMarker) }).Count -eq 0) 'Mongo profile unexpectedly produced CAST global findings for the JPA fixtures'

$bothCallGraph = @($both | Where-Object { $_.message.text.Contains($callGraphMarker) })
$bothGlobal = @($both | Where-Object { $_.message.text.Contains($globalMarker) })
Assert-True ($bothCallGraph.Count -eq 24) "Expected 24 Call Graph findings in both, found $($bothCallGraph.Count)"
Assert-True ($bothGlobal.Count -eq 7) "Expected 7 global CAST findings in both, found $($bothGlobal.Count)"

Write-Host 'V3.2 SARIF validation passed.'
Write-Host "JPA: $($jpa.Count) results; Mongo: $($mongo.Count); both: $($both.Count)."
Write-Host "both = exact unique union ($($bothKeys.Count)); Call Graph: $($bothCallGraph.Count); CAST global: $($bothGlobal.Count)."
