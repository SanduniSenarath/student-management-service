package com.example.sms;

import com.example.sms.dto.*;
import com.example.sms.model.StudentStatus;
import java.time.LocalDate;

public final class TestData {
    private TestData() { }

    public static StudentDto sample() {
        return new StudentDto(
                new PersonalInformationDto("STU-2026-1042", "200312345678", "Akalanka Senarath Bandara", "A.S. Bandara",
                        LocalDate.of(2003, 5, 12), "Male", "45/A, Temple Road, Kandy, Sri Lanka", "+94712345678",
                        "akalanka.personal@gmail.com", "akalanka.b@ou.ac.lk"),
                new AcademicDetailsDto("Faculty of Engineering Technology", "Electrical and Computer Engineering",
                        "BSc in Software Engineering", "Part-time", LocalDate.of(2026, 1, 15), "Level 6",
                        StudentStatus.ACTIVE),
                new AcademicAdvisorDto("STAFF-0457", "Chaminda Perera", "chaminda.p@ou.ac.lk", "+94771234567"),
                null);
    }
}
