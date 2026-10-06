package m2t

import java.util.HashMap
import java.util.Map

/**
 * Resolves the logical names produced by an Orion evolution sequence to the
 * names that still exist in the source code used to build the CodeQL database.
 */
class EvolutionContext {
	val Map<String, String> entityOrigins = new HashMap<String, String>()
	val Map<String, Map<String, FeatureOrigin>> featureOrigins =
		new HashMap<String, Map<String, FeatureOrigin>>()
	val Map<String, String> relationshipOrigins = new HashMap<String, String>()

	def String resolveEntity(String currentName) {
		val originalName = entityOrigins.get(currentName)
		if (originalName === null) currentName else originalName
	}

	def FeatureOrigin resolveFeature(String currentEntityName, String currentFeatureName) {
		val features = featureOrigins.get(currentEntityName)
		val origin = if (features === null) null else features.get(currentFeatureName)

		if (origin === null)
			new FeatureOrigin(resolveEntity(currentEntityName), currentFeatureName)
		else
			origin
	}

	def void renameEntity(String currentName, String newName) {
		val originalName = resolveEntity(currentName)
		val features = featureOrigins.remove(currentName)

		entityOrigins.remove(currentName)
		entityOrigins.put(newName, originalName)

		if (features !== null)
			featureOrigins.put(newName, features)
	}

	def void deleteEntity(String currentName) {
		entityOrigins.remove(currentName)
		featureOrigins.remove(currentName)
	}

	def void splitEntity(
		String currentName,
		String firstEntityName,
		Iterable<String> firstFeatureNames,
		String secondEntityName,
		Iterable<String> secondFeatureNames
	) {
		val originalEntityName = resolveEntity(currentName)
		val firstFeatures = resolveFeatures(currentName, firstFeatureNames)
		val secondFeatures = resolveFeatures(currentName, secondFeatureNames)

		entityOrigins.remove(currentName)
		featureOrigins.remove(currentName)

		entityOrigins.put(firstEntityName, originalEntityName)
		entityOrigins.put(secondEntityName, originalEntityName)
		featureOrigins.put(firstEntityName, firstFeatures)
		featureOrigins.put(secondEntityName, secondFeatures)
	}

	def void renameFeature(String currentEntityName, String currentFeatureName, String newFeatureName) {
		val origin = resolveFeature(currentEntityName, currentFeatureName)
		val features = getOrCreateFeatures(currentEntityName)

		features.remove(currentFeatureName)
		features.put(newFeatureName, origin)
	}

	def void deleteFeature(String currentEntityName, String currentFeatureName) {
		val features = featureOrigins.get(currentEntityName)
		if (features !== null)
			features.remove(currentFeatureName)
	}

	def void moveFeature(
		String sourceEntityName,
		String sourceFeatureName,
		String targetEntityName,
		String targetFeatureName
	) {
		val origin = resolveFeature(sourceEntityName, sourceFeatureName)
		deleteFeature(sourceEntityName, sourceFeatureName)
		getOrCreateFeatures(targetEntityName).put(targetFeatureName, origin)
	}

	def String resolveRelationship(String currentName) {
		val originalName = relationshipOrigins.get(currentName)
		if (originalName === null) currentName else originalName
	}

	def void renameRelationship(String currentName, String newName) {
		val originalName = resolveRelationship(currentName)
		relationshipOrigins.remove(currentName)
		relationshipOrigins.put(newName, originalName)
	}

	def void deleteRelationship(String currentName) {
		relationshipOrigins.remove(currentName)
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

	static class FeatureOrigin {
		val String entityName
		val String featureName

		new(String entityName, String featureName) {
			this.entityName = entityName
			this.featureName = featureName
		}

		def String getEntityName() {
			entityName
		}

		def String getFeatureName() {
			featureName
		}
	}
}
