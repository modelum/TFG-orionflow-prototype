package m2t

import java.util.HashMap
import java.util.Map

/**
 * Resolves the logical names produced by an Orion evolution sequence to the
 * names that still exist in the source code used to build the CodeQL database.
 */
class EvolutionContext {
	val Map<String, String> entityOrigins = new HashMap<String, String>()
	val Map<String, EntityOrigin> entityIdentities = new HashMap<String, EntityOrigin>()
	val Map<String, EntityOrigin> deletedEntities = new HashMap<String, EntityOrigin>()
	val Map<String, Map<String, FeatureOrigin>> featureOrigins =
		new HashMap<String, Map<String, FeatureOrigin>>()
	val Map<String, FeatureOrigin> deletedFeatures = new HashMap<String, FeatureOrigin>()
	val Map<String, String> relationshipOrigins = new HashMap<String, String>()
	val Map<String, RelationshipOrigin> relationshipIdentities =
		new HashMap<String, RelationshipOrigin>()
	val Map<String, RelationshipOrigin> deletedRelationships =
		new HashMap<String, RelationshipOrigin>()
	long nextEntityId
	long nextFeatureId
	long nextRelationshipId

	def String resolveEntity(String currentName) {
		resolveEntityOrigin(currentName).originalName
	}

	def EntityOrigin resolveEntityOrigin(String currentName) {
		var origin = entityIdentities.get(currentName)
		if (origin === null)
			origin = deletedEntities.get(currentName)
		if (origin === null) {
			val originalName = entityOrigins.get(currentName)
			origin = new EntityOrigin(
				nextEntityLogicalId,
				if (originalName === null) currentName else originalName,
				currentName
			)
			entityIdentities.put(currentName, origin)
		}
		origin
	}

	def FeatureOrigin resolveFeature(String currentEntityName, String currentFeatureName) {
		val features = featureOrigins.get(currentEntityName)
		val origin = if (features === null) null else features.get(currentFeatureName)

		if (origin !== null)
			return origin

		val deleted = deletedFeatures.get(featureKey(currentEntityName, currentFeatureName))
		if (deleted !== null)
			return deleted

		val created = new FeatureOrigin(
			nextFeatureLogicalId,
			resolveEntity(currentEntityName),
			currentFeatureName,
			currentEntityName,
			currentFeatureName
		)
		getOrCreateFeatures(currentEntityName).put(currentFeatureName, created)
		created
	}

	def void renameEntity(String currentName, String newName) {
		if (currentName != newName &&
			(entityIdentities.containsKey(newName) || entityOrigins.containsKey(newName)))
			throw new IllegalArgumentException(
				"Entity name collision while renaming '" + currentName + "' to '" + newName + "'."
			)
		val entityOrigin = resolveEntityOrigin(currentName)
		val originalName = entityOrigin.originalName
		val features = featureOrigins.remove(currentName)

		entityOrigins.remove(currentName)
		entityOrigins.put(newName, originalName)
		entityIdentities.remove(currentName)
		entityOrigin.currentName = newName
		entityIdentities.put(newName, entityOrigin)

		if (features !== null) {
			for (feature : features.values)
				feature.currentEntityName = newName
			featureOrigins.put(newName, features)
		}
	}

	def void deleteEntity(String currentName) {
		val entityOrigin = resolveEntityOrigin(currentName)
		entityOrigin.deleted = true
		deletedEntities.put(currentName, entityOrigin)
		entityOrigins.remove(currentName)
		entityIdentities.remove(currentName)
		val features = featureOrigins.get(currentName)
		if (features !== null) {
			for (entry : features.entrySet) {
				entry.value.deleted = true
				deletedFeatures.put(featureKey(currentName, entry.key), entry.value)
			}
		}
		featureOrigins.remove(currentName)
	}

