package fixtures.feature;

import java.time.LocalDate;
import java.util.List;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.NamedQuery;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.Repository;
import org.springframework.validation.Errors;
import org.springframework.validation.Validator;

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

class VisitValidator implements Validator {
    @Override
    public boolean supports(Class<?> type) {
        return Visit.class.isAssignableFrom(type);
    }

    @Override
    public void validate(Object target, Errors errors) {
        Visit visit = (Visit) target;
        if (visit.getBirthDate() == null) {
            errors.rejectValue("birthDate", "required"); // positive local Object cast
        }
    }
}

class WrongValidator implements Validator {
    @Override
    public boolean supports(Class<?> type) {
        return Owner.class.isAssignableFrom(type);
    }

    @Override
    public void validate(Object target, Errors errors) {
        Owner owner = (Owner) target;
        owner.getBirthDate();
        errors.rejectValue("birthDate", "required"); // negative: cast to another entity
    }
}

class AmbiguousValidator implements Validator {
    @Override
    public boolean supports(Class<?> type) {
        return Visit.class.isAssignableFrom(type) || Owner.class.isAssignableFrom(type);
    }

    @Override
    public void validate(Object target, Errors errors) {
        Visit visit = (Visit) target;
        Owner owner = (Owner) target;
        visit.getBirthDate();
        owner.getBirthDate();
        errors.rejectValue("birthDate", "required"); // negative: ambiguous entity
    }
}

class Unrelated {
    LocalDate getBirthDate() { return LocalDate.now(); } // negative owner
}

class VisitQueries {
    static final String SELECT_VISIT = "SELECT v FROM Visit v ";
    static final String BIRTH_DATE =
        SELECT_VISIT + "WHERE v.birthDate = :birthDate";
    static final String UNRELATED = "SELECT o FROM Owner o";
}

interface VisitRepository extends Repository<Visit, Long> {
    List<Visit> findByBirthDate(LocalDate birthDate); // positive derived query

    List<Visit> findByOwner(String owner); // negative property

    @Query("SELECT v FROM Visit v WHERE v.birthDate = :birthDate")
    List<Visit> explicitBirthDate(LocalDate birthDate); // positive static JPQL

    @Query(VisitQueries.BIRTH_DATE)
    List<Visit> constantBirthDate(LocalDate birthDate); // positive cross-class constant

    @Query(VisitQueries.UNRELATED)
    List<Visit> unrelatedConstant(); // negative query text
}

@Entity
class Owner {
    private LocalDate birthDate; // negative: homonymous field on another entity
    LocalDate getBirthDate() { return birthDate; }
}
