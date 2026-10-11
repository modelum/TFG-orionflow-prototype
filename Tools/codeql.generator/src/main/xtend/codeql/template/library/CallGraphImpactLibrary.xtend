package codeql.template.library

/**
 * Generates the bounded, field-seeded call-graph propagation used by SCOs
 * whose removal or relocation can affect callers indirectly.
 */
class CallGraphImpactLibrary {
	def static CharSequence generate()
	'''
	import java
	import orion_java
	import semmle.code.java.Collections
	import semmle.code.java.dispatch.VirtualDispatch

	/** A source method whose implementation accesses the affected field. */
	private predicate directlyDependsOnField(Method method, Field field) {
	  method.fromSource() and
	  exists(FieldAccess access |
	    access.getField() = field and
	    access.getEnclosingCallable() = method
	  )
	}

	/** Direct dependencies that mutate the field propagate as effects. */
	private predicate directlyMutatesField(Method method, Field field) {
	  exists(FieldWrite write |
	    write.getField() = field and
	    write.getEnclosingCallable() = method
	  )
	  or
	  exists(MethodCall mutation, FieldAccess access |
	    mutation.getEnclosingCallable() = method and
	    mutation.getMethod() instanceof CollectionMutator and
	    mutation.getQualifier() = access and
	    access.getField() = field
	  )
	}

	/**
	 * Resolves a concrete/static target or a viable virtual-dispatch target.
	 * Source declarations preserve overload resolution while normalizing
	 * generic method instantiations.
	 */
	private predicate resolvedCallTo(MethodCall call, Method callee) {
	  call.getMethod().getSourceDeclaration() = callee.getSourceDeclaration()
	  or
	  viableCallable(call).(Method).getSourceDeclaration() =
	    callee.getSourceDeclaration()
	}

	/** The called value is used as the receiver of a collection mutation. */
	private predicate callFeedsCollectionMutation(MethodCall call) {
	  exists(MethodCall mutation |
	    mutation.getMethod() instanceof CollectionMutator and
	    mutation.getQualifier() = call
	  )
	}

	/** Kind of dependency exported by a field-accessing seed method. */
	private predicate directDependencyKind(Method method, Field field, string kind) {
	  directlyDependsOnField(method, field) and
	  (
	    directlyMutatesField(method, field) and kind = "effect"
	    or
	    not directlyMutatesField(method, field) and kind = "value"
	  )
	}

	/**
	 * A call edge is relevant when its result is consumed, when it drives a
	 * collection mutation, or when it invokes an already effectful method.
	 */
	private predicate relevantCallEdge(
	  MethodCall call, string incomingKind, string outgoingKind, string reason
	) {
	  incomingKind = "effect" and
	  outgoingKind = "effect" and
	  reason = "invokes an affected method with an indirect mutation effect"
	  or
	  incomingKind = "value" and
	  callFeedsCollectionMutation(call) and
	  outgoingKind = "effect" and
	  reason = "uses the affected result as the receiver of a collection mutation"
	  or
	  incomingKind = "value" and
	  not callFeedsCollectionMutation(call) and
	  not call instanceof ValueDiscardingExpr and
	  outgoingKind = "value" and
	  reason = "consumes the value returned by an affected method"
	}

	/** A relevant caller exactly one resolved call edge from a direct seed. */
	private predicate oneLevelFieldImpact(
	  Field field, Method directMethod, Method impactedMethod,
	  MethodCall evidence, string outgoingKind, string reason
	) {
	  exists(string directKind |
	    directDependencyKind(directMethod, field, directKind) and
	    evidence.getEnclosingCallable() = impactedMethod and
	    impactedMethod.fromSource() and
	    impactedMethod != directMethod and
	    resolvedCallTo(evidence, directMethod) and
	    relevantCallEdge(evidence, directKind, outgoingKind, reason)
	  )
	}

	/**
	 * Bounded propagation for one or two call edges. There is deliberately no
	 * transitive closure over the application call graph.
	 */
	predicate fieldCallGraphImpact(
	  Field field, Method impactedMethod, MethodCall evidence,
	  string depth, string reason
	) {
	  exists(Method directMethod, string kind |
	    oneLevelFieldImpact(
	      field, directMethod, impactedMethod, evidence, kind, reason
	    ) and
	    depth = "1"
	  )
	  or
	  exists(
	    Method directMethod, Method intermediateMethod, MethodCall firstEvidence,
	    string intermediateKind, string finalKind
	  |
	    oneLevelFieldImpact(
	      field, directMethod, intermediateMethod, firstEvidence,
	      intermediateKind, _
	    ) and
	    evidence.getEnclosingCallable() = impactedMethod and
	    impactedMethod.fromSource() and
	    impactedMethod != intermediateMethod and
	    impactedMethod != directMethod and
	    resolvedCallTo(evidence, intermediateMethod) and
	    relevantCallEdge(evidence, intermediateKind, finalKind, reason) and
	    depth = "2"
	  )
	}
	'''
}
