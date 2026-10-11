package codeql.template.library

import config.PersistenceFramework

/** Facade that composes the structural core with the selected adapters. */
class Library {
	def static CharSequence generateUsesOldEntity(String entityName) {
		generateUsesOldEntity(entityName, PersistenceFramework.JPA)
	}

	def static CharSequence generateUsesOldEntity(
		String entityName,
		PersistenceFramework framework
	)
	'''
	/** Check if entity «entityName» is used in a selected framework query. */
	predicate usesOldEntity(StringLiteral queryValue) {
	  «IF framework.includesJpa»
	  queryValue.getValue().regexpMatch(
	    "(?i).*\\b(FROM|UPDATE|DELETE\\s+FROM)\\s+«entityName»\\b.*"
	  )
	  or
	  queryValue.getValue().regexpMatch(
	    "(?i).*\\bJOIN\\s+(?:FETCH\\s+)?«entityName»\\b.*"
	  )
	  «IF framework.includesMongo»or«ENDIF»
	  «ENDIF»
	  «IF framework.includesMongo»
	  // Mongo aggregation/look-up collection references. The entity name is a
	  // generated literal, never an AST-derived regex fragment.
	  queryValue.getValue().regexpMatch(
	    "(?i).*(from|collection)\\s*['\"]?\\s*[:=,(]\\s*['\"]?«entityName»\\b.*"
	  )
	  «ENDIF»
	}
	'''

	def static CharSequence generateUsesField(String entityName, String fieldName) {
		generateUsesField(entityName, fieldName, PersistenceFramework.JPA)
	}

	def static CharSequence generateUsesField(
		String entityName,
		String fieldName,
		PersistenceFramework framework
	)
	'''
	/** Check if logical field «entityName».«fieldName» occurs in a framework query. */
	predicate usesField(Expr queryValue) {
	  «IF framework.includesJpa»
	  queryValue.toString().regexpMatch(
	    "(?i).*\\b«entityName»\\s*\\.\\s*«fieldName»\\b.*"
	  )
	  or
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
	  queryValue.toString().regexpMatch("(?i).*FROM\\s+«entityName»\\b.*") and
	  queryValue.toString().regexpMatch("(?i).*\\bWHERE\\b.*\\b«fieldName»\\b.*")
	  «IF framework.includesMongo»or«ENDIF»
	  «ENDIF»
	  «IF framework.includesMongo»
	  queryValue.toString().regexpMatch(
	    "(?i).*['\"]?«fieldName»['\"]?\\s*:.*"
	  )
	  «ENDIF»
	}
	'''

	def static CharSequence generateFeatureSemanticPredicates(
		String entityName,
		String fieldName
	)
	'''
	/** A Spring validation API argument that unambiguously names «fieldName». */
	predicate isSpringPropertyReference(
	  MethodCall call, StringLiteral propertyName, Class entity
	) {
	  entity.hasName("«entityName»") and
	  isEntity(entity) and
	  propertyName.getValue() = "«fieldName»" and
	  isSpringValidationPropertyCall(call, propertyName) and
	  exists(Parameter entityParameter |
	    entityParameter = call.getEnclosingCallable().getAParameter() and
	    entityParameter.getType() = entity
	  )
	}

	/** A selected Spring Data repository query derived from «fieldName». */
	predicate isSpringDataDerivedQuery(Method method, Class entity) {
	  isSpringRepositoryMethodForEntity(method, entity) and
	  method.getName().regexpMatch(
	    "^(find|read|get|query|search|stream|count|exists|delete|remove).*(By|And|Or)«capitalize(fieldName)»([A-Z0-9].*)?$"
	  )
	}
	'''

	private static def String capitalize(String value) {
		if (value === null || value.empty)
			value
		else
			value.substring(0, 1).toUpperCase + value.substring(1)
	}

	def static CharSequence generateUtils() {
		generateUtils(PersistenceFramework.JPA)
	}

