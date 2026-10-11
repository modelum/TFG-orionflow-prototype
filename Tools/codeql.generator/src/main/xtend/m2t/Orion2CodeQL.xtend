package m2t

import codeql.option.SeverityEnum
import codeql.template.attribute.AttributeQuery
import codeql.template.entity.EntityQuery
import codeql.template.feature.FeatureQuery
import codeql.template.library.DataFlowLibrary
import codeql.template.library.JavaStructuralLibrary
import codeql.template.library.JpaLibrary
import codeql.template.library.Library
import codeql.template.Metadata
import codeql.template.library.MongoLibrary
import codeql.template.library.SpringCommonLibrary
import codeql.template.relationship.RelationshipQuery
import config.PersistenceFramework
import es.um.uschema.xtext.orion.orion.AttributeCastOp
import es.um.uschema.xtext.orion.orion.AttributePromoteOp
import es.um.uschema.xtext.orion.orion.BasicOperation
import es.um.uschema.xtext.orion.orion.EntityDeleteOp
import es.um.uschema.xtext.orion.orion.EntityRenameOp
import es.um.uschema.xtext.orion.orion.EntitySplitOp
import es.um.uschema.xtext.orion.orion.FeatureDeleteOp
import es.um.uschema.xtext.orion.orion.FeatureMoveOp
import es.um.uschema.xtext.orion.orion.FeatureRenameOp
import es.um.uschema.xtext.orion.orion.OrionOperations
import es.um.uschema.xtext.orion.orion.RelationshipDeleteOp
import es.um.uschema.xtext.orion.orion.RelationshipRenameOp
import java.util.LinkedHashMap
import java.util.List
import java.util.Map
import orion.Mapper
import es.um.uschema.xtext.orion.orion.ReferenceCastOp

class Orion2CodeQL {
	
	Map<String, String> results
	EvolutionContext evolutionContext
	PersistenceFramework framework
	int contOp = 0;
	
	new()
	{
		this(PersistenceFramework.JPA)
	}

	new(PersistenceFramework framework)
	{
		this.framework = if (framework === null) PersistenceFramework.JPA else framework
		resetState()
	}
	
	def Map<String, String> m2t(OrionOperations orion)
	{
		resetState()
		if(!orion.operations.empty || !orion.evolBlocks.empty)
		{
			results.put("orion_java.qll", JavaStructuralLibrary.generate.toString)
			results.put("orion_spring.qll", SpringCommonLibrary.generate.toString)
			results.put("orion_dataflow.qll", DataFlowLibrary.generate.toString)
			if (framework.includesJpa)
				results.put("orion_jpa.qll", JpaLibrary.generate.toString)
			if (framework.includesMongo)
				results.put("orion_mongo.qll", MongoLibrary.generate.toString)
			results.put("utils.qll", Library.generateUtils(framework).toString)
			results.put("suite.qls", Metadata.generateSuite(orion.name + "-query-suite").toString);
			results.put("codeql-pack.yml", Metadata.generateCodeQLPack(orion.name).toString);
		}
		
		if (!orion.operations.empty) {
			generateOperations(orion.operations)
		} else {
			for (evolutionBlock : orion.evolBlocks)
				generateOperations(evolutionBlock.operations)
		}

		results
	}

	private def void resetState() {
		results = new LinkedHashMap<String, String>()
		evolutionContext = new EvolutionContext()
		contOp = 0
	}
	
	def void generateOperations(List<BasicOperation> operations)
	{
		for( op : operations)
		{
			generateOperation(op)
			contOp++;
		}
	}
	
	def dispatch generateOperation(BasicOperation op)
	{
		// Operations without implementation
		contOp--
	}
	
	def dispatch generateOperation(EntityDeleteOp op)
	{
		val sourceEntityName = evolutionContext.resolveEntity(op.spec.ref)
		results.put(contOp + "-EntityDeleteOp.ql", 
		'''«Metadata.generateHeader("Deleted Entity", "alert", SeverityEnum.WARNING.value, "java/orion/entity-deleted/" + contOp)»«EntityQuery.generateEntityDeleteOp(sourceEntityName, framework)»''')
		evolutionContext.deleteEntity(op.spec.ref)
	}
	
	def dispatch generateOperation(EntityRenameOp op)
	{
		val sourceEntityName = evolutionContext.resolveEntity(op.spec.ref)
		results.put(contOp + "-EntityRenameOp.ql", 
		'''«Metadata.generateHeader("Renamed Entity", "alert", SeverityEnum.WARNING.value, "java/orion/entity-renamed/" + contOp)»«EntityQuery.generateEntityRenameOp(sourceEntityName, op.spec.name, framework)»''')
		evolutionContext.renameEntity(op.spec.ref, op.spec.name)
	}
	
	def dispatch generateOperation(FeatureRenameOp op)
	{
		val selector = op.spec.selector
		val sourceFeature = evolutionContext.resolveFeature(selector.ref, selector.target)
		results.put(contOp + "-FeatureRenameOp.ql", 
		'''«Metadata.generateHeader("Feature Renamed", "alert", SeverityEnum.WARNING.value, "java/orion/feature-renamed/" + contOp)»«FeatureQuery.generateFeatureRenameOp(sourceFeature.entityName, sourceFeature.featureName, op.spec.name, framework)»''')
		evolutionContext.renameFeature(selector.ref, selector.target, op.spec.name)
	}
	
