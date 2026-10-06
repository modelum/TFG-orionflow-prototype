# OrionFlow experimental comparison protocol

## Versions

| Label | Reproducible definition | Mode |
|---|---|---|
| V1 | Git commit `3f8b0c652b5a7dd005ebacb46be3c256af551141` | Original generator |
| V2 | Current generator | `STRUCTURAL` |
| V3-semantic ablation | Current generator | `STRUCTURAL_SEMANTIC` |
| V3 | Current generator | `DATAFLOW` |

The semantic-only run is retained as an ablation even though the requested V3
comparison is the complete structural + semantic + local-flow mode.

## Existing pilot evidence

The following PetClinic values were supplied as the pre-V2 pilot. They were not
rerun or re-normalized here because the frozen ground truth and raw SARIF were
not available in this workspace.

| SCO | GT | TP | FP | FN | Precision | Recall | F1 |
|---|---:|---:|---:|---:|---:|---:|---:|
| Rename Entity | 9 | 1 | 0 | 8 | 1.000 | 0.111 | 0.200 |
| Delete Entity | 13 | 3 | 0 | 10 | 1.000 | 0.231 | 0.375 |
| Rename Feature | 10 | 3 | 0 | 7 | 1.000 | 0.300 | 0.462 |
| Delete Feature | 3 | 3 | 0 | 0 | 1.000 | 1.000 | 1.000 |
| Cast Attribute | 5 | 3 | 0 | 2 | 1.000 | 0.600 | 0.750 |
| Rename Relationship | 1 | 1 | 0 | 0 | 1.000 | 1.000 | 1.000 |
| Delete Relationship | 5 | 1 | 0 | 4 | 1.000 | 0.200 | 0.333 |
| **Aggregate** | **46** | **15** | **0** | **31** | **1.000** | **0.326** | **0.492** |

These values are baseline evidence, not proof of V2/V3 improvement. No V2/V3
TP, FP, FN, precision, recall, F1, or evaluation-time result is invented.

## Frozen evaluation unit

The comparison uses one normalized construct keyed by:

```text
CodeQL rule/SCO id + repository-relative file + start line
```

The ground-truth CSV also stores `construct` for stratified analysis. Duplicate
SARIF alerts with the same key count once. One alert cannot satisfy two ground
truth entries. Line changes between versions require a frozen source commit or
an explicit mapping; the GT itself must not be edited to improve a version.

`evaluation/ground-truth-template.csv` defines the input schema.
`scripts/compare-sarif.ps1` performs deterministic deduplication and produces
per-rule plus aggregate TP/FP/FN/precision/recall/F1:

```powershell
.\scripts\compare-sarif.ps1 `
  -GroundTruthCsv evaluation\petclinic-ground-truth.csv `
  -VersionSarif V1=results\v1.sarif,V2=results\v2.sarif,V3=results\v3.sarif
```

Raw SARIF inputs are read-only and remain preserved. The output metric CSV is a
derived artifact and must be stored alongside the CodeQL/tool versions and
timing manifest.

## Required experiment table

For each project, version, SCO, and construct category, record:

| Project | Commit | Version | SCO | Construct | TP | FP | FN | Precision | Recall | F1 | DB build s | QL compile s | QL eval s | Workflow s |
|---|---|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| Pending | Pending | V1/V2/V3 | Pending | Pending | — | — | — | — | — | — | — | — | — | — |

Run at least three measured repetitions after one warm-up when practical, and
report medians plus dispersion. PetClinic and OpenMRS must use their own frozen
commits and the same normalization rules.

## Interpretation boundaries

- Structural improvements test whether SCO-guided symbol resolution closes
  direct false negatives.
- Semantic improvements test the incremental value of explicit JPA/Spring
  roles rather than arbitrary strings.
- DATAFLOW results are labelled potential and must be reported separately from
  confirmed structural/semantic impacts.
- Global data flow and taint tracking are disabled, so the experiment cannot
  claim interprocedural or dynamic-query completeness.
