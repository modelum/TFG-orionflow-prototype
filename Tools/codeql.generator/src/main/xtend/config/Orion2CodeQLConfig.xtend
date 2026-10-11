package config

import java.nio.file.Path
import org.apache.commons.cli.DefaultParser
import org.apache.commons.cli.HelpFormatter
import org.apache.commons.cli.Option
import org.apache.commons.cli.Options

class Orion2CodeQLConfig {
	Path inputScript
	Path outputPath = Path.of(".")
	PersistenceFramework framework = PersistenceFramework.JPA
	boolean helpRequested
	val Options options
  
  	/**
   	* Constructor que parsea los argumentos de línea de comandos.
   	*   -h / --help      Muestra la ayuda
   	*   -i / --input     Ruta al fichero .orion
   	*   -o / --output    Ruta de salida (opcional)
   	*/
	new(String[] args) {
		options = createOptions()
		try {
			val cmd = new DefaultParser().parse(options, if (args === null) #[] else args)
			helpRequested = cmd.hasOption("h")

			if (!helpRequested && !cmd.hasOption("i"))
				throw new IllegalArgumentException("Missing required option: -i/--input")

			if (cmd.hasOption("i"))
				inputScript = Path.of(cmd.getOptionValue("i"))
			if (cmd.hasOption("o"))
				outputPath = Path.of(cmd.getOptionValue("o"))
			if (cmd.hasOption("framework"))
				framework = PersistenceFramework.parse(cmd.getOptionValue("framework"))

			if (cmd.hasOption("a")) {
				val requested = cmd.getOptionValue("a")
				if (requested === null || !requested.trim.equalsIgnoreCase("ALL"))
					throw new IllegalArgumentException(
						"Unsupported analysis '" + requested +
						"'. Only the deprecated compatibility value ALL is accepted; " +
						"analysis rules are now selected automatically."
					)
			}
		} catch (IllegalArgumentException exception) {
			throw exception
		} catch (Exception exception) {
			throw new IllegalArgumentException(exception.message, exception)
		}
	}

	private static def Options createOptions() {
		val result = new Options
		result.addOption(Option.builder("h").longOpt("help").desc("Prints help").build())
		result.addOption(Option.builder("i").longOpt("input")
			.desc("Path to an Orion script file (.orion)")
			.hasArg().argName("orion_file").build())
		result.addOption(Option.builder("o").longOpt("output")
			.desc("Path to an output folder (default: current directory)")
			.hasArg().argName("output_folder").build())
		result.addOption(Option.builder("f").longOpt("framework")
			.desc("Persistence adapters: jpa (default), mongo or both")
			.hasArg().argName("jpa|mongo|both").build())
		result.addOption(Option.builder("a").longOpt("analysis")
			.desc("Deprecated compatibility alias; only ALL is accepted and has no effect")
			.hasArg().argName("ALL").build())
		result
	}

  	def setInputScript(Path inputScript) {
    	this.inputScript = inputScript
  	}

  	def Path getInputScript() {
    	return this.inputScript
  	}

  	def setOutputPath(Path outputPath) {
    	this.outputPath = outputPath
  	}

  	def Path getOutputPath() {
    	return this.outputPath
  	}

	def PersistenceFramework getFramework() {
		return this.framework
	}

	def boolean isHelpRequested() {
		helpRequested
	}

	def void printHelp() {
		new HelpFormatter().printHelp("orionflow-codeql", options)
	}
		
}
