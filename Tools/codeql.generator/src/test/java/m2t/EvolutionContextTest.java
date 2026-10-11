package m2t;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.List;
import org.junit.jupiter.api.Test;

class EvolutionContextTest {

    @Test
    void preservesOriginalEntityAndFeatureAcrossChainedRenames() {
        EvolutionContext context = new EvolutionContext();

        context.renameEntity("Visit", "Appointment");
        context.renameFeature("Appointment", "startDatetime", "startDate");

        EvolutionContext.FeatureOrigin origin =
            context.resolveFeature("Appointment", "startDate");
        assertEquals("Visit", origin.getEntityName());
        assertEquals("startDatetime", origin.getFeatureName());
    }

    @Test
    void preservesOriginAcrossMoveAndFurtherEntityRename() {
        EvolutionContext context = new EvolutionContext();

        context.renameFeature("Visit", "telephone", "phone");
        context.moveFeature("Visit", "phone", "Patient", "contactPhone");
        context.renameEntity("Patient", "Person");

        EvolutionContext.FeatureOrigin origin =
            context.resolveFeature("Person", "contactPhone");
        assertEquals("Visit", origin.getEntityName());
        assertEquals("telephone", origin.getFeatureName());
        assertEquals("Person", origin.getCurrentEntityName());
        assertEquals("contactPhone", origin.getCurrentFeatureName());
        assertFalse(origin.isDeleted());
    }

    @Test
    void recordsBothSidesOfEntitySplit() {
        EvolutionContext context = new EvolutionContext();

        context.splitEntity(
            "Visit",
            "Appointment", List.of("startDatetime"),
            "VisitMetadata", List.of("uuid"));

        EvolutionContext.FeatureOrigin appointment =
            context.resolveFeature("Appointment", "startDatetime");
        EvolutionContext.FeatureOrigin metadata =
            context.resolveFeature("VisitMetadata", "uuid");
        assertEquals("Visit", appointment.getEntityName());
        assertEquals("Visit", metadata.getEntityName());
    }

    @Test
    void stableIdsSurviveRepeatedRenamesAndDeletionLeavesATombstone() {
        EvolutionContext context = new EvolutionContext();

        EvolutionContext.EntityOrigin entity = context.resolveEntityOrigin("Visit");
        context.renameEntity("Visit", "Appointment");
        context.renameEntity("Appointment", "Consultation");
        assertEquals(entity.getLogicalId(),
            context.resolveEntityOrigin("Consultation").getLogicalId());
        assertEquals("Visit", context.resolveEntity("Consultation"));

        EvolutionContext.FeatureOrigin feature =
            context.resolveFeature("Consultation", "date");
        context.renameFeature("Consultation", "date", "startDate");
        context.deleteFeature("Consultation", "startDate");
        EvolutionContext.FeatureOrigin deleted =
            context.resolveFeature("Consultation", "startDate");

        assertEquals(feature.getLogicalId(), deleted.getLogicalId());
        assertEquals("Visit", deleted.getEntityName());
        assertEquals("date", deleted.getFeatureName());
        assertTrue(deleted.isDeleted());
    }

    @Test
    void relationshipRenameThenDeletePreservesIdentityAndOriginalName() {
        EvolutionContext context = new EvolutionContext();

        EvolutionContext.RelationshipOrigin original =
            context.resolveRelationshipOrigin("visit_tags");
        context.renameRelationship("visit_tags", "visit_labels");
        context.deleteRelationship("visit_labels");
        EvolutionContext.RelationshipOrigin deleted =
            context.resolveRelationshipOrigin("visit_labels");

        assertEquals(original.getLogicalId(), deleted.getLogicalId());
        assertEquals("visit_tags", deleted.getOriginalName());
        assertTrue(deleted.isDeleted());
    }
}
