package m2t;

import com.google.common.base.Objects;
import java.util.Collection;
import java.util.HashMap;
import java.util.Map;
import java.util.Set;

/**
 * Resolves the logical names produced by an Orion evolution sequence to the
 * names that still exist in the source code used to build the CodeQL database.
 */
@SuppressWarnings("all")
public class EvolutionContext {
  public static class EntityOrigin {
    private final String logicalId;

    private final String originalName;

    private String currentName;

    private boolean deleted;

    public EntityOrigin(final String logicalId, final String originalName, final String currentName) {
      this.logicalId = logicalId;
      this.originalName = originalName;
      this.currentName = currentName;
    }

    public String getLogicalId() {
      return this.logicalId;
    }

    public String getOriginalName() {
      return this.originalName;
    }

    public String getCurrentName() {
      return this.currentName;
    }

    public boolean isDeleted() {
      return this.deleted;
    }
  }

  public static class FeatureOrigin {
    private final String logicalId;

    private final String entityName;

    private final String featureName;

    private String currentEntityName;

    private String currentFeatureName;

    private boolean deleted;

    public FeatureOrigin(final String entityName, final String featureName) {
      this("F0", entityName, featureName, entityName, featureName);
    }

    public FeatureOrigin(final String logicalId, final String entityName, final String featureName, final String currentEntityName, final String currentFeatureName) {
      this.logicalId = logicalId;
      this.entityName = entityName;
      this.featureName = featureName;
      this.currentEntityName = currentEntityName;
      this.currentFeatureName = currentFeatureName;
    }

    public String getLogicalId() {
      return this.logicalId;
    }

    public String getEntityName() {
      return this.entityName;
    }

    public String getFeatureName() {
      return this.featureName;
    }

    public String getCurrentEntityName() {
      return this.currentEntityName;
    }

    public String getCurrentFeatureName() {
      return this.currentFeatureName;
    }

    public boolean isDeleted() {
      return this.deleted;
    }
  }

  public static class RelationshipOrigin {
    private final String logicalId;

    private final String originalName;

    private String currentName;

    private boolean deleted;

    public RelationshipOrigin(final String logicalId, final String originalName, final String currentName) {
      this.logicalId = logicalId;
      this.originalName = originalName;
      this.currentName = currentName;
    }

    public String getLogicalId() {
      return this.logicalId;
    }

    public String getOriginalName() {
      return this.originalName;
    }

    public String getCurrentName() {
      return this.currentName;
    }

    public boolean isDeleted() {
      return this.deleted;
    }
  }

  private final Map<String, String> entityOrigins = new HashMap<String, String>();

  private final Map<String, EvolutionContext.EntityOrigin> entityIdentities = new HashMap<String, EvolutionContext.EntityOrigin>();

  private final Map<String, EvolutionContext.EntityOrigin> deletedEntities = new HashMap<String, EvolutionContext.EntityOrigin>();

  private final Map<String, Map<String, EvolutionContext.FeatureOrigin>> featureOrigins = new HashMap<String, Map<String, EvolutionContext.FeatureOrigin>>();

  private final Map<String, EvolutionContext.FeatureOrigin> deletedFeatures = new HashMap<String, EvolutionContext.FeatureOrigin>();

  private final Map<String, String> relationshipOrigins = new HashMap<String, String>();

  private final Map<String, EvolutionContext.RelationshipOrigin> relationshipIdentities = new HashMap<String, EvolutionContext.RelationshipOrigin>();

  private final Map<String, EvolutionContext.RelationshipOrigin> deletedRelationships = new HashMap<String, EvolutionContext.RelationshipOrigin>();

  private long nextEntityId;

  private long nextFeatureId;

  private long nextRelationshipId;

  public String resolveEntity(final String currentName) {
    return this.resolveEntityOrigin(currentName).originalName;
  }

  public EvolutionContext.EntityOrigin resolveEntityOrigin(final String currentName) {
    EvolutionContext.EntityOrigin _xblockexpression = null;
    {
      EvolutionContext.EntityOrigin origin = this.entityIdentities.get(currentName);
      if ((origin == null)) {
        origin = this.deletedEntities.get(currentName);
      }
      if ((origin == null)) {
        final String originalName = this.entityOrigins.get(currentName);
        String _nextEntityLogicalId = this.nextEntityLogicalId();
        String _xifexpression = null;
        if ((originalName == null)) {
          _xifexpression = currentName;
        } else {
          _xifexpression = originalName;
        }
        EvolutionContext.EntityOrigin _entityOrigin = new EvolutionContext.EntityOrigin(_nextEntityLogicalId, _xifexpression, currentName);
        origin = _entityOrigin;
        this.entityIdentities.put(currentName, origin);
      }
      _xblockexpression = origin;
    }
    return _xblockexpression;
  }

