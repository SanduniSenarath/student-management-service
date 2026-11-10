package com.example.sms.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

public record AcademicAdvisorDto(
        @NotBlank @Size(max = 20) String advisorStaffId,
        @NotBlank @Size(max = 150) String advisorName,
        @NotBlank @Email @Size(max = 150) String advisorEmail,
        @NotBlank @Pattern(regexp = "^\\+94\\d{9}$", message = "must be in +94XXXXXXXXX format") String advisorMobile) { }
