[CmdletBinding()]
param(
    [string]$JavaHome = 'C:\Program Files\Java\jdk-11',
    [string]$OrionScript = 'src/test/resources/orion/codeql-fixtures.orion',
    [string]$OutputRoot = 'target/v2-verification',
    [string]$CodeqlDatabase,
    [switch]$CreateFixtureDatabase
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$moduleRoot = Split-Path -Parent $PSScriptRoot
$measurements = [System.Collections.Generic.List[object]]::new()

function Invoke-Checked {
    param(
        [Parameter(Mandatory)] [scriptblock]$Action,
        [Parameter(Mandatory)] [string]$Label
    )

    $elapsed = Measure-Command { & $Action }
    if ($LASTEXITCODE -ne 0) {
        throw "$Label failed with exit code $LASTEXITCODE"
    }
    return [math]::Round($elapsed.TotalSeconds, 3)
}

Push-Location $moduleRoot
try {
    if ($JavaHome) {
        $env:JAVA_HOME = $JavaHome
        $env:Path = "$JavaHome\bin;$env:Path"
    }

    $buildSeconds = Invoke-Checked -Label 'Generator build and tests' -Action {
        & mvn clean test
    }

    $fixtureSeconds = Invoke-Checked -Label 'Fixture compilation' -Action {
        & mvn -f src/test/resources/fixtures/pom.xml clean test
    }
    & mvn -q -f src/test/resources/fixtures/pom.xml clean
    if ($LASTEXITCODE -ne 0) {
        throw "Fixture cleanup failed with exit code $LASTEXITCODE"
    }

    $packageSeconds = Invoke-Checked -Label 'Generator packaging' -Action {
        & mvn package -DskipTests
    }

    $resolvedOutputRoot = [IO.Path]::GetFullPath((Join-Path $moduleRoot $OutputRoot))
    New-Item -ItemType Directory -Force -Path $resolvedOutputRoot | Out-Null
    $jar = Join-Path $moduleRoot 'target/SpringDataJPA.predictor-1.0.0.jar'
    $resolvedScript = [IO.Path]::GetFullPath((Join-Path $moduleRoot $OrionScript))

    foreach ($mode in @('STRUCTURAL', 'STRUCTURAL_SEMANTIC', 'DATAFLOW')) {
        $modeDirectory = Join-Path $resolvedOutputRoot $mode.ToLowerInvariant().Replace('_', '-')
        $generationSeconds = Invoke-Checked -Label "$mode generation" -Action {
            & java -jar $jar -i $resolvedScript -o $modeDirectory -m $mode
        }

        $measurements.Add([pscustomobject]@{
            mode = $mode
            build_seconds = $buildSeconds
            fixture_compile_seconds = $fixtureSeconds
            package_seconds = $packageSeconds
            generation_seconds = $generationSeconds
            query_compile_seconds = $null
            query_evaluation_seconds = $null
            result_count = $null
        })
    }

    $codeql = Get-Command codeql -ErrorAction SilentlyContinue
    if ($null -eq $codeql) {
        Write-Warning 'CodeQL CLI not found; generated queries were not compiled or evaluated.'
    }
    else {
        if ($CreateFixtureDatabase) {
            $fixtureRoot = Join-Path $moduleRoot 'src/test/resources/fixtures'
            $fixtureDatabase = Join-Path $resolvedOutputRoot 'fixture-database'
            $databaseSeconds = Invoke-Checked -Label 'Fixture database creation' -Action {
                & $codeql.Source database create $fixtureDatabase --language=java `
                    --source-root=$fixtureRoot '--command=mvn -q clean package' --overwrite
            }
            $CodeqlDatabase = $fixtureDatabase
            Write-Host "Fixture database build: $databaseSeconds s"
        }

        foreach ($measurement in $measurements) {
            $modeDirectory = Join-Path $resolvedOutputRoot $measurement.mode.ToLowerInvariant().Replace('_', '-')
            & $codeql.Source pack install $modeDirectory
            if ($LASTEXITCODE -ne 0) {
                throw "CodeQL pack install failed for $($measurement.mode)"
            }

            $queries = Get-ChildItem -LiteralPath $modeDirectory -Filter '*.ql' -File
            $measurement.query_compile_seconds = Invoke-Checked -Label "$($measurement.mode) query compilation" -Action {
                foreach ($query in $queries) {
                    & $codeql.Source query compile $query.FullName
                    if ($LASTEXITCODE -ne 0) {
                        throw "CodeQL query compilation failed for $($query.FullName)"
                    }
                }
            }

            if ($CodeqlDatabase) {
                $sarif = Join-Path $modeDirectory 'raw-results.sarif'
                $suite = Join-Path $modeDirectory 'suite.qls'
                $measurement.query_evaluation_seconds = Invoke-Checked -Label "$($measurement.mode) evaluation" -Action {
                    & $codeql.Source database analyze $CodeqlDatabase $suite `
                        --format=sarifv2.1.0 --output=$sarif --rerun
                }

                $sarifDocument = Get-Content -Raw -LiteralPath $sarif | ConvertFrom-Json
                $measurement.result_count = @(
                    $sarifDocument.runs | ForEach-Object { @($_.results).Count }
                ) | Measure-Object -Sum | Select-Object -ExpandProperty Sum
            }
        }
    }

    $measurementFile = Join-Path $resolvedOutputRoot 'performance.json'
    $measurements | ConvertTo-Json -Depth 4 | Set-Content -Encoding utf8 $measurementFile
    $measurements | Format-Table -AutoSize
    Write-Host "Measurements written to $measurementFile"
}
finally {
    Pop-Location
}
