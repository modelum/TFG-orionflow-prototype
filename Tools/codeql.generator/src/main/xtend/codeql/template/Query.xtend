package codeql.template

import config.AnalysisMode

class Query {

	static def generateEntityDeleteOp(String entityName) {
		generateEntityDeleteOp(entityName, AnalysisMode.STRUCTURAL_SEMANTIC)
	}

   static def generateEntityDeleteOp(String entityName, AnalysisMode mode)
		'''
		import java
		import utils

		«Library.generateUsesOldEntity(entityName)»
		
		from Class entity, Location usageLoc, string message
		where
		  entity.hasName("«entityName»") and
		  isEntity(entity) and
		  (
		    (
		      usageLoc = entity.getLocation() and
		      message =
		        "Entity '" + entity.getName() + "' is marked for deletion."
		    )
		
		    or
		    // Any source type reference resolved to the affected entity. This
		    // covers fields, generic arguments, parameters, returns, locals,
		    // supertypes, interfaces and repository declarations.
		    exists(TypeAccess typeReference |
		      referencesEntityType(typeReference, entity) and
		      not exists(ClassInstanceExpr creation |
		        creation.getTypeName() = typeReference
		      ) and
		      usageLoc = typeReference.getLocation() and
		      message =
		        "Resolved type reference to entity '" + entity.getName() +
		        "' must be removed or replaced because the entity is being deleted."
		    )

		    or
		    // Constructor calls are reported once at the complete construction,
		    // rather than again at their nested type access.
		    exists(ClassInstanceExpr creation |
		      constructsEntity(creation, entity) and
		      usageLoc = creation.getLocation() and
		      message =
		        "Construction of entity '" + entity.getName() +
		        "' is invalid after the entity is deleted."
		    )
		
		    or
		    // Named JPQL queries referenced through @Query
		    exists(Annotation nq, Annotation q, StringLiteral queryLiteral |
		      isQuery(q) and
		      isNamedQuery(nq) and
		      isEqual(nq.getValue("name"), q.getValue("name")) and
		      queryLiteral = nq.getValue("query") and
		      usesOldEntity(queryLiteral) and
		      usageLoc = q.getTarget().getLocation() and
		      message =
		        "Named query uses entity '" + entity.getName() +
		        "' which is marked for deletion."
		    )
		
		    or
		    // JPQL queries in @Query
		    exists(Annotation q, StringLiteral queryLiteral |
		      isQuery(q) and
		      queryLiteral = q.getValue("value") and
		      usesOldEntity(queryLiteral) and
		      usageLoc = q.getTarget().getLocation() and
		      message =
		        "Query uses entity '" + entity.getName() +
		        "' which is marked for deletion."
		    )
		
		    or
		    // EntityManager.createQuery(...)
		    exists(MethodCall call, StringLiteral queryLiteral |
		      isCreateQuery(call) and
		      queryLiteral = call.getArgument(0) and
		      usesOldEntity(queryLiteral) and
		      usageLoc = call.getLocation() and
		      message =
		        "Call to createQuery uses entity '" + entity.getName() +
		        "' which is marked for deletion."
		    )
		
		    or
		    // EntityManager.createNamedQuery(...)
		    exists(MethodCall call, StringLiteral nameArg,
		           Annotation nq, StringLiteral queryLiteral |
		      isCreateNamedQuery(call) and
		      nameArg = call.getArgument(0) and
		      isNamedQuery(nq) and
		      "\"" + nameArg.getValue() + "\"" = nq.getValue("name").toString() and
		      queryLiteral = nq.getValue("query") and
		      usesOldEntity(queryLiteral) and
		      usageLoc = call.getLocation() and
		      message =
		        "Call to createNamedQuery uses entity '" + entity.getName() +
		        "' which is marked for deletion."
		    )
		  )
		
		select usageLoc, message
		'''	      
	
	static def generateEntityRenameOp(String oldEntityName, String newEntityName) {
		generateEntityRenameOp(oldEntityName, newEntityName, AnalysisMode.STRUCTURAL_SEMANTIC)
	}

