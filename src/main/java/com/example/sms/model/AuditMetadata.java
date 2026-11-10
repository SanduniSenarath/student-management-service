package com.example.sms.model;

import jakarta.persistence.Embeddable;
import java.time.Instant;

@Embeddable
public record AuditMetadata(String insertedBy, Instant insertedAt, String updatedBy, Instant updatedAt) { }
