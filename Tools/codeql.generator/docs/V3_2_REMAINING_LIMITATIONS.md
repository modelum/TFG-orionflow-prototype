# OrionFlow V3.2 known limitations

- Call Graph propagation is intentionally bounded to two resolved edges. A
  relevant dependency beyond that boundary is not reported by this extension.
- Reflection, dynamic proxies whose concrete implementation is unavailable,
  native calls, and unresolved external bytecode are outside the call graph.
- Global DataFlow is enabled only for Cast Attribute and Cast Reference. It is
  not a general taint-tracking mode and does not apply to other SCOs.
- Replacement-type support is matched by resolved type name and its supertypes;
  Orion selectors still provide simple type names, so same-named types in
  different packages remain ambiguous.
- Query-string analysis remains bounded to compile-time constants and the
  supported JPQL/Mongo grammars. Runtime builders and external configuration
  are not inferred.
- The current V3.2 evidence uses internal fixtures. External project results
  and precision/recall/F1 require an independent ground truth and are not
  claimed here.

