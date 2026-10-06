package fixtures.feature;

import java.time.LocalDate;
import java.util.List;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.NamedQuery;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.Repository;
import org.springframework.validation.Errors;

@Entity
@NamedQuery(
    name = "Visit.byBirthDate",
    query = "SELECT v FROM Visit v WHERE v.birthDate = :birthDate"
)
class Visit {
    @Column(name = "birthDate")
    private LocalDate birthDate;

    LocalDate getBirthDate() { return birthDate; }
    void setBirthDate(LocalDate value) { this.birthDate = value; }

    // Homonymous overload: negative expectation for resolved setter matching.
    void setBirthDate(String formatted) { }
}

class VisitController {
    void validate(Visit visit, Errors errors) {
        visit.getBirthDate();                         // positive accessor call
        visit.setBirthDate(LocalDate.now());          // positive accessor call
        errors.rejectValue("birthDate", "invalid"); // positive framework property
        errors.rejectValue("owner", "invalid");     // negative property
    }
}

class Unrelated {
    LocalDate getBirthDate() { return LocalDate.now(); } // negative owner
}

interface VisitRepository extends Repository<Visit, Long> {
    List<Visit> findByBirthDate(LocalDate birthDate); // positive derived query

    List<Visit> findByOwner(String owner); // negative property

    @Query("SELECT v FROM Visit v WHERE v.birthDate = :birthDate")
    List<Visit> explicitBirthDate(LocalDate birthDate); // positive static JPQL
}

@Entity
class Owner {
    private LocalDate birthDate; // negative: homonymous field on another entity
}
