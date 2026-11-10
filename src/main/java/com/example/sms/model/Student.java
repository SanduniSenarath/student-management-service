package com.example.sms.model;

import jakarta.persistence.Embedded;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

@Entity
@Table(name = "students")
public class Student {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Embedded private PersonalInformation personalInformation;
    @Embedded private AcademicDetails academicDetails;
    @Embedded private AcademicAdvisor academicAdvisor;
    @Embedded private AuditMetadata auditMetadata;

    public Long getId() { return id; }
    public PersonalInformation getPersonalInformation() { return personalInformation; }
    public void setPersonalInformation(PersonalInformation v) { this.personalInformation = v; }
    public AcademicDetails getAcademicDetails() { return academicDetails; }
    public void setAcademicDetails(AcademicDetails v) { this.academicDetails = v; }
    public AcademicAdvisor getAcademicAdvisor() { return academicAdvisor; }
    public void setAcademicAdvisor(AcademicAdvisor v) { this.academicAdvisor = v; }
    public AuditMetadata getAuditMetadata() { return auditMetadata; }
    public void setAuditMetadata(AuditMetadata v) { this.auditMetadata = v; }
}
