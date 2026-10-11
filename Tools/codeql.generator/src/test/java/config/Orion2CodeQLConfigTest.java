package config;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.nio.file.Path;
import org.junit.jupiter.api.Test;

class Orion2CodeQLConfigTest {

    @Test
    void defaultAndExplicitJpaAreEquivalent() {
        Orion2CodeQLConfig implicit = new Orion2CodeQLConfig(
            new String[] { "-i", "change.orion", "-a", "ALL" });
        Orion2CodeQLConfig explicit = new Orion2CodeQLConfig(
            new String[] { "-i", "change.orion", "--framework", "jpa", "-a", "ALL" });

        assertEquals(PersistenceFramework.JPA, implicit.getFramework());
        assertEquals(explicit.getFramework(), implicit.getFramework());
        assertEquals(Path.of("."), implicit.getOutputPath());
    }

    @Test
    void parsesMongoBothInputAndOutput() {
        Orion2CodeQLConfig mongo = new Orion2CodeQLConfig(
            new String[] { "-i", "change.orion", "-o", "out", "-f", "mongo" });
        Orion2CodeQLConfig both = new Orion2CodeQLConfig(
            new String[] { "-i", "change.orion", "--framework", "both" });

        assertEquals(Path.of("change.orion"), mongo.getInputScript());
        assertEquals(PersistenceFramework.MONGO, mongo.getFramework());
        assertEquals(Path.of("out"), mongo.getOutputPath());
        assertEquals(PersistenceFramework.BOTH, both.getFramework());
    }

    @Test
    void deprecatedAllAnalysisAliasIsCaseInsensitiveAndHasNoEffect() {
        Orion2CodeQLConfig shortAlias = new Orion2CodeQLConfig(
            new String[] { "-i", "change.orion", "-a", "all" });
        Orion2CodeQLConfig longAlias = new Orion2CodeQLConfig(
            new String[] { "-i", "change.orion", "--analysis", "ALL", "-f", "mongo" });

        assertEquals(PersistenceFramework.JPA, shortAlias.getFramework());
        assertEquals(PersistenceFramework.MONGO, longAlias.getFramework());
    }

    @Test
    void helpDoesNotRequireInput() {
        Orion2CodeQLConfig help = new Orion2CodeQLConfig(new String[] { "--help" });
        assertTrue(help.isHelpRequested());
    }

    @Test
    void reportsMissingInputAndInvalidFramework() {
        assertTrue(assertThrows(
            IllegalArgumentException.class,
            () -> new Orion2CodeQLConfig(new String[0]))
            .getMessage().contains("--input"));
        assertTrue(assertThrows(
            IllegalArgumentException.class,
            () -> new Orion2CodeQLConfig(
                new String[] { "-i", "change.orion", "--framework", "other" }))
            .getMessage().contains("jpa, mongo, both"));
    }

    @Test
    void rejectsRemovedModesAndAnalysisValuesOtherThanAll() {
        IllegalArgumentException structural = assertThrows(
            IllegalArgumentException.class,
            () -> new Orion2CodeQLConfig(
                new String[] { "-i", "change.orion", "-a", "STRUCTURAL" }));
        IllegalArgumentException dataFlow = assertThrows(
            IllegalArgumentException.class,
            () -> new Orion2CodeQLConfig(
                new String[] { "-i", "change.orion", "--analysis", "DATAFLOW" }));
        IllegalArgumentException shortMode = assertThrows(
            IllegalArgumentException.class,
            () -> new Orion2CodeQLConfig(
                new String[] { "-i", "change.orion", "-m", "STRUCTURAL" }));
        IllegalArgumentException longMode = assertThrows(
            IllegalArgumentException.class,
            () -> new Orion2CodeQLConfig(
                new String[] { "-i", "change.orion", "--mode", "DATAFLOW" }));

        assertTrue(structural.getMessage().contains("Only the deprecated compatibility value ALL"));
        assertTrue(dataFlow.getMessage().contains("Only the deprecated compatibility value ALL"));
        assertTrue(shortMode.getMessage().contains("Unrecognized option: -m"));
        assertTrue(longMode.getMessage().contains("Unrecognized option: --mode"));
    }
}
