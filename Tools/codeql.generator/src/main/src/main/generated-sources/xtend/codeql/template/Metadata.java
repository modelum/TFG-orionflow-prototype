package codeql.template;

import org.eclipse.xtend2.lib.StringConcatenation;
import util.StringUtilities;

@SuppressWarnings("all")
public class Metadata {
  public static CharSequence generateHeader(final String name, final String kind, final String severity, final String id) {
    StringConcatenation _builder = new StringConcatenation();
    _builder.append("/**");
    _builder.newLine();
    _builder.append(" ");
    _builder.append("* This is an automatically generated file");
    _builder.newLine();
    _builder.append(" ");
    _builder.append("*");
    _builder.newLine();
    _builder.append(" ");
    _builder.append("* @name ");
    _builder.append(name, " ");
    _builder.newLineIfNotEmpty();
    _builder.append(" ");
    _builder.append("* @kind ");
    _builder.append(kind, " ");
    _builder.newLineIfNotEmpty();
    _builder.append(" ");
    _builder.append("* @problem.severity ");
    _builder.append(severity, " ");
    _builder.newLineIfNotEmpty();
    _builder.append(" ");
    _builder.append("* @id ");
    _builder.append(id, " ");
    _builder.newLineIfNotEmpty();
    _builder.append(" ");
    _builder.append("*/");
    _builder.newLine();
    _builder.append(" ");
    _builder.newLine();
    return _builder;
  }

  public static CharSequence generateCodeQLPack(final String name) {
    StringConcatenation _builder = new StringConcatenation();
    _builder.append("# This is an automatically generated file.");
    _builder.newLine();
    _builder.append("name: ");
    String _replaceUnderscoreWithDash = StringUtilities.replaceUnderscoreWithDash(name.toLowerCase());
    _builder.append(_replaceUnderscoreWithDash);
    _builder.append("-queries");
    _builder.newLineIfNotEmpty();
    _builder.append("version: 0.0.0");
    _builder.newLine();
    _builder.append("dependencies:");
    _builder.newLine();
    _builder.append("  ");
    _builder.append("codeql/java-all: \"*\"");
    _builder.newLine();
    _builder.append("extractor: java");
    _builder.newLine();
    return _builder;
  }

  public static CharSequence generateSuite(final String name) {
    StringConcatenation _builder = new StringConcatenation();
    _builder.append("- description: ");
    _builder.append(name);
    _builder.newLineIfNotEmpty();
    _builder.append("- queries: .");
    _builder.newLine();
    return _builder;
  }
}
