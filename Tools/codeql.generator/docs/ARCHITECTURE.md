# OrionFlow V2 architecture

## Design goals

V2 extends the existing generator rather than replacing it. Public generation
methods remain available, the output pack layout stays compatible, and
`EvolutionContext` remains the authority for mapping logical Orion names to
identifiers present in the source CodeQL database.

The implementation follows four constraints:

1. Resolve Java declarations and calls semantically whenever CodeQL exposes the
   relevant symbol.
2. Generate Orion names as literals; never build a regex from an AST-derived
   name when a static capture plus equality is sufficient.
3. Bind the affected declaration before searching dependants.
4. Keep local DataFlow optional and constrain both source and sink.

## Components

### Orion2CodeQL

- Iterates operations in source order.
- Resolves original entity/feature/relationship names through
  `EvolutionContext`.
- Passes the selected analysis mode to query templates.
- Preserves one output query per SCO/target and the existing traceable IDs.

### EvolutionContext

This component is preserved. It stores entity, feature and relationship origins
for chained operations. For example:

```orion
RENAME ENTITY Visit TO Appointment
RENAME Appointment::startDatetime TO startDate
```

The second query must still resolve `Visit.startDatetime`, because that is what
exists in the source database.

### Query

Owns the complete `.ql` query shape and alert messages. Existing signatures are
kept as compatibility overloads. Mode-aware overloads control semantic and
DataFlow-only branches at generation time, so disabled analyses add no runtime
search domain.

### Library / `utils.qll`

The physical output remains one `utils.qll` for workflow compatibility. Its
predicates are organized into logical groups:

- Entity impact: resolved type references and constructions.
- Feature impact: accessors, calls and value-producing expressions.
- JPA semantics: dual `jakarta`/`javax` annotations and EntityManager APIs.
- Spring semantics: constrained property-name APIs and derived queries.
- Relationship semantics: `JoinTable`, `mappedBy` and association fields.
- Type dependency: assignments, consumers and local-flow source/sink helpers.

A future physical split into `EntityImpactPredicates.qll`,
`FeatureImpactPredicates.qll`, `JpaSemanticPredicates.qll`, and related files is
possible, but is deliberately deferred until the workflow supports multiple
generated libraries without compatibility risk.

## Analysis modes

- `STRUCTURAL`: declarations, resolved type references, field accesses and
  accessor calls. Existing static JPQL/JPA coverage is retained for backward
  compatibility.
- `STRUCTURAL_SEMANTIC`: structural rules plus expanded JPA and conservative
  Spring framework rules. This is the default.
- `DATAFLOW`: semantic mode plus targeted local flow from the affected field or
  getter to an old-type-dependent consumer.

The mode is selected with `--mode`/`-m`. Existing clients that do not pass a
mode keep the default behavior.

## DataFlow boundary

The initial DataFlow rule uses the modular Java library and
`DataFlow::localFlow`. Sources are only resolved reads of the affected field or
its getter. Sinks are only qualifying values of method calls whose declaration
belongs to the old type hierarchy. Results are labelled as potential when
availability on the target type cannot be proven.

Global DataFlow and taint tracking remain disabled. They require separate
precision and performance evidence before inclusion.

## Result identity and deduplication

Queries select the impacted source location and one category-specific message.
Type construction is reported as a construction, while its nested type access
is excluded from the generic type-reference branch. Resolved accessor calls are
reported at the call, not once per argument or internal evidence path.

The experimental harness must additionally normalize SARIF by query ID, file,
region and construct category before comparing with ground truth.

## Build and test architecture

The Xtend Maven plugin is bound to the normal lifecycle. JUnit tests cover:

- Mode parsing and compatibility defaults.
- Generated structural/semantic/DataFlow fragments.
- Chained `EvolutionContext` behavior.
- End-to-end Orion AST generation.
- Positive and negative fixture expectations.

Actual CodeQL query compilation/evaluation is a separate test tier and must be
reported as unavailable when the CLI/database is absent.

