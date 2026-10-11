package codeql.template.library;

import config.PersistenceFramework;
import org.eclipse.xtend2.lib.StringConcatenation;

/**
 * Facade that composes the structural core with the selected adapters.
 */
@SuppressWarnings("all")
public class Library {
  public static CharSequence generateUsesOldEntity(final String entityName) {
    return Library.generateUsesOldEntity(entityName, PersistenceFramework.JPA);
  }

  public static CharSequence generateUsesOldEntity(final String entityName, final PersistenceFramework framework) {
    StringConcatenation _builder = new StringConcatenation();
    _builder.append("/** Check if entity ");
    _builder.append(entityName);
    _builder.append(" is used in a selected framework query. */");
    _builder.newLineIfNotEmpty();
    _builder.append("predicate usesOldEntity(Expr queryValue) {");
    _builder.newLine();
    _builder.append("  ");
    _builder.append("exists(string queryText |");
    _builder.newLine();
    _builder.append("    ");
    _builder.append("compileTimeStringValue(queryValue, queryText) and");
    _builder.newLine();
    _builder.append("    ");
    _builder.append("(");
    _builder.newLine();
    {
      boolean _includesJpa = framework.includesJpa();
      if (_includesJpa) {
        _builder.append("  ");
        _builder.append("queryText.regexpMatch(");
        _builder.newLine();
        _builder.append("  ");
        _builder.append("  ");
        _builder.append("\"(?i).*\\\\b(FROM|UPDATE|DELETE\\\\s+FROM)\\\\s+");
        _builder.append(entityName, "    ");
        _builder.append("\\\\b.*\"");
        _builder.newLineIfNotEmpty();
        _builder.append("  ");
        _builder.append(")");
        _builder.newLine();
        _builder.append("  ");
        _builder.append("or");
        _builder.newLine();
        _builder.append("  ");
        _builder.append("queryText.regexpMatch(");
        _builder.newLine();
        _builder.append("  ");
        _builder.append("  ");
        _builder.append("\"(?i).*\\\\bJOIN\\\\s+(?:FETCH\\\\s+)?");
        _builder.append(entityName, "    ");
        _builder.append("\\\\b.*\"");
        _builder.newLineIfNotEmpty();
        _builder.append("  ");
        _builder.append(")");
        _builder.newLine();
        _builder.append("  ");
        {
          boolean _includesMongo = framework.includesMongo();
          if (_includesMongo) {
            _builder.append("or");
          }
        }
        _builder.newLineIfNotEmpty();
      }
    }
    {
      boolean _includesMongo_1 = framework.includesMongo();
      if (_includesMongo_1) {
        _builder.append("  ");
        _builder.append("// Mongo aggregation/look-up collection references. The entity name is a");
        _builder.newLine();
        _builder.append("  ");
        _builder.append("// generated literal, never an AST-derived regex fragment.");
        _builder.newLine();
        _builder.append("  ");
        _builder.append("queryText.regexpMatch(");
        _builder.newLine();
        _builder.append("  ");
        _builder.append("  ");
        _builder.append("\"(?i).*(from|collection)\\\\s*[\'\\\"]?\\\\s*[:=,(]\\\\s*[\'\\\"]?");
        _builder.append(entityName, "    ");
        _builder.append("\\\\b.*\"");
        _builder.newLineIfNotEmpty();
        _builder.append("  ");
        _builder.append(")");
        _builder.newLine();
      }
    }
    _builder.append("    ");
    _builder.append(")");
    _builder.newLine();
    _builder.append("  ");
    _builder.append(")");
    _builder.newLine();
    _builder.append("}");
    _builder.newLine();
    return _builder;
  }

  public static CharSequence generateUsesField(final String entityName, final String fieldName) {
    return Library.generateUsesField(entityName, fieldName, PersistenceFramework.JPA);
  }

