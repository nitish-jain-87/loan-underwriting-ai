package com.nitish.underwriting;

import static org.assertj.core.api.Assertions.assertThatThrownBy;

import org.junit.jupiter.api.Test;
import org.springframework.boot.WebApplicationType;
import org.springframework.boot.builder.SpringApplicationBuilder;

/** Proves the real application, not just the guard class, refuses to start without a provider. */
class StartupFailFastTest {

    @Test
    void applicationRefusesToStartWithoutProviderProfile() {
        assertThatThrownBy(() -> new SpringApplicationBuilder(UnderwritingApplication.class)
                .web(WebApplicationType.NONE)
                .run())
                .rootCause()
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("Exactly one AI provider profile");
    }
}
