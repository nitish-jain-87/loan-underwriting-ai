package com.nitish.underwriting.assistant;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.math.BigDecimal;
import java.util.NoSuchElementException;

import org.junit.jupiter.api.Test;

class UnderwritingToolsTest {

    private final UnderwritingTools tools = new UnderwritingTools(new CreditBureau(), "test-conversation");

    @Test
    void knownApplicantReturnsTheBureauScoreAndIsRecorded() {
        assertThat(tools.getCreditScore("APP-1001").score()).isEqualTo(712);
        assertThat(tools.calls()).hasSize(1);
        assertThat(tools.calls().getFirst().tool()).isEqualTo("getCreditScore");
        assertThat(tools.calls().getFirst().outcome()).isEqualTo("OK");
    }

    @Test
    void modelSuppliedIdIsNormalised() {
        assertThat(tools.getCreditScore("  app-1002 ").score()).isEqualTo(584);
    }

    @Test
    void unknownApplicantFailsAndTheFailureIsRecorded() {
        assertThatThrownBy(() -> tools.getCreditScore("APP-9999"))
                .isInstanceOf(NoSuchElementException.class);
        assertThat(tools.calls().getFirst().outcome()).startsWith("ERROR");
    }

    @Test
    void malformedIdIsRejectedBeforeAnyLookup() {
        assertThatThrownBy(() -> tools.getCreditScore("1001' OR '1'='1"))
                .isInstanceOf(IllegalArgumentException.class);
    }

    @Test
    void dtiIsComputedInJava() {
        assertThat(tools.calculateDebtToIncome(new BigDecimal("2100"), new BigDecimal("6000")))
                .isEqualByComparingTo("35.00");
    }

    @Test
    void dtiRejectsZeroIncome() {
        assertThatThrownBy(() -> tools.calculateDebtToIncome(BigDecimal.ONE, BigDecimal.ZERO))
                .isInstanceOf(IllegalArgumentException.class);
    }
}