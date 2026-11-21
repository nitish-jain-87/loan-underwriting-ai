package com.nitish.underwriting.assistant;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;
import org.springframework.ai.chat.memory.ChatMemory;
import org.springframework.ai.chat.memory.InMemoryChatMemoryRepository;
import org.springframework.ai.chat.memory.MessageWindowChatMemory;
import org.springframework.ai.chat.messages.Message;
import org.springframework.ai.chat.messages.UserMessage;

class ChatMemoryWindowTest {

    private final ChatMemory memory = MessageWindowChatMemory.builder()
            .chatMemoryRepository(new InMemoryChatMemoryRepository())
            .maxMessages(4)
            .build();

    @Test
    void windowSilentlyDropsTheOldestMessages() {
        for (int i = 1; i <= 6; i++) {
            memory.add("c1", new UserMessage("message " + i));
        }
        assertThat(memory.get("c1")).extracting(Message::getText)
                .containsExactly("message 3", "message 4", "message 5", "message 6");
    }

    @Test
    void conversationsAreIsolated() {
        memory.add("applicant-a", new UserMessage("Applicant A, income 6000"));
        assertThat(memory.get("applicant-b")).isEmpty();
    }
}