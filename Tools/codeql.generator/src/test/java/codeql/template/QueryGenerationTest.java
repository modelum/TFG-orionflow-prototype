package codeql.template;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import codeql.template.attribute.AttributeQuery;
import codeql.template.entity.EntityQuery;
import codeql.template.feature.FeatureQuery;
import codeql.template.library.JavaStructuralLibrary;
import codeql.template.library.JpaLibrary;
import codeql.template.library.Library;
import codeql.template.relationship.RelationshipQuery;
import config.PersistenceFramework;
import org.junit.jupiter.api.Test;

class QueryGenerationTest {

    @Test
    void entityRenameUsesResolvedTypesAndConstructions() {
        String query = EntityQuery.generateEntityRenameOp(
            "Visit", "Consultation", PersistenceFramework.JPA).toString();

        assertTrue(query.contains("referencesEntityType(typeReference, oldEntity)"));
        assertTrue(query.contains("constructsEntity(creation, oldEntity)"));
        assertTrue(query.contains("declaresEntityConstructor(constructor, oldEntity)"));
        assertTrue(query.contains("oldEntity.hasName(\"Visit\")"));
        assertFalse(query.contains("field.getType().getName() = oldEntity.getName()"));
    }

    @Test
    void featureQueriesAlwaysIncludeStructuralAndSemanticRules() {
        String query = FeatureQuery.generateFeatureRenameOp(
            "Visit", "birthDate", "dateOfBirth", PersistenceFramework.JPA).toString();
        String both = FeatureQuery.generateFeatureRenameOp(
            "Visit", "birthDate", "dateOfBirth", PersistenceFramework.BOTH).toString();

        assertTrue(query.contains("callsAccessor(call, featureField)"));
        assertTrue(query.contains("predicate isSpringPropertyReference"));
        assertTrue(query.contains("propertyName.getValue() = \"birthDate\""));
        assertTrue(query.contains("predicate isSpringDataDerivedQuery"));
        assertTrue(query.contains("isSpringRepositoryMethodForEntity(method, entity)"));
        assertTrue(query.contains("frameworkMetadataReferencesField(metadata, featureField)"));
        assertTrue(both.contains("isJpaFrameworkQuery(q) and usesField(q.getValue(\"value\"))"));
        assertTrue(both.contains("isMongoFrameworkQuery(q)"));
        assertTrue(both.contains("frameworkQueryReferencesField(q, featureField)"));
        assertFalse(both.contains("isQuery(q) and"));
        assertFalse(query.contains("ATTR"));
    }

    @Test
    void dataFlowIsBoundToTheSelectedScoTemplates() {
        String cast = AttributeQuery.generateAttributeCastOp(
            "Visit", "date", "String", PersistenceFramework.JPA).toString();
        String rename = FeatureQuery.generateFeatureRenameOp(
            "Visit", "date", "startDate", PersistenceFramework.JPA).toString();

        assertTrue(cast.contains("import orion_dataflow"));
        assertTrue(cast.contains("fieldValueFlowsToOldTypeConsumer"));
        assertTrue(cast.contains("fieldValueGloballyFlowsToOldTypeConsumer"));
        assertTrue(cast.contains("[Global]"));
        assertTrue(cast.contains("[Potential]"));
        assertFalse(rename.contains("import orion_dataflow"));
    }

    @Test
    void relationshipRenameStaysPhysicalWhileDeleteIncludesDomainUses() {
        String rename = RelationshipQuery.generateRelationshipRenameOp(
            "vet_specialties", "vet_expertise", PersistenceFramework.JPA).toString();
        String delete = RelationshipQuery.generateRelationshipDeleteOp(
            "vet_specialties", PersistenceFramework.JPA).toString();

        assertTrue(rename.contains("getRelationshipMappingAnnotation(relationshipField, oldTableName, joinTable)"));
        assertFalse(rename.contains("callsAccessor"));
        assertTrue(delete.contains("callsAccessor(accessorCall, relationshipField)"));
        assertTrue(delete.contains("access.getField() = relationshipField"));
        assertTrue(delete.contains("fieldCallGraphImpact"));
        assertFalse(rename.contains("fieldCallGraphImpact"));
    }

    @Test
    void standaloneNamedQueriesAreAnalyzedAtTheirDeclaration() {
        String entity = EntityQuery.generateEntityRenameOp(
            "Visit", "Consultation", PersistenceFramework.JPA).toString();
        String feature = FeatureQuery.generateFeatureRenameOp(
            "Visit", "birthDate", "dateOfBirth", PersistenceFramework.JPA).toString();

        assertTrue(entity.contains("usageLoc = nq.getLocation()"));
        assertTrue(feature.contains("usageLoc = nq.getLocation()"));
        assertFalse(entity.contains("isEqual(nq.getValue(\"name\"), q.getValue(\"name\"))"));
        assertFalse(feature.contains("isEqual(nq.getValue(\"name\"), q.getValue(\"name\"))"));
    }

    @Test
    void utilityPredicatesSupportBothJpaNamespacesWithoutDynamicRegexes() {
        String structural = JavaStructuralLibrary.generate().toString();
        String jpa = JpaLibrary.generate().toString();
        String library = Library.generateUtils(PersistenceFramework.JPA).toString();

        assertTrue(jpa.contains("hasQualifiedName(\"jakarta.persistence\", simpleName)"));
        assertTrue(jpa.contains("hasQualifiedName(\"javax.persistence\", simpleName)"));
        assertTrue(structural.contains("creation.getConstructedType() = entity"));
        assertTrue(structural.contains("expression.(CompileTimeConstantExpr).getStringValue()"));
        assertTrue(structural.contains("constructor.getDeclaringType() = entity"));
        assertTrue(structural.contains("not constructor.isDefaultConstructor()"));
        assertTrue(structural.contains("field.getType().(ParameterizedType).getATypeArgument() = entity"));
        assertTrue(jpa.contains("fieldTargetsEntity(mappedField, relationshipField.getDeclaringType())"));
        assertTrue(library.contains("import orion_java"));
        assertTrue(library.contains("import orion_jpa"));
        assertFalse(structural.contains("creation.fromSource()"));
        assertFalse(jpa.contains("regexpMatch(\"(?i).*\\\\b\" + entity.getName()"));
        assertFalse(jpa.contains("regexpMatch(\"(?i).*\\\\b\" + field.getName()"));
    }

    @Test
    void entityMetadataReportsOnlyAnIndependentExplicitLogicalRename() {
        String rename = EntityQuery.generateEntityRenameOp(
            "Visit", "Consultation", PersistenceFramework.BOTH).toString();
        String delete = EntityQuery.generateEntityDeleteOp(
            "Visit", PersistenceFramework.BOTH).toString();

        assertTrue(rename.contains("frameworkEntityRenameMetadataAnnotation"));
        assertFalse(rename.contains("frameworkEntityMetadataAnnotation"));
        assertFalse(delete.contains("frameworkEntityMetadataAnnotation"));
    }
}
