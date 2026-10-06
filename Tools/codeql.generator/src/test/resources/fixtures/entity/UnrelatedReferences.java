package fixtures.entity;

// Negative expectations: similar variable/string names are not type references.
public class UnrelatedReferences {
    private String visit;
    private String description = "Visit";

    public void processVisitName(String visitName) {
    }
}
