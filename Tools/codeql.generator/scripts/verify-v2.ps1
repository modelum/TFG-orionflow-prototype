[CmdletBinding()]
param(
    [string]$JavaHome = 'C:\Program Files\Java\jdk-11',
    [string]$OrionScript = 'src/test/resources/orion/codeql-fixtures.orion',
    [string]$OutputRoot = 'target/v2-verification',
    [string]$CodeqlDatabase,
    [switch]$CreateFixtureDatabase,
    [string]$CodeqlExe,
    [string[]]$CodeqlPacks,
    [ValidateRange(1, 2147483647)] [int]$ExpectedQueryCount = 16
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$requiredCodeqlVersion = '2.27.2'
$requiredJavaPackVersion = '9.3.2'
$moduleRoot = Split-Path -Parent $PSScriptRoot
$measurements = [System.Collections.Generic.List[object]]::new()

function Invoke-NativeCommand {
    param(
        [Parameter(Mandatory)] [string]$Executable,
        [Parameter(Mandatory)] [string[]]$CommandArguments,
        [Parameter(Mandatory)] [string]$Label
    )

    & $Executable @CommandArguments
    if ($LASTEXITCODE -ne 0) {
        throw "$Label failed with exit code $LASTEXITCODE"
    }
}

function Measure-Operation {
    param(
        [Parameter(Mandatory)] [scriptblock]$Action
    )

    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        & $Action | Out-Host
    }
    finally {
        $stopwatch.Stop()
    }

    return [math]::Round($stopwatch.Elapsed.TotalSeconds, 3)
}

function Reset-ProfileDirectory {
    param(
        [Parameter(Mandatory)] [string]$Root,
        [Parameter(Mandatory)] [string]$ProfileName
    )

    $resolvedRoot = [IO.Path]::GetFullPath($Root).TrimEnd(
        [IO.Path]::DirectorySeparatorChar,
        [IO.Path]::AltDirectorySeparatorChar
    )
    $profileDirectory = [IO.Path]::GetFullPath((Join-Path $resolvedRoot $ProfileName))
    $requiredPrefix = $resolvedRoot + [IO.Path]::DirectorySeparatorChar

    if (-not $profileDirectory.StartsWith(
        $requiredPrefix,
        [StringComparison]::OrdinalIgnoreCase
    )) {
        throw "Refusing to reset profile directory outside verification root: $profileDirectory"
    }

    if (Test-Path -LiteralPath $profileDirectory) {
        Remove-Item -LiteralPath $profileDirectory -Recurse -Force
    }
    New-Item -ItemType Directory -Path $profileDirectory | Out-Null
    return $profileDirectory
}

function Get-GeneratedManifest {
    param(
        [Parameter(Mandatory)] [string]$Directory
    )

    $basePath = [IO.Path]::GetFullPath($Directory).TrimEnd(
        [IO.Path]::DirectorySeparatorChar,
        [IO.Path]::AltDirectorySeparatorChar
    )

    Get-ChildItem -LiteralPath $basePath -File -Recurse |
        ForEach-Object {
            [pscustomobject]@{
                relative_path = $_.FullName.Substring($basePath.Length + 1)
                sha256 = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash
            }
        } |
        Sort-Object -Property relative_path
}

function Assert-EquivalentGeneration {
    param(
        [Parameter(Mandatory)] [string]$DefaultDirectory,
        [Parameter(Mandatory)] [string]$JpaDirectory
    )

    $defaultManifest = @(Get-GeneratedManifest -Directory $DefaultDirectory)
    $jpaManifest = @(Get-GeneratedManifest -Directory $JpaDirectory)
    $differences = @(
        Compare-Object -ReferenceObject $defaultManifest -DifferenceObject $jpaManifest `
            -Property relative_path, sha256
    )

    if ($differences.Count -ne 0) {
        $details = $differences |
            ForEach-Object { "$($_.SideIndicator) $($_.relative_path) [$($_.sha256)]" }
        throw "Default generation differs from explicit JPA generation:`n$($details -join "`n")"
    }
}

function Assert-GeneratedModuleLayout {
    param(
        [Parameter(Mandatory)] [string]$Directory,
        [Parameter(Mandatory)] [ValidateSet('jpa', 'mongo', 'both')] [string]$Framework
    )

    $requiredModules = @(
        'orion_java.qll',
        'orion_spring.qll',
        'orion_dataflow.qll',
        'utils.qll',
        'suite.qls',
        'codeql-pack.yml'
    )
    if ($Framework -in @('jpa', 'both')) {
        $requiredModules += 'orion_jpa.qll'
    }
    if ($Framework -in @('mongo', 'both')) {
        $requiredModules += 'orion_mongo.qll'
    }

    foreach ($module in $requiredModules) {
        $modulePath = Join-Path $Directory $module
        if (-not (Test-Path -LiteralPath $modulePath -PathType Leaf)) {
            throw "Missing generated module for $Framework profile: $modulePath"
        }
    }

    $forbiddenModules = @()
    if ($Framework -eq 'jpa') {
        $forbiddenModules += 'orion_mongo.qll'
    }
    if ($Framework -eq 'mongo') {
        $forbiddenModules += 'orion_jpa.qll'
    }
    foreach ($module in $forbiddenModules) {
        $modulePath = Join-Path $Directory $module
        if (Test-Path -LiteralPath $modulePath) {
            throw "Unexpected generated module for $Framework profile: $modulePath"
        }
    }
}

function Assert-TargetJavaPack {
    param(
        [Parameter(Mandatory)] [string[]]$PackRoots,
        [Parameter(Mandatory)] [string]$RequiredVersion
    )

    foreach ($packRoot in $PackRoots) {
        $candidateManifests = @(
            (Join-Path $packRoot 'qlpack.yml'),
            (Join-Path $packRoot "codeql/java-all/$RequiredVersion/qlpack.yml"),
            (Join-Path $packRoot 'codeql/java-all/qlpack.yml')
        )
        foreach ($manifest in $candidateManifests) {
            if (-not (Test-Path -LiteralPath $manifest -PathType Leaf)) {
                continue
            }
            $metadata = Get-Content -Raw -LiteralPath $manifest
            $isJavaPack = $metadata -match '(?m)^\s*name:\s*codeql/java-all\s*$'
            $hasRequiredVersion = $metadata -match (
                '(?m)^\s*version:\s*' + [regex]::Escape($RequiredVersion) + '\s*$'
            )
            if ($isJavaPack -and $hasRequiredVersion) {
                return (Resolve-Path -LiteralPath $manifest).Path
            }
        }
    }

    throw "codeql/java-all $RequiredVersion was not found under the supplied pack roots."
}

