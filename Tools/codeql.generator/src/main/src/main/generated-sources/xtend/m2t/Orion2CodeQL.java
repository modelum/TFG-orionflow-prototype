package m2t;

import codeql.option.SeverityEnum;
import codeql.template.Metadata;
import codeql.template.attribute.AttributeQuery;
import codeql.template.entity.EntityQuery;
import codeql.template.feature.FeatureQuery;
import codeql.template.library.CallGraphImpactLibrary;
import codeql.template.library.DataFlowLibrary;
import codeql.template.library.JavaStructuralLibrary;
import codeql.template.library.JpaLibrary;
import codeql.template.library.Library;
import codeql.template.library.MongoLibrary;
import codeql.template.library.SpringCommonLibrary;
import codeql.template.relationship.RelationshipQuery;
import config.PersistenceFramework;
import es.um.uschema.xtext.orion.orion.AttributeCastOp;
import es.um.uschema.xtext.orion.orion.AttributePromoteOp;
import es.um.uschema.xtext.orion.orion.BasicOperation;
import es.um.uschema.xtext.orion.orion.EntityDeleteOp;
import es.um.uschema.xtext.orion.orion.EntityRenameOp;
import es.um.uschema.xtext.orion.orion.EntitySplitOp;
import es.um.uschema.xtext.orion.orion.EvolBlock;
import es.um.uschema.xtext.orion.orion.FeatureDeleteOp;
import es.um.uschema.xtext.orion.orion.FeatureMoveOp;
import es.um.uschema.xtext.orion.orion.FeatureRenameOp;
import es.um.uschema.xtext.orion.orion.MultipleFeatureSelector;
import es.um.uschema.xtext.orion.orion.OrionOperations;
import es.um.uschema.xtext.orion.orion.ReferenceCastOp;
import es.um.uschema.xtext.orion.orion.RelationshipDeleteOp;
import es.um.uschema.xtext.orion.orion.RelationshipRenameOp;
import es.um.uschema.xtext.orion.orion.SingleFeatureSelector;
import java.util.Arrays;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import org.eclipse.emf.common.util.EList;
import org.eclipse.xtend2.lib.StringConcatenation;
import org.eclipse.xtext.xbase.lib.Functions.Function1;
import org.eclipse.xtext.xbase.lib.IterableExtensions;
import org.eclipse.xtext.xbase.lib.ListExtensions;
import org.eclipse.xtext.xbase.lib.XbaseGenerated;
import orion.Mapper;

@SuppressWarnings("all")
public class Orion2CodeQL {
  private Map<String, String> results;

  private EvolutionContext evolutionContext;

  private PersistenceFramework framework;

  private int contOp = 0;

  public Orion2CodeQL() {
    this(PersistenceFramework.JPA);
  }

  public Orion2CodeQL(final PersistenceFramework framework) {
    PersistenceFramework _xifexpression = null;
    if ((framework == null)) {
      _xifexpression = PersistenceFramework.JPA;
    } else {
      _xifexpression = framework;
    }
    this.framework = _xifexpression;
    this.resetState();
  }

  public Map<String, String> m2t(final OrionOperations orion) {
    Map<String, String> _xblockexpression = null;
    {
      this.resetState();
      if (((!orion.getOperations().isEmpty()) || (!orion.getEvolBlocks().isEmpty()))) {
        this.results.put("orion_java.qll", JavaStructuralLibrary.generate().toString());
        this.results.put("orion_spring.qll", SpringCommonLibrary.generate().toString());
        this.results.put("orion_dataflow.qll", DataFlowLibrary.generate().toString());
        this.results.put("orion_callgraph.qll", CallGraphImpactLibrary.generate().toString());
        boolean _includesJpa = this.framework.includesJpa();
        if (_includesJpa) {
          this.results.put("orion_jpa.qll", JpaLibrary.generate().toString());
        }
        boolean _includesMongo = this.framework.includesMongo();
        if (_includesMongo) {
          this.results.put("orion_mongo.qll", MongoLibrary.generate().toString());
        }
        this.results.put("utils.qll", Library.generateUtils(this.framework).toString());
        String _name = orion.getName();
        String _plus = (_name + "-query-suite");
        this.results.put("suite.qls", Metadata.generateSuite(_plus).toString());
        this.results.put("codeql-pack.yml", Metadata.generateCodeQLPack(orion.getName()).toString());
      }
      boolean _isEmpty = orion.getOperations().isEmpty();
      boolean _not = (!_isEmpty);
      if (_not) {
        this.generateOperations(orion.getOperations());
      } else {
        EList<EvolBlock> _evolBlocks = orion.getEvolBlocks();
        for (final EvolBlock evolutionBlock : _evolBlocks) {
          this.generateOperations(evolutionBlock.getOperations());
        }
      }
      _xblockexpression = this.results;
    }
    return _xblockexpression;
  }

