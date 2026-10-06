# OrionFlow V2 coverage matrix

Legend: **Current support** describes the immutable V1 baseline. **V2 target**
records the implemented target except where the cell explicitly says deferred
or research target. “Semantic” means resolved framework or ORM semantics rather
than unrestricted text matching.

| SCO | Code construct | Current support | V2 target | Detection mechanism |
|---|---|---:|---:|---|
| Rename/Delete Entity | JPA entity declaration | Yes | Yes | AST + JPA annotation |
| Rename/Delete Entity | Ordinary field type | Partial: associations only | Yes | Resolved `TypeAccess` |
| Rename/Delete Entity | Generic type argument | No | Yes | Resolved nested `TypeAccess` |
| Rename/Delete Entity | Parameter type | No | Yes | Resolved `TypeAccess` |
| Rename/Delete Entity | Return type | No | Yes | Resolved `TypeAccess` |
| Rename/Delete Entity | Local variable type | No | Yes | Resolved `TypeAccess` |
| Rename/Delete Entity | `new Entity()` | No | Yes | `ClassInstanceExpr` + resolved type |
| Rename/Delete Entity | Base class/interface | No | Yes | Resolved `TypeAccess` |
| Rename/Delete Entity | Repository generic | No | Yes | Resolved generic `TypeAccess` |
| Rename/Delete Entity | JPA association | Partial | Yes | Type resolution + dual JPA namespace |
| Rename/Delete Entity | Static JPQL/EntityManager | Yes | Yes | Static literal regex + annotation/API semantics |
| Rename/Delete Entity | Dynamic JPQL | No | Out of current scope | Potential future taint tracking |
| Rename/Delete Feature | Field declaration | Yes | Yes | Resolved field |
| Rename/Delete Feature | Getter/setter declaration | Partial | Yes | Name + signature + owner |
| Rename/Delete Feature | Direct field access | Yes | Yes | Resolved `FieldAccess` |
| Rename/Delete Feature | Getter/setter call | No | Yes | Resolved `MethodCall.getMethod()` |
| Rename/Delete Feature | `mappedBy` reference | No | Yes | JPA annotation semantics |
| Rename/Delete Feature | Column/join-column metadata | No | Yes | JPA annotation semantics |
| Rename/Delete Feature | Spring validation property | No | Yes, conservative | Framework method + entity parameter + exact literal |
| Rename/Delete Feature | Spring Data derived query | No | Yes, conservative | Repository generic + generated static name regex |
| Rename/Delete Feature | Static JPQL | Yes | Yes | Generated literal regex |
| Delete Relationship | Owning mapping/field | Yes | Yes | `@JoinTable` + association field |
| Delete Relationship | Opposite `mappedBy` | Yes | Yes | JPA annotation semantics |
| Delete Relationship | Accessor declarations/calls | No | Yes | Resolved methods/calls |
| Delete Relationship | Direct/collection use | No | Yes | Resolved field/accessor calls |
| Delete Relationship | Static JPQL | Yes | Yes | Static captures + resolved field |
| Rename Relationship | `@JoinTable(name=...)` | Yes | Yes | Exact annotation value |
| Rename Relationship | Accessors/domain field | Intentionally No | No | Not affected by physical rename |
| Cast Attribute/Reference | Field declaration | Yes | Yes | Resolved field |
| Cast Attribute/Reference | Accessor declaration | Yes | Yes | Name + signature + owner |
| Cast Attribute/Reference | Accessor invocation | No | Yes | Resolved call |
| Cast Attribute/Reference | Initialization/assignment | Partial | Yes | AST + resolved expression type |
| Cast Attribute/Reference | Old-type method consumer | No | Yes | AST in semantic mode; local flow in dataflow mode |
| Cast Attribute/Reference | Local propagation | No | Experimental | Local `DataFlow::localFlow` |
| Cast Attribute/Reference | Interprocedural propagation | No | Deferred | Global DataFlow only after evidence |
| Move Feature | Source declaration/access | Partial | Yes | Reused feature rules + lineage |
| Move Feature | New-owner navigation rewrite | No | Research target | Semantic navigation; possible local flow |
| Promote Attribute | Identifier declaration/annotations | Yes | Yes | AST + JPA semantics |
| Promote Attribute | Multiple promoted fields | Partial | Later V2 | Per-feature query generation |
| All relevant SCOs | `jakarta.persistence` | Yes | Yes | Semantic annotation/API predicates |
| All relevant SCOs | `javax.persistence` | No | Yes | Semantic annotation/API predicates |
| All relevant SCOs | Comments/similar variable names | No | No | Explicitly excluded |
| All relevant SCOs | Arbitrary strings | No | No | Only explicit framework/JPQL roles |

## Mode allocation

| Mechanism | STRUCTURAL | STRUCTURAL_SEMANTIC | DATAFLOW |
|---|---:|---:|---:|
| Resolved Java declarations/types/accesses/calls | Yes | Yes | Yes |
| JPA/JPQL/Spring-aware rules | Existing compatibility subset | Yes | Yes |
| Local value propagation to type-dependent sinks | No | No | Yes |
| Global DataFlow | No | No | Not enabled initially |
| Taint tracking for dynamic queries | No | No | Not enabled initially |

