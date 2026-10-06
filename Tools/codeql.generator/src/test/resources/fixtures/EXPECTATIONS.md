# Fixture expectations

These fixtures define positive and negative constructs independently from
PetClinic/OpenMRS. They are resources rather than Maven compilation sources so
the generator tests do not require application framework dependencies.

- `entity/EntityReferences.java`: fields, generic arguments, inheritance,
  parameter, return, local and construction are positive for Rename/Delete
  Entity. Similar strings/variables in `UnrelatedReferences.java` and the
  homonymous non-entity `entity/other/Visit.java` are negative.
- `feature/FeatureImpact.java`: matching accessor declarations/calls and the
  exact first `Errors.rejectValue` argument are positive, as are the static
  JPQL and repository method derived from `birthDate`. The overload, unrelated
  class/entity, `findByOwner`, and `"owner"` property are negative.
- `relationship/RelationshipImpact.java`: mapping, field, accessor and call are
  positive for Delete Relationship. Only `@JoinTable(name=...)` is positive for
  Rename Relationship.
- `cast/CastImpact.java`: the old-type local consumer is a potential DataFlow
  impact. `String.trim()` has no affected source and is negative.
- `legacy/LegacyJpa.java`: verifies the legacy `javax.persistence` namespace.

The nested `pom.xml` makes the fixture sources compilable and suitable for a
CodeQL test database without adding framework dependencies to the generator.

Execution of these expectations against CodeQL is intentionally not claimed
until a CodeQL CLI and test database are available.
