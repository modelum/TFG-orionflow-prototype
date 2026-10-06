package m2t;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

import config.AnalysisMode;
import es.um.uschema.xtext.orion.orion.EntityRenameOp;
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
            new Orion2CodeQL(AnalysisMode.STRUCTURAL_SEMANTIC).m2t(operations);
        String query = generated.get("1-FeatureRenameOp.ql");

        assertNotNull(query);
        assertTrue(query.contains("entity.hasName(\"Visit\")"));
        assertTrue(query.contains("startDatetime"));
        assertFalse(query.contains("entity.hasName(\"Appointment\")"));
        assertFalse(query.contains("ATTR"));
    }
}
