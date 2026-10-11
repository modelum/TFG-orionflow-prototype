package codeql.template.attribute

import config.PersistenceFramework

/** Generates CodeQL queries for attribute/reference Orion operations. */
class AttributeQuery {
	static def generateAttributeCastOp(String entityName, String fieldName, String newFieldType) {
		generateAttributeCastOp(entityName, fieldName, newFieldType, PersistenceFramework.JPA)
	}



	static def generateAttributeCastOp(String entityName, String fieldName, String newFieldType, PersistenceFramework framework)
	'''
	import java
	import orion_dataflow
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
	    // Typed persistence APIs may impose ordering/comparison semantics that
	    // depend on the attribute's previous type.
	    exists(MethodCall call, StringLiteral propertyName |
	      isFrameworkFieldNameCall(call, propertyName, attributeField) and
	      usageLoc = propertyName.getLocation() and
	      message = "Persistence API uses attribute '" + attributeField.getName() +
	        "' whose type will change from '" + oldType + "' to '" + newType + "'."
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

	    or
	    // Experimental local flow: only affected field/getter sources and
	    // method consumers declared on the old type hierarchy are considered.
	    exists(Expr source, MethodCall consumer |
	      readsFieldValue(source, attributeField) and
	      isOldTypeMethodCall(consumer, attributeField) and
	      fieldValueFlowsToOldTypeConsumer(attributeField, source, consumer) and
	      usageLoc = consumer.getLocation() and
	      message = "[Potential] Value from attribute '" + attributeField.getName() +
	        "' flows locally to old-type operation '" + consumer.getMethod().getName() +
	        "' after conversion to '" + newType + "'."
	    )
	  )
	select usageLoc, message
	'''

	static def generateReferenceCastOp(String entityName, String fieldName, String newFieldType) {
		generateReferenceCastOp(
			entityName,
			fieldName,
			newFieldType,
			PersistenceFramework.JPA
		)
	}