  public EvolutionContext.FeatureOrigin resolveFeature(final String currentEntityName, final String currentFeatureName) {
    EvolutionContext.FeatureOrigin _xblockexpression = null;
    {
      final Map<String, EvolutionContext.FeatureOrigin> features = this.featureOrigins.get(currentEntityName);
      EvolutionContext.FeatureOrigin _xifexpression = null;
      if ((features == null)) {
        _xifexpression = null;
      } else {
        _xifexpression = features.get(currentFeatureName);
      }
      final EvolutionContext.FeatureOrigin origin = _xifexpression;
      if ((origin != null)) {
        return origin;
      }
      final EvolutionContext.FeatureOrigin deleted = this.deletedFeatures.get(EvolutionContext.featureKey(currentEntityName, currentFeatureName));
      if ((deleted != null)) {
        return deleted;
      }
      String _nextFeatureLogicalId = this.nextFeatureLogicalId();
      String _resolveEntity = this.resolveEntity(currentEntityName);
      final EvolutionContext.FeatureOrigin created = new EvolutionContext.FeatureOrigin(_nextFeatureLogicalId, _resolveEntity, currentFeatureName, currentEntityName, currentFeatureName);
      this.getOrCreateFeatures(currentEntityName).put(currentFeatureName, created);
      _xblockexpression = created;
    }
    return _xblockexpression;
  }

  public void renameEntity(final String currentName, final String newName) {
    if (((!Objects.equal(currentName, newName)) && (this.entityIdentities.containsKey(newName) || this.entityOrigins.containsKey(newName)))) {
      throw new IllegalArgumentException(
        (((("Entity name collision while renaming \'" + currentName) + "\' to \'") + newName) + "\'."));
    }
    final EvolutionContext.EntityOrigin entityOrigin = this.resolveEntityOrigin(currentName);
    final String originalName = entityOrigin.originalName;
    final Map<String, EvolutionContext.FeatureOrigin> features = this.featureOrigins.remove(currentName);
    this.entityOrigins.remove(currentName);
    this.entityOrigins.put(newName, originalName);
    this.entityIdentities.remove(currentName);
    entityOrigin.currentName = newName;
    this.entityIdentities.put(newName, entityOrigin);
    if ((features != null)) {
      Collection<EvolutionContext.FeatureOrigin> _values = features.values();
      for (final EvolutionContext.FeatureOrigin feature : _values) {
        feature.currentEntityName = newName;
      }
      this.featureOrigins.put(newName, features);
    }
  }

  public void deleteEntity(final String currentName) {
    final EvolutionContext.EntityOrigin entityOrigin = this.resolveEntityOrigin(currentName);
    entityOrigin.deleted = true;
    this.deletedEntities.put(currentName, entityOrigin);
    this.entityOrigins.remove(currentName);
    this.entityIdentities.remove(currentName);
    final Map<String, EvolutionContext.FeatureOrigin> features = this.featureOrigins.get(currentName);
    if ((features != null)) {
      Set<Map.Entry<String, EvolutionContext.FeatureOrigin>> _entrySet = features.entrySet();
      for (final Map.Entry<String, EvolutionContext.FeatureOrigin> entry : _entrySet) {
        {
          EvolutionContext.FeatureOrigin _value = entry.getValue();
          _value.deleted = true;
          this.deletedFeatures.put(EvolutionContext.featureKey(currentName, entry.getKey()), entry.getValue());
        }
      }
    }
    this.featureOrigins.remove(currentName);
  }

