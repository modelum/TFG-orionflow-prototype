package config;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import org.junit.jupiter.api.Test;

class PersistenceFrameworkTest {

    @Test
    void parsesSupportedValuesAndDefaultsToJpa() {
        assertEquals(PersistenceFramework.JPA, PersistenceFramework.parse(null));
        assertEquals(PersistenceFramework.JPA, PersistenceFramework.parse("jpa"));
        assertEquals(PersistenceFramework.MONGO, PersistenceFramework.parse("Mongo"));
        assertEquals(PersistenceFramework.BOTH, PersistenceFramework.parse("BOTH"));
    }

    @Test
    void exposesAdapterCapabilities() {
        assertTrue(PersistenceFramework.JPA.includesJpa());
        assertFalse(PersistenceFramework.JPA.includesMongo());
        assertFalse(PersistenceFramework.MONGO.includesJpa());
        assertTrue(PersistenceFramework.MONGO.includesMongo());
        assertTrue(PersistenceFramework.BOTH.includesJpa());
        assertTrue(PersistenceFramework.BOTH.includesMongo());
    }

    @Test
    void invalidValueListsAllSupportedFrameworks() {
        IllegalArgumentException exception = assertThrows(
            IllegalArgumentException.class,
            () -> PersistenceFramework.parse("mongoose"));

        assertTrue(exception.getMessage().contains("jpa, mongo, both"));
    }
}