	static def generateEntityRenameOp(String oldEntityName, String newEntityName, AnalysisMode mode)
		'''
		import java
		import utils

		«Library.generateUsesOldEntity(oldEntityName)»
		
		from Class oldEntity, Location usageLoc, string message, string newName
		where
		  oldEntity.hasName("«oldEntityName»") and
		  isEntity(oldEntity) and
		  newName = "«newEntityName»" and
		  (
		    (
		      usageLoc = oldEntity.getLocation() and
		      message =
		        "Entity '" + oldEntity.getName() +
		        "' will be renamed to '" + newName + "'."
		    )
		
		    or
		    // Any source type reference resolved to the affected entity.
		    exists(TypeAccess typeReference |
		      referencesEntityType(typeReference, oldEntity) and
		      not exists(ClassInstanceExpr creation |
		        creation.getTypeName() = typeReference
		      ) and
		      usageLoc = typeReference.getLocation() and
		      message =
		        "Resolved type reference to entity '" + oldEntity.getName() +
		        "' must be renamed to '" + newName + "'."
		    )

		    or
		    exists(ClassInstanceExpr creation |
		      constructsEntity(creation, oldEntity) and
		      usageLoc = creation.getLocation() and
		      message =
		        "Construction of entity '" + oldEntity.getName() +
		        "' must use the new name '" + newName + "'."
		    )
		
		    or
		    // Named JPQL queries referenced through @Query
		    exists(Annotation nq, Annotation q, StringLiteral queryLiteral |
		      isQuery(q) and
		      isNamedQuery(nq) and
		      isEqual(nq.getValue("name"), q.getValue("name")) and
		      queryLiteral = nq.getValue("query") and
		      usesOldEntity(queryLiteral) and
		      usageLoc = q.getTarget().getLocation() and
		      message =
		        "Named query uses old entity name '" + oldEntity.getName() +
		        "' which will be renamed to '" + newName + "'."
		    )
		
		    or
		    // JPQL queries in @Query
		    exists(Annotation q, StringLiteral queryLiteral |
		      isQuery(q) and
		      queryLiteral = q.getValue("value") and
		      usesOldEntity(queryLiteral) and
		      usageLoc = q.getTarget().getLocation() and
		      message =
		        "Query uses old entity name '" + oldEntity.getName() +
		        "' which will be renamed to '" + newName + "'."
		    )
		
		    or
		    // EntityManager.createQuery(...)
		    exists(MethodCall call, StringLiteral queryLiteral |
		      isCreateQuery(call) and
		      queryLiteral = call.getArgument(0) and
		      usesOldEntity(queryLiteral) and
		      usageLoc = call.getLocation() and
		      message =
		        "Call to createQuery uses old entity name '" + oldEntity.getName() +
		        "' which will be renamed to '" + newName + "'."
		    )
		
		    or
		    // EntityManager.createNamedQuery(...)
		    exists(MethodCall call, StringLiteral nameArg,
		           Annotation nq, StringLiteral queryLiteral |
		      isCreateNamedQuery(call) and
		      nameArg = call.getArgument(0) and
		      isNamedQuery(nq) and
		      "\"" + nameArg.getValue() + "\"" = nq.getValue("name").toString() and
		      queryLiteral = nq.getValue("query") and
		      usesOldEntity(queryLiteral) and
		      usageLoc = call.getLocation() and
		      message =
		        "Call to createNamedQuery uses old entity name '" + oldEntity.getName() +
		        "' which will be renamed to '" + newName + "'."
		    )
		  )
		
		select usageLoc, message
		'''
	
	 
	
	static def generateFeatureRenameOp(String entityName, String featureOldName, String featureNewName) {
		generateFeatureRenameOp(entityName, featureOldName, featureNewName, AnalysisMode.STRUCTURAL_SEMANTIC)
	}