	def dispatch generateOperation(FeatureDeleteOp op)
	{
		val selector = op.spec.selector
		var targetCount = 0;
		for(String target : selector.targets)
		{
			val sourceFeature = evolutionContext.resolveFeature(selector.ref, target)
			results.put(contOp + "-" + targetCount + "-FeatureDeleteOp.ql", 
			'''«Metadata.generateHeader("Feature Deleted", "alert", SeverityEnum.WARNING.value, "java/orion/feature-deleted/" + contOp + "/" + targetCount)»«FeatureQuery.generateFeatureDeleteOp(sourceFeature.entityName, sourceFeature.featureName, framework)»''')
			evolutionContext.deleteFeature(selector.ref, target)
			targetCount++;	
		}
	}
	
	def dispatch generateOperation(AttributeCastOp op)
	{
		val selector = op.spec.selector
		val type = Mapper.OrionType2Java(op.spec.type.typename)
		var targetCount = 0;
		if(!type.isEmpty)
		{
			for(String target : selector.targets)
			{
				val sourceFeature = evolutionContext.resolveFeature(selector.ref, target)
				results.put(contOp + "-" + targetCount + "-AttributeCastOp.ql", 
				'''«Metadata.generateHeader("Attribute Casted", "alert", SeverityEnum.WARNING.value, "java/orion/attribute-casted/" + contOp + "/" + targetCount)»«AttributeQuery.generateAttributeCastOp(sourceFeature.entityName, sourceFeature.featureName, type, framework)»''')
				targetCount++;
			}
		}else
		{
			contOp--
		}
	}
	
	def dispatch generateOperation(AttributePromoteOp op)
	{
		val selector = op.spec.selector
		val sourceEntityName = evolutionContext.resolveEntity(selector.ref)
		val fields = selector.targets.map[evolutionContext.resolveFeature(selector.ref, it).featureName].join(",")
		results.put(contOp + "-AttributePromoteOp.ql", 
			'''«Metadata.generateHeader("Attribute Promoted", "alert", SeverityEnum.WARNING.value, "java/orion/attribute-promoted/" + contOp)»«AttributeQuery.generateAttributePromoteOp(sourceEntityName, fields, framework)»''')

	}
	
	def dispatch generateOperation(RelationshipDeleteOp op)
	{
		val sourceRelationshipName = evolutionContext.resolveRelationship(op.spec.ref)
		results.put(contOp + "-RelationshipDeleteOp.ql", 
		'''«Metadata.generateHeader("Relationship Deleted", "alert", SeverityEnum.WARNING.value, "java/orion/relationship-deleted/" + contOp)»«RelationshipQuery.generateRelationshipDeleteOp(sourceRelationshipName, framework)»''')
		evolutionContext.deleteRelationship(op.spec.ref)
	}
	
	def dispatch generateOperation(RelationshipRenameOp op)
	{
		val sourceRelationshipName = evolutionContext.resolveRelationship(op.spec.ref)
		results.put(contOp + "-RelationshipRenameOp.ql", 
		'''«Metadata.generateHeader("Relationship Renamed", "alert", SeverityEnum.WARNING.value, "java/orion/relationship-renamed/" + contOp)»«RelationshipQuery.generateRelationshipRenameOp(sourceRelationshipName, op.spec.name, framework)»''')
		evolutionContext.renameRelationship(op.spec.ref, op.spec.name)
	}
	
	def dispatch generateOperation(EntitySplitOp op)
	{
		val sourceEntityName = evolutionContext.resolveEntity(op.spec.ref)
		results.put(contOp + "-EntitySplitOp.ql", 
		'''«Metadata.generateHeader("Split Entity", "alert", SeverityEnum.WARNING.value, "java/orion/entity-splited/" + contOp)»«EntityQuery.generateEntitySplitOp(sourceEntityName, framework)»''')
		evolutionContext.splitEntity(
			op.spec.ref,
			op.spec.name1,
			op.spec.features1.features,
			op.spec.name2,
			op.spec.features2.features
		)
	}
	
	def dispatch generateOperation(FeatureMoveOp op)
	{
		val sourceSelector = op.spec.sourceSelector
		val targetSelector = op.spec.targetSelector
		val sourceFeature = evolutionContext.resolveFeature(sourceSelector.ref, sourceSelector.target)
		results.put(contOp + "-FeatureMoveOp.ql", 
		'''«Metadata.generateHeader("Feature Moved", "alert", SeverityEnum.WARNING.value, "java/orion/feature-moved/" + contOp)»«FeatureQuery.generateFeatureMoveOp(sourceFeature.entityName, sourceFeature.featureName, targetSelector.ref, targetSelector.target, framework)»''')
		evolutionContext.moveFeature(
			sourceSelector.ref,
			sourceSelector.target,
			targetSelector.ref,
			targetSelector.target
		)
	}
	
	def dispatch generateOperation(ReferenceCastOp op)
	{
		val selector = op.spec.selector
		val type = Mapper.OrionType2Java(op.spec.type.typename)
		var targetCount = 0;
		if(!type.isEmpty)
		{
			for(String target : selector.targets)
			{
				val sourceFeature = evolutionContext.resolveFeature(selector.ref, target)
				results.put(contOp + "-" + targetCount + "-ReferenceCastOp.ql", 
				'''«Metadata.generateHeader("Reference Casted", "alert", SeverityEnum.WARNING.value, "java/orion/reference-casted/" + contOp + "/" + targetCount)»«AttributeQuery.generateReferenceCastOp(sourceFeature.entityName, sourceFeature.featureName, type, framework)»''')
				targetCount++;
			}
		}else
		{
			contOp--
		}
	}

}
