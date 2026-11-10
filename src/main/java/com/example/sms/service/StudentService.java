package com.example.sms.service;

import com.example.sms.dto.StudentDto;
import com.example.sms.exception.DuplicateStudentException;
import com.example.sms.exception.StudentNotFoundException;
import com.example.sms.model.Student;
import com.example.sms.repository.StudentRepository;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@Transactional
public class StudentService {

    private final StudentRepository repository;

    public StudentService(StudentRepository repository) {
        this.repository = repository;
    }

    public StudentDto create(StudentDto dto, String actor) {

        var p = dto.personalInformation();

        if (repository.existsByPersonalInformationStudentNumber(p.studentNumber())) {
            throw new DuplicateStudentException(
                    "Student number already exists: " + p.studentNumber()
            );
        }

        if (repository.existsByPersonalInformationNic(p.nic().toUpperCase())) {
            throw new DuplicateStudentException(
                    "NIC already registered"
            );
        }

        if (repository.existsByPersonalInformationUniversityEmail(p.universityEmail())) {
            throw new DuplicateStudentException(
                    "Work email already registered"
            );
        }

        return StudentMapper.toDto(
                repository.save(
                        StudentMapper.toEntity(dto, actor)
                )
        );
    }

    @Transactional(readOnly = true)
    public StudentDto get(String studentNumber) {
        return StudentMapper.toDto(find(studentNumber));
    }

    @Transactional(readOnly = true)
    public Page<StudentDto> list(Pageable pageable) {
        return repository.findAll(pageable)
                .map(StudentMapper::toDto);
    }

    public StudentDto update(
            String studentNumber,
            StudentDto dto,
            String actor
    ) {

        if (!studentNumber.equals(dto.personalInformation().studentNumber())) {
            throw new IllegalArgumentException(
                    "studentNumber in body must match the path"
            );
        }

        Student entity = find(studentNumber);

        StudentMapper.applyUpdate(entity, dto, actor);

        return StudentMapper.toDto(
                repository.save(entity)
        );
    }

    public void delete(String studentNumber) {
        repository.delete(find(studentNumber));
    }

    private Student find(String studentNumber) {
        return repository
                .findByPersonalInformationStudentNumber(studentNumber)
                .orElseThrow(
                        () -> new StudentNotFoundException(studentNumber)
                );
    }
}