	static def generateFeatureRenameOp(String entityName, String featureOldName, String featureNewName, AnalysisMode mode)
	'''
	import java
	import utils

	«Library.generateUsesField(entityName, featureOldName)»
	«IF mode.includesSemantic»
	«Library.generateFeatureSemanticPredicates(entityName, featureOldName)»
	«ENDIF»
	
	from
	  Class entity, Field featureField, Location usageLoc, string oldName, string newName,
	  string message
	where
	  isEntity(entity) and
	  entity.hasName("«entityName»") and // Name entity with the field
	  featureField = entity.getAField() and
	  featureField.hasName("«featureOldName»") and // Last field name
	
	  oldName = featureField.getName() and
	  newName = "«featureNewName»" and 
	  (
	    // the field will be renamed
	    (usageLoc = featureField.getLocation() and
	    message = "Feature '" + oldName + "' in entity '" + entity.getName() + "' will be renamed to '" + newName + "'.")
	
	    or
	    // use the field in embedded classes
	    exists(Class embeddedClass, Field embeddedField, Field containerField |
	      isEmbeddable(embeddedClass) and
	      embeddedField = embeddedClass.getAField() and
	      embeddedField.getName() = oldName and
	      containerField.getDeclaringType() = entity and
	      containerField.getType() = embeddedClass and
	      isEmbeddedField(containerField) and
	      usageLoc = embeddedField.getLocation() and
	      message = "Embedded field '" + oldName + "' matches feature '" + oldName + "' which will be renamed to '" + newName + "'."
	    )
	
	    or
	    // getters y setters
	    exists(Method method |
	      (isGetter(method, featureField) or isSetter(method, featureField)) and
	      usageLoc = method.getLocation() and
	      message = "Method '" + method.getName() + "' accesses feature '" + oldName + "' which will be renamed to '" + newName + "'."
	    )

	    or
	    // resolved calls to the getter/setter, including calls from other classes
	    exists(MethodCall call |
	      callsAccessor(call, featureField) and
	      usageLoc = call.getLocation() and
	      message = "Call to accessor '" + call.getMethod().getName() +
	        "' depends on feature '" + oldName + "' which will be renamed to '" + newName + "'."
	    )
	
	    or
	    // direct access to the feature
	    exists(FieldAccess access |
	      access.getField() = featureField and
	      not isAccessInsideAccessor(access, featureField) and
	      usageLoc = access.getLocation() and
	      message = "Direct access to feature '" + oldName + "' which will be renamed to '" + newName + "'."
	    )

	    «IF mode.includesSemantic»
	    or
	    // JPA metadata whose value names the affected feature.
	    exists(Annotation metadata |
	      jpaMetadataReferencesField(metadata, featureField) and
	      usageLoc = metadata.getLocation() and
	      message = "JPA metadata references feature '" + oldName +
	        "' which will be renamed to '" + newName + "'."
	    )

	    or
	    // Exact Spring validation property name in an entity-binding callable.
	    exists(MethodCall call, StringLiteral propertyName |
	      isSpringPropertyReference(call, propertyName, entity) and
	      usageLoc = propertyName.getLocation() and
	      message = "Spring API references property '" + oldName +
	        "' which will be renamed to '" + newName + "'."
	    )

	    or
	    // Spring Data query method whose repository generic is the entity.
	    exists(Method repositoryMethod |
	      isSpringDataDerivedQuery(repositoryMethod, entity) and
	      usageLoc = repositoryMethod.getLocation() and
	      message = "Spring Data derived query method '" + repositoryMethod.getName() +
	        "' references feature '" + oldName + "' which will be renamed to '" + newName + "'."
	    )
	    «ENDIF»
	
	    or
	    // query annotations
	    exists(Annotation nq, Annotation q |
	      (
	        // NamedQuery
	        (isQuery(q) and
	        isNamedQuery(nq) and
	        isEqual(nq.getValue("name"), q.getValue("name")) and
	        usesField(nq.getValue("query")) and
	        usageLoc = q.getLocation() and
	        message = "Named query uses feature '" + oldName + "' which will be renamed to '" + newName + "'.")
	        or
	
	        // Query
	        (isQuery(q) and
	        usesField(q.getValue("value")) and
	        usageLoc = q.getLocation() and
	        message = "Query uses feature '" + oldName + "' which will be renamed to '" + newName + "'.")
	      )
	    )
	
	    or
	    // createQuery y createNamedQuery
	    exists(MethodCall call |
	      (
	        (isCreateQuery(call) and
	        exists(StringLiteral queryLiteral |
	          queryLiteral = call.getArgument(0) and
	          usesField(queryLiteral)
	        ))
	
	        or
	        (isCreateNamedQuery(call) and
	        exists(StringLiteral nameArg, Annotation nq2 |
	          nameArg = call.getArgument(0) and
	          isNamedQuery(nq2) and
	          "\"" + nameArg.getValue() + "\"" = nq2.getValue("name").toString() and
	          usesField(nq2.getValue("query"))
	        ))
	      ) and
	      usageLoc = call.getLocation() and
	      message = "Query uses feature '" + oldName + "' which will be renamed to '" + newName + "'."
	    )
	  )
	select usageLoc, message
	'''
	
