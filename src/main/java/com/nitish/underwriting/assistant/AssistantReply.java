package com.nitish.underwriting.assistant;

import java.util.List;

public record AssistantReply(
        String conversationId,
        String answer,
        List<ToolCallRecord> toolCalls,
        String model,
        Integer promptTokens,       // cumulative over all tool rounds
        Integer completionTokens,
        long latencyMs
) {}
