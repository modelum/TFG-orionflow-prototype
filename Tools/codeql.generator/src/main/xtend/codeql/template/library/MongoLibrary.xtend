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

	/** One layer of array/generic containment used by a persistent field type. */
	private predicate mongoContainedType(Type outer, Type contained) {
	  contained = outer.(Array).getElementType()
	  or
	  contained = outer.(ParameterizedType).getATypeArgument()
	}

	/** A class occurring directly or inside arrays/parameterized field types. */
	private predicate mongoFieldContainsClass(Field field, Class contained) {
	  mongoContainedType*(field.getType(), contained)
	}

	/** Field persisted as embedded composition rather than a document reference. */
	private predicate isMongoEmbeddedProperty(Field field) {
	  field.fromSource() and
	  not field.isStatic() and
	  not field.isTransient() and
	  not exists(Annotation ignored |
	    ignored = field.getAnAnnotation() and
	    ignored.getType().hasQualifiedName(
	      "org.springframework.data.annotation", "Transient"
	    )
	  ) and
	  not exists(Annotation reference |
	    reference = field.getAnAnnotation() and
	    isMongoAssociationAnnotation(reference)
	  )
	}

	/** A direct, persisted composition edge between two source classes. */
	predicate mongoDirectlyEmbeds(Class owner, Class embedded) {
	  exists(Field property |
	    property.getDeclaringType() = owner and
	    isMongoEmbeddedProperty(property) and
	    mongoFieldContainsClass(property, embedded) and
	    embedded.fromSource() and
	    embedded != owner
	  )
	}

	/** Root document that owns an entity directly or through embedded composition. */
	predicate mongoDocumentContainsEntity(Class root, Class entity) {
	  isMongoDocument(root) and
	  (root = entity or mongoDirectlyEmbeds+(root, entity))
	}

	/** Root documents and non-root entities reachable through persisted composition. */
	predicate isMongoPersistentEntity(Class entity) {
	  exists(Class root | mongoDocumentContainsEntity(root, entity))
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

	/** Exact property name, or the final component of a nested property path. */
	bindingset[path]
	private predicate mongoPropertyPathReferencesField(string path, Field field) {
	  mongoFieldHasName(field, path)
	  or
	  exists(string prefix, string name |
	    prefix != "" and
	    mongoFieldHasName(field, name) and
	    path = prefix + "." + name
	  )
	}

	/** A type contains the selected class directly, as an array, or generically. */
	private predicate mongoTypeContainsClass(Type type, Class entity) {
	  mongoContainedType*(type, entity)
	}

	/**
	 * The enclosing callable provides a concrete Mongo root for this property.
	 * This prevents a matching literal in an unrelated helper from being bound to
	 * every persistent class that happens to declare a homonymous field.
	 */
	private predicate mongoCallHasEntityContext(MethodCall call, Field field) {
	  exists(Class root |
	    mongoDocumentContainsEntity(root, field.getDeclaringType()) and
	    (
	      exists(TypeLiteral literal |
	        literal.getEnclosingCallable() = call.getEnclosingCallable() and
	        literal.getReferencedType() = root
	      )
	      or
	      exists(Parameter parameter |
	        parameter.getCallable() = call.getEnclosingCallable() and
	        mongoTypeContainsClass(parameter.getType(), root)
	      )
	      or
	      mongoTypeContainsClass(call.getEnclosingCallable().getReturnType(), root)
	    )
	  )
	}

	private predicate isSpringDataSortMethod(Method method) {
	  method.getDeclaringType().getSourceDeclaration().hasQualifiedName(
	    "org.springframework.data.domain", "Sort"
	  ) and
	  method.getName() = "by"
	}

	private predicate isSpringDataSortOrderMethod(Method method) {
	  method.getDeclaringType().getSourceDeclaration().getName() = "Order" and
	  method.getDeclaringType().getSourceDeclaration().getEnclosingType()
	    .hasQualifiedName("org.springframework.data.domain", "Sort") and
	  method.getName().regexpMatch("^(asc|desc|by)$")
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
	  mongoPropertyPathReferencesField(propertyName.getValue(), field) and
	  mongoCallHasEntityContext(call, field) and
	  (
	    propertyName = call.getArgument(0) and
	    call.getMethod().getDeclaringType().getASupertype*().hasQualifiedName(
	      "org.springframework.data.mongodb.core.query", "Criteria"
	    ) and
	    call.getMethod().getName().regexpMatch("^(where|and)$")
	    or
	    exists(int i |
	      propertyName = call.getArgument(i) and
	      isSpringDataSortMethod(call.getMethod())
	    )
	    or
	    propertyName = call.getArgument(0) and
	    isSpringDataSortOrderMethod(call.getMethod())
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
