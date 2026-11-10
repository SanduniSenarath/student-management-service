package com.example.sms.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Past;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import java.time.LocalDate;

public record PersonalInformationDto(
        @NotBlank @Pattern(regexp = "^STU-\\d{4}-\\d{4}$", message = "must look like STU-2026-1042") String studentNumber,
        @NotBlank @Pattern(regexp = "^(\\d{9}[VvXx]|\\d{12})$", message = "must be a valid Sri Lankan NIC") String nic,
        @NotBlank @Size(max = 150) String fullName,
        @NotBlank @Size(max = 100) String initialsWithName,
        @NotNull @Past LocalDate dob,
        @NotBlank @Pattern(regexp = "^(Male|Female|Other)$", message = "must be Male, Female or Other") String gender,
        @NotBlank @Size(max = 255) String address,
        @NotBlank @Pattern(regexp = "^\\+94\\d{9}$", message = "must be in +94XXXXXXXXX format") String mobile,
        @NotBlank @Email @Size(max = 150) String personalEmail,
        @NotBlank @Email @Size(max = 150) String universityEmail) { }
