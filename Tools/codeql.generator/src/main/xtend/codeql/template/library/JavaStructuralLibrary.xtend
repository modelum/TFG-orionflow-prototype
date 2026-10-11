package codeql.template.library

/** Framework-independent Java AST and symbol predicates. */
class JavaStructuralLibrary {
	def static CharSequence generate()
	'''
	import java

	/** Check if two expressions have the same source representation. */
	predicate isEqual(Expr a, Expr b) {
	  a.toString() = b.toString()
	}

	/** A source-level type reference resolved to the affected class. */
	predicate referencesEntityType(TypeAccess typeReference, Class entity) {
	  typeReference.fromSource() and
	  typeReference.getType() = entity
	}

	/** A constructor expression resolved to the affected class. */
	predicate constructsEntity(ClassInstanceExpr creation, Class entity) {
	  creation.getConstructedType() = entity
	}

	/** A JavaBeans getter for the affected field, validated by owner and signature. */
	predicate isGetter(Method method, Field field) {
	  method.getDeclaringType() = field.getDeclaringType() and
	  method.getNumberOfParameters() = 0 and
	  method.getReturnType() = field.getType() and
	  (
	    method.getName() = "get" + field.getName().substring(0, 1).toUpperCase() +
	      field.getName().substring(1, field.getName().length())
	    or
	    (
	      method.getName() = "is" + field.getName().substring(0, 1).toUpperCase() +
	        field.getName().substring(1, field.getName().length()) and
	      (
	        field.getType().hasName("boolean") or
	        field.getType().(RefType).hasQualifiedName("java.lang", "Boolean")
	      )
	    )
	  )
	}

	/** A JavaBeans setter for the affected field, validated by owner and signature. */
	predicate isSetter(Method method, Field field) {
	  method.getDeclaringType() = field.getDeclaringType() and
	  method.getName() = "set" + field.getName().substring(0, 1).toUpperCase() +
	    field.getName().substring(1, field.getName().length()) and
	  method.getNumberOfParameters() = 1 and
	  method.getParameter(0).getType() = field.getType()
	}

	/** A call resolved to the field's getter or setter. */
	predicate callsAccessor(MethodCall call, Field field) {
	  exists(Method accessor |
	    (isGetter(accessor, field) or isSetter(accessor, field)) and
	    call.getMethod() = accessor
	  )
	}

	/** Avoid reporting an accessor and its internal field access twice. */
	predicate isAccessInsideAccessor(FieldAccess access, Field field) {
	  exists(Method accessor |
	    (isGetter(accessor, field) or isSetter(accessor, field)) and
	    access.getEnclosingCallable() = accessor
	  )
	}

	/** An expression that reads the affected field value. */
	predicate readsFieldValue(Expr expression, Field field) {
	  expression.(FieldAccess).getField() = field
	  or
	  exists(Method getter |
	    isGetter(getter, field) and
	    expression.(MethodCall).getMethod() = getter
	  )
	}

	/** A direct expression whose operation depends on the old field type. */
	predicate usesFieldWithTypeDependency(Expr expression, Field field) {
	  exists(CastExpr cast |
	    expression = cast and
	    readsFieldValue(cast.getExpr(), field)
	  )
	  or
	  exists(MethodCall call |
	    expression = call and
	    call.hasQualifier() and
	    readsFieldValue(call.getQualifier(), field)
	  )
	}

	/** A method consumer declared on the old reference-type hierarchy. */
	predicate isOldTypeMethodCall(MethodCall call, Field field) {
	  call.hasQualifier() and
	  call.getMethod().getDeclaringType() = field.getType().(RefType).getASupertype*() and
	  not call.getMethod().getDeclaringType().hasQualifiedName("java.lang", "Object")
	}

	/** A field whose direct or generic element type is the given class. */
	predicate fieldTargetsEntity(Field field, Class entity) {
	  field.getType() = entity
	  or
	  field.getType().(ParameterizedType).getATypeArgument() = entity
	}
	'''
}
