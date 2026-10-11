# OrionFlow V2 performance and validation report

## Current status

This report deliberately separates generator verification from CodeQL query
compilation and evaluation. A passing Maven build proves that the generator and
its tests compile and run; it does not prove that every generated QL query
compiles or produces the expected alerts.

Verified facts for the current modular refactoring:

| Check | Result |
|---|---|
| Maven test lifecycle | Passes |
| Default persistence profile | JPA |
| Generated operation queries, JPA profile | 16 |
| Generated operation queries, MongoDB profile | 16 |
| Generated operation queries, `both` profile | 16 |
| Target CodeQL CLI | 2.27.2 |
| Target Java QL pack | `codeql/java-all` 9.3.2 |
| Compatibility compilation | Partial earlier pass completed |
| Final compilation of all current modular profiles | In progress |
| Query evaluation and result validation | In progress |

No elapsed time, alert count, or speedup is reported for the current modular
version until the corresponding command has completed and its raw output has
been retained.

## Performance safeguards in the generator

The generated code avoids the performance issue observed when a regular
expression is built from an AST-derived `Class.getName()` or `Field.getName()`:

- Entity and feature names available from Orion are embedded as literals while
  generating the QL file.
- Reusable framework predicates use constant regular expressions, capture a
  candidate name, and compare that value to a semantically resolved declaration.
- Java references prefer CodeQL symbol/type equality over textual matching.
- `both` mode emits `orion_java.qll` and `orion_spring.qll` once and combines
  only the adapter predicates in `utils.qll`.
- DataFlow uses `DataFlow::localFlow`, with an affected-field source and a
  SCO-specific sink. It is imported only by Delete Feature, Cast Attribute,
  Cast Reference, Move Feature, and Delete Relationship queries.
- Global DataFlow and taint tracking are not enabled.

These are design safeguards, not benchmark results.

## Measurement table

Complete this table from retained command output. Do not replace “Pending” with
an estimate.

| Profile | Generator wall time | QL compile wall time | Queries compiled | Evaluation wall time | Raw alerts | Normalized alerts | Status/notes |
|---|---:|---:|---:|---:|---:|---:|---|
| JPA | Pending | Pending | Pending | Pending | Pending | Pending | Final modular validation in progress |
| MongoDB | Pending | Pending | Pending | Pending | Pending | Pending | Final modular validation in progress |
| Both | Pending | Pending | Pending | Pending | Pending | Pending | Final modular validation in progress |

For application-level campaigns, add one row per commit/database and record the
database creation time separately from query compilation and evaluation.

## Reproducible validation protocol

Use JDK 11 for the generator build. Validate the generated packs with the exact
target versions, CodeQL CLI 2.27.2 and `codeql/java-all` 9.3.2.

The repository verifier executes the build, fixture compilation, generation,
pack installation, query compilation, evaluation, and measurement sequence:

```powershell
.\scripts\verify-v2.ps1 `
  -CodeqlExe C:\tools\codeql\codeql.exe `
  -CodeqlPacks C:\tools\codeql-bundle\qlpacks
```

The paths are examples; the script rejects a CLI or Java QL pack whose version
does not match the target and resolves the packaged JAR identity from
`pom.xml`. It also applies the fixture oracle in
[`EXPECTATIONS.md`](../src/test/resources/fixtures/EXPECTATIONS.md): default
and explicit JPA must be identical, adapter results must remain isolated,
`both` must be the exact normalized union, duplicate identities are rejected,
and the required positive/negative locations are checked.

1. Run `mvn clean test` and retain the Surefire summary.
2. Run `mvn clean package` and generate three fresh output directories from the
   same Orion input: `--framework jpa`, `mongo`, and `both`.
3. Confirm that each profile has the same expected set of 16 operation queries
   and that only its selected adapter modules are present.
4. Install/resolve the pack dependencies in the target CodeQL environment.
5. Compile every generated `.ql` file with `codeql query compile --check-only
   --keep-going`; retain stdout/stderr and elapsed time per profile.
6. Evaluate the same queries against the same CodeQL database and retain raw
   BQRS/SARIF before normalization.
7. Normalize results by query ID, fixture-relative file, full region, and
   message before comparing profiles or ground truth.
8. Record cache state, database commit, OS/hardware, JDK, CLI/pack versions, and
   the number of repetitions.

## Compatibility checkpoint

The earlier CodeQL failure was caused by calling `fromSource()` on
`Expr::ClassInstanceExpr`. The modular structural library no longer makes that
call. Constructor matching keeps the semantic test
`creation.getConstructedType() = entity`. The final compile pass must still
exercise all generated modules and all 16 queries in each profile; the earlier
partial compilation is not treated as final evidence.

## Acceptance record

The final report should include:

- zero QL compilation errors for JPA, MongoDB, and `both`;
- query evaluation completion for every generated query;
- expected positive/negative fixture findings;
- raw and normalized alert counts;
- per-query and total timings with no inferred or missing values;
- an explicit comparison against the baseline using the same database and
  cache conditions.
