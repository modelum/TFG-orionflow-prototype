package codeql.template.entity

import codeql.template.library.Library
import config.PersistenceFramework

/** Generates CodeQL queries for entity-level Orion operations. */
class EntityQuery {
	static def generateEntityDeleteOp(String entityName) {
		generateEntityDeleteOp(entityName, PersistenceFramework.JPA)
	}

	static def generateEntityDeleteOp(String entityName, PersistenceFramework framework)
		'''
		import java
		import utils

		«Library.generateUsesOldEntity(entityName, framework)»
		
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
		    exists(Annotation metadata |
		      frameworkEntityMetadataAnnotation(entity, metadata) and
		      usageLoc = metadata.getLocation() and
		      message = "Persistence metadata declares entity '" + entity.getName() +
		        "' which is marked for deletion."
		    )

		    or
		    exists(MethodCall call, StringLiteral collectionName |
		      isFrameworkCollectionNameCall(call, collectionName, entity) and
		      usageLoc = collectionName.getLocation() and
		      message = "Persistence call references the stored collection for entity '" +
		        entity.getName() + "' which is marked for deletion."
		    )
		
		    or
		    // A declared JPA named query is itself a schema dependency; it does
		    // not need a separate Spring Data @Query reference to be relevant.
		    exists(Annotation nq, StringLiteral queryLiteral |
		      isNamedQuery(nq) and
		      queryLiteral = nq.getValue("query") and
		      usesOldEntity(queryLiteral) and
		      usageLoc = nq.getLocation() and
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
		generateEntityRenameOp(oldEntityName, newEntityName, PersistenceFramework.JPA)
	}

	static def generateEntityRenameOp(
		String oldEntityName,
		String newEntityName,
		PersistenceFramework framework
	)
		'''
		import java
		import utils

		«Library.generateUsesOldEntity(oldEntityName, framework)»
		
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
		    exists(Annotation metadata |
		      frameworkEntityMetadataAnnotation(oldEntity, metadata) and
		      usageLoc = metadata.getLocation() and
		      message = "Persistence metadata declares entity '" + oldEntity.getName() +
		        "' which will be renamed to '" + newName + "'."
		    )

		    or
		    exists(MethodCall call, StringLiteral collectionName |
		      isFrameworkCollectionNameCall(call, collectionName, oldEntity) and
		      usageLoc = collectionName.getLocation() and
		      message = "Persistence call references the stored collection for entity '" +
		        oldEntity.getName() + "' which will be renamed to '" + newName + "'."
		    )
		
		    or
		    // A declared JPA named query is itself a schema dependency.
		    exists(Annotation nq, StringLiteral queryLiteral |
		      isNamedQuery(nq) and
		      queryLiteral = nq.getValue("query") and
		      usesOldEntity(queryLiteral) and
		      usageLoc = nq.getLocation() and
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

	/**
	 * Splitting removes the original entity from the source model. Keep the
	 * dedicated entry point while intentionally reusing the deletion detector.
	 */
	static def generateEntitySplitOp(String entityName) {
		generateEntitySplitOp(entityName, PersistenceFramework.JPA)
	}

	static def generateEntitySplitOp(String entityName, PersistenceFramework framework) {
		generateEntityDeleteOp(entityName, framework)
	}
}
