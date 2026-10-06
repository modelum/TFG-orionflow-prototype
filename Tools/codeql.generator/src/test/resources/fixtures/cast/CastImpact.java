package fixtures.cast;

import java.time.LocalDate;
import jakarta.persistence.Entity;

@Entity
class Visit {
    private LocalDate date;
    LocalDate getDate() { return date; }
    void setDate(LocalDate value) { date = value; }
}

class CastConsumer {
    boolean impacted(Visit visit, LocalDate other) {
        LocalDate local = visit.getDate();
        return local.plusDays(1).isAfter(other); // local DataFlow sink
    }

    String unaffected(String value) {
        return value.trim(); // negative, unrelated source
    }
}
