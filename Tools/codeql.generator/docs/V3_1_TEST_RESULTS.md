# OrionFlow V3.1 test results

Validation date: 2026-10-11.

## Toolchain

- Generator: Maven with JDK 11 (Xtend 2.25.0).
- CodeQL CLI: 2.27.2.
- CodeQL Java pack: `codeql/java-all@9.3.2`.
- Dataset: checked-in internal Java fixtures. PetClinic and StudAdvice were not
  available in this workspace; OpenMRS and DZHW were intentionally not used
  because they are reserved evaluation sets.

## Results

- Maven unit/integration tests: 33 passed, 0 failed.
- Default CLI profile and explicit `--framework jpa`: byte-identical output.
- Generated queries: 9 JPA, 9 Mongo, and 9 Both.
- CodeQL `query compile --check-only`: 27/27 passed.
- CodeQL database creation: passed.
- CodeQL `database analyze`: all three suites passed.
- SARIF alerts: JPA 74, Mongo 35, Both 109.
- After normalizing duplicate result identities, Both is exactly
  `set(JPA) union set(Mongo)`: 103 expected, 103 actual, 0 missing, 0 extra.

The functional checks include three explicit constructors with different
visibility/signatures, a homonymous non-persistent class, embedded Mongo types,
document references, Criteria/Sort calls, positive/wrong/ambiguous Validators,
direct and external query constants, constant concatenation, unrelated query
constants, and dynamic property-name negatives.

These numbers are fixture results, not precision/recall measurements against a
ground truth. No TP, FP, precision, recall, or F1 values are claimed for the
reserved datasets.

