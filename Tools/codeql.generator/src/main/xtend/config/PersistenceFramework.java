package config;

import java.util.Locale;

/** Persistence adapters enabled while generating CodeQL queries. */
public enum PersistenceFramework {
    JPA(true, false),
    MONGO(false, true),
    BOTH(true, true);

    private final boolean jpa;
    private final boolean mongo;

    PersistenceFramework(boolean jpa, boolean mongo) {
        this.jpa = jpa;
        this.mongo = mongo;
    }

    public boolean includesJpa() {
        return jpa;
    }

    public boolean includesMongo() {
        return mongo;
    }

    public static PersistenceFramework parse(String value) {
        if (value == null || value.trim().isEmpty()) {
            return JPA;
        }

        String normalized = value.trim().toUpperCase(Locale.ROOT);
        try {
            return PersistenceFramework.valueOf(normalized);
        } catch (IllegalArgumentException exception) {
            throw new IllegalArgumentException(
                "Unsupported framework '" + value
                    + "'. Supported values: jpa, mongo, both.",
                exception);
        }
    }
}
