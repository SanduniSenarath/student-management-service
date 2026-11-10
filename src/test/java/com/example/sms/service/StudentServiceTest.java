package com.example.sms.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.example.sms.TestData;
import com.example.sms.dto.StudentDto;
import com.example.sms.exception.DuplicateStudentException;
import com.example.sms.exception.StudentNotFoundException;
import com.example.sms.model.Student;
import com.example.sms.repository.StudentRepository;
import java.util.Optional;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

@ExtendWith(MockitoExtension.class)
class StudentServiceTest {

    @Mock StudentRepository repository;
    @InjectMocks StudentService service;

    @Test
    void createSetsInsertAuditAndLeavesUpdateAuditNull() {
        when(repository.save(any(Student.class))).thenAnswer(i -> i.getArgument(0));

        StudentDto result = service.create(TestData.sample(), "HR_ADMIN_01");

        assertThat(result.auditMetadata().insertedBy()).isEqualTo("HR_ADMIN_01");
        assertThat(result.auditMetadata().insertedAt()).isNotNull();
        assertThat(result.auditMetadata().updatedBy()).isNull();
        assertThat(result.auditMetadata().updatedAt()).isNull();
    }

    @Test
    void createRejectsDuplicateStudentNumber() {
        when(repository.existsByPersonalInformationStudentNumber("STU-2026-1042")).thenReturn(true);

        assertThatThrownBy(() -> service.create(TestData.sample(), "HR_ADMIN_01"))
                .isInstanceOf(DuplicateStudentException.class);
        verify(repository, never()).save(any());
    }

    @Test
    void getThrowsWhenMissing() {
        when(repository.findByPersonalInformationStudentNumber("STU-2026-9999")).thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.get("STU-2026-9999")).isInstanceOf(StudentNotFoundException.class);
    }

    @Test
    void updateKeepsInsertAuditAndSetsUpdateAudit() {
        Student existing = StudentMapper.toEntity(TestData.sample(), "HR_ADMIN_01");
        when(repository.findByPersonalInformationStudentNumber("STU-2026-1042")).thenReturn(Optional.of(existing));
        when(repository.save(any(Student.class))).thenAnswer(i -> i.getArgument(0));

        StudentDto result = service.update("STU-2026-1042", TestData.sample(), "HR_ADMIN_02");

        assertThat(result.auditMetadata().insertedBy()).isEqualTo("HR_ADMIN_01");
        assertThat(result.auditMetadata().updatedBy()).isEqualTo("HR_ADMIN_02");
        assertThat(result.auditMetadata().updatedAt()).isNotNull();
    }

    @Test
    void updateRejectsMismatchedStudentNumber() {
        assertThatThrownBy(() -> service.update("STU-2026-0001", TestData.sample(), "X"))
                .isInstanceOf(IllegalArgumentException.class);
    }

    @Test
    void deleteThrowsWhenMissing() {
        when(repository.findByPersonalInformationStudentNumber("STU-2026-9999")).thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.delete("STU-2026-9999")).isInstanceOf(StudentNotFoundException.class);
    }
}
