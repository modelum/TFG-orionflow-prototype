package codeql.template;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import codeql.template.attribute.AttributeQuery;
import codeql.template.feature.FeatureQuery;
import codeql.template.library.DataFlowLibrary;
import codeql.template.library.CallGraphImpactLibrary;
import codeql.template.library.JpaLibrary;
import codeql.template.library.Library;
import codeql.template.library.MongoLibrary;
import codeql.template.library.SpringCommonLibrary;
import codeql.template.relationship.RelationshipQuery;
import config.PersistenceFramework;
import org.junit.jupiter.api.Test;

class ModuleGenerationTest {

    @Test
    void frameworkCompositionImportsOnlySelectedAdapters() {
        String jpa = Library.generateUtils(PersistenceFramework.JPA).toString();
        String mongo = Library.generateUtils(PersistenceFramework.MONGO).toString();
        String both = Library.generateUtils(PersistenceFramework.BOTH).toString();

        assertTrue(jpa.contains("import orion_jpa"));
        assertFalse(jpa.contains("import orion_mongo"));
        assertTrue(mongo.contains("import orion_mongo"));
        assertFalse(mongo.contains("import orion_jpa"));
        assertTrue(both.contains("import orion_jpa"));
        assertTrue(both.contains("import orion_mongo"));
        assertTrue(both.contains("import orion_java"));
    }

    @Test
    void springRepositoryDomainUsesSemanticParameterizedSupertypes() {
        String spring = SpringCommonLibrary.generate().toString();

        assertTrue(spring.contains("ParameterizedType repositoryType"));
        assertTrue(spring.contains("repositoryType = repository.getASupertype*()"));
        assertTrue(spring.contains("repositoryType.getTypeArgument(0) = entity"));
        assertTrue(spring.contains("repositoryType.getGenericType().getASupertype*()"));
        assertFalse(spring.contains("repository.contains(repositoryType)"));
        assertFalse(spring.contains("repositoryType.getTypeArgument(0).getType()"));
    }

    @Test
    void mongoAdapterSeparatesJavaStoredFieldAndCollectionNames() {
        String mongo = MongoLibrary.generate().toString();

        assertTrue(mongo.contains("predicate mongoCollectionHasName"));
        assertTrue(mongo.contains("annotation.getStringValue(\"collection\")"));
        assertTrue(mongo.contains("predicate mongoFieldHasName"));
        assertTrue(mongo.contains("predicate isMongoPersistentEntity"));
        assertTrue(mongo.contains("mongoDirectlyEmbeds+(root, entity)"));
        assertTrue(mongo.contains("not field.isStatic()"));
        assertTrue(mongo.contains("not field.isTransient()"));
        assertTrue(mongo.contains("isMongoCollectionNameCall"));
        assertTrue(mongo.contains("MongoOperations"));
        assertTrue(mongo.contains("CompoundIndex"));
        assertTrue(mongo.contains("queryValue.(CompileTimeConstantExpr).getStringValue()"));
        assertTrue(mongo.contains("document.splitAt(\"{\").splitAt(\"[\").splitAt(\",\")"));
        assertEquals(2, occurrences(mongo, "bindingset[document]"));
        assertEquals(1, occurrences(mongo, "bindingset[path]"));
        assertTrue(mongo.contains("mongoDocumentReferencesField(annotation.getStringValue(\"def\"), field)"));
        assertTrue(mongo.contains("name = annotation.getStringValue(\"value\")"));
        assertTrue(mongo.contains("^(update|set|setOnInsert|unset|rename|inc|multiply|min|max|currentDate|currentTimestamp|push|pushAll|addToSet|pop|pull|pullAll|bitwise)$"));
        assertTrue(mongo.contains("^(where|and)$"));
        assertTrue(mongo.contains("isSpringDataSortMethod"));
        assertTrue(mongo.contains("isSpringDataSortOrderMethod"));
        assertTrue(mongo.contains("mongoCallHasEntityContext(call, field)"));
        assertFalse(mongo.contains("queryValue.toString().regexpCapture"));
    }

    @Test
    void springValidationSupportsTypedAndLocalObjectCastBindings() {
        String spring = SpringCommonLibrary.generate().toString();

        assertTrue(spring.contains("predicate springValidationCallTargetsEntity"));
        assertTrue(spring.contains("target.getType().(RefType).hasQualifiedName(\"java.lang\", \"Object\")"));
        assertTrue(spring.contains("cast.getExpr() = target.getAnAccess()"));
        assertTrue(spring.contains("variable.getInitializer() = cast"));
        assertTrue(spring.contains("springValidatorSupportsEntity"));
        assertTrue(spring.contains("otherEntity != entity"));
    }

    @Test
    void joinTableTraversalUsesOfficialAnnotationApis() {
        String jpa = JpaLibrary.generate().toString();

        assertTrue(jpa.contains("getAnArrayValue(\"joinColumns\").(Annotation)"));
        assertTrue(jpa.contains("getAnArrayValue(\"inverseJoinColumns\").(Annotation)"));
        assertTrue(jpa.contains("getStringValue(\"referencedColumnName\")"));
        assertTrue(jpa.contains("getEnumConstantValue(\"strategy\").hasName(\"JOINED\")"));
    }