  private void resetState() {
    LinkedHashMap<String, String> _linkedHashMap = new LinkedHashMap<String, String>();
    this.results = _linkedHashMap;
    EvolutionContext _evolutionContext = new EvolutionContext();
    this.evolutionContext = _evolutionContext;
    this.contOp = 0;
  }

  public void generateOperations(final List<BasicOperation> operations) {
    for (final BasicOperation op : operations) {
      {
        this.generateOperation(op);
        this.contOp++;
      }
    }
  }

  protected Object _generateOperation(final BasicOperation op) {
    return Integer.valueOf(this.contOp--);
  }

  protected Object _generateOperation(final EntityDeleteOp op) {
    final String sourceEntityName = this.evolutionContext.resolveEntity(op.getSpec().getRef());
    String _plus = (Integer.valueOf(this.contOp) + "-EntityDeleteOp.ql");
    StringConcatenation _builder = new StringConcatenation();
    CharSequence _generateHeader = Metadata.generateHeader("Deleted Entity", "alert", SeverityEnum.WARNING.getValue(), ("java/orion/entity-deleted/" + Integer.valueOf(this.contOp)));
    _builder.append(_generateHeader);
    CharSequence _generateEntityDeleteOp = EntityQuery.generateEntityDeleteOp(sourceEntityName, this.framework);
    _builder.append(_generateEntityDeleteOp);
    this.results.put(_plus, _builder.toString());
    this.evolutionContext.deleteEntity(op.getSpec().getRef());
    return null;
  }

  protected Object _generateOperation(final EntityRenameOp op) {
    final String sourceEntityName = this.evolutionContext.resolveEntity(op.getSpec().getRef());
    String _plus = (Integer.valueOf(this.contOp) + "-EntityRenameOp.ql");
    StringConcatenation _builder = new StringConcatenation();
    CharSequence _generateHeader = Metadata.generateHeader("Renamed Entity", "alert", SeverityEnum.WARNING.getValue(), ("java/orion/entity-renamed/" + Integer.valueOf(this.contOp)));
    _builder.append(_generateHeader);
    CharSequence _generateEntityRenameOp = EntityQuery.generateEntityRenameOp(sourceEntityName, op.getSpec().getName(), this.framework);
    _builder.append(_generateEntityRenameOp);
    this.results.put(_plus, _builder.toString());
    this.evolutionContext.renameEntity(op.getSpec().getRef(), op.getSpec().getName());
    return null;
  }

  protected Object _generateOperation(final FeatureRenameOp op) {
    final SingleFeatureSelector selector = op.getSpec().getSelector();
    final EvolutionContext.FeatureOrigin sourceFeature = this.evolutionContext.resolveFeature(selector.getRef(), selector.getTarget());
    String _plus = (Integer.valueOf(this.contOp) + "-FeatureRenameOp.ql");
    StringConcatenation _builder = new StringConcatenation();
    CharSequence _generateHeader = Metadata.generateHeader("Feature Renamed", "alert", SeverityEnum.WARNING.getValue(), ("java/orion/feature-renamed/" + Integer.valueOf(this.contOp)));
    _builder.append(_generateHeader);
    CharSequence _generateFeatureRenameOp = FeatureQuery.generateFeatureRenameOp(sourceFeature.getEntityName(), sourceFeature.getFeatureName(), op.getSpec().getName(), this.framework);
    _builder.append(_generateFeatureRenameOp);
    this.results.put(_plus, _builder.toString());
    this.evolutionContext.renameFeature(selector.getRef(), selector.getTarget(), op.getSpec().getName());
    return null;
  }

