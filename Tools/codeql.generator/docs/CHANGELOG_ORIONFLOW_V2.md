# OrionFlow V2 changelog

## Generator and configuration

- Added `STRUCTURAL`, `STRUCTURAL_SEMANTIC`, and `DATAFLOW` analysis modes.
- Added `-m` / `--mode`; omission defaults to `STRUCTURAL_SEMANTIC`.
- Kept every previous public `Query.generate...` signature as a compatibility
  overload.
- Propagated the mode through `Orion2CodeQL` without changing SCO dispatch or
  generated query IDs.
- Bound Xtend compilation and JUnit 5 to the normal Maven lifecycle.

## Impact detection

- Rename/Delete Entity now reports resolved source `TypeAccess` nodes across
  fields, generic arguments, parameters, returns, locals, inheritance, and
  repository declarations, plus resolved construction expressions.
- Rename/Delete Feature now emits an Orion-specific `usesField` predicate,
  validates accessor signatures, and resolves external getter/setter calls.
- Embedded-field matching is restricted to containers owned by the affected
  entity.
- Delete Relationship now includes accessor declarations/calls, direct field
  use, collection use through the accessor, and opposite `mappedBy` metadata.
- Rename Relationship remains deliberately restricted to the physical
  `@JoinTable(name=...)` value.
- Cast Attribute/Reference now covers resolved accessor calls, old-type direct
  consumers, initializers, assignments, and method arguments. DATAFLOW adds a
  source/sink-constrained local flow and labels its findings `[Potential]`.

## JPA and Spring semantics

- Centralized dual `jakarta.persistence` / `javax.persistence` matching.
- Generalized association support to `ManyToOne`, `OneToOne`, `OneToMany`, and
  `ManyToMany`.
- Added `@Column`, `@JoinColumn`, and `mappedBy` feature metadata rules.
- Added exact first-argument Spring `Errors` property handling, constrained to
  a callable that receives the affected entity.
- Added conservative Spring Data derived-query matching constrained by the
  repository's resolved entity type.
- Removed a hard-coded `VideoPost` inheritance condition.

## Performance safeguards

- Entity/feature JPQL regexes contain generation-time Orion literals.
- Generic helpers use constant capture regexes followed by equality; they do
  not concatenate AST-derived names into regex patterns.
- Structural symbol equality is preferred over textual type/name matching.
- Local DataFlow is absent from generated output unless explicitly selected.

## Tests and evaluation support

- Added 13 JUnit tests for mode parsing, query generation, lineage, and
  end-to-end Orion-to-query generation.
- Added a compilable Java/JPA/Spring fixture project with positive/negative
  cases for homonyms, generics, inheritance, overloads, accessors, JPQL, JPA,
  relationships, framework properties, and local flow.
- Added a verification runner that can create a fixture CodeQL database,
  compile queries, evaluate suites, retain raw SARIF, and record timings when a
  CLI is installed.
- Added a deterministic SARIF/ground-truth comparison script and CSV schema.

## Compatibility and provenance

- `EvolutionContext.xtend` was not modified. Regression tests confirm that an
  entity rename followed by a feature rename still queries the original source
  identifiers.
- `utils.qll`, `.ql`, `suite.qls`, and `codeql-pack.yml` output layout is
  preserved.
- No generated Java source was edited as source of truth.
- No PetClinic/OpenMRS file, deployed generator JAR, remote branch, or ground
  truth was changed.

## Known limitations

- The current environment has no CodeQL CLI/database, so generated QL syntax
  and query results are not yet execution-validated.
- Orion entity selectors expose simple names, leaving same-named JPA entities
  in different packages ambiguous.
- JPQL detection covers static literals and a bounded grammar, not a complete
  JPQL parser, Criteria API, native SQL, or dynamically assembled queries.
- Spring property modeling covers a conservative set of `Errors` methods and
  does not treat arbitrary strings as schema references.
- Derived-query parsing is intentionally bounded and does not model every
  Spring Data keyword or nested-property ambiguity.
- Cast compatibility currently identifies old-type-dependent categories; it
  does not prove that every consumer is absent on the new type.
- Global DataFlow and taint tracking remain disabled pending precision and
  performance evidence.
- Move Feature still reuses source-side deletion impact; Promote Attribute
  still treats multiple comma-joined promoted names as a known limitation.
