package com.example.sms.dto;

import com.example.sms.model.StudentStatus;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.PastOrPresent;
import jakarta.validation.constraints.Size;
import java.time.LocalDate;

public record AcademicDetailsDto(
        @NotBlank @Size(max = 100) String faculty,
        @NotBlank @Size(max = 100) String department,
        @NotBlank @Size(max = 150) String programme,
        @NotBlank @Size(max = 30) String enrolmentType,
        @NotNull @PastOrPresent LocalDate enrolledDate,
        @NotBlank @Size(max = 20) String academicLevel,
        @NotNull StudentStatus studentStatus) { }
