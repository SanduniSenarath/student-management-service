package com.example.sms.web;

import com.example.sms.dto.StudentDto;
import com.example.sms.service.StudentService;
import jakarta.validation.Valid;
import java.net.URI;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.web.PageableDefault;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/students")
public class StudentController {

    private static final String ACTOR_HEADER = "X-Actor-Id";
    private final StudentService service;

    public StudentController(StudentService service) {
        this.service = service;
    }

    @PostMapping
    public ResponseEntity<StudentDto> create(@Valid @RequestBody StudentDto body,
            @RequestHeader(value = ACTOR_HEADER, defaultValue = "SYSTEM") String actor) {
        StudentDto created = service.create(body, actor);
        URI location = URI.create("/api/v1/students/" + created.personalInformation().studentNumber());
        return ResponseEntity.created(location).body(created);
    }

    @GetMapping("/{studentNumber}")
    public StudentDto get(@PathVariable String studentNumber) {
        return service.get(studentNumber);
    }

    @GetMapping
    public Page<StudentDto> list(@PageableDefault(size = 20, sort = "id") Pageable pageable) {
        return service.list(pageable);
    }

    @PutMapping("/{studentNumber}")
    public StudentDto update(@PathVariable String studentNumber, @Valid @RequestBody StudentDto body,
            @RequestHeader(value = ACTOR_HEADER, defaultValue = "SYSTEM") String actor) {
        return service.update(studentNumber, body, actor);
    }

    @DeleteMapping("/{studentNumber}")
    public ResponseEntity<Void> delete(@PathVariable String studentNumber) {
        service.delete(studentNumber);
        return ResponseEntity.noContent().build();
    }
}