	def static CharSequence generateUtils(PersistenceFramework framework)
	'''
	import java
	import orion_java
	import orion_spring
	«IF framework.includesJpa»import orion_jpa«ENDIF»
	«IF framework.includesMongo»import orion_mongo«ENDIF»

	/** Persistent domain type according to the selected adapter composition. */
	predicate isEntity(Class entity) {
	  «IF framework.includesJpa»isJpaEntity(entity)«IF framework.includesMongo» or«ENDIF»«ENDIF»
	  «IF framework.includesMongo»isMongoDocument(entity)«ENDIF»
	}

	predicate frameworkEntityMetadataAnnotation(Class entity, Annotation annotation) {
	  «IF framework.includesJpa»isJpaEntityMetadataAnnotation(entity, annotation)«IF framework.includesMongo» or«ENDIF»«ENDIF»
	  «IF framework.includesMongo»isMongoEntityMetadataAnnotation(entity, annotation)«ENDIF»
	}

	predicate isFrameworkCollectionNameCall(
	  MethodCall call, StringLiteral collectionName, Class entity
	) {
	  «IF framework.includesMongo»isMongoCollectionNameCall(call, collectionName, entity)«ELSE»collectionName = call.getArgument(0) and
	  entity.hasName(collectionName.getValue()) and
	  call.getMethod().hasQualifiedName("orionflow.disabled", "MongoOperations", "find")«ENDIF»
	}

	predicate isQuery(Annotation annotation) {
	  «IF framework.includesJpa»isJpaQuery(annotation)«IF framework.includesMongo» or«ENDIF»«ENDIF»
	  «IF framework.includesMongo»isMongoQuery(annotation)«ENDIF»
	}

	predicate isNamedQuery(Annotation annotation) {
	  «IF framework.includesJpa»isJpaNamedQuery(annotation)«ELSE»annotation.getType().hasQualifiedName("orionflow.disabled", "NamedQuery")«ENDIF»
	}

	predicate isEmbeddable(Class cls) {
	  «IF framework.includesJpa»isJpaEmbeddable(cls)«ELSE»cls.hasQualifiedName("orionflow.disabled", "Embeddable")«ENDIF»
	}

	predicate isEmbeddedField(Field field) {
	  «IF framework.includesJpa»isJpaEmbeddedField(field)«ELSE»field.getDeclaringType().hasQualifiedName("orionflow.disabled", "Embedded")«ENDIF»
	}

	predicate usesField(Expr queryValue, Field field) {
	  «IF framework.includesJpa»jpaQueryReferencesField(queryValue, field)«IF framework.includesMongo» or«ENDIF»«ENDIF»
	  «IF framework.includesMongo»mongoQueryReferencesField(queryValue, field)«ENDIF»
	}

	predicate frameworkQueryReferencesField(Annotation query, Field field) {
	  «IF framework.includesJpa»isJpaEntity(field.getDeclaringType()) and
	  isJpaQuery(query) and
	  jpaQueryReferencesField(query.getValue("value"), field)«IF framework.includesMongo» or«ENDIF»«ENDIF»
	  «IF framework.includesMongo»isMongoDocument(field.getDeclaringType()) and
	  isMongoQuery(query) and
	  mongoQueryReferencesField(query.getValue("value"), field)«ENDIF»
	}

	predicate isCreateQuery(MethodCall call) {
	  «IF framework.includesJpa»isJpaCreateQuery(call)«ELSE»call.getMethod().hasQualifiedName("orionflow.disabled", "EntityManager", "createQuery")«ENDIF»
	}

	predicate isCreateNamedQuery(MethodCall call) {
	  «IF framework.includesJpa»isJpaCreateNamedQuery(call)«ELSE»call.getMethod().hasQualifiedName("orionflow.disabled", "EntityManager", "createNamedQuery")«ENDIF»
	}

	predicate frameworkMetadataReferencesField(Annotation annotation, Field field) {
	  «IF framework.includesJpa»isJpaEntity(field.getDeclaringType()) and
	  jpaMetadataReferencesField(annotation, field)«IF framework.includesMongo» or«ENDIF»«ENDIF»
	  «IF framework.includesMongo»isMongoDocument(field.getDeclaringType()) and
	  mongoMetadataReferencesField(annotation, field)«ENDIF»
	}

	predicate isFrameworkFieldNameCall(
	  MethodCall call, StringLiteral propertyName, Field field
	) {
	  «IF framework.includesMongo»isMongoDocument(field.getDeclaringType()) and
	  isMongoFieldNameCall(call, propertyName, field)«ELSE»propertyName = call.getArgument(0) and
	  field.hasName(propertyName.getValue()) and
	  call.getMethod().hasQualifiedName("orionflow.disabled", "FieldApi", "field")«ENDIF»
	}

	predicate isAssociationAnnotation(Annotation annotation) {
	  «IF framework.includesJpa»isJpaAssociationAnnotation(annotation)«IF framework.includesMongo» or«ENDIF»«ENDIF»
	  «IF framework.includesMongo»isMongoAssociationAnnotation(annotation)«ENDIF»
	}

	predicate isReferenceMappingAnnotation(Annotation annotation, Field field) {
	  «IF framework.includesJpa»isJpaReferenceMappingAnnotation(annotation, field)«IF framework.includesMongo» or«ENDIF»«ENDIF»
	  «IF framework.includesMongo»isMongoReferenceMappingAnnotation(annotation, field)«ENDIF»
	}

	predicate isRelationshipField(Field field) {
	  «IF framework.includesJpa»isJpaRelationshipField(field)«IF framework.includesMongo» or«ENDIF»«ENDIF»
	  «IF framework.includesMongo»isMongoRelationshipField(field)«ENDIF»
	}

	predicate isRelatedField(Field relationshipField, Field mappedField) {
	  «IF framework.includesJpa»isJpaRelatedField(relationshipField, mappedField)«IF framework.includesMongo» or«ENDIF»«ENDIF»
	  «IF framework.includesMongo»isMongoRelatedField(relationshipField, mappedField)«ENDIF»
	}

	predicate usesRelationship(Expr queryValue, Field relationshipField) {
	  «IF framework.includesJpa»jpaRelationshipReferencedInQuery(queryValue, relationshipField)«IF framework.includesMongo» or«ENDIF»«ENDIF»
	  «IF framework.includesMongo»mongoRelationshipReferencedInQuery(queryValue, relationshipField)«ENDIF»
	}

	predicate frameworkQueryReferencesRelationship(
	  Annotation query, Expr queryValue, Field relationshipField
	) {
	  «IF framework.includesJpa»isJpaQuery(query) and
	  jpaRelationshipReferencedInQuery(queryValue, relationshipField)«IF framework.includesMongo» or«ENDIF»«ENDIF»
	  «IF framework.includesMongo»isMongoQuery(query) and
	  mongoRelationshipReferencedInQuery(queryValue, relationshipField)«ENDIF»
	}

	Field getRelationshipField(Class sourceEntity, string relationshipName) {
	  «IF framework.includesJpa»result = getJpaRelationshipField(sourceEntity, relationshipName)«IF framework.includesMongo» or«ENDIF»«ENDIF»
	  «IF framework.includesMongo»result = getMongoRelationshipField(sourceEntity, relationshipName)«ENDIF»
	}

	predicate getRelationshipMappingAnnotation(
	  Field field, string relationshipName, Annotation mapping
	) {
	  «IF framework.includesJpa»getJpaRelationshipMappingAnnotation(field, relationshipName, mapping)«IF framework.includesMongo» or«ENDIF»«ENDIF»
	  «IF framework.includesMongo»getMongoRelationshipMappingAnnotation(field, relationshipName, mapping)«ENDIF»
	}

	predicate isIdAnnotation(Annotation annotation) {
	  «IF framework.includesJpa»isJpaAnnotation(annotation, "Id") or isJpaAnnotation(annotation, "EmbeddedId")«IF framework.includesMongo» or«ENDIF»«ENDIF»
	  «IF framework.includesMongo»isMongoIdAnnotation(annotation)«ENDIF»
	}

	predicate isGeneratedValueAnnotation(Annotation annotation) {
	  «IF framework.includesJpa»isJpaAnnotation(annotation, "GeneratedValue")«ELSE»annotation.getType().hasQualifiedName("orionflow.disabled", "GeneratedValue")«ENDIF»
	}

	predicate isJoinColumnAnnotation(Annotation annotation) {
	  «IF framework.includesJpa»isJpaAnnotation(annotation, "JoinColumn")«ELSE»annotation.getType().hasQualifiedName("orionflow.disabled", "JoinColumn")«ENDIF»
	}
	'''
}
