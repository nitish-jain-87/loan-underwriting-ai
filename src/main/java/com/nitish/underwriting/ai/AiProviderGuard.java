package com.nitish.underwriting.ai;

import java.util.Arrays;
import java.util.List;
import java.util.Set;

/**
 * Exactly one AI provider profile must be active. Anything else is a deployment error,
 * and it must fail at startup with a message that names the fix: never at the first
 * request, and never by silently picking a provider (that could send PII to a third party).
 */
public final class AiProviderGuard {

    static final Set<String> PROVIDER_PROFILES = Set.of("local", "openai");

    private AiProviderGuard() {
    }

    /** Returns the single active provider profile, or throws. */
    public static String requireExactlyOneProvider(String... activeProfiles) {
        List<String> providers = Arrays.stream(activeProfiles)
                .filter(PROVIDER_PROFILES::contains)
                .distinct()
                .toList();
        if (providers.size() != 1) {
            throw new IllegalStateException(
                    "Exactly one AI provider profile must be active (one of " + PROVIDER_PROFILES
                            + "), but active profiles are " + Arrays.toString(activeProfiles)
                            + ". Start with --spring.profiles.active=local (Ollama) or openai.");
        }
        return providers.getFirst();
    }
}