	def void splitEntity(
		String currentName,
		String firstEntityName,
		Iterable<String> firstFeatureNames,
		String secondEntityName,
		Iterable<String> secondFeatureNames
	) {
		if (firstEntityName == secondEntityName ||
			entityIdentities.containsKey(firstEntityName) ||
			entityIdentities.containsKey(secondEntityName))
			throw new IllegalArgumentException(
				"Entity name collision while splitting '" + currentName + "'."
			)
		val sourceOrigin = resolveEntityOrigin(currentName)
		val originalEntityName = sourceOrigin.originalName
		val firstFeatures = resolveFeatures(currentName, firstFeatureNames)
		val secondFeatures = resolveFeatures(currentName, secondFeatureNames)

		entityOrigins.remove(currentName)
		entityIdentities.remove(currentName)
		sourceOrigin.deleted = true
		deletedEntities.put(currentName, sourceOrigin)
		featureOrigins.remove(currentName)

		entityOrigins.put(firstEntityName, originalEntityName)
		entityOrigins.put(secondEntityName, originalEntityName)
		entityIdentities.put(firstEntityName, new EntityOrigin(
			nextEntityLogicalId, originalEntityName, firstEntityName
		))
		entityIdentities.put(secondEntityName, new EntityOrigin(
			nextEntityLogicalId, originalEntityName, secondEntityName
		))
		for (feature : firstFeatures.values)
			feature.currentEntityName = firstEntityName
		for (feature : secondFeatures.values)
			feature.currentEntityName = secondEntityName
		featureOrigins.put(firstEntityName, firstFeatures)
		featureOrigins.put(secondEntityName, secondFeatures)
	}

	def void renameFeature(String currentEntityName, String currentFeatureName, String newFeatureName) {
		val origin = resolveFeature(currentEntityName, currentFeatureName)
		val features = getOrCreateFeatures(currentEntityName)
		if (currentFeatureName != newFeatureName && features.containsKey(newFeatureName))
			throw new IllegalArgumentException(
				"Feature name collision in entity '" + currentEntityName +
				"': '" + newFeatureName + "'."
			)

		features.remove(currentFeatureName)
		origin.currentEntityName = currentEntityName
		origin.currentFeatureName = newFeatureName
		features.put(newFeatureName, origin)
	}

	def void deleteFeature(String currentEntityName, String currentFeatureName) {
		val features = featureOrigins.get(currentEntityName)
		val origin = if (features === null) null else features.remove(currentFeatureName)
		val resolved = if (origin === null)
			resolveFeature(currentEntityName, currentFeatureName)
		else
			origin
		resolved.deleted = true
		deletedFeatures.put(featureKey(currentEntityName, currentFeatureName), resolved)
		val liveFeatures = featureOrigins.get(currentEntityName)
		if (liveFeatures !== null)
			liveFeatures.remove(currentFeatureName)
	}

	def void moveFeature(
		String sourceEntityName,
		String sourceFeatureName,
		String targetEntityName,
		String targetFeatureName
	) {
		val origin = resolveFeature(sourceEntityName, sourceFeatureName)
		val targetFeatures = getOrCreateFeatures(targetEntityName)
		if (targetFeatures.containsKey(targetFeatureName))
			throw new IllegalArgumentException(
				"Feature name collision in target entity '" + targetEntityName +
				"': '" + targetFeatureName + "'."
			)
		val sourceFeatures = featureOrigins.get(sourceEntityName)
		if (sourceFeatures !== null)
			sourceFeatures.remove(sourceFeatureName)
		origin.currentEntityName = targetEntityName
		origin.currentFeatureName = targetFeatureName
		targetFeatures.put(targetFeatureName, origin)
	}

	def String resolveRelationship(String currentName) {
		resolveRelationshipOrigin(currentName).originalName
	}

	def RelationshipOrigin resolveRelationshipOrigin(String currentName) {
		var origin = relationshipIdentities.get(currentName)
		if (origin === null)
			origin = deletedRelationships.get(currentName)
		if (origin === null) {
			val originalName = relationshipOrigins.get(currentName)
			origin = new RelationshipOrigin(
				nextRelationshipLogicalId,
				if (originalName === null) currentName else originalName,
				currentName
			)
			relationshipIdentities.put(currentName, origin)
		}
		origin
	}