	static def generateFeatureDeleteOp(String entityName, String featureName) {
		generateFeatureDeleteOp(entityName, featureName, AnalysisMode.STRUCTURAL_SEMANTIC)
	}

	static def generateFeatureDeleteOp(String entityName, String featureName, AnalysisMode mode)
	'''
	import java
	import utils

	«Library.generateUsesField(entityName, featureName)»
	«IF mode.includesSemantic»
	«Library.generateFeatureSemanticPredicates(entityName, featureName)»
	«ENDIF»
	
	from Class entity, Field attributeField, Location usageLoc, string message
	where
	  isEntity(entity) and
	  entity.hasName("«entityName»") and 
	  attributeField = entity.getAField() and
	  attributeField.hasName("«featureName»") and // Last field name
	  (
	    // the field will be renamed
	    (usageLoc = attributeField.getLocation() and
	    message = "Attribute '" + attributeField.getName() + "' in entity '" + entity.getName() + "' will be deleted.")
	    
	    or
	    // use the field in embedded classes
	    exists(Class embeddedClass, Field embeddedField, Field containerField |
	      isEmbeddable(embeddedClass) and
	      embeddedField = embeddedClass.getAField() and
	      embeddedField.getName() = attributeField.getName() and
	      containerField.getDeclaringType() = entity and
	      containerField.getType() = embeddedClass and
	      isEmbeddedField(containerField) and
	      usageLoc = embeddedField.getLocation() and
	      message = "Embedded field '" + embeddedField.getName() + "' matches attribute '" + attributeField.getName() + "' which will be deleted."
	    )
	
	    or
	    // getters y setters
	    exists(Method method |
	      (isGetter(method, attributeField) or isSetter(method, attributeField)) and
	      usageLoc = method.getLocation() and
	      message = "Method '" + method.getName() + "' accesses attribute '" + attributeField.getName() + "' which will be deleted."
	    )

	    or
	    exists(MethodCall call |
	      callsAccessor(call, attributeField) and
	      usageLoc = call.getLocation() and
	      message = "Call to accessor '" + call.getMethod().getName() +
	        "' depends on attribute '" + attributeField.getName() + "' which will be deleted."
	    )
	
	    or
	    // direct access to the attribute
	    exists(FieldAccess access |
	      access.getField() = attributeField and
	      not isAccessInsideAccessor(access, attributeField) and
	      usageLoc = access.getLocation() and
	      message = "Direct access to attribute '" + attributeField.getName() + "' which will be deleted."
	    )

	    «IF mode.includesSemantic»
	    or
	    exists(Annotation metadata |
	      jpaMetadataReferencesField(metadata, attributeField) and
	      usageLoc = metadata.getLocation() and
	      message = "JPA metadata references attribute '" + attributeField.getName() +
	        "' which will be deleted."
	    )

	    or
	    exists(MethodCall call, StringLiteral propertyName |
	      isSpringPropertyReference(call, propertyName, entity) and
	      usageLoc = propertyName.getLocation() and
	      message = "Spring API references property '" + attributeField.getName() +
	        "' which will be deleted."
	    )

	    or
	    exists(Method repositoryMethod |
	      isSpringDataDerivedQuery(repositoryMethod, entity) and
	      usageLoc = repositoryMethod.getLocation() and
	      message = "Spring Data derived query method '" + repositoryMethod.getName() +
	        "' references attribute '" + attributeField.getName() + "' which will be deleted."
	    )
	    «ENDIF»
	
	    or
	    // query annotations
	    exists(Annotation nq, Annotation q |
	      (
	        // Named queries
	        (isQuery(q) and
	        isNamedQuery(nq) and
	        isEqual(nq.getValue("name"), q.getValue("name")) and
	        usesField(nq.getValue("query")) and
	        usageLoc = q.getTarget().getLocation() and
	        message = "Named query uses attribute '" + attributeField.getName() + "' which will be deleted.")
	
	        or
	        // Regular queries
	        (isQuery(q) and usesField(q.getValue("value"))) and
	        usageLoc = q.getTarget().getLocation() and
	        message = "Query uses attribute '" + attributeField.getName() + "' which will be deleted."
	      )
	    )
	
	    or
	    // createQuery y createNamedQuery
	    exists(MethodCall call |
	      (
	        // agrupa las dos alternativas
	        (isCreateQuery(call) and
	        exists(StringLiteral queryLiteral |
	          queryLiteral = call.getArgument(0) and
	          usesField(queryLiteral)
	        ))
	
	        or
	        (isCreateNamedQuery(call) and
	        exists(StringLiteral nameArg, Annotation nq |
	          nameArg = call.getArgument(0) and
	          isNamedQuery(nq) and
	          "\"" + nameArg.getValue() + "\"" = nq.getValue("name").toString() and
	          usesField(nq.getValue("query"))
	        ))
	      ) and
	      usageLoc = call.getLocation() and
	      message = "Query uses attribute '" + attributeField.getName() + "' which will be deleted."
	    )
	  )
	select usageLoc, message
	'''
	
