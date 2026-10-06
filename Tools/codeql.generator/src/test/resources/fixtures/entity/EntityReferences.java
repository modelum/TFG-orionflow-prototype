package fixtures.entity;

import java.util.List;
import java.util.Optional;

// Every Visit type below is a positive structural expectation.
public class EntityReferences extends Visit {
    private Visit directField;
    private List<Visit> genericField;

    public Optional<Visit> findVisit(Visit parameter) {
        Visit local = new Visit();
        return Optional.of(local);
    }
}