  public static CharSequence generateUsesField(final String entityName, final String fieldName, final PersistenceFramework framework) {
    StringConcatenation _builder = new StringConcatenation();
    _builder.append("/** Check if logical field ");
    _builder.append(entityName);
    _builder.append(".");
    _builder.append(fieldName);
    _builder.append(" occurs in a framework query. */");
    _builder.newLineIfNotEmpty();
    _builder.append("predicate usesField(Expr queryValue) {");
    _builder.newLine();
    _builder.append("  ");
    _builder.append("exists(string queryText |");
    _builder.newLine();
    _builder.append("    ");
    _builder.append("compileTimeStringValue(queryValue, queryText) and");
    _builder.newLine();
    _builder.append("    ");
    _builder.append("(");
    _builder.newLine();
    {
      boolean _includesJpa = framework.includesJpa();
      if (_includesJpa) {
        _builder.append("  ");
        _builder.append("queryText.regexpMatch(");
        _builder.newLine();
        _builder.append("  ");
        _builder.append("  ");
        _builder.append("\"(?i).*\\\\b");
        _builder.append(entityName, "    ");
        _builder.append("\\\\s*\\\\.\\\\s*");
        _builder.append(fieldName, "    ");
        _builder.append("\\\\b.*\"");
        _builder.newLineIfNotEmpty();
        _builder.append("  ");
        _builder.append(")");
        _builder.newLine();
        _builder.append("  ");
        _builder.append("or");
        _builder.newLine();
        _builder.append("  ");
        _builder.append("exists(string declaredAlias, string usedAlias |");
        _builder.newLine();
        _builder.append("  ");
        _builder.append("  ");
        _builder.append("declaredAlias = queryText.regexpCapture(");
        _builder.newLine();
        _builder.append("  ");
        _builder.append("    ");
        _builder.append("\"(?i).*(FROM|JOIN)\\\\s+");
        _builder.append(entityName, "      ");
        _builder.append("\\\\s+([a-zA-Z0-9_]+).*\", 2");
        _builder.newLineIfNotEmpty();
        _builder.append("  ");
        _builder.append("  ");
        _builder.append(") and");
        _builder.newLine();
        _builder.append("  ");
        _builder.append("  ");
        _builder.append("usedAlias = queryText.regexpCapture(");
        _builder.newLine();
        _builder.append("  ");
        _builder.append("    ");
        _builder.append("\"(?i).*\\\\b([a-zA-Z0-9_]+)\\\\s*\\\\.\\\\s*");
        _builder.append(fieldName, "      ");
        _builder.append("\\\\b.*\", 1");
        _builder.newLineIfNotEmpty();
        _builder.append("  ");
        _builder.append("  ");
        _builder.append(") and");
        _builder.newLine();
        _builder.append("  ");
        _builder.append("  ");
        _builder.append("declaredAlias = usedAlias");
        _builder.newLine();
        _builder.append("  ");
        _builder.append(")");
        _builder.newLine();
        _builder.append("  ");
        _builder.append("or");
        _builder.newLine();
        _builder.append("  ");
        _builder.append("queryText.regexpMatch(\"(?i).*FROM\\\\s+");
        _builder.append(entityName, "  ");
        _builder.append("\\\\b.*\") and");
        _builder.newLineIfNotEmpty();
        _builder.append("  ");
        _builder.append("queryText.regexpMatch(\"(?i).*\\\\bWHERE\\\\b.*\\\\b");
        _builder.append(fieldName, "  ");
        _builder.append("\\\\b.*\")");
        _builder.newLineIfNotEmpty();
        _builder.append("  ");
        {
          boolean _includesMongo = framework.includesMongo();
          if (_includesMongo) {
            _builder.append("or");
          }
        }
        _builder.newLineIfNotEmpty();
      }
    }
    {
      boolean _includesMongo_1 = framework.includesMongo();
      if (_includesMongo_1) {
        _builder.append("  ");
        _builder.append("queryText.regexpMatch(");
        _builder.newLine();
        _builder.append("  ");
        _builder.append("  ");
        _builder.append("\"(?i).*[\'\\\"]?");
        _builder.append(fieldName, "    ");
        _builder.append("[\'\\\"]?\\\\s*:.*\"");
        _builder.newLineIfNotEmpty();
        _builder.append("  ");
        _builder.append(")");
        _builder.newLine();
      }
    }
    _builder.append("    ");
    _builder.append(")");
    _builder.newLine();
    _builder.append("  ");
    _builder.append(")");
    _builder.newLine();
    _builder.append("}");
    _builder.newLine();
    return _builder;
  }