function Get-CodeqlResolutionArguments {
    param(
        [Parameter(Mandatory)] [string[]]$AdditionalPackRoots,
        [string]$PackageCache
    )

    $resolutionArguments = [System.Collections.Generic.List[string]]::new()
    $additionalPacks = $AdditionalPackRoots -join [IO.Path]::PathSeparator
    $resolutionArguments.Add("--additional-packs=$additionalPacks")

    if ($PackageCache -and (Test-Path -LiteralPath $PackageCache -PathType Container)) {
        $resolutionArguments.Add("--search-path=$PackageCache")
    }

    return $resolutionArguments.ToArray()
}

function Get-SarifResultCount {
    param(
        [Parameter(Mandatory)] [string]$SarifFile
    )

    $document = Get-Content -Raw -LiteralPath $SarifFile | ConvertFrom-Json
    $count = 0
    $runsProperty = $document.PSObject.Properties['runs']
    if ($null -eq $runsProperty) {
        return $count
    }

    foreach ($run in @($runsProperty.Value)) {
        $resultsProperty = $run.PSObject.Properties['results']
        if ($null -ne $resultsProperty -and $null -ne $resultsProperty.Value) {
            $count += @($resultsProperty.Value).Count
        }
    }
    return $count
}

function ConvertTo-NormalizedFixtureUri {
    param(
        [Parameter(Mandatory)] [string]$ArtifactUri,
        [Parameter(Mandatory)] [string]$FixtureRoot
    )

    try {
        $decodedUri = [Uri]::UnescapeDataString($ArtifactUri)
    }
    catch {
        $decodedUri = $ArtifactUri
    }

    $candidatePath = $decodedUri
    $parsedUri = $null
    if (
        [Uri]::TryCreate($decodedUri, [UriKind]::Absolute, [ref]$parsedUri) -and
        $parsedUri.IsFile
    ) {
        $candidatePath = $parsedUri.LocalPath
    }

    $normalized = $candidatePath.Replace('\', '/')
    $normalizedFixtureRoot = [IO.Path]::GetFullPath($FixtureRoot).Replace('\', '/').TrimEnd('/')
    if ([IO.Path]::IsPathRooted($candidatePath)) {
        $absoluteCandidate = [IO.Path]::GetFullPath($candidatePath).Replace('\', '/')
        $fixturePrefix = $normalizedFixtureRoot + '/'
        if ($absoluteCandidate.StartsWith($fixturePrefix, [StringComparison]::OrdinalIgnoreCase)) {
            return $absoluteCandidate.Substring($fixturePrefix.Length)
        }
        $normalized = $absoluteCandidate
    }

    $normalized = $normalized.TrimStart('.', '/')
    $fixtureMarker = 'src/test/resources/fixtures/'
    $markerIndex = $normalized.IndexOf(
        $fixtureMarker,
        [StringComparison]::OrdinalIgnoreCase
    )
    if ($markerIndex -ge 0) {
        return $normalized.Substring($markerIndex + $fixtureMarker.Length)
    }

    if ($normalized -match '(?i)(?:^|/)(entity|feature|cast|relationship|legacy|mongo)/(.+)$') {
        return "$($Matches[1].ToLowerInvariant())/$($Matches[2])"
    }

    return $normalized
}

function Get-IntegerProperty {
    param(
        [object]$Object,
        [Parameter(Mandatory)] [string]$Name,
        [int]$DefaultValue = 0
    )

    if ($null -ne $Object) {
        $property = $Object.PSObject.Properties[$Name]
        if ($null -ne $property -and $null -ne $property.Value) {
            return [int]$property.Value
        }
    }
    return $DefaultValue
}

function Get-NormalizedSarifResults {
    param(
        [Parameter(Mandatory)] [string]$SarifFile,
        [Parameter(Mandatory)] [string]$FixtureRoot
    )

    $document = Get-Content -Raw -LiteralPath $SarifFile | ConvertFrom-Json
    $normalizedResults = [System.Collections.Generic.List[object]]::new()
    $runsProperty = $document.PSObject.Properties['runs']
    if ($null -eq $runsProperty) {
        return $normalizedResults.ToArray()
    }

    foreach ($run in @($runsProperty.Value)) {
        $resultsProperty = $run.PSObject.Properties['results']
        if ($null -eq $resultsProperty -or $null -eq $resultsProperty.Value) {
            continue
        }
        foreach ($result in @($resultsProperty.Value)) {
            $locationsProperty = $result.PSObject.Properties['locations']
            if ($null -eq $locationsProperty -or @($locationsProperty.Value).Count -eq 0) {
                throw "SARIF result '$($result.ruleId)' has no physical location."
            }

            $location = @($locationsProperty.Value)[0]
            $physicalLocation = $location.physicalLocation
            $artifactUri = [string]$physicalLocation.artifactLocation.uri
            if ([string]::IsNullOrWhiteSpace($artifactUri)) {
                throw "SARIF result '$($result.ruleId)' has no artifact URI."
            }

            $region = $physicalLocation.region
            $startLine = Get-IntegerProperty -Object $region -Name 'startLine'
            $startColumn = Get-IntegerProperty -Object $region -Name 'startColumn'
            $endLine = Get-IntegerProperty -Object $region -Name 'endLine'
            $endColumn = Get-IntegerProperty -Object $region -Name 'endColumn'
            $message = [string]$result.message.text
            $normalizedUri = ConvertTo-NormalizedFixtureUri `
                -ArtifactUri $artifactUri -FixtureRoot $FixtureRoot
            $identity = @(
                [string]$result.ruleId,
                $normalizedUri,
                $startLine,
                $startColumn,
                $endLine,
                $endColumn,
                $message
            ) -join [char]0x1f

            $normalizedResults.Add([pscustomobject]@{
                identity = $identity
                rule_id = [string]$result.ruleId
                normalized_uri = $normalizedUri
                start_line = $startLine
                start_column = $startColumn
                end_line = $endLine
                end_column = $endColumn
                message = $message
            })
        }
    }

    return $normalizedResults.ToArray()
}

function Assert-NoDuplicateSarifResults {
    param(
        [Parameter(Mandatory)] [object[]]$Results,
        [Parameter(Mandatory)] [string]$Profile
    )

    $duplicates = @($Results | Group-Object -Property identity | Where-Object Count -gt 1)
    if ($duplicates.Count -gt 0) {
        $details = $duplicates | ForEach-Object {
            $sample = $_.Group[0]
            "$($_.Count)x $($sample.rule_id) $($sample.normalized_uri):$($sample.start_line) [$($sample.message)]"
        }
        throw "Duplicate normalized SARIF identities in $Profile profile:`n$($details -join "`n")"
    }
}

function Assert-SarifSetEqual {
    param(
        [Parameter(Mandatory)] [object[]]$Expected,
        [Parameter(Mandatory)] [object[]]$Actual,
        [Parameter(Mandatory)] [string]$Label
    )

    $expectedIdentities = @($Expected.identity | Sort-Object -Unique)
    $actualIdentities = @($Actual.identity | Sort-Object -Unique)
    $differences = @(
        Compare-Object -ReferenceObject $expectedIdentities `
            -DifferenceObject $actualIdentities
    )
    if ($differences.Count -gt 0) {
        $details = $differences | Select-Object -First 30 | ForEach-Object {
            "$($_.SideIndicator) $($_.InputObject)"
        }
        throw "$Label differs after SARIF normalization:`n$($details -join "`n")"
    }
}

function Assert-RequiredSarifResult {
    param(
        [Parameter(Mandatory)] [object[]]$Results,
        [Parameter(Mandatory)] [string]$RuleId,
        [Parameter(Mandatory)] [string]$Uri,
        [Parameter(Mandatory)] [int]$FirstLine,
        [Parameter(Mandatory)] [int]$LastLine,
        [string]$MessageFragment
    )

    $matches = @($Results | Where-Object {
        $_.rule_id -eq $RuleId -and
        $_.normalized_uri -ieq $Uri -and
        $_.start_line -ge $FirstLine -and
        $_.start_line -le $LastLine -and
        (
            [string]::IsNullOrWhiteSpace($MessageFragment) -or
            $_.message.IndexOf($MessageFragment, [StringComparison]::OrdinalIgnoreCase) -ge 0
        )
    })
    if ($matches.Count -eq 0) {
        throw "Missing SARIF positive: $RuleId at ${Uri}:$FirstLine-$LastLine with message containing '$MessageFragment'."
    }
}

function Assert-ForbiddenSarifRange {
    param(
        [Parameter(Mandatory)] [object[]]$Results,
        [Parameter(Mandatory)] [string]$RuleId,
        [Parameter(Mandatory)] [string]$Uri,
        [Parameter(Mandatory)] [int]$FirstLine,
        [Parameter(Mandatory)] [int]$LastLine
    )

    $matches = @($Results | Where-Object {
        $_.rule_id -eq $RuleId -and
        $_.normalized_uri -ieq $Uri -and
        $_.start_line -ge $FirstLine -and
        $_.start_line -le $LastLine
    })
    if ($matches.Count -gt 0) {
        $details = $matches | ForEach-Object {
            "$($_.normalized_uri):$($_.start_line) [$($_.message)]"
        }
        throw "Unexpected SARIF negative for $RuleId at ${Uri}:$FirstLine-${LastLine}:`n$($details -join "`n")"
    }
}

function Assert-SarifFixtureContract {
    param(
        [Parameter(Mandatory)] [hashtable]$ResultsByProfile
    )

    foreach ($profile in @('default', 'jpa', 'mongo', 'both')) {
        if (-not $ResultsByProfile.ContainsKey($profile)) {
            throw "Missing normalized SARIF results for profile '$profile'."
        }
        Assert-NoDuplicateSarifResults -Results @($ResultsByProfile[$profile]) `
            -Profile $profile
    }

    $defaultResults = @($ResultsByProfile['default'])
    $jpaResults = @($ResultsByProfile['jpa'])
    $mongoResults = @($ResultsByProfile['mongo'])
    $bothResults = @($ResultsByProfile['both'])

    Assert-SarifSetEqual -Expected $jpaResults -Actual $defaultResults `
        -Label 'Default and explicit JPA profiles'

    $mongoRuleIds = @(
        'java/orion/entity-renamed/9',
        'java/orion/feature-renamed/10',
        'java/orion/feature-deleted/11/0',
        'java/orion/reference-casted/12/0',
        'java/orion/feature-moved/13',
        'java/orion/relationship-deleted/14'
    )
    $jpaRuleIds = @(
        'java/orion/entity-renamed/0',
        'java/orion/feature-renamed/1',
        'java/orion/feature-deleted/2/0',
        'java/orion/attribute-casted/3/0',
        'java/orion/reference-casted/4/0',
        'java/orion/feature-moved/5',
        'java/orion/entity-deleted/6',
        'java/orion/relationship-renamed/7',
        'java/orion/relationship-deleted/8',
        'java/orion/entity-renamed/15'
    )

    $crossedJpaResults = @($jpaResults | Where-Object {
        $_.normalized_uri -like 'mongo/*' -or $_.rule_id -in $mongoRuleIds
    })
    if ($crossedJpaResults.Count -gt 0) {
        throw "JPA profile contains MongoDB results: $($crossedJpaResults.identity -join "`n")"
    }

    $crossedMongoResults = @($mongoResults | Where-Object {
        $_.normalized_uri -match '^(entity|feature|cast|relationship|legacy)/' -or
        $_.rule_id -in $jpaRuleIds
    })
    if ($crossedMongoResults.Count -gt 0) {
        throw "MongoDB profile contains JPA fixture results: $($crossedMongoResults.identity -join "`n")"
    }

    $unionByIdentity = @{}
    foreach ($result in @($jpaResults) + @($mongoResults)) {
        $unionByIdentity[$result.identity] = $result
    }
    $expectedBoth = @($unionByIdentity.Values)
    Assert-SarifSetEqual -Expected $expectedBoth -Actual $bothResults `
        -Label 'BOTH profile and exact JPA/MongoDB union'

    $jpaPositives = @(
        @{ Rule = 'java/orion/entity-renamed/0'; Uri = 'entity/Visit.java'; First = 5; Last = 5; Message = 'Persistence metadata' },
        @{ Rule = 'java/orion/entity-renamed/0'; Uri = 'entity/Visit.java'; First = 6; Last = 6; Message = "Entity 'Visit' will be renamed" },
        @{ Rule = 'java/orion/entity-renamed/0'; Uri = 'feature/FeatureImpact.java'; First = 17; Last = 17; Message = "Entity 'Visit' will be renamed" },
        @{ Rule = 'java/orion/entity-renamed/0'; Uri = 'cast/CastImpact.java'; First = 7; Last = 7; Message = "Entity 'Visit' will be renamed" },
        @{ Rule = 'java/orion/entity-renamed/0'; Uri = 'entity/EntityReferences.java'; First = 7; Last = 11; Message = 'Resolved type reference' },
        @{ Rule = 'java/orion/entity-renamed/0'; Uri = 'entity/EntityReferences.java'; First = 12; Last = 12; Message = 'Construction of entity' },
        @{ Rule = 'java/orion/entity-renamed/0'; Uri = 'feature/FeatureImpact.java'; First = 13; Last = 16; Message = 'Named query uses old entity name' },
        @{ Rule = 'java/orion/entity-renamed/0'; Uri = 'feature/FeatureImpact.java'; First = 46; Last = 47; Message = 'Query uses old entity name' },

        @{ Rule = 'java/orion/feature-renamed/1'; Uri = 'feature/FeatureImpact.java'; First = 18; Last = 18; Message = 'Persistence metadata references feature' },
        @{ Rule = 'java/orion/feature-renamed/1'; Uri = 'feature/FeatureImpact.java'; First = 19; Last = 19; Message = "Feature 'birthDate'" },
        @{ Rule = 'java/orion/feature-renamed/1'; Uri = 'feature/FeatureImpact.java'; First = 21; Last = 22; Message = 'accesses feature' },
        @{ Rule = 'java/orion/feature-renamed/1'; Uri = 'feature/FeatureImpact.java'; First = 30; Last = 31; Message = 'Call to accessor' },
        @{ Rule = 'java/orion/feature-renamed/1'; Uri = 'feature/FeatureImpact.java'; First = 32; Last = 32; Message = 'Spring API references property' },
        @{ Rule = 'java/orion/feature-renamed/1'; Uri = 'feature/FeatureImpact.java'; First = 42; Last = 42; Message = 'Spring Data derived query method' },
        @{ Rule = 'java/orion/feature-renamed/1'; Uri = 'feature/FeatureImpact.java'; First = 13; Last = 16; Message = 'Named query uses feature' },
        @{ Rule = 'java/orion/feature-renamed/1'; Uri = 'feature/FeatureImpact.java'; First = 46; Last = 47; Message = 'Query uses feature' },

        @{ Rule = 'java/orion/feature-deleted/2/0'; Uri = 'feature/FeatureImpact.java'; First = 19; Last = 19; Message = "Attribute 'birthDate'" },
        @{ Rule = 'java/orion/feature-deleted/2/0'; Uri = 'feature/FeatureImpact.java'; First = 30; Last = 32; Message = 'birthDate' },
        @{ Rule = 'java/orion/feature-deleted/2/0'; Uri = 'feature/FeatureImpact.java'; First = 42; Last = 42; Message = 'Spring Data derived query method' },
        @{ Rule = 'java/orion/feature-deleted/2/0'; Uri = 'feature/FeatureImpact.java'; First = 13; Last = 16; Message = 'Named query uses attribute' },
        @{ Rule = 'java/orion/feature-deleted/2/0'; Uri = 'feature/FeatureImpact.java'; First = 46; Last = 47; Message = 'Query uses attribute' },

        @{ Rule = 'java/orion/attribute-casted/3/0'; Uri = 'cast/CastImpact.java'; First = 8; Last = 8; Message = "Attribute 'date'" },
        @{ Rule = 'java/orion/attribute-casted/3/0'; Uri = 'cast/CastImpact.java'; First = 9; Last = 10; Message = 'uses attribute' },
        @{ Rule = 'java/orion/attribute-casted/3/0'; Uri = 'cast/CastImpact.java'; First = 15; Last = 15; Message = 'Variable declaration expects old type' },
        @{ Rule = 'java/orion/attribute-casted/3/0'; Uri = 'cast/CastImpact.java'; First = 16; Last = 16; Message = '[Potential]' },

        @{ Rule = 'java/orion/reference-casted/4/0'; Uri = 'relationship/RelationshipImpact.java'; First = 10; Last = 12; Message = "reference 'specialties'" },
        @{ Rule = 'java/orion/reference-casted/4/0'; Uri = 'relationship/RelationshipImpact.java'; First = 14; Last = 15; Message = 'old reference type' },
        @{ Rule = 'java/orion/reference-casted/4/0'; Uri = 'relationship/RelationshipImpact.java'; First = 20; Last = 20; Message = 'Call to reference accessor' },

        @{ Rule = 'java/orion/feature-moved/5'; Uri = 'cast/CastImpact.java'; First = 8; Last = 8; Message = "Feature 'date' will move" },
        @{ Rule = 'java/orion/feature-moved/5'; Uri = 'cast/CastImpact.java'; First = 9; Last = 10; Message = 'must navigate moved feature' },
        @{ Rule = 'java/orion/feature-moved/5'; Uri = 'cast/CastImpact.java'; First = 15; Last = 15; Message = 'must be updated for moved feature' },
        @{ Rule = 'java/orion/feature-moved/5'; Uri = 'cast/CastImpact.java'; First = 16; Last = 16; Message = '[Potential]' },

        @{ Rule = 'java/orion/entity-deleted/6'; Uri = 'entity/Visit.java'; First = 5; Last = 6; Message = "entity 'Visit'" },
        @{ Rule = 'java/orion/entity-deleted/6'; Uri = 'feature/FeatureImpact.java'; First = 17; Last = 17; Message = "Entity 'Visit' is marked for deletion" },
        @{ Rule = 'java/orion/entity-deleted/6'; Uri = 'cast/CastImpact.java'; First = 7; Last = 7; Message = "Entity 'Visit' is marked for deletion" },
        @{ Rule = 'java/orion/entity-deleted/6'; Uri = 'entity/EntityReferences.java'; First = 7; Last = 11; Message = 'Resolved type reference' },
        @{ Rule = 'java/orion/entity-deleted/6'; Uri = 'entity/EntityReferences.java'; First = 12; Last = 12; Message = 'Construction of entity' },
        @{ Rule = 'java/orion/entity-deleted/6'; Uri = 'feature/FeatureImpact.java'; First = 13; Last = 16; Message = 'Named query uses entity' },
        @{ Rule = 'java/orion/entity-deleted/6'; Uri = 'feature/FeatureImpact.java'; First = 46; Last = 47; Message = 'Query uses entity' },

        @{ Rule = 'java/orion/relationship-renamed/7'; Uri = 'relationship/RelationshipImpact.java'; First = 11; Last = 11; Message = 'Join table name will change' },
        @{ Rule = 'java/orion/relationship-deleted/8'; Uri = 'relationship/RelationshipImpact.java'; First = 12; Last = 12; Message = 'Relationship field' },
        @{ Rule = 'java/orion/relationship-deleted/8'; Uri = 'relationship/RelationshipImpact.java'; First = 14; Last = 15; Message = 'exposes relationship' },
        @{ Rule = 'java/orion/relationship-deleted/8'; Uri = 'relationship/RelationshipImpact.java'; First = 20; Last = 20; Message = 'Call to accessor' },
        @{ Rule = 'java/orion/relationship-deleted/8'; Uri = 'relationship/RelationshipImpact.java'; First = 26; Last = 27; Message = 'references relationship' },

        @{ Rule = 'java/orion/entity-renamed/15'; Uri = 'legacy/LegacyJpa.java'; First = 7; Last = 7; Message = 'Persistence metadata' },
        @{ Rule = 'java/orion/entity-renamed/15'; Uri = 'legacy/LegacyJpa.java'; First = 8; Last = 8; Message = "Entity 'LegacyVisit' will be renamed" },
        @{ Rule = 'java/orion/entity-renamed/15'; Uri = 'legacy/LegacyJpa.java'; First = 15; Last = 15; Message = 'Resolved type reference' }
    )

    $mongoPositives = @(
        @{ Rule = 'java/orion/entity-renamed/9'; Uri = 'mongo/MongoImpact.java'; First = 20; Last = 20; Message = 'Persistence metadata declares entity' },
        @{ Rule = 'java/orion/entity-renamed/9'; Uri = 'mongo/MongoImpact.java'; First = 22; Last = 22; Message = "Entity 'PatientDocument' will be renamed" },
        @{ Rule = 'java/orion/entity-renamed/9'; Uri = 'mongo/MongoImpact.java'; First = 53; Last = 57; Message = 'Resolved type reference' },
        @{ Rule = 'java/orion/entity-renamed/9'; Uri = 'mongo/MongoImpact.java'; First = 71; Last = 71; Message = 'stored collection' },
        @{ Rule = 'java/orion/entity-renamed/9'; Uri = 'mongo/MongoImpact.java'; First = 71; Last = 75; Message = 'Resolved type reference' },

        @{ Rule = 'java/orion/feature-renamed/10'; Uri = 'mongo/MongoImpact.java'; First = 21; Last = 21; Message = 'Persistence metadata references feature' },
        @{ Rule = 'java/orion/feature-renamed/10'; Uri = 'mongo/MongoImpact.java'; First = 26; Last = 27; Message = 'Persistence metadata references feature' },
        @{ Rule = 'java/orion/feature-renamed/10'; Uri = 'mongo/MongoImpact.java'; First = 28; Last = 28; Message = "Feature 'birthDate'" },
        @{ Rule = 'java/orion/feature-renamed/10'; Uri = 'mongo/MongoImpact.java'; First = 39; Last = 39; Message = 'accesses feature' },
        @{ Rule = 'java/orion/feature-renamed/10'; Uri = 'mongo/MongoImpact.java'; First = 54; Last = 54; Message = 'Spring Data derived query method' },
        @{ Rule = 'java/orion/feature-renamed/10'; Uri = 'mongo/MongoImpact.java'; First = 56; Last = 57; Message = 'Query uses feature' },
        @{ Rule = 'java/orion/feature-renamed/10'; Uri = 'mongo/MongoImpact.java'; First = 68; Last = 68; Message = 'Persistence API references feature' },
        @{ Rule = 'java/orion/feature-renamed/10'; Uri = 'mongo/MongoImpact.java'; First = 69; Last = 69; Message = 'Persistence API references feature' },
        @{ Rule = 'java/orion/feature-renamed/10'; Uri = 'mongo/MongoImpact.java'; First = 70; Last = 70; Message = 'Persistence API references feature' },
        @{ Rule = 'java/orion/feature-renamed/10'; Uri = 'mongo/MongoImpact.java'; First = 72; Last = 72; Message = 'Persistence API references feature' },
        @{ Rule = 'java/orion/feature-renamed/10'; Uri = 'mongo/MongoImpact.java'; First = 76; Last = 76; Message = 'Call to accessor' },

        @{ Rule = 'java/orion/feature-deleted/11/0'; Uri = 'mongo/MongoImpact.java'; First = 28; Last = 28; Message = "Attribute 'birthDate'" },
        @{ Rule = 'java/orion/feature-deleted/11/0'; Uri = 'mongo/MongoImpact.java'; First = 54; Last = 54; Message = 'Spring Data derived query method' },
        @{ Rule = 'java/orion/feature-deleted/11/0'; Uri = 'mongo/MongoImpact.java'; First = 56; Last = 57; Message = 'Query uses attribute' },
        @{ Rule = 'java/orion/feature-deleted/11/0'; Uri = 'mongo/MongoImpact.java'; First = 68; Last = 72; Message = 'Persistence API references attribute' },
        @{ Rule = 'java/orion/feature-deleted/11/0'; Uri = 'mongo/MongoImpact.java'; First = 76; Last = 76; Message = 'Call to accessor' },
        @{ Rule = 'java/orion/feature-deleted/11/0'; Uri = 'mongo/MongoImpact.java'; First = 77; Last = 77; Message = '[Potential]' },

        @{ Rule = 'java/orion/reference-casted/12/0'; Uri = 'mongo/MongoImpact.java'; First = 33; Last = 34; Message = "reference 'primaryProvider'" },
        @{ Rule = 'java/orion/reference-casted/12/0'; Uri = 'mongo/MongoImpact.java'; First = 42; Last = 42; Message = 'old reference type' },
        @{ Rule = 'java/orion/reference-casted/12/0'; Uri = 'mongo/MongoImpact.java'; First = 82; Last = 82; Message = 'old reference type' },
        @{ Rule = 'java/orion/reference-casted/12/0'; Uri = 'mongo/MongoImpact.java'; First = 83; Last = 83; Message = '[Potential]' },

        @{ Rule = 'java/orion/feature-moved/13'; Uri = 'mongo/MongoImpact.java'; First = 31; Last = 31; Message = "Feature 'status' will move" },
        @{ Rule = 'java/orion/feature-moved/13'; Uri = 'mongo/MongoImpact.java'; First = 41; Last = 41; Message = 'must navigate moved feature' },
        @{ Rule = 'java/orion/feature-moved/13'; Uri = 'mongo/MongoImpact.java'; First = 85; Last = 85; Message = 'must be updated for moved feature' },
        @{ Rule = 'java/orion/feature-moved/13'; Uri = 'mongo/MongoImpact.java'; First = 86; Last = 86; Message = '[Potential]' },

        @{ Rule = 'java/orion/relationship-deleted/14'; Uri = 'mongo/MongoImpact.java'; First = 37; Last = 37; Message = 'Relationship field' },
        @{ Rule = 'java/orion/relationship-deleted/14'; Uri = 'mongo/MongoImpact.java'; First = 43; Last = 43; Message = 'exposes relationship' },
        @{ Rule = 'java/orion/relationship-deleted/14'; Uri = 'mongo/MongoImpact.java'; First = 88; Last = 88; Message = 'Call to accessor' },
        @{ Rule = 'java/orion/relationship-deleted/14'; Uri = 'mongo/MongoImpact.java'; First = 89; Last = 89; Message = '[Potential]' }
    )

    foreach ($expectation in $jpaPositives) {
        Assert-RequiredSarifResult -Results $jpaResults -RuleId $expectation.Rule `
            -Uri $expectation.Uri -FirstLine $expectation.First `
            -LastLine $expectation.Last -MessageFragment $expectation.Message
    }
    foreach ($expectation in $mongoPositives) {
        Assert-RequiredSarifResult -Results $mongoResults -RuleId $expectation.Rule `
            -Uri $expectation.Uri -FirstLine $expectation.First `
            -LastLine $expectation.Last -MessageFragment $expectation.Message
    }

    $negativeExpectations = @(
        @{ Profile = 'jpa'; Rule = 'java/orion/entity-renamed/0'; Uri = 'entity/UnrelatedReferences.java'; First = 5; Last = 9 },
        @{ Profile = 'jpa'; Rule = 'java/orion/entity-deleted/6'; Uri = 'entity/UnrelatedReferences.java'; First = 5; Last = 9 },
        @{ Profile = 'jpa'; Rule = 'java/orion/entity-renamed/0'; Uri = 'entity/other/Visit.java'; First = 4; Last = 4 },
        @{ Profile = 'jpa'; Rule = 'java/orion/entity-deleted/6'; Uri = 'entity/other/Visit.java'; First = 4; Last = 4 },
        @{ Profile = 'jpa'; Rule = 'java/orion/feature-renamed/1'; Uri = 'feature/FeatureImpact.java'; First = 25; Last = 25 },
        @{ Profile = 'jpa'; Rule = 'java/orion/feature-deleted/2/0'; Uri = 'feature/FeatureImpact.java'; First = 25; Last = 25 },
        @{ Profile = 'jpa'; Rule = 'java/orion/feature-renamed/1'; Uri = 'feature/FeatureImpact.java'; First = 33; Last = 33 },
        @{ Profile = 'jpa'; Rule = 'java/orion/feature-deleted/2/0'; Uri = 'feature/FeatureImpact.java'; First = 33; Last = 33 },
        @{ Profile = 'jpa'; Rule = 'java/orion/feature-renamed/1'; Uri = 'feature/FeatureImpact.java'; First = 38; Last = 38 },
        @{ Profile = 'jpa'; Rule = 'java/orion/feature-deleted/2/0'; Uri = 'feature/FeatureImpact.java'; First = 38; Last = 38 },
        @{ Profile = 'jpa'; Rule = 'java/orion/feature-renamed/1'; Uri = 'feature/FeatureImpact.java'; First = 44; Last = 44 },
        @{ Profile = 'jpa'; Rule = 'java/orion/feature-deleted/2/0'; Uri = 'feature/FeatureImpact.java'; First = 44; Last = 44 },
        @{ Profile = 'jpa'; Rule = 'java/orion/feature-renamed/1'; Uri = 'feature/FeatureImpact.java'; First = 52; Last = 52 },
        @{ Profile = 'jpa'; Rule = 'java/orion/feature-deleted/2/0'; Uri = 'feature/FeatureImpact.java'; First = 52; Last = 52 },
        @{ Profile = 'jpa'; Rule = 'java/orion/attribute-casted/3/0'; Uri = 'cast/CastImpact.java'; First = 19; Last = 20 },
        @{ Profile = 'jpa'; Rule = 'java/orion/feature-moved/5'; Uri = 'cast/CastImpact.java'; First = 19; Last = 20 },
        @{ Profile = 'jpa'; Rule = 'java/orion/relationship-deleted/8'; Uri = 'relationship/RelationshipImpact.java'; First = 31; Last = 36 }
    )
    foreach ($rule in $mongoRuleIds | Where-Object { $_ -ne 'java/orion/entity-renamed/9' }) {
        $negativeExpectations += @{
            Profile = 'mongo'
            Rule = $rule
            Uri = 'mongo/MongoImpact.java'
            First = 92
            Last = 99
        }
    }

    foreach ($expectation in $negativeExpectations) {
        $profileResults = @($ResultsByProfile[$expectation.Profile])
        Assert-ForbiddenSarifRange -Results $profileResults -RuleId $expectation.Rule `
            -Uri $expectation.Uri -FirstLine $expectation.First `
            -LastLine $expectation.Last
    }
}

Push-Location $moduleRoot
try {
    if ($JavaHome) {
        $resolvedJavaHome = (Resolve-Path -LiteralPath $JavaHome).Path
        $env:JAVA_HOME = $resolvedJavaHome
        $env:Path = "$resolvedJavaHome\bin;$env:Path"
    }

    $resolvedScript = (Resolve-Path -LiteralPath $OrionScript).Path
    $resolvedOutputRoot = [IO.Path]::GetFullPath((Join-Path $moduleRoot $OutputRoot))
    New-Item -ItemType Directory -Force -Path $resolvedOutputRoot | Out-Null

    if ($CodeqlExe) {
        $resolvedCodeql = (Resolve-Path -LiteralPath $CodeqlExe).Path
    }
    else {
        $codeqlCommand = Get-Command codeql -ErrorAction SilentlyContinue
        if ($null -eq $codeqlCommand) {
            throw 'CodeQL CLI was not found. Supply -CodeqlExe or add CodeQL to PATH.'
        }
        $resolvedCodeql = $codeqlCommand.Source
    }

    $versionOutput = & $resolvedCodeql version --format=json
    if ($LASTEXITCODE -ne 0) {
        throw "CodeQL version detection failed with exit code $LASTEXITCODE"
    }
    $codeqlVersion = ($versionOutput | Out-String | ConvertFrom-Json).version
    if ($codeqlVersion -ne $requiredCodeqlVersion) {
        throw "CodeQL $requiredCodeqlVersion is required; found $codeqlVersion at $resolvedCodeql"
    }

    if (-not $CodeqlPacks -or $CodeqlPacks.Count -eq 0) {
        $bundleRoot = Split-Path -Parent (Split-Path -Parent $resolvedCodeql)
        $CodeqlPacks = @(Join-Path $bundleRoot 'qlpacks')
    }

    $resolvedPackRoots = @(
        $CodeqlPacks | ForEach-Object {
            (Resolve-Path -LiteralPath $_).Path
        }
    )
    if ($resolvedPackRoots.Count -eq 0) {
        throw 'At least one CodeQL pack root is required.'
    }
    $javaPackManifest = Assert-TargetJavaPack -PackRoots $resolvedPackRoots `
        -RequiredVersion $requiredJavaPackVersion
    Write-Host "Resolved codeql/java-all $requiredJavaPackVersion at $javaPackManifest"

    $userProfile = [Environment]::GetFolderPath([Environment+SpecialFolder]::UserProfile)
    $codeqlPackageCache = Join-Path $userProfile '.codeql\packages'
    $initialResolutionArguments = @(
        Get-CodeqlResolutionArguments -AdditionalPackRoots $resolvedPackRoots `
            -PackageCache $codeqlPackageCache
    )

    $buildSeconds = Measure-Operation {
        Invoke-NativeCommand -Executable 'mvn' -CommandArguments @('clean', 'test') `
            -Label 'Generator build and tests'
    }

    $fixtureSeconds = Measure-Operation {
        Invoke-NativeCommand -Executable 'mvn' `
            -CommandArguments @('-f', 'src/test/resources/fixtures/pom.xml', 'clean', 'test') `
            -Label 'Fixture compilation'
    }
    Invoke-NativeCommand -Executable 'mvn' `
        -CommandArguments @('-q', '-f', 'src/test/resources/fixtures/pom.xml', 'clean') `
        -Label 'Fixture cleanup'

    $packageSeconds = Measure-Operation {
        Invoke-NativeCommand -Executable 'mvn' -CommandArguments @('package', '-DskipTests') `
            -Label 'Generator packaging'
    }

    [xml]$pomDocument = Get-Content -Raw -LiteralPath (Join-Path $moduleRoot 'pom.xml')
    $pomNamespace = [System.Xml.XmlNamespaceManager]::new($pomDocument.NameTable)
    $pomNamespace.AddNamespace('m', 'http://maven.apache.org/POM/4.0.0')
    $artifactNode = $pomDocument.SelectSingleNode(
        '/m:project/m:artifactId',
        $pomNamespace
    )
    $versionNode = $pomDocument.SelectSingleNode(
        '/m:project/m:version',
        $pomNamespace
    )
    if ($null -eq $artifactNode -or $null -eq $versionNode) {
        throw 'Unable to resolve artifactId/version from pom.xml.'
    }

    $jarName = "$($artifactNode.InnerText)-$($versionNode.InnerText).jar"
    $jar = Join-Path $moduleRoot (Join-Path 'target' $jarName)
    if (-not (Test-Path -LiteralPath $jar -PathType Leaf)) {
        throw "Packaged generator not found: $jar"
    }

    $profiles = @(
        [pscustomobject]@{
            name = 'default'
            framework = 'jpa'
            framework_arguments = @()
        },
        [pscustomobject]@{
            name = 'jpa'
            framework = 'jpa'
            framework_arguments = @('--framework', 'jpa')
        },
        [pscustomobject]@{
            name = 'mongo'
            framework = 'mongo'
            framework_arguments = @('--framework', 'mongo')
        },
        [pscustomobject]@{
            name = 'both'
            framework = 'both'
            framework_arguments = @('--framework', 'both')
        }
    )

    $profileDirectories = @{}
    foreach ($profile in $profiles) {
        $profileDirectory = Reset-ProfileDirectory -Root $resolvedOutputRoot `
            -ProfileName $profile.name
        $profileDirectories[$profile.name] = $profileDirectory

        $generatorArguments = @(
            '-jar',
            $jar,
            '-i',
            $resolvedScript,
            '-o',
            $profileDirectory
        ) + @($profile.framework_arguments)

        $generationSeconds = Measure-Operation {
            Invoke-NativeCommand -Executable 'java' -CommandArguments $generatorArguments `
                -Label "$($profile.name) generation"
        }
        Assert-GeneratedModuleLayout -Directory $profileDirectory `
            -Framework $profile.framework
        $generatedQueries = @(
            Get-ChildItem -LiteralPath $profileDirectory -Filter '*.ql' -File
        )
        if ($generatedQueries.Count -ne $ExpectedQueryCount) {
            throw "Expected $ExpectedQueryCount generated queries for $($profile.name); found $($generatedQueries.Count)."
        }

        $measurements.Add([pscustomobject]@{
            profile = $profile.name
            framework = $profile.framework
            default_matches_jpa = $null
            codeql_version = $codeqlVersion
            build_seconds = $buildSeconds
            fixture_compile_seconds = $fixtureSeconds
            package_seconds = $packageSeconds
            database_build_seconds = $null
            generation_seconds = $generationSeconds
            pack_install_seconds = $null
            query_compile_seconds = $null
            query_evaluation_seconds = $null
            result_count = $null
            normalized_result_count = $null
        })
    }

    Assert-EquivalentGeneration -DefaultDirectory $profileDirectories['default'] `
        -JpaDirectory $profileDirectories['jpa']
    foreach ($measurement in $measurements) {
        if ($measurement.profile -eq 'default' -or $measurement.profile -eq 'jpa') {
            $measurement.default_matches_jpa = $true
        }
    }

    $fixtureRoot = (Resolve-Path -LiteralPath 'src/test/resources/fixtures').Path
    $databaseBuildSeconds = 0.0
    if ($CreateFixtureDatabase -or [string]::IsNullOrWhiteSpace($CodeqlDatabase)) {
        $fixtureDatabase = Join-Path $resolvedOutputRoot 'fixture-database'
        $databaseBuildSeconds = Measure-Operation {
            $databaseArguments = @(
                'database',
                'create',
                $fixtureDatabase,
                '--language=java',
                "--source-root=$fixtureRoot",
                '--command=mvn -q clean package',
                '--overwrite'
            )
            Invoke-NativeCommand -Executable $resolvedCodeql `
                -CommandArguments $databaseArguments -Label 'Fixture database creation'
        }
        $CodeqlDatabase = $fixtureDatabase
    }
    else {
        $CodeqlDatabase = (Resolve-Path -LiteralPath $CodeqlDatabase).Path
    }

    $sarifResultsByProfile = @{}
    foreach ($measurement in $measurements) {
        $measurement.database_build_seconds = $databaseBuildSeconds
        $profileDirectory = $profileDirectories[$measurement.profile]

        $measurement.pack_install_seconds = Measure-Operation {
            $packArguments = @('pack', 'install', $profileDirectory) + `
                $initialResolutionArguments
            Invoke-NativeCommand -Executable $resolvedCodeql -CommandArguments $packArguments `
                -Label "$($measurement.profile) CodeQL pack install"
        }

        $resolutionArguments = @(
            Get-CodeqlResolutionArguments -AdditionalPackRoots $resolvedPackRoots `
                -PackageCache $codeqlPackageCache
        )
        $queries = @(Get-ChildItem -LiteralPath $profileDirectory -Filter '*.ql' -File)
        if ($queries.Count -eq 0) {
            throw "No generated CodeQL queries found for profile $($measurement.profile)"
        }

        $measurement.query_compile_seconds = Measure-Operation {
            foreach ($query in $queries) {
                $compileArguments = @(
                    'query',
                    'compile',
                    '--check-only',
                    '--keep-going',
                    $query.FullName
                ) + $resolutionArguments
                Invoke-NativeCommand -Executable $resolvedCodeql `
                    -CommandArguments $compileArguments `
                    -Label "$($measurement.profile) query compilation: $($query.Name)"
            }
        }

        $sarif = Join-Path $profileDirectory 'raw-results.sarif'
        $suite = Join-Path $profileDirectory 'suite.qls'
        if (-not (Test-Path -LiteralPath $suite -PathType Leaf)) {
            throw "Generated CodeQL suite not found: $suite"
        }

        $measurement.query_evaluation_seconds = Measure-Operation {
            $analysisArguments = @(
                'database',
                'analyze',
                $CodeqlDatabase,
                $suite,
                '--format=sarifv2.1.0',
                "--output=$sarif",
                '--rerun'
            ) + $resolutionArguments
            Invoke-NativeCommand -Executable $resolvedCodeql `
                -CommandArguments $analysisArguments `
                -Label "$($measurement.profile) query evaluation"
        }
        $normalizedResults = @(
            Get-NormalizedSarifResults -SarifFile $sarif -FixtureRoot $fixtureRoot
        )
        $rawResultCount = Get-SarifResultCount -SarifFile $sarif
        if ($rawResultCount -ne $normalizedResults.Count) {
            throw "SARIF normalization lost results for $($measurement.profile): raw=$rawResultCount normalized=$($normalizedResults.Count)."
        }
        $sarifResultsByProfile[$measurement.profile] = $normalizedResults
        $measurement.result_count = $rawResultCount
        $measurement.normalized_result_count = @(
            $normalizedResults.identity | Sort-Object -Unique
        ).Count
    }

    Assert-SarifFixtureContract -ResultsByProfile $sarifResultsByProfile

    $measurementFile = Join-Path $resolvedOutputRoot 'performance.json'
    $measurements | ConvertTo-Json -Depth 4 | Set-Content -Encoding utf8 $measurementFile
    $measurements | Format-Table -AutoSize
    Write-Host "Verified CodeQL $codeqlVersion profiles: default, jpa, mongo, both"
    Write-Host "Measurements written to $measurementFile"
}
finally {
    Pop-Location
}
