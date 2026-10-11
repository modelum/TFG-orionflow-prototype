# OrionFlow V3.1

V3.1 is the reproducible baseline immediately before interprocedural call-graph
and global-data-flow propagation are introduced in V3.2.

## Coverage changes

- Rename/Delete Entity report every explicit constructor declaration while
  keeping constructor expressions as a separate impact category.
- Mongo persistent components are derived only from bounded composition rooted
  at `@Document` classes. Transient, static, `@DBRef`, and
  `@DocumentReference` fields do not create embedded ownership.
- Mongo `Criteria.where/and`, `Sort.by`, and `Sort.Order.asc/desc` property
  arguments are resolved against the affected persistent field.
- Entity rename metadata is limited to an explicit logical JPA entity name;
  marker annotations, physical table/document names, and Lombok annotations do
  not produce redundant rename alerts.
- Spring `Validator.validate(Object, Errors)` property references can be tied
  to an entity through an unambiguous local cast and `supports` contract.
- Java compile-time constant strings, including external constants and constant
  concatenations, are evaluated through `CompileTimeConstantExpr` for query
  annotations. No DataFlow analysis is used for constants.

The generated regular expressions remain static with respect to CodeQL AST
nodes: entity and feature names are inserted by Xtend when the query is
generated.

## Compatibility correction found during validation

The `both` profile originally emitted an unparenthesized JPA/Mongo alternative
inside a larger conjunction. CodeQL correctly rejected the resulting query
because `message` was not bound on one alternative. The template now groups the
adapter alternatives explicitly.

