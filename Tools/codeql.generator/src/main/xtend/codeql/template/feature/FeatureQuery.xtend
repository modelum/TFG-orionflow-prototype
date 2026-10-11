package codeql.template.feature

import codeql.template.library.Library
import config.PersistenceFramework

/** Generates CodeQL queries for feature-level Orion operations. */
class FeatureQuery {
	private static def CharSequence queryUsesField(String queryExpression)
	'''usesField(«queryExpression»)'''

	private static def CharSequence queryAnnotationUsesField(
		String queryVariable,
		String queryExpression,
		String fieldVariable,
		PersistenceFramework framework
	)
	'''
	«IF framework.includesJpa && framework.includesMongo»
	(
	(isJpaFrameworkQuery(«queryVariable») and usesField(«queryExpression»))
	 or
	(isMongoFrameworkQuery(«queryVariable») and
	 frameworkQueryReferencesField(«queryVariable», «fieldVariable»))
	)
	«ELSEIF framework.includesMongo»
	isQuery(«queryVariable») and
	(usesField(«queryExpression») or
	 frameworkQueryReferencesField(«queryVariable», «fieldVariable»))
	«ELSE»
	isQuery(«queryVariable») and usesField(«queryExpression»)
	«ENDIF»
	'''

	static def generateFeatureRenameOp(String entityName, String featureOldName, String featureNewName) {
		generateFeatureRenameOp(entityName, featureOldName, featureNewName, PersistenceFramework.JPA)
	}



	static def generateFeatureRenameOp(String entityName, String featureOldName, String featureNewName, PersistenceFramework framework)
	'''
	import java
	import utils

	«Library.generateUsesField(entityName, featureOldName, framework)»
	«Library.generateFeatureSemanticPredicates(entityName, featureOldName)»
	
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

	    or
	    // JPA metadata whose value names the affected feature.
	    exists(Annotation metadata |
	      frameworkMetadataReferencesField(metadata, featureField) and
	      usageLoc = metadata.getLocation() and
	      message = "Persistence metadata references feature '" + oldName +
	        "' which will be renamed to '" + newName + "'."
	    )

	    or
	    // Typed persistence APIs such as Criteria.where("field") and Update.set(...).
	    exists(MethodCall call, StringLiteral propertyName |
	      isFrameworkFieldNameCall(call, propertyName, featureField) and
	      usageLoc = propertyName.getLocation() and
	      message = "Persistence API references feature '" + oldName +
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
	
	    or
	    // Declared JPA named queries.
	    exists(Annotation nq |
	      isNamedQuery(nq) and
	      «queryUsesField('nq.getValue("query")')» and
	      usageLoc = nq.getLocation() and
	      message = "Named query uses feature '" + oldName +
	        "' which will be renamed to '" + newName + "'."
	    )

	    or
	    // Spring Data query annotations.
	    exists(Annotation q |
	      «queryAnnotationUsesField("q", 'q.getValue("value")', "featureField", framework)» and
	      usageLoc = q.getLocation() and
	      message = "Query uses feature '" + oldName +
	        "' which will be renamed to '" + newName + "'."
	    )
	
	    or
	    // createQuery y createNamedQuery
	    exists(MethodCall call |
	      (
	        (isCreateQuery(call) and
	        exists(Expr queryValue |
	          queryValue = call.getArgument(0) and
	          «queryUsesField("queryValue")»
	        ))
	
	        or
	        (isCreateNamedQuery(call) and
	        exists(StringLiteral nameArg, Annotation nq2 |
	          nameArg = call.getArgument(0) and
	          isNamedQuery(nq2) and
	          "\"" + nameArg.getValue() + "\"" = nq2.getValue("name").toString() and
	          «queryUsesField('nq2.getValue("query")')»
	        ))
	      ) and
	      usageLoc = call.getLocation() and
	      message = "Query uses feature '" + oldName + "' which will be renamed to '" + newName + "'."
	    )
	  )
	select usageLoc, message
	'''
	
	static def generateFeatureDeleteOp(String entityName, String featureName) {
		generateFeatureDeleteOp(entityName, featureName, PersistenceFramework.JPA)
	}



	static def generateFeatureDeleteOp(String entityName, String featureName, PersistenceFramework framework)
	'''
	import java
	import orion_dataflow
	import utils

	«Library.generateUsesField(entityName, featureName, framework)»
	«Library.generateFeatureSemanticPredicates(entityName, featureName)»
	
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

	    or
	    exists(Annotation metadata |
	      frameworkMetadataReferencesField(metadata, attributeField) and
	      usageLoc = metadata.getLocation() and
	      message = "Persistence metadata references attribute '" + attributeField.getName() +
	        "' which will be deleted."
	    )

	    or
	    exists(MethodCall call, StringLiteral propertyName |
	      isFrameworkFieldNameCall(call, propertyName, attributeField) and
	      usageLoc = propertyName.getLocation() and
	      message = "Persistence API references attribute '" + attributeField.getName() +
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
	
	    or
	    // Declared JPA named queries.
	    exists(Annotation nq |
	      isNamedQuery(nq) and
	      «queryUsesField('nq.getValue("query")')» and
	      usageLoc = nq.getLocation() and
	      message = "Named query uses attribute '" + attributeField.getName() +
	        "' which will be deleted."
	    )

	    or
	    // Spring Data query annotations.
	    exists(Annotation q |
	      «queryAnnotationUsesField("q", 'q.getValue("value")', "attributeField", framework)» and
	      usageLoc = q.getTarget().getLocation() and
	      message = "Query uses attribute '" + attributeField.getName() +
	        "' which will be deleted."
	    )
	
	    or
	    // createQuery y createNamedQuery
	    exists(MethodCall call |
	      (
	        // agrupa las dos alternativas
	        (isCreateQuery(call) and
	        exists(Expr queryValue |
	          queryValue = call.getArgument(0) and
	          «queryUsesField("queryValue")»
	        ))
	
	        or
	        (isCreateNamedQuery(call) and
	        exists(StringLiteral nameArg, Annotation nq |
	          nameArg = call.getArgument(0) and
	          isNamedQuery(nq) and
	          "\"" + nameArg.getValue() + "\"" = nq.getValue("name").toString() and
	          «queryUsesField('nq.getValue("query")')»
	        ))
	      ) and
	      usageLoc = call.getLocation() and
	      message = "Query uses attribute '" + attributeField.getName() + "' which will be deleted."
	    )

	    or
	    // A local alias or argument derived from the deleted field remains an
	    // impact only when it reaches a concrete call site.
	    exists(Expr source, MethodCall consumer |
	      fieldValueFlowsToDependentCall(attributeField, source, consumer) and
	      usageLoc = consumer.getLocation() and
	      message = "[Potential] Value from deleted attribute '" +
	        attributeField.getName() + "' flows to call '" +
	        consumer.getMethod().getName() + "'."
	    )
	  )
	select usageLoc, message
	'''

