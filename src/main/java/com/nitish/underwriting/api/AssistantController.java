package com.nitish.underwriting.api;

import java.util.UUID;

import com.nitish.underwriting.assistant.AssistantReply;
import com.nitish.underwriting.assistant.AssistantService;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/assistant")
public class AssistantController {

    /**
     * conversationId: omit on the first turn, the server issues one. Must be a UUID we issued.
     * NOT authorization: anyone who knows the UUID can read that conversation (no auth yet).
     */
    public record ChatRequest(
            @Pattern(regexp = "^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$") String conversationId,
            @NotBlank @Size(max = 2000) String message) {}

    private final AssistantService service;

    public AssistantController(AssistantService service) {
        this.service = service;
    }

    @PostMapping("/chat")
    public AssistantReply chat(@Valid @RequestBody ChatRequest request) {
        String conversationId = request.conversationId() != null
                ? request.conversationId()
                : UUID.randomUUID().toString();
        return service.chat(conversationId, request.message());
    }
}