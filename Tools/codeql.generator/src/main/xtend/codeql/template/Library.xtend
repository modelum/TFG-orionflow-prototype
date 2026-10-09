package codeql.template

class Library {
	def static CharSequence generateUsesOldEntity(String entityName)
	'''
	/** Check if entity «entityName» is used in a static JPQL query. */
	predicate usesOldEntity(StringLiteral queryValue) {
	  queryValue.getValue().regexpMatch(
	    "(?i).*\\b(FROM|UPDATE|DELETE\\s+FROM)\\s+«entityName»\\b.*"
	  )
	  or
	  queryValue.getValue().regexpMatch(
	    "(?i).*\\bJOIN\\s+(?:FETCH\\s+)?«entityName»\\b.*"
	  )
	}
	'''

	def static CharSequence generateUsesField(String entityName, String fieldName)
	'''
	/** Check if field «entityName».«fieldName» is used in a static JPQL query. */
	predicate usesField(Expr queryValue) {
	  // Qualified entity reference.
	  queryValue.toString().regexpMatch(
	    "(?i).*\\b«entityName»\\s*\\.\\s*«fieldName»\\b.*"
	  )
	  or
	  // Reference through an alias declared for the affected entity.
	  exists(string declaredAlias, string usedAlias |
	    declaredAlias = queryValue.toString().regexpCapture(
	      "(?i).*(FROM|JOIN)\\s+«entityName»\\s+([a-zA-Z0-9_]+).*", 2
	    ) and
	    usedAlias = queryValue.toString().regexpCapture(
	      "(?i).*\\b([a-zA-Z0-9_]+)\\s*\\.\\s*«fieldName»\\b.*", 1
	    ) and
	    declaredAlias = usedAlias
	  )
	  or
	  // Unqualified property in a WHERE clause for the affected entity.
	  queryValue.toString().regexpMatch("(?i).*FROM\\s+«entityName»\\b.*") and
	  queryValue.toString().regexpMatch("(?i).*\\bWHERE\\b.*\\b«fieldName»\\b.*")
	}
	'''

	def static CharSequence generateFeatureSemanticPredicates(String entityName, String fieldName)
	'''
	/**
	 * A Spring validation API argument that unambiguously names «fieldName» in
	 * a callable that also receives the affected entity.
	 */
	predicate isSpringPropertyReference(MethodCall call, StringLiteral propertyName, Class entity) {
	  entity.hasName("«entityName»") and
	  isEntity(entity) and
	  propertyName = call.getArgument(0) and
	  propertyName.getValue() = "«fieldName»" and
	  exists(Parameter entityParameter |
	    entityParameter = call.getEnclosingCallable().getAParameter() and
	    entityParameter.getType() = entity
	  ) and
	  call.getMethod().getDeclaringType().getASupertype*()
	    .hasQualifiedName("org.springframework.validation", "Errors") and
	  (
	    call.getMethod().getName() = "rejectValue" or
	    call.getMethod().getName() = "getFieldValue" or
	    call.getMethod().getName() = "getFieldError" or
	    call.getMethod().getName() = "hasFieldErrors"
	  )
	}

	/** A Spring Data repository query derived from property «fieldName». */
	predicate isSpringDataDerivedQuery(Method method, Class entity) {
	  exists(ClassOrInterface repository, TypeAccess repositoryType |
	    method.getDeclaringType() = repository and
	    repository.contains(repositoryType) and
	    repositoryType.getTypeArgument(0).getType() = entity and
	    repositoryType.getType().(RefType).getASupertype*()
	      .hasQualifiedName("org.springframework.data.repository", "Repository") and
	    method.getName().regexpMatch(
	      "^(find|read|get|query|search|stream|count|exists|delete|remove).*(By|And|Or)«capitalize(fieldName)»([A-Z0-9].*)?$"
	    )
	  )
	}
	'''

	private static def String capitalize(String value) {
		if (value === null || value.empty)
			value
		else
			value.substring(0, 1).toUpperCase + value.substring(1)
	}

