package fixtures.mongo;

import java.time.LocalDate;
import java.util.List;
import java.util.Set;
import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.MongoTemplate;
import org.springframework.data.mongodb.core.aggregation.Aggregation;
import org.springframework.data.mongodb.core.index.CompoundIndex;
import org.springframework.data.mongodb.core.index.Indexed;
import org.springframework.data.mongodb.core.mapping.DBRef;
import org.springframework.data.mongodb.core.mapping.Document;
import org.springframework.data.mongodb.core.mapping.DocumentReference;
import org.springframework.data.mongodb.core.mapping.Field;
import org.springframework.data.mongodb.core.query.Criteria;
import org.springframework.data.mongodb.core.query.Query;
import org.springframework.data.mongodb.core.query.Update;
import org.springframework.data.mongodb.repository.MongoRepository;

@Document(collection = "patients")
@CompoundIndex(def = "{'birth_date': 1, 'status': 1}")
class PatientDocument {
    @Id
    private String id;

    @Field("birth_date")
    @Indexed
    private LocalDate birthDate;

    private LocalDate date;
    private String status;

    @DBRef
    private ProviderDocument primaryProvider;

    @DocumentReference
    private Set<ProviderDocument> providers;

    LocalDate getBirthDate() { return birthDate; }
    LocalDate getDate() { return date; }
    String getStatus() { return status; }
    ProviderDocument getPrimaryProvider() { return primaryProvider; }
    Set<ProviderDocument> getProviders() { return providers; }
}

@Document("providers")
class ProviderDocument {
    @Id private String id;
    private String name;
    String getName() { return name; }
}

interface PatientRepository extends MongoRepository<PatientDocument, String> {
    List<PatientDocument> findByBirthDate(LocalDate birthDate);

    @org.springframework.data.mongodb.repository.Query("{'birth_date': ?0}")
    List<PatientDocument> explicitBirthDate(LocalDate birthDate);
}

class MongoImpact {
    private final MongoTemplate template;

    MongoImpact(MongoTemplate template) {
        this.template = template;
    }

    void frameworkApis() {
        Criteria.where("birth_date").is(LocalDate.now());
        Update.update("birth_date", LocalDate.now());
        Aggregation.project("birth_date");
        template.findAll(PatientDocument.class, "patients");
        template.findDistinct(new Query(), "birth_date", PatientDocument.class, LocalDate.class);
    }

    void selectedDataFlow(PatientDocument patient, ProviderDocument provider) {
        LocalDate deletedValue = patient.getBirthDate();
        deletedValue.toString(); // DELETE FEATURE local propagation

        LocalDate castValue = patient.getDate();
        castValue.plusDays(1); // CAST ATTRIBUTE local propagation

        ProviderDocument reference = patient.getPrimaryProvider();
        reference.getName(); // CAST REFERENCE local propagation

        String movedValue = patient.getStatus();
        movedValue.trim(); // MOVE FEATURE local propagation

        Set<ProviderDocument> relationship = patient.getProviders();
        relationship.add(provider); // DELETE RELATIONSHIP local propagation
    }

    void negatives(String unrelated, Set<String> values) {
        unrelated.trim();
        values.add("providers");
        arbitrary("birth_date");
    }

    private void arbitrary(String value) {
    }
}
