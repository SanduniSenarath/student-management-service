package com.example.sms.service;

import com.example.sms.dto.*;
import com.example.sms.model.*;

import java.time.Instant;

final class StudentMapper {

    private StudentMapper() {
    }

    static Student toEntity(StudentDto d, String actor) {

        Student s = new Student();

        applyBusinessFields(s, d);

        s.setAuditMetadata(
                new AuditMetadata(
                        actor,
                        Instant.now(),
                        null,
                        null
                )
        );

        return s;
    }

    static void applyUpdate(Student s, StudentDto d, String actor) {

        applyBusinessFields(s, d);

        AuditMetadata old = s.getAuditMetadata();

        s.setAuditMetadata(
                new AuditMetadata(
                        old.insertedBy(),
                        old.insertedAt(),
                        actor,
                        Instant.now()
                )
        );
    }

    private static void applyBusinessFields(Student s, StudentDto d) {

        PersonalInformationDto p = d.personalInformation();

        s.setPersonalInformation(
                new PersonalInformation(
                        p.studentNumber(),
                        p.nic().toUpperCase(),
                        p.fullName(),
                        p.initialsWithName(),
                        p.dob(),
                        p.gender(),
                        p.address(),
                        p.mobile(),
                        p.personalEmail(),
                        p.universityEmail()
                )
        );

        AcademicDetailsDto a = d.academicDetails();

        s.setAcademicDetails(
                new AcademicDetails(
                        a.faculty(),
                        a.department(),
                        a.programme(),
                        a.enrolmentType(),
                        a.enrolledDate(),
                        a.academicLevel(),
                        a.studentStatus()
                )
        );

        AcademicAdvisorDto v = d.academicAdvisor();

        s.setAcademicAdvisor(
                new AcademicAdvisor(
                        v.advisorStaffId(),
                        v.advisorName(),
                        v.advisorEmail(),
                        v.advisorMobile()
                )
        );
    }

    static StudentDto toDto(Student s) {

        PersonalInformation p = s.getPersonalInformation();
        AcademicDetails a = s.getAcademicDetails();
        AcademicAdvisor v = s.getAcademicAdvisor();
        AuditMetadata m = s.getAuditMetadata();

        return new StudentDto(
                new PersonalInformationDto(
                        p.studentNumber(),
                        p.nic(),
                        p.fullName(),
                        p.initialsWithName(),
                        p.dob(),
                        p.gender(),
                        p.address(),
                        p.mobile(),
                        p.personalEmail(),
                        p.universityEmail()
                ),

                new AcademicDetailsDto(
                        a.faculty(),
                        a.department(),
                        a.programme(),
                        a.enrolmentType(),
                        a.enrolledDate(),
                        a.academicLevel(),
                        a.studentStatus()
                ),

                new AcademicAdvisorDto(
                        v.advisorStaffId(),
                        v.advisorName(),
                        v.advisorEmail(),
                        v.advisorMobile()
                ),

                new AuditMetadataDto(
                        m.insertedBy(),
                        m.insertedAt(),
                        m.updatedBy(),
                        m.updatedAt()
                )
        );
    }
}