  public void splitEntity(final String currentName, final String firstEntityName, final Iterable<String> firstFeatureNames, final String secondEntityName, final Iterable<String> secondFeatureNames) {
    if (((Objects.equal(firstEntityName, secondEntityName) || 
      this.entityIdentities.containsKey(firstEntityName)) || 
      this.entityIdentities.containsKey(secondEntityName))) {
      throw new IllegalArgumentException(
        (("Entity name collision while splitting \'" + currentName) + "\'."));
    }
    final EvolutionContext.EntityOrigin sourceOrigin = this.resolveEntityOrigin(currentName);
    final String originalEntityName = sourceOrigin.originalName;
    final Map<String, EvolutionContext.FeatureOrigin> firstFeatures = this.resolveFeatures(currentName, firstFeatureNames);
    final Map<String, EvolutionContext.FeatureOrigin> secondFeatures = this.resolveFeatures(currentName, secondFeatureNames);
    this.entityOrigins.remove(currentName);
    this.entityIdentities.remove(currentName);
    sourceOrigin.deleted = true;
    this.deletedEntities.put(currentName, sourceOrigin);
    this.featureOrigins.remove(currentName);
    this.entityOrigins.put(firstEntityName, originalEntityName);
    this.entityOrigins.put(secondEntityName, originalEntityName);
    String _nextEntityLogicalId = this.nextEntityLogicalId();
    EvolutionContext.EntityOrigin _entityOrigin = new EvolutionContext.EntityOrigin(_nextEntityLogicalId, originalEntityName, firstEntityName);
    this.entityIdentities.put(firstEntityName, _entityOrigin);
    String _nextEntityLogicalId_1 = this.nextEntityLogicalId();
    EvolutionContext.EntityOrigin _entityOrigin_1 = new EvolutionContext.EntityOrigin(_nextEntityLogicalId_1, originalEntityName, secondEntityName);
    this.entityIdentities.put(secondEntityName, _entityOrigin_1);
    Collection<EvolutionContext.FeatureOrigin> _values = firstFeatures.values();
    for (final EvolutionContext.FeatureOrigin feature : _values) {
      feature.currentEntityName = firstEntityName;
    }
    Collection<EvolutionContext.FeatureOrigin> _values_1 = secondFeatures.values();
    for (final EvolutionContext.FeatureOrigin feature_1 : _values_1) {
      feature_1.currentEntityName = secondEntityName;
    }
    this.featureOrigins.put(firstEntityName, firstFeatures);
    this.featureOrigins.put(secondEntityName, secondFeatures);
  }

  public void renameFeature(final String currentEntityName, final String currentFeatureName, final String newFeatureName) {
    final EvolutionContext.FeatureOrigin origin = this.resolveFeature(currentEntityName, currentFeatureName);
    final Map<String, EvolutionContext.FeatureOrigin> features = this.getOrCreateFeatures(currentEntityName);
    if (((!Objects.equal(currentFeatureName, newFeatureName)) && features.containsKey(newFeatureName))) {
      throw new IllegalArgumentException(
        (((("Feature name collision in entity \'" + currentEntityName) + 
          "\': \'") + newFeatureName) + "\'."));
    }
    features.remove(currentFeatureName);
    origin.currentEntityName = currentEntityName;
    origin.currentFeatureName = newFeatureName;
    features.put(newFeatureName, origin);
  }

  public void deleteFeature(final String currentEntityName, final String currentFeatureName) {
    final Map<String, EvolutionContext.FeatureOrigin> features = this.featureOrigins.get(currentEntityName);
    EvolutionContext.FeatureOrigin _xifexpression = null;
    if ((features == null)) {
      _xifexpression = null;
    } else {
      _xifexpression = features.remove(currentFeatureName);
    }
    final EvolutionContext.FeatureOrigin origin = _xifexpression;
    EvolutionContext.FeatureOrigin _xifexpression_1 = null;
    if ((origin == null)) {
      _xifexpression_1 = this.resolveFeature(currentEntityName, currentFeatureName);
    } else {
      _xifexpression_1 = origin;
    }
    final EvolutionContext.FeatureOrigin resolved = _xifexpression_1;
    resolved.deleted = true;
    this.deletedFeatures.put(EvolutionContext.featureKey(currentEntityName, currentFeatureName), resolved);
    final Map<String, EvolutionContext.FeatureOrigin> liveFeatures = this.featureOrigins.get(currentEntityName);
    if ((liveFeatures != null)) {
      liveFeatures.remove(currentFeatureName);
    }
  }

  public void moveFeature(final String sourceEntityName, final String sourceFeatureName, final String targetEntityName, final String targetFeatureName) {
    final EvolutionContext.FeatureOrigin origin = this.resolveFeature(sourceEntityName, sourceFeatureName);
    final Map<String, EvolutionContext.FeatureOrigin> targetFeatures = this.getOrCreateFeatures(targetEntityName);
    boolean _containsKey = targetFeatures.containsKey(targetFeatureName);
    if (_containsKey) {
      throw new IllegalArgumentException(
        (((("Feature name collision in target entity \'" + targetEntityName) + 
          "\': \'") + targetFeatureName) + "\'."));
    }
    final Map<String, EvolutionContext.FeatureOrigin> sourceFeatures = this.featureOrigins.get(sourceEntityName);
    if ((sourceFeatures != null)) {
      sourceFeatures.remove(sourceFeatureName);
    }
    origin.currentEntityName = targetEntityName;
    origin.currentFeatureName = targetFeatureName;
    targetFeatures.put(targetFeatureName, origin);
  }