  protected Object _generateOperation(final FeatureDeleteOp op) {
    final MultipleFeatureSelector selector = op.getSpec().getSelector();
    int targetCount = 0;
    EList<String> _targets = selector.getTargets();
    for (final String target : _targets) {
      {
        final EvolutionContext.FeatureOrigin sourceFeature = this.evolutionContext.resolveFeature(selector.getRef(), target);
        String _plus = (Integer.valueOf(this.contOp) + "-");
        String _plus_1 = (_plus + Integer.valueOf(targetCount));
        String _plus_2 = (_plus_1 + "-FeatureDeleteOp.ql");
        StringConcatenation _builder = new StringConcatenation();
        CharSequence _generateHeader = Metadata.generateHeader("Feature Deleted", "alert", SeverityEnum.WARNING.getValue(), ((("java/orion/feature-deleted/" + Integer.valueOf(this.contOp)) + "/") + Integer.valueOf(targetCount)));
        _builder.append(_generateHeader);
        CharSequence _generateFeatureDeleteOp = FeatureQuery.generateFeatureDeleteOp(sourceFeature.getEntityName(), sourceFeature.getFeatureName(), this.framework);
        _builder.append(_generateFeatureDeleteOp);
        this.results.put(_plus_2, _builder.toString());
        this.evolutionContext.deleteFeature(selector.getRef(), target);
        targetCount++;
      }
    }
    return null;
  }

  protected Object _generateOperation(final AttributeCastOp op) {
    int _xblockexpression = (int) 0;
    {
      final MultipleFeatureSelector selector = op.getSpec().getSelector();
      final String type = Mapper.OrionType2Java(op.getSpec().getType().getTypename());
      int targetCount = 0;
      int _xifexpression = (int) 0;
      boolean _isEmpty = type.isEmpty();
      boolean _not = (!_isEmpty);
      if (_not) {
        EList<String> _targets = selector.getTargets();
        for (final String target : _targets) {
          {
            final EvolutionContext.FeatureOrigin sourceFeature = this.evolutionContext.resolveFeature(selector.getRef(), target);
            String _plus = (Integer.valueOf(this.contOp) + "-");
            String _plus_1 = (_plus + Integer.valueOf(targetCount));
            String _plus_2 = (_plus_1 + "-AttributeCastOp.ql");
            StringConcatenation _builder = new StringConcatenation();
            CharSequence _generateHeader = Metadata.generateHeader("Attribute Casted", "alert", SeverityEnum.WARNING.getValue(), ((("java/orion/attribute-casted/" + Integer.valueOf(this.contOp)) + "/") + Integer.valueOf(targetCount)));
            _builder.append(_generateHeader);
            CharSequence _generateAttributeCastOp = AttributeQuery.generateAttributeCastOp(sourceFeature.getEntityName(), sourceFeature.getFeatureName(), type, this.framework);
            _builder.append(_generateAttributeCastOp);
            this.results.put(_plus_2, _builder.toString());
            targetCount++;
          }
        }
      } else {
        _xifexpression = this.contOp--;
      }
      _xblockexpression = _xifexpression;
    }
    return Integer.valueOf(_xblockexpression);
  }

  protected Object _generateOperation(final AttributePromoteOp op) {
    String _xblockexpression = null;
    {
      final MultipleFeatureSelector selector = op.getSpec().getSelector();
      final String sourceEntityName = this.evolutionContext.resolveEntity(selector.getRef());
      final Function1<String, String> _function = (String it) -> {
        return this.evolutionContext.resolveFeature(selector.getRef(), it).getFeatureName();
      };
      final String fields = IterableExtensions.join(ListExtensions.<String, String>map(selector.getTargets(), _function), ",");
      String _plus = (Integer.valueOf(this.contOp) + "-AttributePromoteOp.ql");
      StringConcatenation _builder = new StringConcatenation();
      CharSequence _generateHeader = Metadata.generateHeader("Attribute Promoted", "alert", SeverityEnum.WARNING.getValue(), ("java/orion/attribute-promoted/" + Integer.valueOf(this.contOp)));
      _builder.append(_generateHeader);
      CharSequence _generateAttributePromoteOp = AttributeQuery.generateAttributePromoteOp(sourceEntityName, fields, this.framework);
      _builder.append(_generateAttributePromoteOp);
      _xblockexpression = this.results.put(_plus, _builder.toString());
    }
    return _xblockexpression;
  }

