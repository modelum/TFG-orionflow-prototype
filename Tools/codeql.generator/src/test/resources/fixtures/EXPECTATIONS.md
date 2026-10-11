# Fixture expectations

This directory is the functional oracle for the OrionFlow V2 CodeQL smoke
database. Line numbers below refer to the checked-in Java sources. Assertions
should use a stable message fragment rather than the complete message so that a
wording-only improvement does not invalidate the semantic test.

## Orion operation to rule mapping

The operation ordinal is stable and is part of the generated CodeQL rule id.

| Ordinal | Orion operation | Rule id | Fixture adapter |
| ---: | --- | --- | --- |
| 0 | `RENAME ENTITY Visit TO Consultation` | `java/orion/entity-renamed/0` | JPA |
| 1 | `RENAME Consultation::birthDate TO dateOfBirth` | `java/orion/feature-renamed/1` | JPA |
| 2 | `DELETE Consultation::dateOfBirth` | `java/orion/feature-deleted/2/0` | JPA |
| 3 | `CAST ATTR Consultation::date TO String` | `java/orion/attribute-casted/3/0` | JPA |
| 4 | `CAST REF Vet::specialties TO String` | `java/orion/reference-casted/4/0` | JPA |
| 5 | `MOVE Consultation::date TO VisitArchive::archivedDate` | `java/orion/feature-moved/5` | JPA |
| 6 | `DELETE ENTITY Consultation` | `java/orion/entity-deleted/6` | JPA |
| 7 | `RENAME RELATIONSHIP vet_specialties TO vet_expertise` | `java/orion/relationship-renamed/7` | JPA |
| 8 | `DELETE RELATIONSHIP vet_expertise` | `java/orion/relationship-deleted/8` | JPA |
| 9 | `RENAME ENTITY PatientDocument TO PatientRecord` | `java/orion/entity-renamed/9` | MongoDB |
| 10 | `RENAME PatientRecord::birthDate TO dateOfBirth` | `java/orion/feature-renamed/10` | MongoDB |
| 11 | `DELETE PatientRecord::dateOfBirth` | `java/orion/feature-deleted/11/0` | MongoDB |
| 12 | `CAST REF PatientRecord::primaryProvider TO String` | `java/orion/reference-casted/12/0` | MongoDB |
| 13 | `MOVE PatientRecord::status TO PatientArchive::status` | `java/orion/feature-moved/13` | MongoDB |
| 14 | `DELETE RELATIONSHIP providers` | `java/orion/relationship-deleted/14` | MongoDB |
| 15 | `RENAME ENTITY LegacyVisit TO ArchivedLegacyVisit` | `java/orion/entity-renamed/15` | JPA (`javax.persistence`) |

The chained names in operations 1-6 and 10-11 must resolve to their original
Java declarations (`Visit` and `PatientDocument`, respectively). Results that
look for a non-existent Java class named `Consultation` or `PatientRecord`
indicate an `EvolutionContext` regression.

Operation 8 likewise receives the renamed logical relationship
`vet_expertise`, but must resolve it back to the existing `@JoinTable` name
`vet_specialties`. Searching source code for `vet_expertise` would miss the
intended deletion impact and indicates a relationship-chain regression.

## SARIF comparison contract

Normalize every result to this identity before comparing profiles:

```text
(ruleId, normalized-uri, startLine, startColumn, endLine, endColumn, message.text)
```

For `normalized-uri`, URL-decode the SARIF artifact URI, replace backslashes
with `/`, and compare the path relative to the fixture source root.

The message is part of the identity. Two different impact categories at one
source location are valid; two identical identities are duplicates.

The final verification must enforce all of these invariants:

1. `default` and explicit `jpa` have identical normalized result sets.
2. `jpa` contains no result under `mongo/` and no result for rules 9-14.
3. `mongo` contains no result under `entity/`, `feature/`, `cast/`,
   `relationship/`, or `legacy/`, and no result for rules 0-8 or 15.
4. `both` is exactly `set(jpa) union set(mongo)`; it has neither missing nor
   adapter-crossed results.
5. Each profile's result array has the same size as its set of normalized
   identities. Result ordering is irrelevant.

Raw result counts alone are not a sufficient assertion because they can hide a
lost positive and a compensating false positive.

## Required JPA positives

The following is a minimum location/message checklist. Extra results are valid
only when they identify another real use of the same resolved declaration.