	static def generateFeatureMoveOp(
		String sourceEntityName,
		String sourceFeatureName,
		String targetEntityName,
		String targetFeatureName
	) {
		generateFeatureMoveOp(
			sourceEntityName,
			sourceFeatureName,
			targetEntityName,
			targetFeatureName,
			PersistenceFramework.JPA
		)
	}



	static def generateFeatureMoveOp(
		String sourceEntityName,
		String sourceFeatureName,
		String targetEntityName,
		String targetFeatureName,
		PersistenceFramework framework
	)
	'''
	import java
	import orion_dataflow
	import utils

	«Library.generateUsesField(sourceEntityName, sourceFeatureName, framework)»
	«Library.generateFeatureSemanticPredicates(sourceEntityName, sourceFeatureName)»

	from Class sourceEntity, Field featureField, Location usageLoc, string message,
	     string targetEntityName, string targetFeatureName
	where
	  isEntity(sourceEntity) and
	  sourceEntity.hasName("«sourceEntityName»") and
	  featureField = sourceEntity.getAField() and
	  featureField.hasName("«sourceFeatureName»") and
	  targetEntityName = "«targetEntityName»" and
	  targetFeatureName = "«targetFeatureName»" and
	  (
	    usageLoc = featureField.getLocation() and
	    message = "Feature '" + featureField.getName() + "' will move from entity '" +
	      sourceEntity.getName() + "' to '" + targetEntityName + "." +
	      targetFeatureName + "'."

	    or
	    exists(Method accessor |
	      (isGetter(accessor, featureField) or isSetter(accessor, featureField)) and
	      usageLoc = accessor.getLocation() and
	      message = "Accessor '" + accessor.getName() + "' must navigate moved feature '" +
	        featureField.getName() + "' through entity '" + targetEntityName + "'."
	    )

	    or
	    exists(MethodCall accessorCall |
	      callsAccessor(accessorCall, featureField) and
	      usageLoc = accessorCall.getLocation() and
	      message = "Call to accessor '" + accessorCall.getMethod().getName() +
	        "' must be updated for moved feature '" + featureField.getName() + "'."
	    )

	    or
	    exists(FieldAccess access |
	      access.getField() = featureField and
	      not isAccessInsideAccessor(access, featureField) and
	      usageLoc = access.getLocation() and
	      message = "Direct access to moved feature '" + featureField.getName() +
	        "' must use entity '" + targetEntityName + "'."
	    )

	    or
	    exists(Annotation metadata |
	      frameworkMetadataReferencesField(metadata, featureField) and
	      usageLoc = metadata.getLocation() and
	      message = "Persistence metadata for moved feature '" +
	        featureField.getName() + "' must be updated."
	    )

	    or
	    exists(MethodCall call, StringLiteral propertyName |
	      (
	        isFrameworkFieldNameCall(call, propertyName, featureField) or
	        isSpringPropertyReference(call, propertyName, sourceEntity)
	      ) and
	      usageLoc = propertyName.getLocation() and
	      message = "Property reference to moved feature '" + featureField.getName() +
	        "' must use its new owner."
	    )

	    or
	    exists(Method repositoryMethod |
	      isSpringDataDerivedQuery(repositoryMethod, sourceEntity) and
	      usageLoc = repositoryMethod.getLocation() and
	      message = "Spring Data method '" + repositoryMethod.getName() +
	        "' is derived from moved feature '" + featureField.getName() + "'."
	    )

	    or
	    exists(Annotation namedQuery |
	      isNamedQuery(namedQuery) and
	      «queryUsesField('namedQuery.getValue("query")')» and
	      usageLoc = namedQuery.getLocation() and
	      message = "Named query references moved feature '" +
	        featureField.getName() + "' through its old owner."
	    )

	    or
	    exists(Annotation query |
	      «queryAnnotationUsesField("query", 'query.getValue("value")', "featureField", framework)» and
	      usageLoc = query.getLocation() and
	      message = "Query references moved feature '" + featureField.getName() +
	        "' through its old owner."
	    )

	    or
	    exists(Expr source, MethodCall consumer |
	      fieldValueFlowsToDependentCall(featureField, source, consumer) and
	      usageLoc = consumer.getLocation() and
	      message = "[Potential] Value from moved feature '" +
	        featureField.getName() + "' flows locally to call '" +
	        consumer.getMethod().getName() + "'."
	    )
	  )
	select usageLoc, message
	'''
	
}

