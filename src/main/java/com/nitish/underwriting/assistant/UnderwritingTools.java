package com.nitish.underwriting.assistant;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.List;
import java.util.Locale;
import java.util.NoSuchElementException;
import java.util.concurrent.CopyOnWriteArrayList;
import java.util.regex.Pattern;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.ai.tool.annotation.Tool;
import org.springframework.ai.tool.annotation.ToolParam;

/**
 * Tools the model may ASK us to run. One instance per request, NOT a Spring bean:
 * it records exactly which calls this request made, with no shared mutable state.
 * <p>
 * Everything the model passes in is untrusted input: validate it like a public API.
 * Exception messages are sent back to the model (and to OpenAI under that profile):
 * keep them short and free of internals and PII.
 */
public class UnderwritingTools {

    private static final Logger log = LoggerFactory.getLogger(UnderwritingTools.class);
    private static final Pattern APPLICANT_ID = Pattern.compile("APP-\\d{4}");

    private final CreditBureau bureau;
    private final String conversationId;
    private final List<ToolCallRecord> calls = new CopyOnWriteArrayList<>();

    public UnderwritingTools(CreditBureau bureau, String conversationId) {
        this.bureau = bureau;
        this.conversationId = conversationId;
    }

    /**
     * Trim, upper-case and cap the length: a model-supplied string shouldn't flood logs or errors.
     */
    private static String normalise(String raw) {
        String s = raw == null ? "" : raw.strip().toUpperCase(Locale.ROOT);
        return s.length() > 20 ? s.substring(0, 20) : s;
    }

    @Tool(description = """
            Look up an applicant's current credit score from the credit bureau.
            Use it for every question about a credit score. Never guess a score.""")
    public CreditScore getCreditScore(
            @ToolParam(description = "Applicant ID in the format APP-1234") String applicantId) {
        String id = normalise(applicantId);
        try {
            if (!APPLICANT_ID.matcher(id).matches()) {
                throw new IllegalArgumentException("applicantId must look like APP-1234");
            }
            CreditScore score = bureau.lookup(id)
                    .orElseThrow(() -> new NoSuchElementException("No credit file found for " + id));
            record("getCreditScore", id, "OK");
            return score;
        } catch (RuntimeException e) {
            record("getCreditScore", id, "ERROR: " + e.getMessage());
            throw e;   // the message goes back to the model, which can then say what failed
        }
    }

    @Tool(description = """
            Calculate the debt-to-income (DTI) ratio as a percentage, rounded to 2 decimals.
            Use it whenever a DTI is needed. Never calculate DTI yourself.""")
    public BigDecimal calculateDebtToIncome(
            @ToolParam(description = "Total monthly debt payments in dollars") BigDecimal monthlyDebtPayments,
            @ToolParam(description = "Gross monthly income in dollars") BigDecimal grossMonthlyIncome) {
        String args = monthlyDebtPayments + " / " + grossMonthlyIncome;
        try {
            if (monthlyDebtPayments == null || monthlyDebtPayments.signum() < 0) {
                throw new IllegalArgumentException("monthlyDebtPayments must be 0 or more");
            }
            if (grossMonthlyIncome == null || grossMonthlyIncome.signum() <= 0) {
                throw new IllegalArgumentException("grossMonthlyIncome must be more than 0");
            }
            BigDecimal dti = monthlyDebtPayments.multiply(BigDecimal.valueOf(100))
                    .divide(grossMonthlyIncome, 2, RoundingMode.HALF_UP);
            record("calculateDebtToIncome", args, "OK");
            return dti;
        } catch (RuntimeException e) {
            record("calculateDebtToIncome", args, "ERROR: " + e.getMessage());
            throw e;
        }
    }

    public List<ToolCallRecord> calls() {
        return List.copyOf(calls);
    }

    private void record(String tool, String arguments, String outcome) {
        calls.add(new ToolCallRecord(tool, arguments, outcome));
        // Tool name and outcome only. Never the score or the amounts: that's personal financial data.
        log.info("tool={} outcome={} conversation={}", tool, outcome.startsWith("OK") ? "OK" : "ERROR", conversationId);
    }
}
