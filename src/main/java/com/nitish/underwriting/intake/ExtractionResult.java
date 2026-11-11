package com.nitish.underwriting.intake;

public record ExtractionResult(
        boolean ok,
        LoanRequest result,
        String error,
        String rawOutput,
        String model,
        Integer promptTokens,
        Integer completionTokens,
        long latencyMs
) {
    static ExtractionResult success(LoanRequest r, String model, Integer in, Integer out, long ms) {
        return new ExtractionResult(true, r, null, null, model, in, out, ms);
    }

    static ExtractionResult failure(String error, String raw, String model, Integer in, Integer out, long ms) {
        return new ExtractionResult(false, null, error, raw, model, in, out, ms);
    }
}
