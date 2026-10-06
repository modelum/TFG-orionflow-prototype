package config;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import org.junit.jupiter.api.Test;

class AnalysisModeTest {

    @Test
    void defaultsToStructuralSemantic() {
        assertEquals(AnalysisMode.STRUCTURAL_SEMANTIC, AnalysisMode.parse(null));
        assertEquals(AnalysisMode.STRUCTURAL_SEMANTIC, AnalysisMode.parse("  "));
    }

    @Test
    void parsesCaseAndDashVariants() {
        assertEquals(AnalysisMode.STRUCTURAL, AnalysisMode.parse("structural"));
        assertEquals(AnalysisMode.STRUCTURAL_SEMANTIC,
            AnalysisMode.parse("structural-semantic"));
        assertEquals(AnalysisMode.DATAFLOW, AnalysisMode.parse("dataflow"));
    }

    @Test
    void exposesCapabilities() {
        assertFalse(AnalysisMode.STRUCTURAL.includesSemantic());
        assertFalse(AnalysisMode.STRUCTURAL_SEMANTIC.includesDataFlow());
        assertTrue(AnalysisMode.DATAFLOW.includesSemantic());
        assertTrue(AnalysisMode.DATAFLOW.includesDataFlow());
    }

    @Test
    void rejectsUnknownMode() {
        assertThrows(IllegalArgumentException.class, () -> AnalysisMode.parse("everything"));
    }
}
