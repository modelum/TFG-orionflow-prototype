package fixtures.relationship;

import java.util.Set;
import jakarta.persistence.Entity;
import jakarta.persistence.JoinTable;
import jakarta.persistence.ManyToMany;

@Entity
class Vet {
    @ManyToMany
    @JoinTable(name = "vet_specialties")
    private Set<Specialty> specialties;

    Set<Specialty> getSpecialties() { return specialties; }
    void setSpecialties(Set<Specialty> value) { specialties = value; }
}

class RelationshipConsumer {
    void add(Vet vet, Specialty specialty) {
        vet.getSpecialties().add(specialty); // positive for delete, not rename
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
