package fixtures.entity;

import jakarta.persistence.Entity;
import jakarta.persistence.Table;

@Entity
@Table(name = "visits")
public class Visit {
    public Visit() {
    }

    public Visit(String reason) {
    }

    private Visit(int internalCode) {
    }
}