	static def generateReferenceCastOp(
		String entityName,
		String fieldName,
		String newFieldType,
		PersistenceFramework framework
	)
	'''
	import java
	import orion_dataflow
	import utils

	from Class entity, Field referenceField, Location usageLoc, string message,
	     string oldType, string newType
	where
	  isEntity(entity) and
	  entity.hasName("«entityName»") and
	  referenceField = entity.getAField() and
	  referenceField.hasName("«fieldName»") and
	  oldType = referenceField.getType().getName() and
	  newType = "«newFieldType»" and
	  (
	    usageLoc = referenceField.getLocation() and
	    message = "Reference '" + referenceField.getName() + "' in entity '" +
	      entity.getName() + "' will change type from '" + oldType + "' to '" +
	      newType + "'."

	    or
	    exists(Method accessor |
	      (isGetter(accessor, referenceField) or isSetter(accessor, referenceField)) and
	      usageLoc = accessor.getLocation() and
	      message = "Accessor '" + accessor.getName() +
	        "' exposes the old reference type '" + oldType + "'."
	    )

	    or
	    exists(MethodCall accessorCall |
	      callsAccessor(accessorCall, referenceField) and
	      usageLoc = accessorCall.getLocation() and
	      message = "Call to reference accessor '" +
	        accessorCall.getMethod().getName() + "' depends on old type '" +
	        oldType + "'."
	    )

	    or
	    exists(MethodCall call, StringLiteral propertyName |
	      isFrameworkFieldNameCall(call, propertyName, referenceField) and
	      usageLoc = propertyName.getLocation() and
	      message = "Persistence API uses reference '" + referenceField.getName() +
	        "' whose type will change from '" + oldType + "' to '" + newType + "'."
	    )

	    or
	    exists(Expr expression |
	      usesFieldWithTypeDependency(expression, referenceField) and
	      usageLoc = expression.getLocation() and
	      message = "Code uses reference '" + referenceField.getName() +
	        "' as old type '" + oldType + "'."
	    )

	    or
	    exists(LocalVariableDeclExpr variable, Expr source |
	      source = variable.getInit() and
	      readsFieldValue(source, referenceField) and
	      variable.getType().getName() = oldType and
	      oldType != newType and
	      usageLoc = variable.getLocation() and
	      message = "Variable declaration expects old reference type '" + oldType + "'."
	    )

	    or
	    exists(Assignment assignment, Expr source |
	      source = assignment.getRhs() and
	      readsFieldValue(source, referenceField) and
	      assignment.getDest().getType().getName() = oldType and
	      oldType != newType and
	      usageLoc = assignment.getLocation() and
	      message = "Assignment expects old reference type '" + oldType + "'."
	    )

	    or
	    exists(MethodCall call, Expr source, int i |
	      source = call.getArgument(i) and
	      readsFieldValue(source, referenceField) and
	      call.getMethod().getParameterType(i).getName() = oldType and
	      oldType != newType and
	      usageLoc = call.getLocation() and
	      message = "Method call expects old reference type '" + oldType + "'."
	    )

	    or
	    exists(Annotation association |
	      association = referenceField.getAnAnnotation() and
	      isAssociationAnnotation(association) and
	      usageLoc = association.getLocation() and
	      message = "Persistence association for reference '" +
	        referenceField.getName() + "' must be reviewed for type '" + newType + "'."
	    )

	    or
	    exists(Annotation referenceMapping |
	      isReferenceMappingAnnotation(referenceMapping, referenceField) and
	      usageLoc = referenceMapping.getLocation() and
	      message = "Reference mapping metadata for '" +
	        referenceField.getName() + "' may depend on the old identifier type."
	    )

	    or
	    exists(Class targetEntity, Field targetId, Annotation idAnnotation |
	      fieldTargetsEntity(referenceField, targetEntity) and
	      targetId = targetEntity.getAField() and
	      idAnnotation = targetId.getAnAnnotation() and
	      isIdAnnotation(idAnnotation) and
	      targetId.getType().getName() = oldType and
	      oldType != newType and
	      usageLoc = targetId.getLocation() and
	      message = "Referenced identifier '" + targetId.getName() +
	        "' in entity '" + targetEntity.getName() +
	        "' still has old type '" + oldType + "'."
	    )

	    or
	    exists(Expr source, MethodCall consumer |
	      fieldValueFlowsToOldTypeConsumer(referenceField, source, consumer) and
	      usageLoc = consumer.getLocation() and
	      message = "[Potential] Reference value from '" +
	        referenceField.getName() + "' flows locally to old-type operation '" +
	        consumer.getMethod().getName() + "'."
	    )
	  )
	select usageLoc, message
	'''
	
	def static generateAttributePromoteOp(String entityName, String newKeyName) {
		generateAttributePromoteOp(entityName, newKeyName, PersistenceFramework.JPA)
	}



	def static generateAttributePromoteOp(String entityName, String newKeyName, PersistenceFramework framework)
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
	    isIdAnnotation(idAnnotation)
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
	        isIdAnnotation(annotation) or
	        isGeneratedValueAnnotation(annotation)
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
	    // Declared JPA named queries.
	    exists(Annotation nq |
	      isNamedQuery(nq) and
	      usesField(nq.getValue("query"), existingIdField) and
	      usageLoc = nq.getLocation() and
	      message = "Named query uses field '" + existingIdField.getName() +
	        "' which will become part of a composite key. JPQL needs to be updated."
	    )

	    or
	    // Spring Data query annotations.
	    exists(Annotation q |
	      isQuery(q) and
	      usesField(q.getValue("value"), existingIdField) and
	      usageLoc = q.getLocation() and
	      message = "Query uses field '" + existingIdField.getName() +
	        "' which will become part of a composite key. JPQL needs to be updated."
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
	          isJoinColumnAnnotation(joinColumn) and
	          joinColumn.getValue("referencedColumnName").toString().replaceAll("\"", "") = existingIdField.getName()
	        )
	        or
	        // OneToOne/ManyToOne references
	        (
	          foreignField.getType() = entity and
	          (
	            exists(Annotation association |
	              association = foreignField.getAnAnnotation() and
	              isAssociationAnnotation(association)
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
	
}

