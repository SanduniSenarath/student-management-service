package com.example.sms.model;

import jakarta.persistence.Embeddable;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import java.time.LocalDate;

@Embeddable
public record AcademicDetails(
        String faculty, String department, String programme, String enrolmentType,
        LocalDate enrolledDate, String academicLevel,
        @Enumerated(EnumType.STRING) StudentStatus studentStatus) { }
