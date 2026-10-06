# OrionFlow V2 coverage audit

## Scope and reproducible baseline

- Baseline implementation: Git commit `3f8b0c652b5a7dd005ebacb46be3c256af551141` (`feat: eventual context`).
- Baseline model: `model/Prueba.orion`.
- Baseline generator build that succeeds:

  ```powershell
  $env:JAVA_HOME = 'C:\Program Files\Java\jdk-11'
  mvn org.eclipse.xtend:xtend-maven-plugin:2.25.0:compile package -DskipTests
  java -jar target/SpringDataJPA.predictor-1.0.0.jar `
    -i model/Prueba.orion -o target/baseline-output
  ```

- A plain `mvn clean test` fails at the baseline because the Xtend compiler is
  not bound to the Maven lifecycle and the checked-in `src/main/xtend-gen`
  files have been removed in the current worktree.
- The CodeQL CLI is not installed or discoverable through `PATH`. Therefore the
  baseline queries can be generated, but their compilation and evaluation
  cannot be claimed as validated in this environment.
- The PDF `OrionFlow_constructos_TFG_vs_paper.pdf` was reviewed. Its minimum
  paper-oriented taxonomy is used below.

The Git commit is the immutable V1 reference. No branch, tag, PetClinic/OpenMRS
file, or deployed generator JAR is modified by this audit.

## Current architecture

`Orion2CodeQL` converts the Orion AST into one `.ql` file per supported SCO.
`Query` owns the query templates. `Library` generates `utils.qll` and embeds
name-specific JPQL predicates. `EvolutionContext` maps logical names after an
evolution operation back to names present in the source database.

The following operations currently generate queries:

- Rename/Delete Entity
- Rename/Delete Feature
- Cast Attribute and Cast Reference
- Promote Attribute
- Rename/Delete Relationship
- Move Feature (implemented as feature deletion at the source)
- Split Entity (implemented using entity deletion impact at the source)

Other Orion operations fall through the generic dispatch and generate no query.

## Coverage by supported operation

### Rename Entity / Delete Entity

Current detections:

- JPA entity declaration.
- A direct field whose declared type is exactly the entity and that carries a
  supported JPA association annotation.
- Literal JPQL in Spring `@Query`, JPA `@NamedQuery`,
  `EntityManager.createQuery`, and `createNamedQuery`.

Missing structural dependencies:

- Parameters, return types, local variables and ordinary fields.
- Nested generic arguments such as `List<Visit>` and `Optional<Visit>`.
- `new Visit()` expressions.
- Base classes and implemented interfaces.
- Repository declarations parameterized by the entity.
- Class literals and other resolved source type references.
- `javax.persistence` annotations and APIs.

The entity is selected by simple class name. Two JPA entities with the same
simple name remain ambiguous because Orion selectors do not currently carry a
Java package name.

### Rename Feature / Delete Feature

Current detections:

- Field declaration.
- Getter/setter declarations inferred by name.
- Resolved direct `FieldAccess` expressions.
- Literal JPQL references.
- An embedded field with the same name. This rule is not tied to the owning
  entity and can over-report unrelated embeddables.

Missing dependencies:

- Resolved calls to the getter/setter from other classes.
- Validation/property APIs such as `Errors.rejectValue("birthDate", ...)`.
- Spring Data derived query methods.
- `mappedBy`, `@Column`, and `@JoinColumn` property/column references.
- Boolean `isX` accessors and stronger signature checks for overloaded methods.
- `javax.persistence` variants.

### Cast Attribute / Cast Reference

Current detections:

- Field declaration and inferred accessor declarations.
- Direct field access inside a cast.
- A local initialization from a direct field access.
- Passing a direct field access to a parameter whose simple type name matches
  the old field type.

Missing dependencies:

- Getter/setter invocations.
- Assignments and initializations fed by getters.
- Operations whose availability depends on the old type (`isAfter`,
  `plusDays`, numeric operations, and similar consumers).
- Any propagation through local variables.
- An explicit confidence distinction between confirmed and potential impacts.

### Rename Relationship

Current detection is deliberately narrow: the matching `@JoinTable(name=...)`
annotation. This agrees with the target semantics. It should not report an
accessor merely because the physical join-table name changes.

Current limitation: only `jakarta.persistence.JoinTable` is recognized.

### Delete Relationship

Current detections:

- Owning relationship field selected through `@JoinTable(name=...)`.
- Opposite-side `mappedBy` mapping.
- JPQL references to either side.

Missing dependencies:

- Getter/setter declarations and their resolved call sites.
- Direct reads/writes and collection modification expressions.
- Association annotations other than the current `ManyToMany` restriction.
- `javax.persistence` variants.

### Move Feature

The current implementation reuses Delete Feature for the source declaration.
It detects source-side impacts, but it does not model redirection through the
new owner or changes to navigation expressions. `EvolutionContext` correctly
preserves the original source feature for later operations.

### Promote Attribute

The current query covers identifier annotations, accessors, direct accesses,
JPQL, and some foreign-key mappings. Multiple promoted fields are joined into a
single comma-separated string, while the query treats it as one name; this is a
known semantic limitation outside the first V2 structural increment.

## Cross-cutting semantic limitations

- Most JPA predicates recognize only `jakarta.persistence`, not
  `javax.persistence`.
- Accessors are inferred by text without validating return/parameter type.
- Several framework string APIs have no explicit semantic model.
- The JPQL parser is regex-based and intentionally limited to static literals.
- Dynamic JPQL, Criteria API and native SQL are not currently modeled.
- Queries select locations directly, so multiple evidence paths may produce
  duplicate alerts unless they converge on exactly the same location/message.

## Performance audit

The generated `usesOldEntity` and rename/delete `usesField` predicates embed
literal Orion names and avoid the previously observed dynamic-regex slowdown.
However, `usesField(Expr, Field)`, `usesParentEntity`, and
`fieldReferencedInQuery` still concatenate names obtained from CodeQL AST
objects into regex patterns. They are used by Promote Attribute and Delete
Relationship and are candidates for the same pathological behavior.

Other costly patterns include broad unbound searches over every annotation,
method call or field before the affected entity/field is fixed. V2 must bind the
affected declaration first, prefer resolved equality, and use only static regex
patterns whose captures are compared by equality.

## Test audit

No automated generator tests or CodeQL query tests are present in the baseline.
`model/output` contains examples, not assertions. V2 needs:

- Unit tests for generated query structure and analysis modes.
- EvolutionContext regression tests for chained operations.
- Positive/negative Java/JPA fixtures.
- CodeQL query tests once a CLI and Java database are available.
- A separate performance manifest that never conflates generator build time,
  database build time, query compilation time and query evaluation time.

## Initial priorities

1. Make the Maven build and unit tests reproducible.
2. Add resolved `TypeAccess` coverage for Rename/Delete Entity.
3. Add resolved accessor calls for Rename/Delete Feature and Delete Relationship.
4. Add dual `jakarta`/`javax` JPA support and conservative Spring semantics.
5. Improve cast consumers and add optional, source/sink-constrained local flow.
6. Remove remaining AST-dependent regex construction.

## V2 closure status

The priorities above were implemented in the current worktree. The normal
Maven lifecycle now passes 13 tests, the standalone fixture project compiles,
and all three analysis modes generate the expected pack layout. The structural,
JPA/Spring, and optional local-flow rules are described in
`COVERAGE_MATRIX.md` and `CHANGELOG_ORIONFLOW_V2.md`.

The audit deliberately remains phrased as a V1 baseline inventory. CodeQL query
compilation/evaluation is still open because no CLI or database is available;
this is a validation blocker, not an implemented capability claim.

