package fixtures.relationship;

import java.util.Set;
import jakarta.persistence.Entity;
import jakarta.persistence.JoinTable;
import jakarta.persistence.ManyToMany;

interface SpecialtyView {
    Set<Specialty> getSpecialties();
}

@Entity
class Vet implements SpecialtyView {
    @ManyToMany
    @JoinTable(name = "vet_specialties")
    private Set<Specialty> specialties;

    private Set<Specialty> getSpecialtiesInternal() { return specialties; }
    private Set<Specialty> getSpecialtiesInternal(String unrelated) { return Set.of(); }

    @Override
    public Set<Specialty> getSpecialties() { return getSpecialtiesInternal(); }
    void setSpecialties(Set<Specialty> value) { specialties = value; }

    int getNrOfSpecialties() { return getSpecialtiesInternal().size(); }
    int specialtySummary() { return getNrOfSpecialties(); }

    void addSpecialty(Specialty specialty) {
        getSpecialtiesInternal().add(specialty);
    }

    void addSpecialtyThroughWrapper(Specialty specialty) {
        addSpecialty(specialty);
    }

    void discardedAffectedValue() {
        getSpecialtiesInternal(); // negative: value discarded, no effect
    }

    int unrelatedOverload() {
        return getSpecialtiesInternal("audit").size(); // negative: resolved overload
    }
}

class RelationshipConsumer {
    void add(Vet vet, Specialty specialty) {
        vet.getSpecialties().add(specialty); // positive for delete, not rename
    }

    int virtualDispatch(SpecialtyView view) {
        return view.getSpecialties().size(); // positive virtual call, second level
    }

    int globalCastImpact(Vet vet) {
        Set<Specialty> local = vet.getSpecialties();
        return SpecialtySetHelper.size(local); // global CAST REFERENCE flow
    }

    int unrelatedReference(Set<Specialty> other) {
        return SpecialtySetHelper.size(other); // negative: unrelated source
    }
}

class SpecialtySetHelper {
    static int size(Set<Specialty> values) {
        return values.size(); // old Set operation reached interprocedurally
    }
}

@Entity
class Specialty {
    @ManyToMany(mappedBy = "specialties")
    private Set<Vet> vets; // positive inverse mapping for delete
}

@Entity
class UnrelatedOwner {
    @ManyToMany(mappedBy = "specialties")
    private Set<UnrelatedTarget> targets; // negative: does not target Vet
}

class UnrelatedTarget {
}
