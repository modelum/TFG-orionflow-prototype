package m2t;

import static org.junit.jupiter.api.Assertions.assertEquals;

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
}
