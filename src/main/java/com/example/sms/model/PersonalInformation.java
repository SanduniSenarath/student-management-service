package com.example.sms.model;

import jakarta.persistence.Embeddable;
import java.time.LocalDate;

@Embeddable
public record PersonalInformation(
        String studentNumber, String nic, String fullName, String initialsWithName,
        LocalDate dob, String gender, String address, String mobile,
        String personalEmail, String universityEmail) { }
