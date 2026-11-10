package com.example.sms.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotNull;

public record StudentDto(

        @Valid
        @NotNull
        PersonalInformationDto personalInformation,

        @Valid
        @NotNull
        AcademicDetailsDto academicDetails,

        @Valid
        @NotNull
        AcademicAdvisorDto academicAdvisor,

        AuditMetadataDto auditMetadata

) {
}