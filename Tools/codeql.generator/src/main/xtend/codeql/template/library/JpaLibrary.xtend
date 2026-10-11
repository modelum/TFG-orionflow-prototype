package codeql.template.library

/** JPA, JPQL and Spring Data JPA semantics. */
class JpaLibrary {
	def static CharSequence generate()
	'''
	import java
	import orion_java

	predicate isJpaAnnotation(Annotation annotation, string simpleName) {
	  annotation.getType().hasQualifiedName("jakarta.persistence", simpleName)
	  or
	  annotation.getType().hasQualifiedName("javax.persistence", simpleName)
	}

	predicate isJpaQuery(Annotation annotation) {
	  annotation.getType().hasQualifiedName("org.springframework.data.jpa.repository", "Query")
	}

	predicate isJpaNamedQuery(Annotation annotation) {
	  isJpaAnnotation(annotation, "NamedQuery")
	}

	predicate isJpaEntity(Class entity) {
	  exists(Annotation annotation |
	    annotation = entity.getAnAnnotation() and
	    isJpaAnnotation(annotation, "Entity")
	  )
	}

	predicate jpaEntityHasName(Class entity, string name) {
	  name = entity.getName()
	  or
	  exists(Annotation annotation |
	    annotation = entity.getAnAnnotation() and
	    isJpaAnnotation(annotation, "Entity") and
	    name = annotation.getStringValue("name")
	  )
	}

	predicate isJpaEntityMetadataAnnotation(Class entity, Annotation annotation) {
	  annotation = entity.getAnAnnotation() and
	  (isJpaAnnotation(annotation, "Entity") or isJpaAnnotation(annotation, "Table"))
	}

	predicate isJpaEmbeddable(Class cls) {
	  exists(Annotation annotation |
	    annotation = cls.getAnAnnotation() and
	    isJpaAnnotation(annotation, "Embeddable")
	  )
	}

	predicate isJpaEmbeddedField(Field field) {
	  exists(Annotation annotation |
	    annotation = field.getAnAnnotation() and
	    isJpaAnnotation(annotation, "Embedded")
	  )
	}

	predicate isJpaCreateQuery(MethodCall call) {
	  call.getMethod().hasQualifiedName("jakarta.persistence", "EntityManager", "createQuery")
	  or
	  call.getMethod().hasQualifiedName("javax.persistence", "EntityManager", "createQuery")
	}

	predicate isJpaCreateNamedQuery(MethodCall call) {
	  call.getMethod().hasQualifiedName("jakarta.persistence", "EntityManager", "createNamedQuery")
	  or
	  call.getMethod().hasQualifiedName("javax.persistence", "EntityManager", "createNamedQuery")
	}

	/** JPQL feature matching using static captures and semantic equality. */
	predicate jpaQueryReferencesField(Expr queryValue, Field field) {
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
	        jpaEntityHasName(entity, referencedEntity) and
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
	        jpaEntityHasName(entity, declaredEntity) and
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
	        jpaEntityHasName(entity, declaredEntity) and
	        referencedField = field.getName()
	      )
	    )
	  )
	}

	predicate isJpaAssociationAnnotation(Annotation annotation) {
	  isJpaAnnotation(annotation, "ManyToOne") or
	  isJpaAnnotation(annotation, "OneToOne") or
	  isJpaAnnotation(annotation, "OneToMany") or
	  isJpaAnnotation(annotation, "ManyToMany")
	}

	predicate isJpaReferenceMappingAnnotation(Annotation annotation, Field field) {
	  annotation = field.getAnAnnotation() and
	  (
	    isJpaAssociationAnnotation(annotation) or
	    isJpaAnnotation(annotation, "JoinColumn") or
	    isJpaAnnotation(annotation, "JoinColumns") or
	    isJpaAnnotation(annotation, "JoinTable")
	  )
	}

	predicate isJpaRelationshipField(Field field) {
	  exists(Annotation annotation |
	    annotation = field.getAnAnnotation() and
	    isJpaAssociationAnnotation(annotation)
	  )
	}

	predicate jpaMetadataReferencesField(Annotation annotation, Field field) {
	  exists(Field annotatedField |
	    annotation = annotatedField.getAnAnnotation() and
	    (
	      annotatedField = field and
	      (
	        isJpaAnnotation(annotation, "Column") or
	        isJpaAnnotation(annotation, "JoinColumn") or
	        isJpaAnnotation(annotation, "AttributeOverride")
	      ) and
	      annotation.getStringValue("name") = field.getName()
	      or
	      annotatedField != field and
	      fieldTargetsEntity(annotatedField, field.getDeclaringType()) and
	      isJpaAssociationAnnotation(annotation) and
	      annotation.getStringValue("mappedBy") = field.getName()
	    )
	  )
	  or
	  exists(Field embeddedContainer |
	    annotation = embeddedContainer.getAnAnnotation() and
	    embeddedContainer.getType() = field.getDeclaringType() and
	    isJpaAnnotation(annotation, "AttributeOverride") and
	    annotation.getStringValue("name") = field.getName()
	  )
	  or
	  exists(Field embeddedContainer, Annotation overrides |
	    overrides = embeddedContainer.getAnAnnotation() and
	    embeddedContainer.getType() = field.getDeclaringType() and
	    isJpaAnnotation(overrides, "AttributeOverrides") and
	    annotation = overrides.getAnArrayValue("value").(Annotation) and
	    annotation.getStringValue("name") = field.getName()
	  )
	}

	predicate isJpaRelatedField(Field relationshipField, Field mappedField) {
	  isJpaRelationshipField(relationshipField) and
	  exists(Annotation mappedBy |
	    mappedBy = mappedField.getAnAnnotation() and
	    fieldTargetsEntity(mappedField, relationshipField.getDeclaringType()) and
	    isJpaAssociationAnnotation(mappedBy) and
	    mappedBy.getStringValue("mappedBy") =
	      relationshipField.getName()
	  )
	}

	predicate jpaRelationshipReferencedInQuery(Expr queryValue, Field relationshipField) {
	  isJpaRelationshipField(relationshipField) and
	  jpaQueryReferencesField(queryValue, relationshipField)
	  or
	  exists(Field mappedField |
	    isJpaRelatedField(relationshipField, mappedField) and
	    jpaQueryReferencesField(queryValue, mappedField)
	  )
	}

	Field getJpaRelationshipField(Class sourceEntity, string relationshipName) {
	  result = sourceEntity.getAField() and
	  isJpaRelationshipField(result) and
	  exists(Annotation mapping |
	    getJpaRelationshipMappingAnnotation(result, relationshipName, mapping)
	  )
	}

	predicate getJpaRelationshipMappingAnnotation(
	  Field field, string relationshipName, Annotation mapping
	) {
	  mapping = field.getAnAnnotation() and
	  (
	    isJpaAnnotation(mapping, "JoinTable") and
	    (
	      mapping.getStringValue("name") = relationshipName
	      or
	      exists(Annotation nestedJoinColumn |
	        (
	          nestedJoinColumn = mapping.getAnArrayValue("joinColumns").(Annotation) or
	          nestedJoinColumn = mapping.getAnArrayValue("inverseJoinColumns").(Annotation)
	        ) and
	        (
	          nestedJoinColumn.getStringValue("name") = relationshipName or
	          nestedJoinColumn.getStringValue("referencedColumnName") = relationshipName
	        )
	      )
	    )
	    or
	    isJpaAnnotation(mapping, "JoinColumn") and
	    (
	      mapping.getStringValue("name") = relationshipName or
	      mapping.getStringValue("referencedColumnName") = relationshipName
	    )
	  )
	}

	/** Legacy inheritance helpers retained for generated-query compatibility. */
	class InheritanceStrategyJOINED extends Annotation {
	  InheritanceStrategyJOINED() {
	    isJpaAnnotation(this, "Inheritance") and
	    this.getEnumConstantValue("strategy").hasName("JOINED")
	  }
	}

	predicate childParentInheritanceWithStrategyJOINED(Class child, Class parent) {
	  parent = child.getASupertype().(Class) and
	  parent.getAnAnnotation() instanceof InheritanceStrategyJOINED
	}
	'''
}