  protected Object _generateOperation(final RelationshipDeleteOp op) {
    final String sourceRelationshipName = this.evolutionContext.resolveRelationship(op.getSpec().getRef());
    String _plus = (Integer.valueOf(this.contOp) + "-RelationshipDeleteOp.ql");
    StringConcatenation _builder = new StringConcatenation();
    CharSequence _generateHeader = Metadata.generateHeader("Relationship Deleted", "alert", SeverityEnum.WARNING.getValue(), ("java/orion/relationship-deleted/" + Integer.valueOf(this.contOp)));
    _builder.append(_generateHeader);
    CharSequence _generateRelationshipDeleteOp = RelationshipQuery.generateRelationshipDeleteOp(sourceRelationshipName, this.framework);
    _builder.append(_generateRelationshipDeleteOp);
    this.results.put(_plus, _builder.toString());
    this.evolutionContext.deleteRelationship(op.getSpec().getRef());
    return null;
  }

  protected Object _generateOperation(final RelationshipRenameOp op) {
    final String sourceRelationshipName = this.evolutionContext.resolveRelationship(op.getSpec().getRef());
    String _plus = (Integer.valueOf(this.contOp) + "-RelationshipRenameOp.ql");
    StringConcatenation _builder = new StringConcatenation();
    CharSequence _generateHeader = Metadata.generateHeader("Relationship Renamed", "alert", SeverityEnum.WARNING.getValue(), ("java/orion/relationship-renamed/" + Integer.valueOf(this.contOp)));
    _builder.append(_generateHeader);
    CharSequence _generateRelationshipRenameOp = RelationshipQuery.generateRelationshipRenameOp(sourceRelationshipName, op.getSpec().getName(), this.framework);
    _builder.append(_generateRelationshipRenameOp);
    this.results.put(_plus, _builder.toString());
    this.evolutionContext.renameRelationship(op.getSpec().getRef(), op.getSpec().getName());
    return null;
  }

  protected Object _generateOperation(final EntitySplitOp op) {
    final String sourceEntityName = this.evolutionContext.resolveEntity(op.getSpec().getRef());
    String _plus = (Integer.valueOf(this.contOp) + "-EntitySplitOp.ql");
    StringConcatenation _builder = new StringConcatenation();
    CharSequence _generateHeader = Metadata.generateHeader("Split Entity", "alert", SeverityEnum.WARNING.getValue(), ("java/orion/entity-splited/" + Integer.valueOf(this.contOp)));
    _builder.append(_generateHeader);
    CharSequence _generateEntitySplitOp = EntityQuery.generateEntitySplitOp(sourceEntityName, this.framework);
    _builder.append(_generateEntitySplitOp);
    this.results.put(_plus, _builder.toString());
    this.evolutionContext.splitEntity(
      op.getSpec().getRef(), 
      op.getSpec().getName1(), 
      op.getSpec().getFeatures1().getFeatures(), 
      op.getSpec().getName2(), 
      op.getSpec().getFeatures2().getFeatures());
    return null;
  }

