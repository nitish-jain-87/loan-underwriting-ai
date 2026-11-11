package com.nitish.underwriting.api;

import com.nitish.underwriting.intake.ExtractionResult;
import com.nitish.underwriting.intake.IntakeExtractionService;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/intake")
public class IntakeController {

    /** Size cap = a crude token budget (Day 2, Q6). The real guard comes in Week 1. */
    public record ExtractRequest(@NotBlank @Size(max = 4000) String text) {}

    private final IntakeExtractionService service;

    public IntakeController(IntakeExtractionService service) {
        this.service = service;
    }

    @PostMapping("/extract")
    public ResponseEntity<ExtractionResult> extract(@Valid @RequestBody ExtractRequest request) {
        ExtractionResult result = service.extract(request.text());
        // 502: the upstream (the model) returned something we can't use.
        return ResponseEntity.status(result.ok() ? HttpStatus.OK : HttpStatus.BAD_GATEWAY).body(result);
    }
}