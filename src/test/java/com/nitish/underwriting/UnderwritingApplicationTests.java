package com.nitish.underwriting;

import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;

@SpringBootTest
@ActiveProfiles("local")
class UnderwritingApplicationTests {

    @Test
    void contextLoads() {
        // Fails if the Spring context can't start (bad config, missing bean, etc.).
    }
}
