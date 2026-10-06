package codeql.template;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import config.AnalysisMode;
import org.junit.jupiter.api.Test;

class QueryGenerationTest {

    @Test
    void entityRenameUsesResolvedTypesAndConstructions() {
        String query = Query.generateEntityRenameOp(
            "Visit", "Consultation", AnalysisMode.STRUCTURAL).toString();

        assertTrue(query.contains("referencesEntityType(typeReference, oldEntity)"));
        assertTrue(query.contains("constructsEntity(creation, oldEntity)"));
        assertTrue(query.contains("oldEntity.hasName(\"Visit\")"));
        assertFalse(query.contains("field.getType().getName() = oldEntity.getName()"));
    }

    @Test
    void semanticFeatureModeAddsOnlyConstrainedFrameworkRules() {
        String structural = Query.generateFeatureRenameOp(
            "Visit", "birthDate", "dateOfBirth", AnalysisMode.STRUCTURAL).toString();
        String semantic = Query.generateFeatureRenameOp(
            "Visit", "birthDate", "dateOfBirth", AnalysisMode.STRUCTURAL_SEMANTIC).toString();

        assertTrue(structural.contains("callsAccessor(call, featureField)"));
        assertFalse(structural.contains("predicate isSpringPropertyReference"));
        assertTrue(semantic.contains("predicate isSpringPropertyReference"));
        assertTrue(semantic.contains("propertyName.getValue() = \"birthDate\""));
        assertTrue(semantic.contains("predicate isSpringDataDerivedQuery"));
        assertTrue(semantic.contains("exists(ClassOrInterface repository, TypeAccess repositoryType"));
        assertTrue(semantic.contains("jpaMetadataReferencesField(metadata, featureField)"));
        assertFalse(semantic.contains("ATTR"));
    }

    @Test
    void dataFlowIsEmittedOnlyInDataFlowMode() {
        String semantic = Query.generateAttributeCastOp(
            "Visit", "date", "String", AnalysisMode.STRUCTURAL_SEMANTIC).toString();
        String dataFlow = Query.generateAttributeCastOp(
            "Visit", "date", "String", AnalysisMode.DATAFLOW).toString();

        assertFalse(semantic.contains("semmle.code.java.dataflow.DataFlow"));
        assertFalse(semantic.contains("DataFlow::localFlow"));
        assertTrue(dataFlow.contains("import semmle.code.java.dataflow.DataFlow"));
        assertTrue(dataFlow.contains("DataFlow::localFlow"));
        assertTrue(dataFlow.contains("[Potential]"));
    }

    @Test
    void relationshipRenameStaysPhysicalWhileDeleteIncludesDomainUses() {
        String rename = Query.generateRelationshipRenameOp(
            "vet_specialties", "vet_expertise", AnalysisMode.STRUCTURAL_SEMANTIC).toString();
        String delete = Query.generateRelationshipDeleteOp(
            "vet_specialties", AnalysisMode.STRUCTURAL_SEMANTIC).toString();

        assertTrue(rename.contains("hasJoinTableAnnotation(relationshipField, joinTable)"));
        assertFalse(rename.contains("callsAccessor"));
        assertTrue(delete.contains("callsAccessor(accessorCall, relationshipField)"));
        assertTrue(delete.contains("access.getField() = relationshipField"));
    }

    @Test
    void utilityPredicatesSupportBothJpaNamespacesWithoutDynamicRegexes() {
        String library = Library.generateUtils().toString();

        assertTrue(library.contains("hasQualifiedName(\"jakarta.persistence\", simpleName)"));
        assertTrue(library.contains("hasQualifiedName(\"javax.persistence\", simpleName)"));
        assertTrue(library.contains("creation.getConstructedType() = entity"));
        assertTrue(library.contains("field.getType().(ParameterizedType).getATypeArgument() = entity"));
        assertTrue(library.contains("fieldTargetsEntity(mappedField, relationshipField.getDeclaringType())"));
        assertFalse(library.contains("creation.fromSource()"));
        assertFalse(library.contains("regexpMatch(\"(?i).*\\\\b\" + entity.getName()"));
        assertFalse(library.contains("regexpMatch(\"(?i).*\\\\b\" + field.getName()"));
    }
}
