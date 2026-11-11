package com.nitish.underwriting.ai;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.ai.chat.client.ChatClient;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.env.Environment;

@Configuration
public class AiConfig {

    private static final Logger log = LoggerFactory.getLogger(AiConfig.class);

    /**
     * The guard runs BEFORE the builder is requested (ObjectProvider is lazy). Otherwise,
     * with no provider active, you'd get a cryptic "no ChatClient.Builder bean" error
     * instead of a message that tells you what to do.
     */
    @Bean
    ChatClient chatClient(Environment environment, ObjectProvider<ChatClient.Builder> builder) {
        String provider = AiProviderGuard.requireExactlyOneProvider(environment.getActiveProfiles());
        if ("openai".equals(provider)) {
            log.warn("AI provider: OpenAI. Applicant text LEAVES this machine. Use fake data only.");
        } else {
            log.info("AI provider: local Ollama. Applicant text stays on this machine.");
        }
        return builder.getObject().build();
    }
}
