package com.nitish.underwriting.api;

import java.time.Instant;
import java.util.List;

/**
 * Response for GET /api/ping.
 *
 * EXERCISE 1.1 (Day 1): add a field {@code List<String> activeProfiles}
 * populated from Spring's {@code Environment}. The Day 1 verification script
 * checks for it, so you cannot pass Day 1 without doing it.
 */
public record PingResponse(
        String status,
        String application,
        String javaVersion,
        Instant timestamp,
        List<String> activeProfiles
) {}
