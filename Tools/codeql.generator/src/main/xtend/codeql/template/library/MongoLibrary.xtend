package codeql.template.library

/** Spring Data MongoDB semantics for Java applications. */
class MongoLibrary {
	def static CharSequence generate()
	'''
	import java
	import orion_java

	predicate isMongoAnnotation(Annotation annotation, string packageName, string simpleName) {
	  annotation.getType().hasQualifiedName(packageName, simpleName)
	}

	predicate isMongoDocument(Class entity) {
	  exists(Annotation annotation |
	    annotation = entity.getAnAnnotation() and
	    isMongoAnnotation(
	      annotation, "org.springframework.data.mongodb.core.mapping", "Document"
	    )
	  )
	}

	predicate mongoCollectionHasName(Class entity, string name) {
	  name = entity.getName()
	  or
	  name = entity.getName().substring(0, 1).toLowerCase() +
	    entity.getName().substring(1, entity.getName().length())
	  or
	  exists(Annotation annotation |
	    annotation = entity.getAnAnnotation() and
	    isMongoAnnotation(
	      annotation, "org.springframework.data.mongodb.core.mapping", "Document"
	    ) and
	    (
	      name = annotation.getStringValue("collection") or
	      name = annotation.getStringValue("value")
	    )
	  )
	}

	predicate isMongoEntityMetadataAnnotation(Class entity, Annotation annotation) {
	  annotation = entity.getAnAnnotation() and
	  isMongoAnnotation(
	    annotation, "org.springframework.data.mongodb.core.mapping", "Document"
	  )
	}

	/** MongoOperations call carrying the selected Java or stored collection name. */
	predicate isMongoCollectionNameCall(
	  MethodCall call, StringLiteral collectionName, Class entity
	) {
	  exists(int i | collectionName = call.getArgument(i)) and
	  mongoCollectionHasName(entity, collectionName.getValue()) and
	  call.getMethod().getDeclaringType().getASupertype*().hasQualifiedName(
	    "org.springframework.data.mongodb.core", "MongoOperations"
	  ) and
	  call.getMethod().getName().regexpMatch(
	    "^(find|findAll|findOne|findById|exists|count|insert|save|remove|updateFirst|updateMulti|upsert|findAndModify|findAndRemove|aggregate|stream|execute)$"
	  )
	}

	predicate isMongoQuery(Annotation annotation) {
	  annotation.getType().hasQualifiedName(
	    "org.springframework.data.mongodb.repository", "Query"
	  )
	}

	predicate isMongoIdAnnotation(Annotation annotation) {
	  annotation.getType().hasQualifiedName("org.springframework.data.annotation", "Id") or
	  annotation.getType().hasQualifiedName(
	    "org.springframework.data.mongodb.core.mapping", "MongoId"
	  )
	}

	predicate isMongoAssociationAnnotation(Annotation annotation) {
	  annotation.getType().hasQualifiedName(
	    "org.springframework.data.mongodb.core.mapping", "DBRef"
	  )
	  or
	  annotation.getType().hasQualifiedName(
	    "org.springframework.data.mongodb.core.mapping", "DocumentReference"
	  )
	}

	predicate isMongoReferenceMappingAnnotation(Annotation annotation, Field field) {
	  annotation = field.getAnAnnotation() and
	  isMongoAssociationAnnotation(annotation)
	}

	predicate isMongoRelationshipField(Field field) {
	  exists(Annotation annotation |
	    annotation = field.getAnAnnotation() and
	    isMongoAssociationAnnotation(annotation)
	  )
	}

	/** Java and explicitly persisted names for a MongoDB property. */
	predicate mongoFieldHasName(Field field, string name) {
	  name = field.getName()
	  or
	  exists(Annotation annotation |
	    annotation = field.getAnAnnotation() and
	    annotation.getType().hasQualifiedName(
	      "org.springframework.data.mongodb.core.mapping", "Field"
	    ) and
	    (
	      name = annotation.getStringValue("value") or
	      name = annotation.getStringValue("name")
	    )
	  )
	}

	/**
	 * Gets an individual entry from a MongoDB JSON-like document.
	 *
	 * Splitting first avoids the single-capture/greedy-match problem of applying
	 * one regular expression to a complete document with multiple keys. It also
	 * exposes keys in nested objects and arrays without constructing a regular
	 * expression from a field obtained from the database.
	 */
		bindingset[document]
		private string getAMongoDocumentEntry(string document) {
	  result = document.splitAt("{").splitAt("[").splitAt(",")
	}

	/** JSON/query text that references either the Java or persisted property name. */
	bindingset[document]
	private predicate mongoDocumentReferencesField(string document, Field field) {
	  exists(string entry, string referencedField |
	    entry = getAMongoDocumentEntry(document) and
	    referencedField = entry.regexpCapture(
	      "(?is)\\s*['\"]?([a-zA-Z_][a-zA-Z0-9_.-]*)['\"]?\\s*:.*", 1
	    ) and
	    mongoFieldHasName(field, referencedField)
	  )
	}

	/** A compile-time MongoDB query document that references the selected field. */
	predicate mongoQueryReferencesField(Expr queryValue, Field field) {
	  exists(string queryText |
	    queryText = queryValue.(CompileTimeConstantExpr).getStringValue() and
	    mongoDocumentReferencesField(queryText, field)
	  )
	}

	/** A typed MongoDB API whose field-name argument names the affected property. */
	predicate isMongoFieldNameCall(
	  MethodCall call, StringLiteral propertyName, Field field
	) {
	  mongoFieldHasName(field, propertyName.getValue()) and
	  (
	    propertyName = call.getArgument(0) and
	    call.getMethod().getDeclaringType().getASupertype*().hasQualifiedName(
	      "org.springframework.data.mongodb.core.query", "Criteria"
	    ) and
	    call.getMethod().getName() = "where"
	    or
	    propertyName = call.getArgument(0) and
	    call.getMethod().getDeclaringType().getASupertype*().hasQualifiedName(
	      "org.springframework.data.mongodb.core.query", "Update"
	    ) and
	    call.getMethod().getName().regexpMatch(
	      "^(update|set|setOnInsert|unset|rename|inc|multiply|min|max|currentDate|currentTimestamp|push|pushAll|addToSet|pop|pull|pullAll|bitwise)$"
	    )
	    or
	    propertyName = call.getArgument(0) and
	    call.getMethod().getDeclaringType().getASupertype*().hasQualifiedName(
	      "org.springframework.data.mongodb.core.aggregation", "Aggregation"
	    ) and
	    call.getMethod().getName().regexpMatch("^(group|project|unwind)$")
	    or
	    propertyName = call.getArgument(1) and
	    call.getMethod().getDeclaringType().getASupertype*().hasQualifiedName(
	      "org.springframework.data.mongodb.core.aggregation", "Aggregation"
	    ) and
	    call.getMethod().getName() = "sort"
	    or
	    exists(int i |
	      propertyName = call.getArgument(i) and
	      call.getMethod().getDeclaringType().getASupertype*().hasQualifiedName(
	        "org.springframework.data.mongodb.core", "MongoOperations"
	      ) and
	      call.getMethod().getName() = "findDistinct"
	    )
	  )
	}

	predicate mongoMetadataReferencesField(Annotation annotation, Field field) {
	  (
	    annotation = field.getAnAnnotation() and
	    annotation.getType().hasQualifiedName(
	      "org.springframework.data.mongodb.core.mapping", "Field"
	    )
	    or
	    annotation = field.getAnAnnotation() and
	    annotation.getType().hasQualifiedName(
	      "org.springframework.data.mongodb.core.index", "Indexed"
	    )
	    or
	    annotation = field.getDeclaringType().getAnAnnotation() and
	    annotation.getType().hasQualifiedName(
	      "org.springframework.data.mongodb.core.index", "CompoundIndex"
	    ) and
	    mongoDocumentReferencesField(annotation.getStringValue("def"), field)
	    or
	    exists(Annotation container |
	      container = field.getDeclaringType().getAnAnnotation() and
	      container.getType().hasQualifiedName(
	        "org.springframework.data.mongodb.core.index", "CompoundIndexes"
	      ) and
	      annotation = container.getAnArrayValue("value").(Annotation) and
	      mongoDocumentReferencesField(annotation.getStringValue("def"), field)
	    )
	  )
	}

	predicate isMongoRelatedField(Field relationshipField, Field relatedField) {
	  isMongoRelationshipField(relationshipField) and
	  relatedField != relationshipField and
	  isMongoRelationshipField(relatedField) and
	  fieldTargetsEntity(relatedField, relationshipField.getDeclaringType())
	}

	predicate mongoRelationshipReferencedInQuery(Expr queryValue, Field relationshipField) {
	  isMongoRelationshipField(relationshipField) and
	  mongoQueryReferencesField(queryValue, relationshipField)
	  or
	  exists(Field relatedField |
	    isMongoRelatedField(relationshipField, relatedField) and
	    mongoQueryReferencesField(queryValue, relatedField)
	  )
	}

	Field getMongoRelationshipField(Class sourceEntity, string relationshipName) {
	  result = sourceEntity.getAField() and
	  isMongoRelationshipField(result) and
	  mongoFieldHasName(result, relationshipName)
	}

	predicate getMongoRelationshipMappingAnnotation(
	  Field field, string relationshipName, Annotation mapping
	) {
	  mapping = field.getAnAnnotation() and
	  (
	    isMongoAssociationAnnotation(mapping) and
	    mongoFieldHasName(field, relationshipName)
	    or
	    mapping.getType().hasQualifiedName(
	      "org.springframework.data.mongodb.core.mapping", "Field"
	    ) and
	    (
	      mapping.getStringValue("value") = relationshipName or
	      mapping.getStringValue("name") = relationshipName
	    )
	  )
	}
	'''
}
