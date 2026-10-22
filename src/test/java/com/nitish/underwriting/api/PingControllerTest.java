package com.nitish.underwriting.api;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;

/**
 * Plain unit test, no Spring context. Fast.
 * When you do Exercise 1.1, update this test to cover activeProfiles.
 */
class PingControllerTest {

    @Test
    void pingReportsUp() {
        PingController controller = new PingController("loan-underwriting-ai");

        PingResponse response = controller.ping();

        assertThat(response.status()).isEqualTo("UP");
        assertThat(response.application()).isEqualTo("loan-underwriting-ai");
        assertThat(response.javaVersion()).startsWith("21");
        assertThat(response.timestamp()).isNotNull();
    }
}
