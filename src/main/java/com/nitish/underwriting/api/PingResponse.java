package com.nitish.underwriting.api;

import java.time.Instant;
import java.util.List;

/**
 * Response for GET /api/ping.
 *
 **/
public record PingResponse(
        String status,
        String application,
        String javaVersion,
        Instant timestamp,
        List<String> activeProfiles
) {}
