package com.example.sms.model;

import jakarta.persistence.Embeddable;

@Embeddable
public record AcademicAdvisor(String advisorStaffId, String advisorName, String advisorEmail, String advisorMobile) { }
