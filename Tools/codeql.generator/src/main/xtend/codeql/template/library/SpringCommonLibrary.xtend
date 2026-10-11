package codeql.template.library

/** Spring rules that are independent of the persistence engine. */
class SpringCommonLibrary {
	def static CharSequence generate()
	'''
	import java

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