  public String resolveRelationship(final String currentName) {
    return this.resolveRelationshipOrigin(currentName).originalName;
  }

  public EvolutionContext.RelationshipOrigin resolveRelationshipOrigin(final String currentName) {
    EvolutionContext.RelationshipOrigin _xblockexpression = null;
    {
      EvolutionContext.RelationshipOrigin origin = this.relationshipIdentities.get(currentName);
      if ((origin == null)) {
        origin = this.deletedRelationships.get(currentName);
      }
      if ((origin == null)) {
        final String originalName = this.relationshipOrigins.get(currentName);
        String _nextRelationshipLogicalId = this.nextRelationshipLogicalId();
        String _xifexpression = null;
        if ((originalName == null)) {
          _xifexpression = currentName;
        } else {
          _xifexpression = originalName;
        }
        EvolutionContext.RelationshipOrigin _relationshipOrigin = new EvolutionContext.RelationshipOrigin(_nextRelationshipLogicalId, _xifexpression, currentName);
        origin = _relationshipOrigin;
        this.relationshipIdentities.put(currentName, origin);
      }
      _xblockexpression = origin;
    }
    return _xblockexpression;
  }

  public void renameRelationship(final String currentName, final String newName) {
    if (((!Objects.equal(currentName, newName)) && (this.relationshipIdentities.containsKey(newName) || this.relationshipOrigins.containsKey(newName)))) {
      throw new IllegalArgumentException(
        (((("Relationship name collision while renaming \'" + currentName) + 
          "\' to \'") + newName) + "\'."));
    }
    final EvolutionContext.RelationshipOrigin origin = this.resolveRelationshipOrigin(currentName);
    final String originalName = origin.originalName;
    this.relationshipOrigins.remove(currentName);
    this.relationshipOrigins.put(newName, originalName);
    this.relationshipIdentities.remove(currentName);
    origin.currentName = newName;
    this.relationshipIdentities.put(newName, origin);
  }

  public void deleteRelationship(final String currentName) {
    final EvolutionContext.RelationshipOrigin origin = this.resolveRelationshipOrigin(currentName);
    origin.deleted = true;
    this.deletedRelationships.put(currentName, origin);
    this.relationshipOrigins.remove(currentName);
    this.relationshipIdentities.remove(currentName);
  }

  private String nextEntityLogicalId() {
    String _xblockexpression = null;
    {
      this.nextEntityId = (this.nextEntityId + 1);
      _xblockexpression = ("E" + Long.valueOf(this.nextEntityId));
    }
    return _xblockexpression;
  }

  private String nextFeatureLogicalId() {
    String _xblockexpression = null;
    {
      this.nextFeatureId = (this.nextFeatureId + 1);
      _xblockexpression = ("F" + Long.valueOf(this.nextFeatureId));
    }
    return _xblockexpression;
  }

  private String nextRelationshipLogicalId() {
    String _xblockexpression = null;
    {
      this.nextRelationshipId = (this.nextRelationshipId + 1);
      _xblockexpression = ("R" + Long.valueOf(this.nextRelationshipId));
    }
    return _xblockexpression;
  }

  private static String featureKey(final String entityName, final String featureName) {
    return ((entityName + "::") + featureName);
  }

  private Map<String, EvolutionContext.FeatureOrigin> getOrCreateFeatures(final String entityName) {
    Map<String, EvolutionContext.FeatureOrigin> _xblockexpression = null;
    {
      Map<String, EvolutionContext.FeatureOrigin> features = this.featureOrigins.get(entityName);
      if ((features == null)) {
        HashMap<String, EvolutionContext.FeatureOrigin> _hashMap = new HashMap<String, EvolutionContext.FeatureOrigin>();
        features = _hashMap;
        this.featureOrigins.put(entityName, features);
      }
      _xblockexpression = features;
    }
    return _xblockexpression;
  }

  private Map<String, EvolutionContext.FeatureOrigin> resolveFeatures(final String currentEntityName, final Iterable<String> currentFeatureNames) {
    HashMap<String, EvolutionContext.FeatureOrigin> _xblockexpression = null;
    {
      final HashMap<String, EvolutionContext.FeatureOrigin> resolvedFeatures = new HashMap<String, EvolutionContext.FeatureOrigin>();
      for (final String featureName : currentFeatureNames) {
        resolvedFeatures.put(featureName, this.resolveFeature(currentEntityName, featureName));
      }
      _xblockexpression = resolvedFeatures;
    }
    return _xblockexpression;
  }
}
