package com.nitish.underwriting.ai;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import org.junit.jupiter.api.Test;

class AiProviderGuardTest {

    @Test
    void acceptsExactlyOneProvider() {
        assertThat(AiProviderGuard.requireExactlyOneProvider("local")).isEqualTo("local");
        assertThat(AiProviderGuard.requireExactlyOneProvider("openai")).isEqualTo("openai");
        assertThat(AiProviderGuard.requireExactlyOneProvider("test", "local")).isEqualTo("local");
    }

    @Test
    void rejectsNoProvider() {
        assertThatThrownBy(AiProviderGuard::requireExactlyOneProvider)
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("--spring.profiles.active=local");
        assertThatThrownBy(() -> AiProviderGuard.requireExactlyOneProvider("test"))
                .isInstanceOf(IllegalStateException.class);
    }

    @Test
    void rejectsTwoProviders() {
        assertThatThrownBy(() -> AiProviderGuard.requireExactlyOneProvider("local", "openai"))
                .isInstanceOf(IllegalStateException.class);
    }
}