	static def generateAttributeCastOp(String entityName, String fieldName, String newFieldType) {
		generateAttributeCastOp(entityName, fieldName, newFieldType, AnalysisMode.STRUCTURAL_SEMANTIC)
	}

	static def generateAttributeCastOp(String entityName, String fieldName, String newFieldType, AnalysisMode mode)
	'''
	import java
	«IF mode.includesDataFlow»
	import semmle.code.java.dataflow.DataFlow
	«ENDIF»
	import utils
	
	from
	  Class entity, Field attributeField, Location usageLoc, string message, string oldType,
	  string newType
	where
	  isEntity(entity) and
	  entity.hasName("«entityName»") and 
	  attributeField = entity.getAField() and
	  attributeField.hasName("«fieldName»") and 
	  oldType = attributeField.getType().getName() and
	  newType = "«newFieldType»" and // New type to replace the old one
	  (
	    // the attribute will be casted
	    (usageLoc = attributeField.getLocation() and
	    message = "Attribute '" + attributeField.getName() + "' in entity '" + entity.getName() + "' will change type from '" + oldType + "' to '" + newType + "'.")
	
	    or
	    // getters y setters
	    exists(Method method |
	      (isGetter(method, attributeField) or isSetter(method, attributeField)) and
	      usageLoc = method.getLocation() and
	      message = "Method '" + method.getName() + "' uses attribute '" + attributeField.getName() + "' with type '" + oldType + "' which will be changed to '" + newType + "'."
	    )

	    or
	    // Calls are resolved to the exact accessor, avoiding homonymous methods.
	    exists(MethodCall accessorCall |
	      callsAccessor(accessorCall, attributeField) and
	      usageLoc = accessorCall.getLocation() and
	      message = "Call to accessor '" + accessorCall.getMethod().getName() +
	        "' depends on attribute type '" + oldType + "' which will change to '" + newType + "'."
	    )
	
	    or
	    // direct access to the attribute
	    exists(Expr expr |
	      usesFieldWithTypeDependency(expr, attributeField) and
	      usageLoc = expr.getLocation() and
	      message = "Code depends on attribute '" + attributeField.getName() + "' having type '" + oldType + "' which will be changed to '" + newType + "'."
	    )
	
	    or
	    // variable declarations with used attribute
	    exists(LocalVariableDeclExpr varDecl, Expr source |
	      source = varDecl.getInit() and
	      readsFieldValue(source, attributeField) and
	      varDecl.getType().getName() = oldType and
	      oldType != newType and
	      usageLoc = varDecl.getLocation() and
	      message = "Variable declaration expects old type '" + oldType +
	        "' from attribute '" + attributeField.getName() + "', which will change to '" + newType + "'."
	    )

	    or
	    // Assignment target still expects the old type.
	    exists(Assignment assignment, Expr source |
	      source = assignment.getRhs() and
	      readsFieldValue(source, attributeField) and
	      assignment.getDest().getType().getName() = oldType and
	      oldType != newType and
	      usageLoc = assignment.getLocation() and
	      message = "Assignment expects old type '" + oldType +
	        "' from attribute '" + attributeField.getName() + "', which will change to '" + newType + "'."
	    )

	    or
	    // A field/getter value is passed to a parameter expecting the old type.
	    exists(MethodCall call, Expr source, int i |
	      source = call.getArgument(i) and
	      readsFieldValue(source, attributeField) and
	      call.getMethod().getParameterType(i).getName() = oldType and
	      oldType != newType and
	      usageLoc = call.getLocation() and
	      message = "Method call expects old type '" + oldType +
	        "' from attribute '" + attributeField.getName() + "', which will change to '" + newType + "'."
	    )

	    «IF mode.includesDataFlow»
	    or
	    // Experimental local flow: only affected field/getter sources and
	    // method consumers declared on the old type hierarchy are considered.
	    exists(Expr source, MethodCall consumer |
	      readsFieldValue(source, attributeField) and
	      isOldTypeMethodCall(consumer, attributeField) and
	      DataFlow::localFlow(
	        DataFlow::exprNode(source),
	        DataFlow::exprNode(consumer.getQualifier())
	      ) and
	      not readsFieldValue(consumer.getQualifier(), attributeField) and
	      usageLoc = consumer.getLocation() and
	      message = "[Potential] Value from attribute '" + attributeField.getName() +
	        "' flows locally to old-type operation '" + consumer.getMethod().getName() +
	        "' after conversion to '" + newType + "'."
	    )
	    «ENDIF»
	  )
	select usageLoc, message
	'''
	
