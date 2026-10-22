package com.nitish.underwriting.api;

import java.time.Instant;
import java.util.Arrays;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.env.Environment;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * Smoke-test endpoint. Proves the app boots and serves HTTP.
 * This is the ONLY endpoint on Day 1. No AI code yet.
 */
@RestController
@RequestMapping("/api")
public class PingController {

    private final String applicationName;
    private final Environment environment;

    // Constructor injection: no @Autowired fields anywhere in this project.
    public PingController(@Value("${spring.application.name}") String applicationName, Environment environment) {
        this.applicationName = applicationName;
        this.environment = environment;
    }

    @GetMapping("/ping")
    public PingResponse ping() {
        return new PingResponse(
                "UP",
                applicationName,
                Runtime.version().toString(),
                Instant.now(),
                Arrays.asList(environment.getActiveProfiles())
        );
    }
}
