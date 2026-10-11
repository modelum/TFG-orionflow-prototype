package codeql.template.library

/** Targeted local propagation shared only by SCOs that opt into DataFlow. */
class DataFlowLibrary {
	def static CharSequence generate()
	'''
	import java
	import orion_java
	import semmle.code.java.dataflow.DataFlow

	predicate fieldValueFlowsToOldTypeConsumer(
	  Field field, Expr source, MethodCall consumer
	) {
	  readsFieldValue(source, field) and
	  isOldTypeMethodCall(consumer, field) and
	  DataFlow::localFlow(
	    DataFlow::exprNode(source),
	    DataFlow::exprNode(consumer.getQualifier())
	  ) and
	  not readsFieldValue(consumer.getQualifier(), field)
	}

	/** A propagated field value used as a qualifier or argument of another call. */
	predicate fieldValueFlowsToDependentCall(
	  Field field, Expr source, MethodCall consumer
	) {
	  readsFieldValue(source, field) and
	  not callsAccessor(consumer, field) and
	  (
	    consumer.hasQualifier() and
	    DataFlow::localFlow(
	      DataFlow::exprNode(source),
	      DataFlow::exprNode(consumer.getQualifier())
	    )
	    or
	    exists(int i |
	      DataFlow::localFlow(
	        DataFlow::exprNode(source),
	        DataFlow::exprNode(consumer.getArgument(i))
	      )
	    )
	  )
	}

	/** A propagated collection relationship consumed by a mutating operation. */
	predicate relationshipValueFlowsToMutation(
	  Field relationshipField, Expr source, MethodCall mutation
	) {
	  readsFieldValue(source, relationshipField) and
	  mutation.hasQualifier() and
	  mutation.getMethod().getName().regexpMatch(
	    "^(add|addAll|remove|removeAll|retainAll|clear|put|putAll|replace|set)$"
	  ) and
	  // Resolve the container through the called method's source declaration.
	  // The qualifier commonly has a parameterized type (for example Set<Foo>),
	  // whose direct supertype names are not reliable for this classification.
	  (
	    mutation.getMethod().getDeclaringType().getSourceDeclaration().getASourceSupertype*()
	      .hasQualifiedName("java.util", "Collection")
	    or
	    mutation.getMethod().getDeclaringType().getSourceDeclaration().getASourceSupertype*()
	      .hasQualifiedName("java.util", "Map")
	  ) and
	  DataFlow::localFlow(
	    DataFlow::exprNode(source),
	    DataFlow::exprNode(mutation.getQualifier())
	  ) and
	  not readsFieldValue(mutation.getQualifier(), relationshipField)
	}
	'''

	/**
	 * Generates a query-local global-flow configuration. Entity, field and new
	 * type are literals known at generation time, so the global computation is
	 * seeded only by the field affected by the current CAST operation.
	 */
	def static CharSequence generateGlobalCastFlow(
		String entityName,
		String fieldName,
		String newTypeName
	)
	'''
	/** The single field selected by this generated CAST query. */
	private predicate orionCastField(Field field) {
	  exists(Class entity |
	    isEntity(entity) and
	    entity.hasName("«entityName»") and
	    field = entity.getAField() and
	    field.hasName("«fieldName»")
	  )
	}

	/** The replacement type still supports the resolved old-type operation. */
	private predicate orionNewTypeSupportsCall(MethodCall consumer) {
	  exists(RefType replacementType |
	    replacementType.getName() = "«newTypeName»" and
	    replacementType.getASupertype*().getSourceDeclaration() =
	      consumer.getMethod().getDeclaringType().getSourceDeclaration()
	  )
	}

	/** A method operation that genuinely requires the field's previous type. */
	private predicate orionCastOldTypeSink(
	  Field field, DataFlow::Node sink, MethodCall consumer
	) {
	  orionCastField(field) and
	  isOldTypeMethodCall(consumer, field) and
	  not orionNewTypeSupportsCall(consumer) and
	  sink = DataFlow::exprNode(consumer.getQualifier())
	}

	module OrionCastGlobalConfig implements DataFlow::ConfigSig {
	  predicate isSource(DataFlow::Node source) {
	    exists(Field field, Expr expression |
	      orionCastField(field) and
	      readsFieldValue(expression, field) and
	      source = DataFlow::exprNode(expression)
	    )
	  }

	  predicate isSink(DataFlow::Node sink) {
	    exists(Field field, MethodCall consumer |
	      orionCastOldTypeSink(field, sink, consumer)
	    )
	  }

	  /** Do not re-enter an independently read affected-field source. */
	  predicate isBarrierIn(DataFlow::Node node) { isSource(node) }
	}

	module OrionCastGlobalFlow = DataFlow::Global<OrionCastGlobalConfig>;

	/**
	 * Interprocedural flow only: local paths remain the responsibility of the
	 * existing lightweight predicates in orion_dataflow.qll.
	 */
	predicate fieldValueGloballyFlowsToOldTypeConsumer(
	  Field field, Expr source, MethodCall consumer
	) {
	  orionCastField(field) and
	  readsFieldValue(source, field) and
	  orionCastOldTypeSink(
	    field, DataFlow::exprNode(consumer.getQualifier()), consumer
	  ) and
	  OrionCastGlobalFlow::flow(
	    DataFlow::exprNode(source),
	    DataFlow::exprNode(consumer.getQualifier())
	  ) and
	  not DataFlow::localFlow(
	    DataFlow::exprNode(source),
	    DataFlow::exprNode(consumer.getQualifier())
	  )
	}
	'''
}
