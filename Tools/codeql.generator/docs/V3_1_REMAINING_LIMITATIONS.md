# OrionFlow V3.1 known limitations

- DataFlow is local only. Interprocedural propagation belongs to V3.2 and is
  not claimed by this baseline.
- Query strings must be Java compile-time constants. Runtime concatenation,
  configuration values, builders, and strings read from external resources are
  intentionally not resolved.
- Mongo embedded-component discovery follows persistent fields from a
  `@Document` root and is bounded by that ownership model. Referenced documents
  do not become embedded owners.
- Criteria/Sort support is restricted to resolved Spring Data APIs and static
  literal property paths. Dynamic property-name variables are not inferred.
- Validator inference requires an unambiguous local entity binding. Ambiguous
  casts are rejected instead of producing a low-confidence impact.
- The current experimental evidence is from internal fixtures only. PetClinic
  and StudAdvice were unavailable, and no result is extrapolated to the held-out
  OpenMRS or DZHW datasets.

