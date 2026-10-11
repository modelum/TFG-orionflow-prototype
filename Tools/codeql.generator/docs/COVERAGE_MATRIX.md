# OrionFlow V2 coverage matrix

This matrix describes the current generated predicates. “Local DataFlow” means
the source/sink-constrained helpers in `orion_dataflow.qll`; it does not mean
global flow or taint tracking.

## SCO coverage

| SCO | Structural Java | JPA adapter | MongoDB adapter | Local DataFlow |
|---|---|---|---|---|
| Rename Entity | Entity declaration, resolved `TypeAccess`, construction, typed fields, inheritance, repository type references | `@Entity`/`@Table`, associations, static JPQL, Spring Data JPA `@Query`, named queries, EntityManager | `@Document`, Java/stored collection names, Spring Data Mongo `@Query`, `MongoOperations` collection arguments | No |
| Delete Entity | Same source-code bindings as Rename Entity | Same JPA entity/query coverage | Same MongoDB document/query/collection coverage | No |
| Split Entity | Source-side entity deletion impact using preserved lineage | Selected JPA semantics | Selected MongoDB semantics | No |
| Rename Feature | Field declaration, direct access, accessor declaration and resolved calls | `@Column`, `@JoinColumn`, `mappedBy`, static JPQL, validation properties, derived repository methods | Java and `@Field` names, `@Indexed`/`@CompoundIndex`, JSON query text, Criteria/Update/aggregation field APIs, validation properties, derived repository methods | No |
| Delete Feature | Same structural and framework bindings as Rename Feature | Same JPA feature semantics | Same MongoDB feature semantics | Yes: field/getter value to dependent call |
| Move Feature | Source field/access/accessor impact plus target-owner context | Source-side JPA feature metadata/query impact | Source-side MongoDB Java/stored-name metadata/query impact | Yes: source field/getter value to dependent call |
| Cast Attribute | Field/accessor declarations and calls, initializers, assignments, arguments, direct old-type consumers | Framework metadata associated with the field | Framework metadata and typed field-name APIs | Yes: old value to old-type consumer |
| Cast Reference | Reference field/accessor declarations and calls, assignments and consumers | Association plus `JoinColumn`/`JoinColumns`/`JoinTable` mapping | `@DBRef`/`@DocumentReference` mapping | Yes: old reference to old-type consumer |
| Promote Attribute | Existing identifier declaration and annotation impact | `@Id`, `@EmbeddedId`, `@GeneratedValue`, join-column bindings | `@Id` and `@MongoId` | No |
| Rename Relationship | Mapping annotation containing the physical relationship name | `@JoinTable` and direct/nested `@JoinColumn` names, including `referencedColumnName` | `@Field` stored name and Mongo reference mapping | No |
| Delete Relationship | Relationship field, related side, accessors/calls, direct and query use | JPA association and `mappedBy` semantics | `@DBRef`/`@DocumentReference`, related fields, Java/stored query names | Yes: relationship collection to collection/map mutation |

## Persistence semantics

| Construct | JPA | MongoDB |
|---|---:|---:|
| Entity/document declaration | `jakarta.persistence.Entity`, `javax.persistence.Entity` | `@Document` |
| Explicit persisted type name | `@Entity(name=...)`, table metadata where applicable | `@Document(collection=...)` or `value` |
| Identifier | `@Id`, `@EmbeddedId` | Spring Data `@Id`, `@MongoId` |
| Reference mapping | `ManyToOne`, `OneToOne`, `OneToMany`, `ManyToMany`, join columns/tables | `@DBRef`, `@DocumentReference` |
| Logical versus stored field name | Java field and JPA metadata | Java field and `@Field(value/name)` |
| Query annotations | Spring Data JPA `@Query`, JPA `@NamedQuery` | Spring Data MongoDB `@Query` |
| Programmatic query APIs | `EntityManager.createQuery/createNamedQuery` | `MongoOperations`, `Criteria.where`, `Update`, aggregation field methods |
| Index metadata | Not modelled as a feature-name source | `@Indexed`, `@CompoundIndex`, `@CompoundIndexes` |
| Repository-derived methods | Spring Data repository domain binding plus generated method-name pattern | Same shared repository rule, bound to a Mongo document |

## Framework selection

| CLI selection | Generated persistence modules | Facade behavior |
|---|---|---|
| omitted or `--framework jpa` | `orion_jpa.qll` | JPA predicates only |
| `--framework mongo` | `orion_mongo.qll` | MongoDB predicates only |
| `--framework both` | `orion_jpa.qll`, `orion_mongo.qll` | Union of both adapters; structural modules remain singletons |

## Deliberate boundaries

- Orion-known entity and feature names are generated as literals. Generic
  query helpers use constant captures followed by semantic equality.
- Static JPQL and MongoDB JSON/query strings are covered by a bounded grammar;
  this is not a complete JPQL, JSON, or aggregation parser.
- Dynamically assembled query text, native SQL, reflective access, and arbitrary
  strings are not treated as schema references.
- Local DataFlow is enabled only for the five SCOs in the first table. Global
  DataFlow and taint tracking are not enabled.
- Rename Relationship targets physical mapping names; it intentionally does not
  report unrelated domain accessor names.
- Same-named entities in different packages remain limited by Orion selectors
  that supply only a simple entity name.