  public static CharSequence generateFeatureSemanticPredicates(final String entityName, final String fieldName) {
    StringConcatenation _builder = new StringConcatenation();
    _builder.append("/** A Spring validation API argument that unambiguously names ");
    _builder.append(fieldName);
    _builder.append(". */");
    _builder.newLineIfNotEmpty();
    _builder.append("predicate isSpringPropertyReference(");
    _builder.newLine();
    _builder.append("  ");
    _builder.append("MethodCall call, StringLiteral propertyName, Class entity");
    _builder.newLine();
    _builder.append(") {");
    _builder.newLine();
    _builder.append("  ");
    _builder.append("entity.hasName(\"");
    _builder.append(entityName, "  ");
    _builder.append("\") and");
    _builder.newLineIfNotEmpty();
    _builder.append("  ");
    _builder.append("isEntity(entity) and");
    _builder.newLine();
    _builder.append("  ");
    _builder.append("propertyName.getValue() = \"");
    _builder.append(fieldName, "  ");
    _builder.append("\" and");
    _builder.newLineIfNotEmpty();
    _builder.append("  ");
    _builder.append("isSpringValidationPropertyCall(call, propertyName) and");
    _builder.newLine();
    _builder.append("  ");
    _builder.append("springValidationCallTargetsEntity(call, propertyName.getValue(), entity)");
    _builder.newLine();
    _builder.append("}");
    _builder.newLine();
    _builder.newLine();
    _builder.append("/** A selected Spring Data repository query derived from ");
    _builder.append(fieldName);
    _builder.append(". */");
    _builder.newLineIfNotEmpty();
    _builder.append("predicate isSpringDataDerivedQuery(Method method, Class entity) {");
    _builder.newLine();
    _builder.append("  ");
    _builder.append("isSpringRepositoryMethodForEntity(method, entity) and");
    _builder.newLine();
    _builder.append("  ");
    _builder.append("method.getName().regexpMatch(");
    _builder.newLine();
    _builder.append("    ");
    _builder.append("\"^(find|read|get|query|search|stream|count|exists|delete|remove).*(By|And|Or)");
    String _capitalize = Library.capitalize(fieldName);
    _builder.append(_capitalize, "    ");
    _builder.append("([A-Z0-9].*)?$\"");
    _builder.newLineIfNotEmpty();
    _builder.append("  ");
    _builder.append(")");
    _builder.newLine();
    _builder.append("}");
    _builder.newLine();
    return _builder;
  }

  private static String capitalize(final String value) {
    String _xifexpression = null;
    if (((value == null) || value.isEmpty())) {
      _xifexpression = value;
    } else {
      String _upperCase = value.substring(0, 1).toUpperCase();
      String _substring = value.substring(1);
      _xifexpression = (_upperCase + _substring);
    }
    return _xifexpression;
  }

  public static CharSequence generateUtils() {
    return Library.generateUtils(PersistenceFramework.JPA);
  }