    @Test
    void targetedDataFlowExistsForExactlyTheSelectedTemplates() {
        String deleteFeature = FeatureQuery.generateFeatureDeleteOp("Visit", "date").toString();
        String castAttribute = AttributeQuery.generateAttributeCastOp("Visit", "date", "String").toString();
        String castReference = AttributeQuery.generateReferenceCastOp("Visit", "owner", "String").toString();
        String moveFeature = FeatureQuery.generateFeatureMoveOp(
            "Visit", "date", "Archive", "archivedDate").toString();
        String deleteRelationship = RelationshipQuery.generateRelationshipDeleteOp("visit_tags").toString();
        String renameFeature = FeatureQuery.generateFeatureRenameOp(
            "Visit", "date", "startDate").toString();

        assertTrue(deleteFeature.contains("fieldValueFlowsToDependentCall"));
        assertTrue(castAttribute.contains("fieldValueFlowsToOldTypeConsumer"));
        assertTrue(castReference.contains("fieldValueFlowsToOldTypeConsumer"));
        assertTrue(moveFeature.contains("fieldValueFlowsToDependentCall"));
        assertTrue(deleteRelationship.contains("relationshipValueFlowsToMutation"));
        assertFalse(renameFeature.contains("import orion_dataflow"));
        assertTrue(castAttribute.contains("module OrionCastGlobalConfig"));
        assertTrue(castAttribute.contains("OrionCastGlobalFlow::flow"));
        assertTrue(castReference.contains("module OrionCastGlobalConfig"));
        assertFalse(deleteFeature.contains("OrionCastGlobalFlow::flow"));
        assertFalse(moveFeature.contains("OrionCastGlobalFlow::flow"));
        assertFalse(deleteRelationship.contains("OrionCastGlobalFlow::flow"));
    }

    @Test
    void callGraphIsBoundedAndImportedOnlyBySelectedOperations() {
        String library = CallGraphImpactLibrary.generate().toString();
        String deleteFeature = FeatureQuery.generateFeatureDeleteOp(
            "Visit", "date").toString();
        String moveFeature = FeatureQuery.generateFeatureMoveOp(
            "Visit", "date", "Archive", "archivedDate").toString();
        String deleteRelationship = RelationshipQuery.generateRelationshipDeleteOp(
            "visit_tags").toString();
        String renameFeature = FeatureQuery.generateFeatureRenameOp(
            "Visit", "date", "startDate").toString();

        assertTrue(library.contains("viableCallable(call)"));
        assertTrue(library.contains("not call instanceof ValueDiscardingExpr"));
        assertTrue(library.contains("depth = \"1\""));
        assertTrue(library.contains("depth = \"2\""));
        assertFalse(library.contains("fieldCallGraphImpact+"));
        assertTrue(deleteFeature.contains("import orion_callgraph"));
        assertTrue(moveFeature.contains("import orion_callgraph"));
        assertTrue(deleteRelationship.contains("import orion_callgraph"));
        assertFalse(renameFeature.contains("import orion_callgraph"));
    }

    @Test
    void globalCastConfigurationIsSpecificToGeneratedSco() {
        String global = DataFlowLibrary.generateGlobalCastFlow(
            "Visit", "date", "String").toString();

        assertTrue(global.contains("entity.hasName(\"Visit\")"));
        assertTrue(global.contains("field.hasName(\"date\")"));
        assertTrue(global.contains("replacementType.getName() = \"String\""));
        assertTrue(global.contains("DataFlow::Global<OrionCastGlobalConfig>"));
        assertTrue(global.contains("not DataFlow::localFlow"));
    }

    @Test
    void relationshipMutationNormalizesParameterizedContainerTypes() {
        String dataFlow = DataFlowLibrary.generate().toString();

        assertTrue(dataFlow.contains(
            "mutation.getMethod().getDeclaringType().getSourceDeclaration().getASourceSupertype*()"));
        assertTrue(dataFlow.contains("hasQualifiedName(\"java.util\", \"Collection\")"));
        assertTrue(dataFlow.contains("hasQualifiedName(\"java.util\", \"Map\")"));
        assertFalse(dataFlow.contains(
            "mutation.getQualifier().getType().(RefType).getASupertype*()"));
    }

    @Test
    void generatedNameRegexesContainLiteralsNotAstConcatenation() {
        String entity = Library.generateUsesOldEntity(
            "Visit", PersistenceFramework.BOTH).toString();
        String field = Library.generateUsesField(
            "Visit", "birthDate", PersistenceFramework.BOTH).toString();

        assertTrue(entity.contains("Visit"));
        assertTrue(field.contains("birthDate"));
        assertFalse(entity.contains("+ entity.getName()"));
        assertFalse(field.contains("+ field.getName()"));
        assertTrue(entity.contains("compileTimeStringValue(queryValue, queryText)"));
        assertTrue(field.contains("compileTimeStringValue(queryValue, queryText)"));
        assertFalse(field.contains("queryValue.toString().regexp"));
    }

    private int occurrences(String text, String token) {
        return (text.length() - text.replace(token, "").length()) / token.length();
    }
}
