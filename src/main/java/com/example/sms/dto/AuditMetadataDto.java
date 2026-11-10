package com.example.sms.dto;

import java.time.Instant;

/** Server-controlled. Ignored on input, always populated on output. */
public record AuditMetadataDto(String insertedBy, Instant insertedAt, String updatedBy, Instant updatedAt) { }
