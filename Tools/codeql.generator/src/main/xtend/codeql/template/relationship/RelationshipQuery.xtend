package codeql.template.relationship

import config.PersistenceFramework

/** Generates CodeQL queries for relationship-level Orion operations. */
class RelationshipQuery {
	static def generateRelationshipRenameOp(String oldTableName, String newTableName) {
		generateRelationshipRenameOp(oldTableName, newTableName, PersistenceFramework.JPA)
	}

	static def generateRelationshipRenameOp(
		String oldTableName,
		String newTableName,
		PersistenceFramework framework
	)
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
	    getRelationshipMappingAnnotation(relationshipField, oldTableName, joinTable)
	    and
	    usageLoc = joinTable.getLocation() and
	    message =
	      "Join table name will change from '" + oldTableName + "' to '" + newTableName + "'."
	  ) 
	select usageLoc, message
	'''

	static def generateRelationshipDeleteOp(String deleteTableName) {
		generateRelationshipDeleteOp(deleteTableName, PersistenceFramework.JPA)
	}

	static def generateRelationshipDeleteOp(
		String deleteTableName,
		PersistenceFramework framework
	)
	'''
	import java
	import orion_callgraph
	import orion_dataflow
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
	    // One or two resolved call edges from a direct relationship access.
	    exists(
	      Method impactedMethod, MethodCall evidence, string depth, string reason
	    |
	      fieldCallGraphImpact(
	        relationshipField, impactedMethod, evidence, depth, reason
	      ) and
	      usageLoc = impactedMethod.getLocation() and
	      message = "[CallGraph depth " + depth + "] Method '" +
	        impactedMethod.getName() + "' indirectly depends on relationship '" +
	        relationshipField.getName() + "': it " + reason + "."
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
	      isAssociationAnnotation(mappedBy) and
	      isRelatedField(relationshipField, mappedField) and
	      usageLoc = mappedBy.getLocation() and
	      message =
	        "Field '" + mappedField.getName() + "' references relationship '" +
	          relationshipField.getName() + "' which will be deleted. " +
	          "Remove this mapping configuration."
	    )
	    
	    or    
	    // Declared JPA named queries directly referencing the relationship.
	    exists(Annotation nq |
	      isNamedQuery(nq) and
	      usesRelationship(nq.getValue("query"), relationshipField) and
	      usageLoc = nq.getLocation() and
	      message =
	        "Named query references relationship table '" + relationshipTable +
	        "' which will be deleted. Update query to remove this reference."
	    )

	    or
	    // Spring Data query annotations.
	    exists(Annotation q |
	      isQuery(q) and
	      frameworkQueryReferencesRelationship(
	        q, q.getValue("value"), relationshipField
	      ) and
	      usageLoc = q.getLocation() and
	      message =
	        "Query references relationship table '" + relationshipTable +
	        "' which will be deleted. Update query to remove this reference."
	    )
	    
	    or
	    // EntityManager createQuery/createNamedQuery
	    exists(MethodCall call |
	      (
	        (
	          isCreateQuery(call) and
	          exists(Expr queryValue |
	            queryValue = call.getArgument(0) and
	            usesRelationship(queryValue, relationshipField)
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

	    or
	    // Local aliases of a relationship collection are relevant only when
	    // they reach a mutating collection operation.
	    exists(Expr source, MethodCall mutation |
	      relationshipValueFlowsToMutation(relationshipField, source, mutation) and
	      usageLoc = mutation.getLocation() and
	      message = "[Potential] Collection value from relationship '" +
	        relationshipField.getName() + "' flows locally to mutating call '" +
	        mutation.getMethod().getName() + "'."
	    )
	  )
	select usageLoc, message
	'''
}
