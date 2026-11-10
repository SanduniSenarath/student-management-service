CREATE TABLE students (
    id                  BIGSERIAL PRIMARY KEY,
    -- personalInformation
    student_number      VARCHAR(20)  NOT NULL UNIQUE,
    nic                 VARCHAR(12)  NOT NULL UNIQUE,
    full_name           VARCHAR(150) NOT NULL,
    initials_with_name  VARCHAR(100) NOT NULL,
    dob                 DATE         NOT NULL,
    gender              VARCHAR(10)  NOT NULL,
    address             VARCHAR(255) NOT NULL,
    mobile              VARCHAR(15)  NOT NULL,
    personal_email      VARCHAR(150) NOT NULL,
    university_email    VARCHAR(150) NOT NULL UNIQUE,
    -- academicDetails
    faculty             VARCHAR(100) NOT NULL,
    department          VARCHAR(100) NOT NULL,
    programme           VARCHAR(150) NOT NULL,
    enrolment_type      VARCHAR(30)  NOT NULL,
    enrolled_date       DATE         NOT NULL,
    academic_level      VARCHAR(20)  NOT NULL,
    student_status      VARCHAR(20)  NOT NULL,
    -- academicAdvisor
    advisor_staff_id    VARCHAR(20)  NOT NULL,
    advisor_name        VARCHAR(150) NOT NULL,
    advisor_email       VARCHAR(150) NOT NULL,
    advisor_mobile      VARCHAR(15)  NOT NULL,
    -- auditMetadata
    inserted_by         VARCHAR(50)  NOT NULL,
    inserted_at         TIMESTAMPTZ  NOT NULL,
    updated_by          VARCHAR(50),
    updated_at          TIMESTAMPTZ
);
CREATE INDEX idx_students_department ON students (department);
