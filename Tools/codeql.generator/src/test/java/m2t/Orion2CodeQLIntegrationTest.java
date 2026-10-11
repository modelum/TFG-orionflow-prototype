package m2t;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

import config.PersistenceFramework;
import es.um.uschema.xtext.orion.orion.EntityRenameOp;
import es.um.uschema.xtext.orion.orion.EvolBlock;
import es.um.uschema.xtext.orion.orion.FeatureRenameOp;
import es.um.uschema.xtext.orion.orion.FeatureRenameSpec;
import es.um.uschema.xtext.orion.orion.OrionFactory;
import es.um.uschema.xtext.orion.orion.OrionOperations;
import es.um.uschema.xtext.orion.orion.SchemaTypeRenameSpec;
import es.um.uschema.xtext.orion.orion.SingleFeatureSelector;
import java.util.Map;
import org.junit.jupiter.api.Test;

class Orion2CodeQLIntegrationTest {

    @Test
    void chainedRenameStillQueriesOriginalSourceIdentifiers() {
        OrionFactory factory = OrionFactory.eINSTANCE;
        OrionOperations operations = factory.createOrionOperations();
        operations.setName("lineage-test");

        EntityRenameOp entityRename = factory.createEntityRenameOp();
        SchemaTypeRenameSpec entitySpec = factory.createSchemaTypeRenameSpec();
        entitySpec.setRef("Visit");
        entitySpec.setName("Appointment");
        entityRename.setSpec(entitySpec);
        operations.getOperations().add(entityRename);

        FeatureRenameOp featureRename = factory.createFeatureRenameOp();
        FeatureRenameSpec featureSpec = factory.createFeatureRenameSpec();
        SingleFeatureSelector selector = factory.createSingleFeatureSelector();
        selector.setRef("Appointment");
        selector.setTarget("startDatetime");
        featureSpec.setSelector(selector);
        featureSpec.setName("startDate");
        featureRename.setSpec(featureSpec);
        operations.getOperations().add(featureRename);

        Map<String, String> generated =
            new Orion2CodeQL(PersistenceFramework.JPA).m2t(operations);
        String query = generated.get("1-FeatureRenameOp.ql");

        assertNotNull(query);
        assertTrue(query.contains("entity.hasName(\"Visit\")"));
        assertTrue(query.contains("startDatetime"));
        assertFalse(query.contains("entity.hasName(\"Appointment\")"));
        assertFalse(query.contains("ATTR"));
    }

    @Test
    void frameworkProfilesComposeOnlyTheirSelectedModules() {
        OrionOperations operations = operationsWithRename("Visit", "Consultation");

        Map<String, String> implicitJpa = new Orion2CodeQL().m2t(operations);
        Map<String, String> explicitJpa =
            new Orion2CodeQL(PersistenceFramework.JPA).m2t(operations);
        Map<String, String> mongo =
            new Orion2CodeQL(PersistenceFramework.MONGO).m2t(operations);
        Map<String, String> both =
            new Orion2CodeQL(PersistenceFramework.BOTH).m2t(operations);

        assertEquals(implicitJpa, explicitJpa);
        assertTrue(implicitJpa.containsKey("orion_java.qll"));
        assertTrue(implicitJpa.containsKey("orion_jpa.qll"));
        assertFalse(implicitJpa.containsKey("orion_mongo.qll"));
        assertTrue(mongo.containsKey("orion_mongo.qll"));
        assertFalse(mongo.containsKey("orion_jpa.qll"));
        assertTrue(both.containsKey("orion_jpa.qll"));
        assertTrue(both.containsKey("orion_mongo.qll"));
        assertEquals(1, both.keySet().stream()
            .filter("orion_java.qll"::equals).count());
    }

    @Test
    void transformerResetsLineageAndOrdinalBetweenInvocations() {
        Orion2CodeQL transformer = new Orion2CodeQL(PersistenceFramework.JPA);
        transformer.m2t(operationsWithRename("Visit", "Appointment"));

        Map<String, String> second =
            transformer.m2t(operationsWithRename("Patient", "Person"));
        String query = second.get("0-EntityRenameOp.ql");

        assertNotNull(query);
        assertTrue(query.contains("oldEntity.hasName(\"Patient\")"));
        assertFalse(query.contains("oldEntity.hasName(\"Visit\")"));
    }

    @Test
    void operationsInsideEvolutionBlocksAreGenerated() {
        OrionFactory factory = OrionFactory.eINSTANCE;
        OrionOperations operations = factory.createOrionOperations();
        operations.setName("block-test");
        EvolBlock block = factory.createEvolBlock();
        block.setName(1);
        block.getOperations().add(rename(factory, "Visit", "Consultation"));
        operations.getEvolBlocks().add(block);

        Map<String, String> generated = new Orion2CodeQL().m2t(operations);

        assertTrue(generated.containsKey("0-EntityRenameOp.ql"));
    }

    private OrionOperations operationsWithRename(String oldName, String newName) {
        OrionFactory factory = OrionFactory.eINSTANCE;
        OrionOperations operations = factory.createOrionOperations();
        operations.setName("framework-test");
        operations.getOperations().add(rename(factory, oldName, newName));
        return operations;
    }

    private EntityRenameOp rename(
        OrionFactory factory, String oldName, String newName
    ) {
        EntityRenameOp operation = factory.createEntityRenameOp();
        SchemaTypeRenameSpec spec = factory.createSchemaTypeRenameSpec();
        spec.setRef(oldName);
        spec.setName(newName);
        operation.setSpec(spec);
        return operation;
    }
}
