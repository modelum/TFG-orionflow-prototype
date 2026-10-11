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
}
