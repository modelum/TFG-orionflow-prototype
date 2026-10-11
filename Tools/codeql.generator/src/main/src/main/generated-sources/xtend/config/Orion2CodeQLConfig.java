package config;

import java.nio.file.Path;
import org.apache.commons.cli.CommandLine;
import org.apache.commons.cli.DefaultParser;
import org.apache.commons.cli.HelpFormatter;
import org.apache.commons.cli.Option;
import org.apache.commons.cli.Options;
import org.eclipse.xtext.xbase.lib.Exceptions;

@SuppressWarnings("all")
public class Orion2CodeQLConfig {
  private Path inputScript;

  private Path outputPath = Path.of(".");

  private PersistenceFramework framework = PersistenceFramework.JPA;

  private boolean helpRequested;

  private final Options options;

  /**
   * Constructor que parsea los argumentos de línea de comandos.
   *   -h / --help      Muestra la ayuda
   *   -i / --input     Ruta al fichero .orion
   *   -o / --output    Ruta de salida (opcional)
   */
  public Orion2CodeQLConfig(final String[] args) {
    this.options = Orion2CodeQLConfig.createOptions();
    try {
      DefaultParser _defaultParser = new DefaultParser();
      String[] _xifexpression = null;
      if ((args == null)) {
        _xifexpression = new String[] {};
      } else {
        _xifexpression = args;
      }
      final CommandLine cmd = _defaultParser.parse(this.options, _xifexpression);
      this.helpRequested = cmd.hasOption("h");
      if (((!this.helpRequested) && (!cmd.hasOption("i")))) {
        throw new IllegalArgumentException("Missing required option: -i/--input");
      }
      boolean _hasOption = cmd.hasOption("i");
      if (_hasOption) {
        this.inputScript = Path.of(cmd.getOptionValue("i"));
      }
      boolean _hasOption_1 = cmd.hasOption("o");
      if (_hasOption_1) {
        this.outputPath = Path.of(cmd.getOptionValue("o"));
      }
      boolean _hasOption_2 = cmd.hasOption("framework");
      if (_hasOption_2) {
        this.framework = PersistenceFramework.parse(cmd.getOptionValue("framework"));
      }
      boolean _hasOption_3 = cmd.hasOption("a");
      if (_hasOption_3) {
        final String requested = cmd.getOptionValue("a");
        if (((requested == null) || (!requested.trim().equalsIgnoreCase("ALL")))) {
          throw new IllegalArgumentException(
            ((("Unsupported analysis \'" + requested) + 
              "\'. Only the deprecated compatibility value ALL is accepted; ") + 
              "analysis rules are now selected automatically."));
        }
      }
    } catch (final Throwable _t) {
      if (_t instanceof IllegalArgumentException) {
        final IllegalArgumentException exception = (IllegalArgumentException)_t;
        throw exception;
      } else if (_t instanceof Exception) {
        final Exception exception_1 = (Exception)_t;
        String _message = exception_1.getMessage();
        throw new IllegalArgumentException(_message, exception_1);
      } else {
        throw Exceptions.sneakyThrow(_t);
      }
    }
  }

  private static Options createOptions() {
    Options _xblockexpression = null;
    {
      final Options result = new Options();
      result.addOption(Option.builder("h").longOpt("help").desc("Prints help").build());
      result.addOption(
        Option.builder("i").longOpt("input").desc("Path to an Orion script file (.orion)").hasArg().argName("orion_file").build());
      result.addOption(
        Option.builder("o").longOpt("output").desc("Path to an output folder (default: current directory)").hasArg().argName("output_folder").build());
      result.addOption(
        Option.builder("f").longOpt("framework").desc("Persistence adapters: jpa (default), mongo or both").hasArg().argName("jpa|mongo|both").build());
      result.addOption(
        Option.builder("a").longOpt("analysis").desc("Deprecated compatibility alias; only ALL is accepted and has no effect").hasArg().argName("ALL").build());
      _xblockexpression = result;
    }
    return _xblockexpression;
  }

  public Path setInputScript(final Path inputScript) {
    return this.inputScript = inputScript;
  }

  public Path getInputScript() {
    return this.inputScript;
  }

  public Path setOutputPath(final Path outputPath) {
    return this.outputPath = outputPath;
  }

  public Path getOutputPath() {
    return this.outputPath;
  }

  public PersistenceFramework getFramework() {
    return this.framework;
  }

  public boolean isHelpRequested() {
    return this.helpRequested;
  }

  public void printHelp() {
    new HelpFormatter().printHelp("orionflow-codeql", this.options);
  }
}