  public static CharSequence generateUtils(final PersistenceFramework framework) {
    StringConcatenation _builder = new StringConcatenation();
    _builder.append("import java");
    _builder.newLine();
    _builder.append("import orion_java");
    _builder.newLine();
    _builder.append("import orion_spring");
    _builder.newLine();
    {
      boolean _includesJpa = framework.includesJpa();
      if (_includesJpa) {
        _builder.append("import orion_jpa");
      }
    }
    _builder.newLineIfNotEmpty();
    {
      boolean _includesMongo = framework.includesMongo();
      if (_includesMongo) {
        _builder.append("import orion_mongo");
      }
    }
    _builder.newLineIfNotEmpty();
    _builder.newLine();
    _builder.append("/** Persistent domain type according to the selected adapter composition. */");
    _builder.newLine();
    _builder.append("predicate isEntity(Class entity) {");
    _builder.newLine();
    _builder.append("  ");
    {
      boolean _includesJpa_1 = framework.includesJpa();
      if (_includesJpa_1) {
        _builder.append("isJpaEntity(entity)");
        {
          boolean _includesMongo_1 = framework.includesMongo();
          if (_includesMongo_1) {
            _builder.append(" or");
          }
        }
      }
    }
    _builder.newLineIfNotEmpty();
    _builder.append("  ");
    {
      boolean _includesMongo_2 = framework.includesMongo();
      if (_includesMongo_2) {
        _builder.append("isMongoPersistentEntity(entity)");
      }
    }
    _builder.newLineIfNotEmpty();
    _builder.append("}");
    _builder.newLine();
    _builder.newLine();
    _builder.append("predicate frameworkEntityMetadataAnnotation(Class entity, Annotation annotation) {");
    _builder.newLine();
    _builder.append("  ");
    {
      boolean _includesJpa_2 = framework.includesJpa();
      if (_includesJpa_2) {
        _builder.append("isJpaEntityMetadataAnnotation(entity, annotation)");
        {
          boolean _includesMongo_3 = framework.includesMongo();
          if (_includesMongo_3) {
            _builder.append(" or");
          }
        }
      }
    }
    _builder.newLineIfNotEmpty();
    _builder.append("  ");
    {
      boolean _includesMongo_4 = framework.includesMongo();
      if (_includesMongo_4) {
        _builder.append("isMongoEntityMetadataAnnotation(entity, annotation)");
      }
    }
    _builder.newLineIfNotEmpty();
    _builder.append("}");
    _builder.newLine();
    _builder.newLine();
    _builder.append("/** Metadata that independently carries the logical entity name being renamed. */");
    _builder.newLine();
    _builder.append("predicate frameworkEntityRenameMetadataAnnotation(");
    _builder.newLine();
    _builder.append("  ");
    _builder.append("Class entity, Annotation annotation");
    _builder.newLine();
    _builder.append(") {");
    _builder.newLine();
    _builder.append("  ");
    {
      boolean _includesJpa_3 = framework.includesJpa();
      if (_includesJpa_3) {
        _builder.append("isJpaEntityRenameMetadataAnnotation(entity, annotation)");
      } else {
        _builder.append("annotation = entity.getAnAnnotation() and");
        _builder.newLineIfNotEmpty();
        _builder.append("  ");
        _builder.append("annotation.getType().hasQualifiedName(\"orionflow.disabled\", \"Entity\")");
      }
    }
    _builder.newLineIfNotEmpty();
    _builder.append("}");
    _builder.newLine();
    _builder.newLine();
    _builder.append("predicate isFrameworkCollectionNameCall(");
    _builder.newLine();
    _builder.append("  ");
    _builder.append("MethodCall call, StringLiteral collectionName, Class entity");
    _builder.newLine();
    _builder.append(") {");
    _builder.newLine();
    _builder.append("  ");
    {
      boolean _includesMongo_5 = framework.includesMongo();
      if (_includesMongo_5) {
        _builder.append("isMongoCollectionNameCall(call, collectionName, entity)");
      } else {
        _builder.append("collectionName = call.getArgument(0) and");
        _builder.newLineIfNotEmpty();
        _builder.append("  ");
        _builder.append("entity.hasName(collectionName.getValue()) and");
        _builder.newLine();
        _builder.append("  ");
        _builder.append("call.getMethod().hasQualifiedName(\"orionflow.disabled\", \"MongoOperations\", \"find\")");
      }
    }
    _builder.newLineIfNotEmpty();
    _builder.append("}");
    _builder.newLine();
    _builder.newLine();
    _builder.append("predicate isQuery(Annotation annotation) {");
    _builder.newLine();
    _builder.append("  ");
    {
      boolean _includesJpa_4 = framework.includesJpa();
      if (_includesJpa_4) {
        _builder.append("isJpaQuery(annotation)");
        {
          boolean _includesMongo_6 = framework.includesMongo();
          if (_includesMongo_6) {
            _builder.append(" or");
          }
        }
      }
    }
    _builder.newLineIfNotEmpty();
    _builder.append("  ");
    {
      boolean _includesMongo_7 = framework.includesMongo();
      if (_includesMongo_7) {
        _builder.append("isMongoQuery(annotation)");
      }
    }
    _builder.newLineIfNotEmpty();
    _builder.append("}");
    _builder.newLine();
    _builder.newLine();
    _builder.append("predicate isJpaFrameworkQuery(Annotation annotation) {");
    _builder.newLine();
    _builder.append("  ");
    {
      boolean _includesJpa_5 = framework.includesJpa();
      if (_includesJpa_5) {
        _builder.append("isJpaQuery(annotation)");
      } else {
        _builder.append("annotation.getType().hasQualifiedName(\"orionflow.disabled\", \"JpaQuery\")");
      }
    }
    _builder.newLineIfNotEmpty();
    _builder.append("}");
    _builder.newLine();
    _builder.newLine();
    _builder.append("predicate isMongoFrameworkQuery(Annotation annotation) {");
    _builder.newLine();
    _builder.append("  ");
    {
      boolean _includesMongo_8 = framework.includesMongo();
      if (_includesMongo_8) {
        _builder.append("isMongoQuery(annotation)");
      } else {
        _builder.append("annotation.getType().hasQualifiedName(\"orionflow.disabled\", \"MongoQuery\")");
      }
    }
    _builder.newLineIfNotEmpty();
    _builder.append("}");
    _builder.newLine();
    _builder.newLine();
    _builder.append("predicate isNamedQuery(Annotation annotation) {");
    _builder.newLine();
    _builder.append("  ");
    {
      boolean _includesJpa_6 = framework.includesJpa();
      if (_includesJpa_6) {
        _builder.append("isJpaNamedQuery(annotation)");
      } else {
        _builder.append("annotation.getType().hasQualifiedName(\"orionflow.disabled\", \"NamedQuery\")");
      }
    }
    _builder.newLineIfNotEmpty();
    _builder.append("}");
    _builder.newLine();
    _builder.newLine();
    _builder.append("predicate isEmbeddable(Class cls) {");
    _builder.newLine();
    _builder.append("  ");
    {
      boolean _includesJpa_7 = framework.includesJpa();
      if (_includesJpa_7) {
        _builder.append("isJpaEmbeddable(cls)");
      } else {
        _builder.append("cls.hasQualifiedName(\"orionflow.disabled\", \"Embeddable\")");
      }
    }
    _builder.newLineIfNotEmpty();
    _builder.append("}");
    _builder.newLine();
    _builder.newLine();
    _builder.append("predicate isEmbeddedField(Field field) {");
    _builder.newLine();
    _builder.append("  ");
    {
      boolean _includesJpa_8 = framework.includesJpa();
      if (_includesJpa_8) {
        _builder.append("isJpaEmbeddedField(field)");
      } else {
        _builder.append("field.getDeclaringType().hasQualifiedName(\"orionflow.disabled\", \"Embedded\")");
      }
    }
    _builder.newLineIfNotEmpty();
    _builder.append("}");
    _builder.newLine();
    _builder.newLine();
    _builder.append("predicate usesField(Expr queryValue, Field field) {");
    _builder.newLine();
    _builder.append("  ");
    {
      boolean _includesJpa_9 = framework.includesJpa();
      if (_includesJpa_9) {
        _builder.append("jpaQueryReferencesField(queryValue, field)");
        {
          boolean _includesMongo_9 = framework.includesMongo();
          if (_includesMongo_9) {
            _builder.append(" or");
          }
        }
      }
    }
    _builder.newLineIfNotEmpty();
    _builder.append("  ");
    {
      boolean _includesMongo_10 = framework.includesMongo();
      if (_includesMongo_10) {
        _builder.append("mongoQueryReferencesField(queryValue, field)");
      }
    }
    _builder.newLineIfNotEmpty();
    _builder.append("}");
    _builder.newLine();
    _builder.newLine();
    _builder.append("predicate frameworkQueryReferencesField(Annotation query, Field field) {");
    _builder.newLine();
    _builder.append("  ");
    {
      boolean _includesJpa_10 = framework.includesJpa();
      if (_includesJpa_10) {
        _builder.append("isJpaEntity(field.getDeclaringType()) and");
        _builder.newLineIfNotEmpty();
        _builder.append("  ");
        _builder.append("isJpaQuery(query) and");
        _builder.newLine();
        _builder.append("  ");
        _builder.append("jpaQueryReferencesField(query.getValue(\"value\"), field)");
        {
          boolean _includesMongo_11 = framework.includesMongo();
          if (_includesMongo_11) {
            _builder.append(" or");
          }
        }
      }
    }
    _builder.newLineIfNotEmpty();
    _builder.append("  ");
    {
      boolean _includesMongo_12 = framework.includesMongo();
      if (_includesMongo_12) {
        _builder.append("isMongoPersistentEntity(field.getDeclaringType()) and");
        _builder.newLineIfNotEmpty();
        _builder.append("  ");
        _builder.append("isMongoQuery(query) and");
        _builder.newLine();
        _builder.append("  ");
        _builder.append("mongoQueryReferencesField(query.getValue(\"value\"), field)");
      }
    }
    _builder.newLineIfNotEmpty();
    _builder.append("}");
    _builder.newLine();
    _builder.newLine();
    _builder.append("predicate isCreateQuery(MethodCall call) {");
    _builder.newLine();
    _builder.append("  ");
    {
      boolean _includesJpa_11 = framework.includesJpa();
      if (_includesJpa_11) {
        _builder.append("isJpaCreateQuery(call)");
      } else {
        _builder.append("call.getMethod().hasQualifiedName(\"orionflow.disabled\", \"EntityManager\", \"createQuery\")");
      }
    }
    _builder.newLineIfNotEmpty();
    _builder.append("}");
    _builder.newLine();
    _builder.newLine();
    _builder.append("predicate isCreateNamedQuery(MethodCall call) {");
    _builder.newLine();
    _builder.append("  ");
    {
      boolean _includesJpa_12 = framework.includesJpa();
      if (_includesJpa_12) {
        _builder.append("isJpaCreateNamedQuery(call)");
      } else {
        _builder.append("call.getMethod().hasQualifiedName(\"orionflow.disabled\", \"EntityManager\", \"createNamedQuery\")");
      }
    }
    _builder.newLineIfNotEmpty();
    _builder.append("}");
    _builder.newLine();
    _builder.newLine();
    _builder.append("predicate frameworkMetadataReferencesField(Annotation annotation, Field field) {");
    _builder.newLine();
    _builder.append("  ");
    {
      boolean _includesJpa_13 = framework.includesJpa();
      if (_includesJpa_13) {
        _builder.append("isJpaEntity(field.getDeclaringType()) and");
        _builder.newLineIfNotEmpty();
        _builder.append("  ");
        _builder.append("jpaMetadataReferencesField(annotation, field)");
        {
          boolean _includesMongo_13 = framework.includesMongo();
          if (_includesMongo_13) {
            _builder.append(" or");
          }
        }
      }
    }
    _builder.newLineIfNotEmpty();
    _builder.append("  ");
    {
      boolean _includesMongo_14 = framework.includesMongo();
      if (_includesMongo_14) {
        _builder.append("isMongoPersistentEntity(field.getDeclaringType()) and");
        _builder.newLineIfNotEmpty();
        _builder.append("  ");
        _builder.append("mongoMetadataReferencesField(annotation, field)");
      }
    }
    _builder.newLineIfNotEmpty();
    _builder.append("}");
    _builder.newLine();
    _builder.newLine();
    _builder.append("predicate isFrameworkFieldNameCall(");
    _builder.newLine();
    _builder.append("  ");
    _builder.append("MethodCall call, StringLiteral propertyName, Field field");
    _builder.newLine();
    _builder.append(") {");
    _builder.newLine();
    _builder.append("  ");
    {
      boolean _includesMongo_15 = framework.includesMongo();
      if (_includesMongo_15) {
        _builder.append("isMongoPersistentEntity(field.getDeclaringType()) and");
        _builder.newLineIfNotEmpty();
        _builder.append("  ");
        _builder.append("isMongoFieldNameCall(call, propertyName, field)");
      } else {
        _builder.append("propertyName = call.getArgument(0) and");
        _builder.newLineIfNotEmpty();
        _builder.append("  ");
        _builder.append("field.hasName(propertyName.getValue()) and");
        _builder.newLine();
        _builder.append("  ");
        _builder.append("call.getMethod().hasQualifiedName(\"orionflow.disabled\", \"FieldApi\", \"field\")");
      }
    }
    _builder.newLineIfNotEmpty();
    _builder.append("}");
    _builder.newLine();
    _builder.newLine();
    _builder.append("predicate isAssociationAnnotation(Annotation annotation) {");
    _builder.newLine();
    _builder.append("  ");
    {
      boolean _includesJpa_14 = framework.includesJpa();
      if (_includesJpa_14) {
        _builder.append("isJpaAssociationAnnotation(annotation)");
        {
          boolean _includesMongo_16 = framework.includesMongo();
          if (_includesMongo_16) {
            _builder.append(" or");
          }
        }
      }
    }
    _builder.newLineIfNotEmpty();
    _builder.append("  ");
    {
      boolean _includesMongo_17 = framework.includesMongo();
      if (_includesMongo_17) {
        _builder.append("isMongoAssociationAnnotation(annotation)");
      }
    }
    _builder.newLineIfNotEmpty();
    _builder.append("}");
    _builder.newLine();
    _builder.newLine();
    _builder.append("predicate isReferenceMappingAnnotation(Annotation annotation, Field field) {");
    _builder.newLine();
    _builder.append("  ");
    {
      boolean _includesJpa_15 = framework.includesJpa();
      if (_includesJpa_15) {
        _builder.append("isJpaReferenceMappingAnnotation(annotation, field)");
        {
          boolean _includesMongo_18 = framework.includesMongo();
          if (_includesMongo_18) {
            _builder.append(" or");
          }
        }
      }
    }
    _builder.newLineIfNotEmpty();
    _builder.append("  ");
    {
      boolean _includesMongo_19 = framework.includesMongo();
      if (_includesMongo_19) {
        _builder.append("isMongoReferenceMappingAnnotation(annotation, field)");
      }
    }
    _builder.newLineIfNotEmpty();
    _builder.append("}");
    _builder.newLine();
    _builder.newLine();
    _builder.append("predicate isRelationshipField(Field field) {");
    _builder.newLine();
    _builder.append("  ");
    {
      boolean _includesJpa_16 = framework.includesJpa();
      if (_includesJpa_16) {
        _builder.append("isJpaRelationshipField(field)");
        {
          boolean _includesMongo_20 = framework.includesMongo();
          if (_includesMongo_20) {
            _builder.append(" or");
          }
        }
      }
    }
    _builder.newLineIfNotEmpty();
    _builder.append("  ");
    {
      boolean _includesMongo_21 = framework.includesMongo();
      if (_includesMongo_21) {
        _builder.append("isMongoRelationshipField(field)");
      }
    }
    _builder.newLineIfNotEmpty();
    _builder.append("}");
    _builder.newLine();
    _builder.newLine();
    _builder.append("predicate isRelatedField(Field relationshipField, Field mappedField) {");
    _builder.newLine();
    _builder.append("  ");
    {
      boolean _includesJpa_17 = framework.includesJpa();
      if (_includesJpa_17) {
        _builder.append("isJpaRelatedField(relationshipField, mappedField)");
        {
          boolean _includesMongo_22 = framework.includesMongo();
          if (_includesMongo_22) {
            _builder.append(" or");
          }
        }
      }
    }
    _builder.newLineIfNotEmpty();
    _builder.append("  ");
    {
      boolean _includesMongo_23 = framework.includesMongo();
      if (_includesMongo_23) {
        _builder.append("isMongoRelatedField(relationshipField, mappedField)");
      }
    }
    _builder.newLineIfNotEmpty();
    _builder.append("}");
    _builder.newLine();
    _builder.newLine();
    _builder.append("predicate usesRelationship(Expr queryValue, Field relationshipField) {");
    _builder.newLine();
    _builder.append("  ");
    {
      boolean _includesJpa_18 = framework.includesJpa();
      if (_includesJpa_18) {
        _builder.append("jpaRelationshipReferencedInQuery(queryValue, relationshipField)");
        {
          boolean _includesMongo_24 = framework.includesMongo();
          if (_includesMongo_24) {
            _builder.append(" or");
          }
        }
      }
    }
    _builder.newLineIfNotEmpty();
    _builder.append("  ");
    {
      boolean _includesMongo_25 = framework.includesMongo();
      if (_includesMongo_25) {
        _builder.append("mongoRelationshipReferencedInQuery(queryValue, relationshipField)");
      }
    }
    _builder.newLineIfNotEmpty();
    _builder.append("}");
    _builder.newLine();
    _builder.newLine();
    _builder.append("predicate frameworkQueryReferencesRelationship(");
    _builder.newLine();
    _builder.append("  ");
    _builder.append("Annotation query, Expr queryValue, Field relationshipField");
    _builder.newLine();
    _builder.append(") {");
    _builder.newLine();
    _builder.append("  ");
    {
      boolean _includesJpa_19 = framework.includesJpa();
      if (_includesJpa_19) {
        _builder.append("isJpaQuery(query) and");
        _builder.newLineIfNotEmpty();
        _builder.append("  ");
        _builder.append("jpaRelationshipReferencedInQuery(queryValue, relationshipField)");
        {
          boolean _includesMongo_26 = framework.includesMongo();
          if (_includesMongo_26) {
            _builder.append(" or");
          }
        }
      }
    }
    _builder.newLineIfNotEmpty();
    _builder.append("  ");
    {
      boolean _includesMongo_27 = framework.includesMongo();
      if (_includesMongo_27) {
        _builder.append("isMongoQuery(query) and");
        _builder.newLineIfNotEmpty();
        _builder.append("  ");
        _builder.append("mongoRelationshipReferencedInQuery(queryValue, relationshipField)");
      }
    }
    _builder.newLineIfNotEmpty();
    _builder.append("}");
    _builder.newLine();
    _builder.newLine();
    _builder.append("Field getRelationshipField(Class sourceEntity, string relationshipName) {");
    _builder.newLine();
    _builder.append("  ");
    {
      boolean _includesJpa_20 = framework.includesJpa();
      if (_includesJpa_20) {
        _builder.append("result = getJpaRelationshipField(sourceEntity, relationshipName)");
        {
          boolean _includesMongo_28 = framework.includesMongo();
          if (_includesMongo_28) {
            _builder.append(" or");
          }
        }
      }
    }
    _builder.newLineIfNotEmpty();
    _builder.append("  ");
    {
      boolean _includesMongo_29 = framework.includesMongo();
      if (_includesMongo_29) {
        _builder.append("result = getMongoRelationshipField(sourceEntity, relationshipName)");
      }
    }
    _builder.newLineIfNotEmpty();
    _builder.append("}");
    _builder.newLine();
    _builder.newLine();
    _builder.append("predicate getRelationshipMappingAnnotation(");
    _builder.newLine();
    _builder.append("  ");
    _builder.append("Field field, string relationshipName, Annotation mapping");
    _builder.newLine();
    _builder.append(") {");
    _builder.newLine();
    _builder.append("  ");
    {
      boolean _includesJpa_21 = framework.includesJpa();
      if (_includesJpa_21) {
        _builder.append("getJpaRelationshipMappingAnnotation(field, relationshipName, mapping)");
        {
          boolean _includesMongo_30 = framework.includesMongo();
          if (_includesMongo_30) {
            _builder.append(" or");
          }
        }
      }
    }
    _builder.newLineIfNotEmpty();
    _builder.append("  ");
    {
      boolean _includesMongo_31 = framework.includesMongo();
      if (_includesMongo_31) {
        _builder.append("getMongoRelationshipMappingAnnotation(field, relationshipName, mapping)");
      }
    }
    _builder.newLineIfNotEmpty();
    _builder.append("}");
    _builder.newLine();
    _builder.newLine();
    _builder.append("predicate isIdAnnotation(Annotation annotation) {");
    _builder.newLine();
    _builder.append("  ");
    {
      boolean _includesJpa_22 = framework.includesJpa();
      if (_includesJpa_22) {
        _builder.append("isJpaAnnotation(annotation, \"Id\") or isJpaAnnotation(annotation, \"EmbeddedId\")");
        {
          boolean _includesMongo_32 = framework.includesMongo();
          if (_includesMongo_32) {
            _builder.append(" or");
          }
        }
      }
    }
    _builder.newLineIfNotEmpty();
    _builder.append("  ");
    {
      boolean _includesMongo_33 = framework.includesMongo();
      if (_includesMongo_33) {
        _builder.append("isMongoIdAnnotation(annotation)");
      }
    }
    _builder.newLineIfNotEmpty();
    _builder.append("}");
    _builder.newLine();
    _builder.newLine();
    _builder.append("predicate isGeneratedValueAnnotation(Annotation annotation) {");
    _builder.newLine();
    _builder.append("  ");
    {
      boolean _includesJpa_23 = framework.includesJpa();
      if (_includesJpa_23) {
        _builder.append("isJpaAnnotation(annotation, \"GeneratedValue\")");
      } else {
        _builder.append("annotation.getType().hasQualifiedName(\"orionflow.disabled\", \"GeneratedValue\")");
      }
    }
    _builder.newLineIfNotEmpty();
    _builder.append("}");
    _builder.newLine();
    _builder.newLine();
    _builder.append("predicate isJoinColumnAnnotation(Annotation annotation) {");
    _builder.newLine();
    _builder.append("  ");
    {
      boolean _includesJpa_24 = framework.includesJpa();
      if (_includesJpa_24) {
        _builder.append("isJpaAnnotation(annotation, \"JoinColumn\")");
      } else {
        _builder.append("annotation.getType().hasQualifiedName(\"orionflow.disabled\", \"JoinColumn\")");
      }
    }
    _builder.newLineIfNotEmpty();
    _builder.append("}");
    _builder.newLine();
    return _builder;
  }
}
