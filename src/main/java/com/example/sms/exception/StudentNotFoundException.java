package com.example.sms.exception;

public class StudentNotFoundException extends RuntimeException {
    public StudentNotFoundException(String studentNumber) {
        super("Student not found: " + studentNumber);
    }
}
