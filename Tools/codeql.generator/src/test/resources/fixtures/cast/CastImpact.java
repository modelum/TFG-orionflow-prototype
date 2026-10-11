package fixtures.cast;

import java.time.LocalDate;
import jakarta.persistence.Entity;

@Entity
class Visit {
    private LocalDate date;
    LocalDate getDate() { return date; }
    void setDate(LocalDate value) { date = value; }

    int dateDay() { return getDate().getDayOfMonth(); }
    int dateSummary() { return dateDay(); }

    void discardedDate() {
        getDate(); // negative Call Graph edge: discarded, side-effect free value
    }
}

class CastConsumer {
    boolean impacted(Visit visit, LocalDate other) {
        LocalDate local = visit.getDate();
        return local.plusDays(1).isAfter(other); // local DataFlow sink
    }

    String unaffected(String value) {
        return value.trim(); // negative, unrelated source
    }

    boolean globalArgument(Visit visit, LocalDate other) {
        LocalDate local = visit.getDate();
        return DateRelay.forward(local).isAfter(other);
    }

    boolean globalReturn(Visit visit, LocalDate other) {
        return extract(visit).plusDays(1).isAfter(other);
    }

    boolean multipleSameTypeParameters(Visit visit, LocalDate unrelated) {
        LocalDate affected = visit.getDate();
        return DateHelper.combine(affected, unrelated).isAfter(unrelated);
    }

    int compatibleWithReplacement(Visit visit) {
        return DateHelper.compatible(visit.getDate()); // String remains Object-compatible
    }

    LocalDate unrelatedSource(LocalDate unrelated) {
        return DateRelay.forward(unrelated); // negative: no source from Visit.date
    }

    private static LocalDate extract(Visit visit) {
        return visit.getDate();
    }
}

class DateRelay {
    static LocalDate forward(LocalDate value) {
        return DateHelper.adjust(value);
    }
}

class DateHelper {
    static LocalDate adjust(LocalDate value) {
        return value.plusDays(1); // global old-type sink
    }

    static LocalDate combine(LocalDate affected, LocalDate unrelated) {
        return affected.plusDays(unrelated.getDayOfMonth());
    }

    static int compatible(Object value) {
        return value.hashCode(); // compatible with replacement String
    }
}