	def static generateAttributePromoteOp(String entityName, String newKeyName) {
		generateAttributePromoteOp(entityName, newKeyName, AnalysisMode.STRUCTURAL_SEMANTIC)
	}

	def static generateAttributePromoteOp(String entityName, String newKeyName, AnalysisMode mode)
	'''
	import java
	import utils
	
	from Class entity, Field existingIdField, Location usageLoc, string message, string newIdFieldName
	where
	  isEntity(entity) and 
	  entity.hasName("«entityName»") and 
	  existingIdField = entity.getAField() and
	  
	  // field with a @Id annotation
	  exists(Annotation idAnnotation |
	    idAnnotation = existingIdField.getAnAnnotation() and
	    isJpaAnnotation(idAnnotation, "Id")
	  ) and
	  
	  // Nombre del nuevo campo que será parte de la clave compuesta
	  newIdFieldName = "«newKeyName»" and
	  
	  (
	    (usageLoc = existingIdField.getLocation() and
	     message = "Field '" + existingIdField.getName() + "' will become part of composite key. " + "A new @EmbeddedId class will be created with this field and '" + newIdFieldName + "'.")
	    
	    or
	    // @Id, @GeneratedValue annotations
	    exists(Annotation annotation |
	      annotation = existingIdField.getAnAnnotation() and
	      (
	        isJpaAnnotation(annotation, "Id") or
	        isJpaAnnotation(annotation, "GeneratedValue")
	      ) and
	      usageLoc = annotation.getLocation() and
	      message = "Annotation '" + annotation.getType().getName() + "' will be removed as field becomes part of @EmbeddedId."
	    )
	    
	    or
	    // getters y setters
	    exists(Method method |
	      (isGetter(method, existingIdField) or isSetter(method, existingIdField)) and
	      usageLoc = method.getLocation() and
	      message = "Method '" + method.getName() + "' will need to be updated to use the composite key class instead of " +"accessing '" + existingIdField.getName() + "' directly."
	    )
	    
	    or
	    // direct access to the field
	    exists(FieldAccess access |
	      access.getField() = existingIdField and
	      usageLoc = access.getLocation() and
	      message = "Direct access to field '" + existingIdField.getName() + "' will need to be updated to use the composite key class."
	    )
	    
	    or
	    // query annotations
	    exists(Annotation nq, Annotation q |
	      (
	        // Named queries
	        (isQuery(q) and
	         isNamedQuery(nq) and
	         isEqual(nq.getValue("name"), q.getValue("name")) and
	         usesField(nq.getValue("query"), existingIdField) and
	         usageLoc = q.getLocation() and
	         message = "Named query uses field '" + existingIdField.getName() + "' which will become part of a composite key. JPQL needs to be updated.")
	        or
	        // queries
	        (isQuery(q) and
	         usesField(q.getValue("value"), existingIdField) and
	         usageLoc = q.getLocation() and
	         message = "Query uses field '" + existingIdField.getName() + "' which will become part of a composite key. JPQL needs to be updated.")
	      )
	    )
	    
	    or
	    // createQuery/createNamedQuery
	    exists(MethodCall call |
	      (
	        (isCreateQuery(call) and
	         exists(StringLiteral queryLiteral |
	           queryLiteral = call.getArgument(0) and
	           usesField(queryLiteral, existingIdField)
	         ))
	        or
	        (isCreateNamedQuery(call) and
	         exists(StringLiteral nameArg, Annotation nq2 |
	           nameArg = call.getArgument(0) and
	           isNamedQuery(nq2) and
	           "\"" + nameArg.getValue() + "\"" = nq2.getValue("name").toString() and
	           usesField(nq2.getValue("query"), existingIdField)
	         ))
	      ) and
	      usageLoc = call.getLocation() and
	      message = "Query references field '" + existingIdField.getName() + "' which will become part of a composite key. JPQL needs to be updated."
	    )
	    
	    or
	    // foreign key references
	    exists(Field foreignField, Class foreignEntity |
	      isEntity(foreignEntity) and
	      foreignField = foreignEntity.getAField() and
	      (
	        // joinColumn references 
	        exists(Annotation joinColumn |
	          joinColumn = foreignField.getAnAnnotation() and
	          isJpaAnnotation(joinColumn, "JoinColumn") and
	          joinColumn.getValue("referencedColumnName").toString().replaceAll("\"", "") = existingIdField.getName()
	        )
	        or
	        // OneToOne/ManyToOne references
	        (
	          foreignField.getType() = entity and
	          (
	            exists(Annotation association |
	              association = foreignField.getAnAnnotation() and
	              (isJpaAnnotation(association, "ManyToOne") or
	               isJpaAnnotation(association, "OneToOne"))
	            )
	          )
	        )
	      ) and
	      usageLoc = foreignField.getLocation() and
	      message = "Field '" + foreignField.getName() + "' in entity '" + foreignEntity.getName() + 
	               "' references '" + existingIdField.getName() + "' which will become part of a composite key. " +
	               "Foreign key relationship must be updated to use the composite key."
	    )
	  )
	select usageLoc, message
	'''
	
