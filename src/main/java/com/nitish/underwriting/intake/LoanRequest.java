package com.nitish.underwriting.intake;


import java.math.BigDecimal;

public record LoanRequest(
        String applicantName,
        BigDecimal requestedAmount,
        String purpose,
        Integer termMonths
) {}
