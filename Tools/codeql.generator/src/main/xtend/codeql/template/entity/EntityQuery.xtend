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
		    // Explicit constructor declarations are separate rename/delete sites.
		    // Compiler-provided default constructors have no source location and
		    // are intentionally excluded by declaresEntityConstructor.
		    exists(Constructor constructor |
		      declaresEntityConstructor(constructor, entity) and
		      usageLoc = constructor.getLocation() and
		      message =
		        "Explicit constructor of entity '" + entity.getName() +
		        "' becomes invalid when the entity is deleted."
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
		    exists(MethodCall call, StringLiteral collectionName |
		      isFrameworkCollectionNameCall(call, collectionName, entity) and
		      usageLoc = collectionName.getLocation() and
		      message = "Persistence call references the stored collection for entity '" +
		        entity.getName() + "' which is marked for deletion."
		    )

		    or
		    // A declared JPA named query is itself a schema dependency; it does
		    // not need a separate Spring Data @Query reference to be relevant.
		    exists(Annotation nq, Expr queryValue |
		      isNamedQuery(nq) and
		      queryValue = nq.getValue("query") and
		      usesOldEntity(queryValue) and
		      usageLoc = nq.getLocation() and
		      message =
		        "Named query uses entity '" + entity.getName() +
		        "' which is marked for deletion."
		    )
		
		    or
		    // JPQL queries in @Query
		    exists(Annotation q, Expr queryValue |
		      isQuery(q) and
		      queryValue = q.getValue("value") and
		      usesOldEntity(queryValue) and
		      usageLoc = q.getTarget().getLocation() and
		      message =
		        "Query uses entity '" + entity.getName() +
		        "' which is marked for deletion."
		    )
		
		    or
		    // EntityManager.createQuery(...)
		    exists(MethodCall call, Expr queryValue |
		      isCreateQuery(call) and
		      queryValue = call.getArgument(0) and
		      usesOldEntity(queryValue) and
		      usageLoc = call.getLocation() and
		      message =
		        "Call to createQuery uses entity '" + entity.getName() +
		        "' which is marked for deletion."
		    )
		
		    or
		    // EntityManager.createNamedQuery(...)
		    exists(MethodCall call, StringLiteral nameArg,
		           Annotation nq, Expr queryValue |
		      isCreateNamedQuery(call) and
		      nameArg = call.getArgument(0) and
		      isNamedQuery(nq) and
		      "\"" + nameArg.getValue() + "\"" = nq.getValue("name").toString() and
		      queryValue = nq.getValue("query") and
		      usesOldEntity(queryValue) and
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
		    exists(Constructor constructor |
		      declaresEntityConstructor(constructor, oldEntity) and
		      usageLoc = constructor.getLocation() and
		      message =
		        "Explicit constructor of entity '" + oldEntity.getName() +
		        "' must use the new name '" + newName + "'."
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
		      frameworkEntityRenameMetadataAnnotation(oldEntity, metadata) and
		      usageLoc = metadata.getLocation() and
		      message = "Explicit logical entity name '" + oldEntity.getName() +
		        "' must be reviewed for rename to '" + newName + "'."
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
		    exists(Annotation nq, Expr queryValue |
		      isNamedQuery(nq) and
		      queryValue = nq.getValue("query") and
		      usesOldEntity(queryValue) and
		      usageLoc = nq.getLocation() and
		      message =
		        "Named query uses old entity name '" + oldEntity.getName() +
		        "' which will be renamed to '" + newName + "'."
		    )
		
		    or
		    // JPQL queries in @Query
		    exists(Annotation q, Expr queryValue |
		      isQuery(q) and
		      queryValue = q.getValue("value") and
		      usesOldEntity(queryValue) and
		      usageLoc = q.getTarget().getLocation() and
		      message =
		        "Query uses old entity name '" + oldEntity.getName() +
		        "' which will be renamed to '" + newName + "'."
		    )
		
		    or
		    // EntityManager.createQuery(...)
		    exists(MethodCall call, Expr queryValue |
		      isCreateQuery(call) and
		      queryValue = call.getArgument(0) and
		      usesOldEntity(queryValue) and
		      usageLoc = call.getLocation() and
		      message =
		        "Call to createQuery uses old entity name '" + oldEntity.getName() +
		        "' which will be renamed to '" + newName + "'."
		    )
		
		    or
		    // EntityManager.createNamedQuery(...)
		    exists(MethodCall call, StringLiteral nameArg,
		           Annotation nq, Expr queryValue |
		      isCreateNamedQuery(call) and
		      nameArg = call.getArgument(0) and
		      isNamedQuery(nq) and
		      "\"" + nameArg.getValue() + "\"" = nq.getValue("name").toString() and
		      queryValue = nq.getValue("query") and
		      usesOldEntity(queryValue) and
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