	def static generateRelationshipRenameOp(String oldTableName, String newTableName) {
		generateRelationshipRenameOp(oldTableName, newTableName, AnalysisMode.STRUCTURAL_SEMANTIC)
	}

	def static generateRelationshipRenameOp(String oldTableName, String newTableName, AnalysisMode mode)
	'''
	import java
	import utils
	
	from
	  Class sourceEntity, Field relationshipField, Location usageLoc, string message,
	  string oldTableName, string newTableName
	where
	  isEntity(sourceEntity) and
	  oldTableName = "«oldTableName»" and
	  newTableName = "«newTableName»" and
	
	  // search a field with @JoinTable annotation
	  relationshipField = sourceEntity.getAField() and
	  exists(Annotation joinTable |
	    hasJoinTableAnnotation(relationshipField, joinTable) and
	    joinTable.getValue("name").toString().replaceAll("\"", "") = oldTableName
	    and
	    usageLoc = joinTable.getLocation() and
	    message =
	      "Join table name will change from '" + oldTableName + "' to '" + newTableName + "'."
	  ) 
	select usageLoc, message
	'''
	
	def static generateRelationshipDeleteOp(String deleteTableName) {
		generateRelationshipDeleteOp(deleteTableName, AnalysisMode.STRUCTURAL_SEMANTIC)
	}