  protected Object _generateOperation(final FeatureMoveOp op) {
    final SingleFeatureSelector sourceSelector = op.getSpec().getSourceSelector();
    final SingleFeatureSelector targetSelector = op.getSpec().getTargetSelector();
    final EvolutionContext.FeatureOrigin sourceFeature = this.evolutionContext.resolveFeature(sourceSelector.getRef(), sourceSelector.getTarget());
    String _plus = (Integer.valueOf(this.contOp) + "-FeatureMoveOp.ql");
    StringConcatenation _builder = new StringConcatenation();
    CharSequence _generateHeader = Metadata.generateHeader("Feature Moved", "alert", SeverityEnum.WARNING.getValue(), ("java/orion/feature-moved/" + Integer.valueOf(this.contOp)));
    _builder.append(_generateHeader);
    CharSequence _generateFeatureMoveOp = FeatureQuery.generateFeatureMoveOp(sourceFeature.getEntityName(), sourceFeature.getFeatureName(), targetSelector.getRef(), targetSelector.getTarget(), this.framework);
    _builder.append(_generateFeatureMoveOp);
    this.results.put(_plus, _builder.toString());
    this.evolutionContext.moveFeature(
      sourceSelector.getRef(), 
      sourceSelector.getTarget(), 
      targetSelector.getRef(), 
      targetSelector.getTarget());
    return null;
  }

  protected Object _generateOperation(final ReferenceCastOp op) {
    int _xblockexpression = (int) 0;
    {
      final MultipleFeatureSelector selector = op.getSpec().getSelector();
      final String type = Mapper.OrionType2Java(op.getSpec().getType().getTypename());
      int targetCount = 0;
      int _xifexpression = (int) 0;
      boolean _isEmpty = type.isEmpty();
      boolean _not = (!_isEmpty);
      if (_not) {
        EList<String> _targets = selector.getTargets();
        for (final String target : _targets) {
          {
            final EvolutionContext.FeatureOrigin sourceFeature = this.evolutionContext.resolveFeature(selector.getRef(), target);
            String _plus = (Integer.valueOf(this.contOp) + "-");
            String _plus_1 = (_plus + Integer.valueOf(targetCount));
            String _plus_2 = (_plus_1 + "-ReferenceCastOp.ql");
            StringConcatenation _builder = new StringConcatenation();
            CharSequence _generateHeader = Metadata.generateHeader("Reference Casted", "alert", SeverityEnum.WARNING.getValue(), ((("java/orion/reference-casted/" + Integer.valueOf(this.contOp)) + "/") + Integer.valueOf(targetCount)));
            _builder.append(_generateHeader);
            CharSequence _generateReferenceCastOp = AttributeQuery.generateReferenceCastOp(sourceFeature.getEntityName(), sourceFeature.getFeatureName(), type, this.framework);
            _builder.append(_generateReferenceCastOp);
            this.results.put(_plus_2, _builder.toString());
            targetCount++;
          }
        }
      } else {
        _xifexpression = this.contOp--;
      }
      _xblockexpression = _xifexpression;
    }
    return Integer.valueOf(_xblockexpression);
  }

  @XbaseGenerated
  public Object generateOperation(final BasicOperation op) {
    if (op instanceof EntityDeleteOp) {
      return _generateOperation((EntityDeleteOp)op);
    } else if (op instanceof EntityRenameOp) {
      return _generateOperation((EntityRenameOp)op);
    } else if (op instanceof EntitySplitOp) {
      return _generateOperation((EntitySplitOp)op);
    } else if (op instanceof RelationshipDeleteOp) {
      return _generateOperation((RelationshipDeleteOp)op);
    } else if (op instanceof RelationshipRenameOp) {
      return _generateOperation((RelationshipRenameOp)op);
    } else if (op instanceof AttributeCastOp) {
      return _generateOperation((AttributeCastOp)op);
    } else if (op instanceof AttributePromoteOp) {
      return _generateOperation((AttributePromoteOp)op);
    } else if (op instanceof FeatureDeleteOp) {
      return _generateOperation((FeatureDeleteOp)op);
    } else if (op instanceof FeatureMoveOp) {
      return _generateOperation((FeatureMoveOp)op);
    } else if (op instanceof FeatureRenameOp) {
      return _generateOperation((FeatureRenameOp)op);
    } else if (op instanceof ReferenceCastOp) {
      return _generateOperation((ReferenceCastOp)op);
    } else if (op != null) {
      return _generateOperation(op);
    } else {
      throw new IllegalArgumentException("Unhandled parameter types: " +
        Arrays.<Object>asList(op).toString());
    }
  }
}
