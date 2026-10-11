package codeql.template.library

/** Spring rules that are independent of the persistence engine. */
class SpringCommonLibrary {
	def static CharSequence generate()
	'''
	import java
	import orion_java

	/** A supported Spring validation call whose first argument is a property name. */
	predicate isSpringValidationPropertyCall(MethodCall call, StringLiteral propertyName) {
	  propertyName = call.getArgument(0) and
	  call.getMethod().getDeclaringType().getASupertype*()
	    .hasQualifiedName("org.springframework.validation", "Errors") and
	  (
	    call.getMethod().getName() = "rejectValue" or
	    call.getMethod().getName() = "getFieldValue" or
	    call.getMethod().getName() = "getFieldError" or
	    call.getMethod().getName() = "hasFieldErrors"
	  )
	}

	private predicate springCastBindsEntityVariable(
	  Callable callable, Class entity, LocalVariableDecl variable
	) {
	  exists(Parameter target, CastExpr cast |
	    target.getCallable() = callable and
	    target.getType().(RefType).hasQualifiedName("java.lang", "Object") and
	    cast.getEnclosingCallable() = callable and
	    cast.getExpr() = target.getAnAccess() and
	    cast.getType() = entity and
	    variable.getInitializer() = cast
	  )
	}

	private predicate springVariableUsesField(
	  Callable callable, LocalVariableDecl variable, Field field
	) {
	  exists(MethodCall accessorCall, Method accessor |
	    accessorCall.getEnclosingCallable() = callable and
	    accessorCall.hasQualifier() and
	    accessorCall.getQualifier() = variable.getAnAccess() and
	    isGetter(accessor, field) and
	    accessorCall.getMethod().getSourceDeclaration() = accessor.getSourceDeclaration()
	  )
	}

	private predicate springValidatorSupportsEntity(Callable validation, Class entity) {
	  exists(Method supports, TypeLiteral entityLiteral |
	    validation.getName() = "validate" and
	    supports.getDeclaringType() = validation.getDeclaringType() and
	    supports.getName() = "supports" and
	    supports.getNumberOfParameters() = 1 and
	    supports.getParameter(0).getType().getErasure().(RefType).hasQualifiedName(
	      "java.lang", "Class"
	    ) and
	    entityLiteral.getEnclosingCallable() = supports and
	    entityLiteral.getReferencedType() = entity and
	    not exists(TypeLiteral otherLiteral, Class otherEntity |
	      otherLiteral.getEnclosingCallable() = supports and
	      otherLiteral.getReferencedType() = otherEntity and
	      otherEntity != entity and
	      otherEntity.fromSource()
	    )
	  )
	}

	private predicate springValidationEntityCandidate(
	  MethodCall call, string propertyName, Class entity
	) {
	  exists(Field field |
	    field.getDeclaringType() = entity and
	    field.hasName(propertyName) and
	    (
	      exists(Parameter entityParameter |
	        entityParameter.getCallable() = call.getEnclosingCallable() and
	        entityParameter.getType() = entity
	      )
	      or
	      exists(LocalVariableDecl converted |
	        springCastBindsEntityVariable(call.getEnclosingCallable(), entity, converted) and
	        springVariableUsesField(call.getEnclosingCallable(), converted, field) and
	        (
	          springValidatorSupportsEntity(call.getEnclosingCallable(), entity)
	          or
	          not exists(
	            Class otherEntity, LocalVariableDecl otherConverted, Field otherField |
	            otherEntity != entity and
	            otherField.getDeclaringType() = otherEntity and
	            otherField.hasName(propertyName) and
	            springCastBindsEntityVariable(
	              call.getEnclosingCallable(), otherEntity, otherConverted
	            ) and
	            springVariableUsesField(
	              call.getEnclosingCallable(), otherConverted, otherField
	            )
	          )
	        )
	      )
	    )
	  )
	}

	/**
	 * Entity bound to a validation property call, including an Object parameter
	 * explicitly cast and used as that entity within the same method.
	 */
	predicate springValidationCallTargetsEntity(
	  MethodCall call, string propertyName, Class entity
	) {
	  springValidationEntityCandidate(call, propertyName, entity) and
	  not exists(Class otherEntity |
	    otherEntity != entity and
	    springValidationEntityCandidate(call, propertyName, otherEntity)
	  )
	}

	/** A Spring Data repository method whose domain generic is the selected entity. */
	predicate isSpringRepositoryMethodForEntity(Method method, Class entity) {
	  exists(ClassOrInterface repository, ParameterizedType repositoryType |
	    method.getDeclaringType() = repository and
	    repositoryType = repository.getASupertype*() and
	    repositoryType.getTypeArgument(0) = entity and
	    repositoryType.getGenericType().getASupertype*()
	      .hasQualifiedName("org.springframework.data.repository", "Repository")
	  )
	}
	'''
}
