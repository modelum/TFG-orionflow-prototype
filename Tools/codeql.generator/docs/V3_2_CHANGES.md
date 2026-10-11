# OrionFlow V3.2 changes

V3.2 completes the two interprocedural extensions planned after V3.1 without
adding a CLI mode or changing `EvolutionContext` ownership.

## Bounded Call Graph

The new generated module `orion_callgraph.qll` is emitted once per pack. Delete
Feature, Move Feature, and Delete Relationship import it and report callers one
or two resolved edges away from a method that directly accesses the affected
field.

The propagation distinguishes values from mutation effects:

- a returned value propagates only when the caller consumes it;
- a value used as the receiver of a collection mutation becomes an effect;
- an existing effect propagates through the invoking call;
- discarded pure values do not propagate;
- overload resolution is preserved through source declarations;
- virtual dispatch is resolved with `viableCallable`.

There is no transitive closure and no public configuration flag for depth.

## Global DataFlow for CAST

Cast Attribute and Cast Reference now generate a query-local
`DataFlow::Global` configuration. Its source is restricted by literal entity
and field names known by the Orion generator. Its sinks are method calls that
require the old type and are not supported by the replacement type.

The global branch excludes paths already covered by `DataFlow::localFlow`.
Delete/Move operations retain their existing local flow and do not instantiate
global configurations.

## Generator integration

- `Orion2CodeQL` emits `orion_callgraph.qll` alongside the existing modules.
- Query templates remain responsible only for constructing QL; lineage remains
  in `EvolutionContext`.
- No generated Java source is maintained manually.
- CLI behavior remains `--framework jpa|mongo|both`, with JPA as default and
  deprecated `-a ALL` accepted as a no-op.

## Validation assets

- New Orion script: `src/test/resources/orion/codeql-fixtures-v3_2.orion`.
- Extended positive/negative fixtures for values, mutation effects, overloads,
  discarded calls, virtual dispatch, arguments and returns.
- New SARIF oracle: `scripts/verify-v3_2-results.ps1`.

