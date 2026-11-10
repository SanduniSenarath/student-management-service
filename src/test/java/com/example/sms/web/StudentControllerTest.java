package com.example.sms.web;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.example.sms.TestData;
import com.example.sms.dto.StudentDto;
import com.example.sms.dto.PersonalInformationDto;
import com.example.sms.exception.StudentNotFoundException;
import com.example.sms.service.StudentService;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

@WebMvcTest(StudentController.class)
class StudentControllerTest {

    @Autowired MockMvc mvc;
    @Autowired ObjectMapper mapper;
    @MockBean StudentService service;

    @Test
    void createReturns201() throws Exception {
        when(service.create(any(), eq("HR_ADMIN_01"))).thenReturn(TestData.sample());

        mvc.perform(post("/api/v1/students").header("X-Actor-Id", "HR_ADMIN_01")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(mapper.writeValueAsString(TestData.sample())))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.personalInformation.studentNumber").value("STU-2026-1042"));
    }

    @Test
    void createWithInvalidNicReturns400() throws Exception {
        var p = TestData.sample().personalInformation();
        var bad = new PersonalInformationDto(p.studentNumber(), "BAD", p.fullName(), p.initialsWithName(), p.dob(),
                p.gender(), p.address(), p.mobile(), p.personalEmail(), p.universityEmail());
        var dto = new StudentDto(bad, TestData.sample().academicDetails(),
                TestData.sample().academicAdvisor(), null);

        mvc.perform(post("/api/v1/students").contentType(MediaType.APPLICATION_JSON)
                        .content(mapper.writeValueAsString(dto)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.errors['personalInformation.nic']").exists());
    }

    @Test
    void getUnknownReturns404() throws Exception {
        when(service.get("STU-2026-9999")).thenThrow(new StudentNotFoundException("STU-2026-9999"));

        mvc.perform(get("/api/v1/students/STU-2026-9999")).andExpect(status().isNotFound());
    }
}