	def void renameRelationship(String currentName, String newName) {
		if (currentName != newName &&
			(relationshipIdentities.containsKey(newName) || relationshipOrigins.containsKey(newName)))
			throw new IllegalArgumentException(
				"Relationship name collision while renaming '" + currentName +
				"' to '" + newName + "'."
			)
		val origin = resolveRelationshipOrigin(currentName)
		val originalName = origin.originalName
		relationshipOrigins.remove(currentName)
		relationshipOrigins.put(newName, originalName)
		relationshipIdentities.remove(currentName)
		origin.currentName = newName
		relationshipIdentities.put(newName, origin)
	}

	def void deleteRelationship(String currentName) {
		val origin = resolveRelationshipOrigin(currentName)
		origin.deleted = true
		deletedRelationships.put(currentName, origin)
		relationshipOrigins.remove(currentName)
		relationshipIdentities.remove(currentName)
	}

	private def String nextEntityLogicalId() {
		nextEntityId = nextEntityId + 1
		"E" + nextEntityId
	}

	private def String nextFeatureLogicalId() {
		nextFeatureId = nextFeatureId + 1
		"F" + nextFeatureId
	}

	private def String nextRelationshipLogicalId() {
		nextRelationshipId = nextRelationshipId + 1
		"R" + nextRelationshipId
	}

	private static def String featureKey(String entityName, String featureName) {
		entityName + "::" + featureName
	}

	private def Map<String, FeatureOrigin> getOrCreateFeatures(String entityName) {
		var features = featureOrigins.get(entityName)
		if (features === null) {
			features = new HashMap<String, FeatureOrigin>()
			featureOrigins.put(entityName, features)
		}
		features
	}

	private def Map<String, FeatureOrigin> resolveFeatures(
		String currentEntityName,
		Iterable<String> currentFeatureNames
	) {
		val resolvedFeatures = new HashMap<String, FeatureOrigin>()
		for (featureName : currentFeatureNames)
			resolvedFeatures.put(featureName, resolveFeature(currentEntityName, featureName))
		resolvedFeatures
	}

	static class EntityOrigin {
		val String logicalId
		val String originalName
		var String currentName
		var boolean deleted

		new(String logicalId, String originalName, String currentName) {
			this.logicalId = logicalId
			this.originalName = originalName
			this.currentName = currentName
		}

		def String getLogicalId() { logicalId }
		def String getOriginalName() { originalName }
		def String getCurrentName() { currentName }
		def boolean isDeleted() { deleted }
	}

	static class FeatureOrigin {
		val String logicalId
		val String entityName
		val String featureName
		var String currentEntityName
		var String currentFeatureName
		var boolean deleted

		new(String entityName, String featureName) {
			this("F0", entityName, featureName, entityName, featureName)
		}

		new(
			String logicalId,
			String entityName,
			String featureName,
			String currentEntityName,
			String currentFeatureName
		) {
			this.logicalId = logicalId
			this.entityName = entityName
			this.featureName = featureName
			this.currentEntityName = currentEntityName
			this.currentFeatureName = currentFeatureName
		}

		def String getLogicalId() { logicalId }
		def String getEntityName() { entityName }
		def String getFeatureName() { featureName }
		def String getCurrentEntityName() { currentEntityName }
		def String getCurrentFeatureName() { currentFeatureName }
		def boolean isDeleted() { deleted }
	}

	static class RelationshipOrigin {
		val String logicalId
		val String originalName
		var String currentName
		var boolean deleted

		new(String logicalId, String originalName, String currentName) {
			this.logicalId = logicalId
			this.originalName = originalName
			this.currentName = currentName
		}

		def String getLogicalId() { logicalId }
		def String getOriginalName() { originalName }
		def String getCurrentName() { currentName }
		def boolean isDeleted() { deleted }
	}
}
