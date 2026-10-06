package fixtures.legacy;

import javax.persistence.Entity;
import javax.persistence.JoinColumn;
import javax.persistence.ManyToOne;

@Entity
class LegacyVisit {
}

@Entity
class LegacyObservation {
    @ManyToOne
    @JoinColumn(name = "visit_id")
    private LegacyVisit visit;
}
