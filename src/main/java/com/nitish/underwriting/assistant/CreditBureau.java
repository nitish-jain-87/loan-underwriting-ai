package com.nitish.underwriting.assistant;

import java.util.Map;
import java.util.Optional;

import org.springframework.stereotype.Component;

/**
 * Fake credit bureau, fake data. The scores are deliberately specific numbers a model can't
 * guess, so an answer that contains one proves the tool really ran.
 */
@Component
public class CreditBureau {

    private static final Map<String, CreditScore> FILES = Map.of(
            "APP-1001", new CreditScore("APP-1001", 712, "2026-11-01"),
            "APP-1002", new CreditScore("APP-1002", 584, "2026-11-01"),
            "APP-1003", new CreditScore("APP-1003", 655, "2026-11-01"));

    public Optional<CreditScore> lookup(String applicantId) {
        return Optional.ofNullable(FILES.get(applicantId));
    }
}