	def static generateRelationshipDeleteOp(String deleteTableName, AnalysisMode mode)
	'''
	import java
	import utils
	
	from
	  Class sourceEntity, Field relationshipField, Location usageLoc, string message,
	  string relationshipTable
	where
	  isEntity(sourceEntity) and  
	  relationshipTable = "«deleteTableName»" and
	  relationshipField = getRelationshipField(sourceEntity, relationshipTable) and
	  
	  (
	    // the relationship field 
	    (usageLoc = relationshipField.getLocation() and
	     message = "Relationship field '" + relationshipField.getName() + "' with database table '" +
	        relationshipTable + "' will be deleted. " + "Remove all references to this relationship."
	    )

	    or
	    // Accessor declarations materialize the domain relationship.
	    exists(Method accessor |
	      (isGetter(accessor, relationshipField) or isSetter(accessor, relationshipField)) and
	      usageLoc = accessor.getLocation() and
	      message = "Accessor '" + accessor.getName() + "' exposes relationship '" +
	        relationshipField.getName() + "' which will be deleted."
	    )

	    or
	    // Calls are linked to the resolved accessor, not merely its name.
	    exists(MethodCall accessorCall |
	      callsAccessor(accessorCall, relationshipField) and
	      usageLoc = accessorCall.getLocation() and
	      message = "Call to accessor '" + accessorCall.getMethod().getName() +
	        "' depends on relationship '" + relationshipField.getName() + "' which will be deleted."
	    )

	    or
	    // Direct field reads/writes, including collection operations through it.
	    exists(FieldAccess access |
	      access.getField() = relationshipField and
	      not isAccessInsideAccessor(access, relationshipField) and
	      usageLoc = access.getLocation() and
	      message = "Direct access depends on relationship '" + relationshipField.getName() +
	        "' which will be deleted."
	    )
	    
	    or
	    // Mappings on the other side of the relationship (mappedBy)
	    exists(Field mappedField, Annotation mappedBy |
	      mappedBy = mappedField.getAnAnnotation() and
	      isJpaAssociationAnnotation(mappedBy) and
	      isRelatedField(relationshipField, mappedField) and
	      usageLoc = mappedBy.getLocation() and
	      message =
	        "Field '" + mappedField.getName() + "' references relationship '" +
	          relationshipField.getName() + "' which will be deleted. " +
	          "Remove this mapping configuration."
	    )
	    
	    or    
	    // JPQL queries directly referencing the relationship (any side)
	    exists(Annotation nq, Annotation q |
	      (
	        // Named queries
	        (isQuery(q) and
	         isNamedQuery(nq) and
	         isEqual(nq.getValue("name"), q.getValue("name")) and
	         usesRelationship(nq.getValue("query"), relationshipField) and
	         usageLoc = q.getLocation() and
	         message =
	          "Named query references relationship table '" + relationshipTable +
	            "' which will be deleted. Update query to remove this reference."
	        )
	        or
	        // Queries
	        (isQuery(q) and
	         usesRelationship(q.getValue("value"), relationshipField) and
	         usageLoc = q.getLocation() and
	         message =
	          "Query references relationship table '" + relationshipTable +
	            "' which will be deleted. Update query to remove this reference."
	        )
	      )
	    )
	    
	    or
	    // EntityManager createQuery/createNamedQuery
	    exists(MethodCall call |
	      (
	        (
	          isCreateQuery(call) and
	          exists(StringLiteral queryLiteral |
	            queryLiteral = call.getArgument(0) and
	            usesRelationship(queryLiteral, relationshipField)
	          )
	        )
	        or
	        (
	          isCreateNamedQuery(call) and
	          exists(StringLiteral nameArg, Annotation nq2 |
	            nameArg = call.getArgument(0) and
	            isNamedQuery(nq2) and
	            "\"" + nameArg.getValue() + "\"" = nq2.getValue("name").toString() and
	            usesRelationship(nq2.getValue("query"), relationshipField)
	          )
	        )
	      ) and
	      usageLoc = call.getLocation() and
	      message =
	        "Query references relationship '" + relationshipField.getName() +
	          "' which will be deleted. Update or remove this query."
	    )
	  )
	select usageLoc, message
	'''
	
}