	def static CharSequence generateUtils()
	'''
	import java

	/** Check if two expressions have the same source representation. */
	predicate isEqual(Expr a, Expr b) {
	  a.toString() = b.toString()
	}

	/** Match a JPA annotation in either the Jakarta or legacy Javax namespace. */
	predicate isJpaAnnotation(Annotation annotation, string simpleName) {
	  annotation.getType().hasQualifiedName("jakarta.persistence", simpleName)
	  or
	  annotation.getType().hasQualifiedName("javax.persistence", simpleName)
	}

	/** Check if an annotation is a Spring Data Query annotation. */
	predicate isQuery(Annotation annotation) {
	  annotation.getType().hasQualifiedName("org.springframework.data.jpa.repository", "Query")
	}

	/** Check if an annotation is a JPA NamedQuery annotation. */
	predicate isNamedQuery(Annotation annotation) {
	  isJpaAnnotation(annotation, "NamedQuery")
	}

	/** Check if a class is a JPA entity. */
	predicate isEntity(Class entity) {
	  exists(Annotation annotation |
	    annotation = entity.getAnAnnotation() and
	    isJpaAnnotation(annotation, "Entity")
	  )
	}

	/** Check if a class is JPA embeddable. */
	predicate isEmbeddable(Class cls) {
	  exists(Annotation annotation |
	    annotation = cls.getAnAnnotation() and
	    isJpaAnnotation(annotation, "Embeddable")
	  )
	}

	/** Check if a field is annotated with Embedded. */
	predicate isEmbeddedField(Field field) {
	  exists(Annotation annotation |
	    annotation = field.getAnAnnotation() and
	    isJpaAnnotation(annotation, "Embedded")
	  )
	}

	/** A source-level type reference resolved to the affected entity. */
	predicate referencesEntityType(TypeAccess typeReference, Class entity) {
	  typeReference.fromSource() and
	  typeReference.getType() = entity
	}

	/** A constructor expression resolved to the affected entity. */
	predicate constructsEntity(ClassInstanceExpr creation, Class entity) {
	  creation.getConstructedType() = entity
	}

	/**
	 * Generic JPQL field matching without AST-dependent regex construction.
	 * Static patterns capture identifiers and compare them semantically.
	 */
	predicate usesField(Expr queryValue, Field field) {
	  exists(Class entity |
	    entity = field.getDeclaringType() and
	    (
	      exists(string referencedEntity, string referencedField |
	        referencedEntity = queryValue.toString().regexpCapture(
	          "(?i).*\\b([a-zA-Z0-9_]+)\\s*\\.\\s*([a-zA-Z0-9_]+)\\b.*", 1
	        ) and
	        referencedField = queryValue.toString().regexpCapture(
	          "(?i).*\\b([a-zA-Z0-9_]+)\\s*\\.\\s*([a-zA-Z0-9_]+)\\b.*", 2
	        ) and
	        referencedEntity = entity.getName() and
	        referencedField = field.getName()
	      )
	      or
	      exists(string declaredEntity, string declaredAlias, string usedAlias, string referencedField |
	        declaredEntity = queryValue.toString().regexpCapture(
	          "(?i).*(FROM|JOIN)\\s+([a-zA-Z0-9_]+)\\s+([a-zA-Z0-9_]+).*", 2
	        ) and
	        declaredAlias = queryValue.toString().regexpCapture(
	          "(?i).*(FROM|JOIN)\\s+([a-zA-Z0-9_]+)\\s+([a-zA-Z0-9_]+).*", 3
	        ) and
	        usedAlias = queryValue.toString().regexpCapture(
	          "(?i).*\\b([a-zA-Z0-9_]+)\\s*\\.\\s*([a-zA-Z0-9_]+)\\b.*", 1
	        ) and
	        referencedField = queryValue.toString().regexpCapture(
	          "(?i).*\\b([a-zA-Z0-9_]+)\\s*\\.\\s*([a-zA-Z0-9_]+)\\b.*", 2
	        ) and
	        declaredEntity = entity.getName() and
	        declaredAlias = usedAlias and
	        referencedField = field.getName()
	      )
	      or
	      exists(string declaredEntity, string referencedField |
	        declaredEntity = queryValue.toString().regexpCapture(
	          "(?i).*FROM\\s+([a-zA-Z0-9_]+)\\b.*", 1
	        ) and
	        referencedField = queryValue.toString().regexpCapture(
	          "(?i).*\\bWHERE\\b.*\\b([a-zA-Z0-9_]+)\\b.*", 1
	        ) and
	        declaredEntity = entity.getName() and
	        referencedField = field.getName()
	      )
	    )
	  )
	}

	/** Check if a parent entity is used in a static JPQL query. */
	predicate usesParentEntity(Expr queryValue, Class parent) {
	  exists(string referencedEntity |
	    referencedEntity = queryValue.toString().regexpCapture(
	      "(?i).*\\bSELECT\\b.*\\bFROM\\s+([a-zA-Z0-9_]+)\\b.*", 1
	    ) and
	    referencedEntity = parent.getName()
	  )
	  or
	  exists(string joinedEntity |
	    joinedEntity = queryValue.toString().regexpCapture(
	      "(?i).*\\bJOIN\\s+(?:FETCH\\s+)?([a-zA-Z0-9_]+)\\b.*", 1
	    ) and
	    joinedEntity = parent.getName()
	  )
	}

	/** JPA JOINED inheritance in either namespace. */
	class InheritanceStrategyJOINED extends Annotation {
	  InheritanceStrategyJOINED() {
	    isJpaAnnotation(this, "Inheritance") and
	    this.getValue("strategy").toString() = "InheritanceType.JOINED"
	  }
	}

	predicate childParentInheritanceWithStrategyJOINED(Class child, Class parent) {
	  parent = child.getASupertype().(Class) and
	  parent.getAnAnnotation() instanceof InheritanceStrategyJOINED
	}

	/** A JavaBeans getter for the affected field, validated by signature. */
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

	/** A JavaBeans setter for the affected field, validated by signature. */
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

	/** Avoid reporting an accessor and its internal field access as two constructs. */
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

	predicate isCreateQuery(MethodCall call) {
	  call.getMethod().hasQualifiedName("jakarta.persistence", "EntityManager", "createQuery")
	  or
	  call.getMethod().hasQualifiedName("javax.persistence", "EntityManager", "createQuery")
	}

	predicate isCreateNamedQuery(MethodCall call) {
	  call.getMethod().hasQualifiedName("jakarta.persistence", "EntityManager", "createNamedQuery")
	  or
	  call.getMethod().hasQualifiedName("javax.persistence", "EntityManager", "createNamedQuery")
	}

	predicate hasJpaAssociationTo(Field field) {
	  exists(Annotation annotation |
	    annotation = field.getAnAnnotation() and
	    isJpaAssociationAnnotation(annotation)
	  )
	}

	predicate isJpaAssociationAnnotation(Annotation annotation) {
	  isJpaAnnotation(annotation, "ManyToOne") or
	  isJpaAnnotation(annotation, "OneToOne") or
	  isJpaAnnotation(annotation, "OneToMany") or
	  isJpaAnnotation(annotation, "ManyToMany")
	}

	predicate isRelationshipField(Field field) {
	  hasJpaAssociationTo(field)
	}

	/** A field whose direct or generic element type is the given entity. */
	predicate fieldTargetsEntity(Field field, Class entity) {
	  field.getType() = entity
	  or
	  field.getType().(ParameterizedType).getATypeArgument() = entity
	}

	/** A JPA metadata value that refers to the affected feature. */
	predicate jpaMetadataReferencesField(Annotation annotation, Field field) {
	  exists(Field annotatedField |
	    annotation = annotatedField.getAnAnnotation() and
	    (
	      annotatedField = field and
	      (
	        isJpaAnnotation(annotation, "Column") or
	        isJpaAnnotation(annotation, "JoinColumn")
	      ) and
	      annotation.getValue("name").toString().replaceAll("\"", "") = field.getName()
	      or
	      annotatedField != field and
	      fieldTargetsEntity(annotatedField, field.getDeclaringType()) and
	      isJpaAssociationAnnotation(annotation) and
	      annotation.getValue("mappedBy").toString().replaceAll("\"", "") = field.getName()
	    )
	  )
	}

	predicate isRelatedField(Field relationshipField, Field mappedField) {
	  exists(Annotation mappedBy |
	    mappedBy = mappedField.getAnAnnotation() and
	    fieldTargetsEntity(mappedField, relationshipField.getDeclaringType()) and
	    isJpaAssociationAnnotation(mappedBy) and
	    mappedBy.getValue("mappedBy").toString().replaceAll("\"", "") =
	      relationshipField.getName()
	  )
	}

	private predicate fieldReferencedInQuery(Expr queryValue, Field field) {
	  usesField(queryValue, field)
	}

	predicate usesRelationship(Expr queryValue, Field relationshipField) {
	  fieldReferencedInQuery(queryValue, relationshipField)
	  or
	  exists(Field mappedField |
	    isRelatedField(relationshipField, mappedField) and
	    fieldReferencedInQuery(queryValue, mappedField)
	  )
	}

	Field getRelationshipField(Class sourceEntity, string relationshipTableName) {
	  result = sourceEntity.getAField() and
	  isRelationshipField(result) and
	  exists(Annotation joinTable |
	    hasJoinTableAnnotation(result, joinTable) and
	    joinTable.getValue("name").toString().replaceAll("\"", "") = relationshipTableName
	  )
	}

	predicate hasJoinTableAnnotation(Field field, Annotation joinTable) {
	  joinTable = field.getAnAnnotation() and
	  isJpaAnnotation(joinTable, "JoinTable")
	}
	'''
}
