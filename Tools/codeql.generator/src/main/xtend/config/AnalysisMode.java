package config;

import java.util.Locale;

/** Controls the amount of impact analysis emitted by the generator. */
public enum AnalysisMode {
    STRUCTURAL(false, false),
    STRUCTURAL_SEMANTIC(true, false),
    DATAFLOW(true, true);

    private final boolean semantic;
    private final boolean dataFlow;

    AnalysisMode(boolean semantic, boolean dataFlow) {
        this.semantic = semantic;
        this.dataFlow = dataFlow;
    }

    public boolean includesSemantic() {
        return semantic;
    }

    public boolean includesDataFlow() {
        return dataFlow;
    }

    public static AnalysisMode parse(String value) {
        if (value == null || value.trim().isEmpty()) {
            return STRUCTURAL_SEMANTIC;
        }

        String normalized = value.trim().toUpperCase(Locale.ROOT).replace('-', '_');
        return AnalysisMode.valueOf(normalized);
    }
}