| Rule | Required location(s) | Required message fragment / semantic |
| --- | --- | --- |
| 0 | `entity/Visit.java:5-6` | persistence metadata; entity renamed |
| 0 | `entity/EntityReferences.java:7-12` | resolved inheritance, field, generic, return, parameter and local type references; construction at line 12 |
| 0 | `feature/FeatureImpact.java:46-47` | query uses old entity name `Visit` |
| 0 | `feature/FeatureImpact.java:13-16` | standalone named query uses old entity name `Visit` |
| 1 | `feature/FeatureImpact.java:18-22` | metadata, field and exact getter/setter for `birthDate` |
| 1 | `feature/FeatureImpact.java:30-32` | resolved accessor calls and Spring property `birthDate` |
| 1 | `feature/FeatureImpact.java:42` | derived query method `findByBirthDate` |
| 1 | `feature/FeatureImpact.java:46` | static `@Query` uses feature `birthDate` |
| 1 | `feature/FeatureImpact.java:13-16` | standalone `@NamedQuery` uses feature `birthDate` |
| 2 | the same `birthDate` locations as rule 1 | attribute will be deleted / dependent use |
| 3 | `cast/CastImpact.java:8-10` | `date` changes from `LocalDate` to `String`; getter/setter affected |
| 3 | `cast/CastImpact.java:15-16` | old-type local declaration/accessor and `[Potential]` local flow to `plusDays` |
| 4 | `relationship/RelationshipImpact.java:10-15` | `specialties` reference, accessors and JPA relationship metadata |
| 4 | `relationship/RelationshipImpact.java:20` | resolved accessor/old-type collection use |
| 5 | `cast/CastImpact.java:8-10` | field/accessors must move through `VisitArchive.archivedDate` |
| 5 | `cast/CastImpact.java:15-16` | accessor call and `[Potential]` local flow to `plusDays` |
| 6 | `entity/Visit.java:5-6` | persistence metadata; entity deleted |
| 6 | `entity/EntityReferences.java:7-12` | resolved type references and invalid construction |
| 6 | `feature/FeatureImpact.java:46-47` | query uses deleted entity `Visit` |
| 7 | `relationship/RelationshipImpact.java:11` | join table changes from `vet_specialties` to `vet_expertise` |
| 8 | `relationship/RelationshipImpact.java:12,14-15,20,26` | relationship field, accessors/call and inverse `mappedBy` mapping |
| 15 | `legacy/LegacyJpa.java:7-8,14-15` | legacy `javax.persistence.Entity` metadata, entity declaration and resolved relationship type |

All three JPA entities whose resolved simple name is `Visit`
(`entity/Visit.java:6`, `feature/FeatureImpact.java:17`, and
`cast/CastImpact.java:7`) are legitimate positives for rules 0 and 6. The
homonymous class in `entity/other/Visit.java` is not persistent and is not.

## Required MongoDB positives

| Rule | Required location(s) | Required message fragment / semantic |
| --- | --- | --- |
| 9 | `mongo/MongoImpact.java:20,22` | `@Document` metadata and entity renamed to `PatientRecord` |
| 9 | `mongo/MongoImpact.java:53-57,71-72,75` | resolved `PatientDocument` type references; line 71 also references stored collection `patients` |
| 10 | `mongo/MongoImpact.java:21,26-28` | compound index, stored field metadata and `birthDate` declaration renamed |
| 10 | `mongo/MongoImpact.java:39,54,56` | getter, derived repository query and Mongo `@Query` |
| 10 | `mongo/MongoImpact.java:68-70,72,76` | `Criteria`, `Update`, `Aggregation`, `findDistinct`, and resolved accessor call |
| 11 | all rule-10 `birthDate` locations | attribute will be deleted / dependent use |
| 11 | `mongo/MongoImpact.java:77` | `[Potential]` deleted value flows locally to `toString` |
| 12 | `mongo/MongoImpact.java:33-34,42` | `@DBRef`, `primaryProvider` and getter use old reference type |
| 12 | `mongo/MongoImpact.java:82-83` | old-type local/accessor and `[Potential]` flow to `getName` |
| 13 | `mongo/MongoImpact.java:31,41,85-86` | `status`, getter/call and `[Potential]` moved value flow to `trim` |
| 14 | `mongo/MongoImpact.java:37,43,88-89` | `providers`, getter/call and `[Potential]` collection flow to `add` |

For rule 10/11, both Java name `birthDate` and stored name `birth_date` must map
to the same field. The typed API checks at lines 68-72 are important provenance
tests: an arbitrary call with the same string must not be accepted.

## Required negatives

These locations must not occur for the corresponding rules:

| Location | Rules excluded | Reason |
| --- | --- | --- |
| `entity/UnrelatedReferences.java:5-9` | 0, 6 | strings and variable names are not resolved entity types |
| `entity/other/Visit.java:4` | 0, 6 | homonymous non-persistent class |
| `feature/FeatureImpact.java:25` | 1, 2 | homonymous setter has the wrong parameter type |
| `feature/FeatureImpact.java:33` | 1, 2 | Spring property is `owner`, not `birthDate` |
| `feature/FeatureImpact.java:38` | 1, 2 | homonymous getter belongs to another class |
| `feature/FeatureImpact.java:44` | 1, 2 | repository method derives `owner`, not `birthDate` |
| `feature/FeatureImpact.java:52` | 1, 2 | homonymous field belongs to entity `Owner` |
| `cast/CastImpact.java:19-20` | 3, 5 | `trim` has no source from `Visit.date` |
| `relationship/RelationshipImpact.java:31-36` | 8 | inverse-looking mapping does not target `Vet` |
| `mongo/MongoImpact.java:92-99` | 10-14 | unrelated values and arbitrary string-taking API have no affected provenance |

## Explicit coverage limits

- The selected DataFlow layer is intentionally local: it validates the aliases
  at `CastImpact.java:15-16` and `MongoImpact.java:76-89`, not interprocedural
  propagation.
- `legacy/LegacyJpa.java` is targeted by operation 15 so the JPA and `both`
  profiles must prove real `javax.persistence` detection; Mongo must not report
  that rule.
- `feature/FeatureImpact.java:13-16` contains a standalone `@NamedQuery`. Rules
  0, 1, 2, and 6 must report its declaration directly, without requiring a
  linked Spring Data `@Query(name=...)` annotation.

The nested `pom.xml` makes these sources independently compilable and suitable
for a CodeQL test database without adding application-framework dependencies to
the generator itself.
