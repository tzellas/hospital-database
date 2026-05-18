DROP TABLE IF EXISTS
all_lab_tests,
hospitalization_lab_test,
assistant_procedure_staff,
doctor_review,
hospitalization_review,
prescription,
all_lab_tests,
hospitalization_lab_test,
procedure_room_schedule,
all_medical_procedures,
hospitalization_medical_procedure,
triage_case,
hospitalization,
emergency_contact,
allergy,
duty_shift_staff,
duty_shift,
doctor_department,
bed,
entity_image,
administrative,
nurse,
doctor,
staff,
patient,
procedure_room,
department,
drug_active_substance,
drug,
active_substance,
icd10_diagnosis,
ken
CASCADE;




CREATE TABLE department (
    department_id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    description TEXT,
    bed_count INT NOT NULL,
    floor VARCHAR(30),
    building VARCHAR(50),
    phone VARCHAR(20),

    CHECK (bed_count >= 0)
);

CREATE TABLE staff (
    staff_id SERIAL PRIMARY KEY,
    amka VARCHAR(20) NOT NULL UNIQUE,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    age INT NOT NULL,
    email VARCHAR(100) NOT NULL UNIQUE,
    phone VARCHAR(20),
    hire_date DATE NOT NULL,
    staff_type VARCHAR(20) NOT NULL,

    CHECK (age > 0),
    CHECK (staff_type IN ('DOCTOR', 'NURSE', 'ADMINISTRATIVE'))
);

CREATE TABLE doctor (
    staff_id INT PRIMARY KEY,
    doctor_num VARCHAR(30) NOT NULL UNIQUE,
    medical_license_num VARCHAR(50) NOT NULL UNIQUE,
    specialty VARCHAR(100) NOT NULL,
    rank VARCHAR(50) NOT NULL,
    supervisor_doc_id INT,

    FOREIGN KEY (staff_id)
        REFERENCES staff(staff_id)
        ON DELETE CASCADE,

    FOREIGN KEY (supervisor_doc_id)
        REFERENCES doctor(staff_id),

    CHECK (rank IN (
        'RESIDENT',
        'CONSULTANT_B',
        'CONSULTANT_A',
        'DIRECTOR'
    )),

    CHECK (staff_id <> supervisor_doc_id),

    CHECK (
        (rank = 'RESIDENT' AND supervisor_doc_id IS NOT NULL)
        OR
        (rank = 'DIRECTOR' AND supervisor_doc_id IS NULL)
        OR
        (rank IN ('CONSULTANT_B', 'CONSULTANT_A'))
    )
);

CREATE TABLE nurse (
    staff_id INT PRIMARY KEY,
    nurse_num VARCHAR(30) NOT NULL UNIQUE,
    rank VARCHAR(50) NOT NULL,
    department_id INT NOT NULL,

    FOREIGN KEY (staff_id)
        REFERENCES staff(staff_id)
        ON DELETE CASCADE,

    FOREIGN KEY (department_id)
        REFERENCES department(department_id),

    CHECK (rank IN (
        'ASSISTANT_NURSE',
        'NURSE',
        'HEAD_NURSE'
    ))
);

CREATE TABLE administrative (
    staff_id INT PRIMARY KEY,
    admin_num VARCHAR(30) NOT NULL UNIQUE, 
    role VARCHAR(100) NOT NULL,
    office VARCHAR(50) NOT NULL,
    department_id INT NOT NULL,

    FOREIGN KEY (staff_id)
        REFERENCES staff(staff_id)
        ON DELETE CASCADE,

    FOREIGN KEY (department_id)
        REFERENCES department(department_id)
);


ALTER TABLE department
ADD COLUMN manager_id INT;

ALTER TABLE department
ADD CONSTRAINT fk_department_manager
FOREIGN KEY (manager_id)
REFERENCES doctor(staff_id);


CREATE TABLE bed (
    department_id INT NOT NULL,
    bed_num VARCHAR(20) NOT NULL,
    bed_type VARCHAR(50) NOT NULL,
    status VARCHAR(50) NOT NULL,

    PRIMARY KEY (department_id, bed_num),

    FOREIGN KEY (department_id)
        REFERENCES department(department_id)
        ON DELETE CASCADE,

    CHECK (bed_type IN ('ICU', 'SINGLE', 'MULTI_BED')),
    CHECK (status IN ('AVAILABLE', 'OCCUPIED', 'MAINTENANCE'))
);

CREATE TABLE duty_shift (
    duty_shift_id SERIAL PRIMARY KEY,
    department_id INT NOT NULL,
    shift_date DATE NOT NULL,
    shift_type VARCHAR(20) NOT NULL,
    start_time TIME NOT NULL,
    end_time TIME NOT NULL,

    FOREIGN KEY (department_id)
        REFERENCES department(department_id)
        ON DELETE CASCADE,

    UNIQUE (department_id, shift_date, shift_type),

    CHECK (shift_type IN ('MORNING', 'EVENING', 'NIGHT')),
    CHECK (
        (shift_type = 'MORNING' AND start_time = TIME '07:00' AND end_time = TIME '15:00')
        OR
        (shift_type = 'EVENING' AND start_time = TIME '15:00' AND end_time = TIME '23:00')
        OR
        (shift_type = 'NIGHT' AND start_time = TIME '23:00' AND end_time = TIME '07:00')
    )
);

CREATE TABLE patient (
    patient_id SERIAL PRIMARY KEY,
    amka VARCHAR(20) NOT NULL UNIQUE,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    father_name VARCHAR(50),
    age INT NOT NULL,
    gender VARCHAR(20) NOT NULL,
    weight NUMERIC(5,2),
    height NUMERIC(4,2),

    address_street VARCHAR(100),
    address_num VARCHAR(20),
    postal_code VARCHAR(20),
    city VARCHAR(100),

    phone VARCHAR(20),
    email VARCHAR(100),
    occupation VARCHAR(100),
    nationality VARCHAR(100),
    insurance_provider VARCHAR(100) NOT NULL,

    CHECK (age >= 0),
    CHECK (weight IS NULL OR weight > 0),
    CHECK (height IS NULL OR height > 0),
    CHECK (gender IN ('Male', 'Female', 'Other'))
);

CREATE TABLE emergency_contact (
    patient_id INT NOT NULL,
    contact_num INT NOT NULL,

    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    age INT,
    relationship VARCHAR(50),
    phone VARCHAR(20) NOT NULL,
    email VARCHAR(100),

    PRIMARY KEY (patient_id, contact_num),

    FOREIGN KEY (patient_id)
        REFERENCES patient(patient_id)
        ON DELETE CASCADE,

    CHECK (contact_num > 0),
    CHECK (age IS NULL OR age >= 0)
);

CREATE TABLE icd10_diagnosis (
    icd10_code VARCHAR(20) PRIMARY KEY,
    description TEXT NOT NULL,
    category VARCHAR(3) GENERATED ALWAYS AS (LEFT(icd10_code, 3)) STORED
);

CREATE TABLE ken (
    ken_code VARCHAR(30) PRIMARY KEY,
    description TEXT NOT NULL,
    base_cost NUMERIC(10,2) NOT NULL,
    average_length_of_stay INT NOT NULL,
    extra_daily_charge NUMERIC(10,2)
        GENERATED ALWAYS AS (
            base_cost / average_length_of_stay
        ) STORED,

    CHECK (base_cost >= 0),
    CHECK (average_length_of_stay > 0)
);

CREATE TABLE hospitalization (
    hospitalization_id SERIAL PRIMARY KEY,

    patient_id INT NOT NULL,
    department_id INT NOT NULL,
    bed_num VARCHAR(20) NOT NULL,

    admission_date TIMESTAMP NOT NULL,
    discharge_date TIMESTAMP,

    admission_icd10_code VARCHAR(20) NOT NULL,
    discharge_icd10_code VARCHAR(20),

    ken_code VARCHAR(30) NOT NULL,

    total_cost NUMERIC(10,2) NOT NULL DEFAULT 0,
    extra_charge NUMERIC(10,2) NOT NULL DEFAULT 0,

    FOREIGN KEY (patient_id)
        REFERENCES patient(patient_id),

    FOREIGN KEY (department_id, bed_num)
        REFERENCES bed(department_id, bed_num),

    FOREIGN KEY (admission_icd10_code)
        REFERENCES icd10_diagnosis(icd10_code),

    FOREIGN KEY (discharge_icd10_code)
        REFERENCES icd10_diagnosis(icd10_code),

    FOREIGN KEY (ken_code)
        REFERENCES ken(ken_code),

    CHECK (discharge_date IS NULL OR discharge_date >= admission_date),
    CHECK (total_cost >= 0),
    CHECK (extra_charge >= 0)
);

CREATE TABLE triage_case (
    triage_id SERIAL PRIMARY KEY,

    patient_id INT NOT NULL,
    triage_nurse_id INT NOT NULL,

    arrival_datetime TIMESTAMP NOT NULL,
    service_datetime TIMESTAMP,

    symptoms TEXT NOT NULL,
    urgency_level INT NOT NULL,

    outcome VARCHAR(40) NOT NULL,
    referred_department_id INT,
    hospitalization_id INT UNIQUE,

    FOREIGN KEY (patient_id)
        REFERENCES patient(patient_id),

    FOREIGN KEY (triage_nurse_id)
        REFERENCES nurse(staff_id),

    FOREIGN KEY (referred_department_id)
        REFERENCES department(department_id),

    FOREIGN KEY (hospitalization_id)
        REFERENCES hospitalization(hospitalization_id),

    CHECK (urgency_level BETWEEN 1 AND 5),

    CHECK (
        service_datetime IS NULL
        OR service_datetime >= arrival_datetime
    ),

    CHECK (outcome IN (
        'DISCHARGED_WITH_INSTRUCTIONS',
        'REFERRED_FOR_HOSPITALIZATION'
    )),

    CHECK (
        (outcome = 'DISCHARGED_WITH_INSTRUCTIONS'
            AND hospitalization_id IS NULL)
        OR
        (outcome = 'REFERRED_FOR_HOSPITALIZATION'
            AND hospitalization_id IS NOT NULL
            AND referred_department_id IS NOT NULL)
    )
);

CREATE TABLE all_lab_tests (
    test_code VARCHAR(50) PRIMARY KEY,
    description TEXT NOT NULL,
    default_cost NUMERIC(10,2) NOT NULL,

    CHECK (default_cost >= 0)
);

CREATE TABLE hospitalization_lab_test (
    lab_test_id SERIAL PRIMARY KEY,

    hospitalization_id INT NOT NULL,
    ordered_by_doctor_id INT NOT NULL,
    test_code VARCHAR(50) NOT NULL,

    test_date TIMESTAMP NOT NULL,

    result_text TEXT,
    result_value NUMERIC(12,3),
    result_unit VARCHAR(50),

    actual_cost NUMERIC(10,2) NOT NULL,

    FOREIGN KEY (hospitalization_id)
        REFERENCES hospitalization(hospitalization_id)
        ON DELETE CASCADE,

    FOREIGN KEY (ordered_by_doctor_id)
        REFERENCES doctor(staff_id),

    FOREIGN KEY (test_code)
        REFERENCES all_lab_tests(test_code),

    CHECK (actual_cost >= 0),
    CHECK (result_text IS NOT NULL OR result_value IS NOT NULL)
);


CREATE TABLE active_substance (
    substance_id SERIAL PRIMARY KEY,
    substance_name VARCHAR(255) NOT NULL UNIQUE
);

CREATE TABLE drug (
    drug_id SERIAL PRIMARY KEY,
    ema_name VARCHAR(255) NOT NULL,
    route_of_administration VARCHAR(255) NOT NULL,
    marketing_authorisation_holder VARCHAR(255) NOT NULL,
    pharmacovigilance_system_master_file_location VARCHAR(255) NOT NULL,
    pharmacovigilance_enquiries_email_address VARCHAR(255) NOT NULL,
    pharmacovigilance_enquiries_telephone_number VARCHAR(255) NOT NULL
);

CREATE TABLE prescription (
    prescription_id SERIAL PRIMARY KEY,

    hospitalization_id INT NOT NULL,
    patient_id INT NOT NULL,
    doctor_id INT NOT NULL,
    drug_id INT NOT NULL,

    dosage VARCHAR(100) NOT NULL,
    frequency VARCHAR(100) NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE,

    FOREIGN KEY (hospitalization_id)
        REFERENCES hospitalization(hospitalization_id)
        ON DELETE CASCADE,

    FOREIGN KEY (patient_id)
        REFERENCES patient(patient_id),

    FOREIGN KEY (doctor_id)
        REFERENCES doctor(staff_id),

    FOREIGN KEY (drug_id)
        REFERENCES drug(drug_id),

    UNIQUE (doctor_id, patient_id, drug_id, start_date),

    CHECK (end_date IS NULL OR end_date >= start_date)
);

CREATE TABLE procedure_room (
    room_id SERIAL PRIMARY KEY,
    room_name VARCHAR(100) NOT NULL UNIQUE,
    room_type VARCHAR(50) NOT NULL,

    CHECK (room_type IN ('OPERATING_ROOM', 'PROCEDURE_ROOM'))
);

CREATE TABLE all_medical_procedures (
    procedure_code VARCHAR(50) PRIMARY KEY,
    description TEXT NOT NULL,
    category VARCHAR(255) NOT NULL,
    default_cost NUMERIC(10,2) NOT NULL,

    CHECK (category IN ('SURGICAL', 'DIAGNOSTIC', 'THERAPEUTIC')),
    CHECK (default_cost >= 0)
);

CREATE TABLE hospitalization_medical_procedure (
    procedure_id SERIAL PRIMARY KEY,

    hospitalization_id INT NOT NULL,
    procedure_code VARCHAR(50) NOT NULL,
    main_doctor_id INT NOT NULL,

    actual_duration_minutes INT,
    actual_cost NUMERIC(10,2) NOT NULL,

    FOREIGN KEY (hospitalization_id)
        REFERENCES hospitalization(hospitalization_id)
        ON DELETE CASCADE,

    FOREIGN KEY (procedure_code)
        REFERENCES all_medical_procedures(procedure_code),

    FOREIGN KEY (main_doctor_id)
        REFERENCES doctor(staff_id),

    CHECK (actual_duration_minutes IS NULL OR actual_duration_minutes > 0),
    CHECK (actual_cost >= 0)
);

CREATE TABLE procedure_room_schedule (
    procedure_id INT NOT NULL,
    room_id INT NOT NULL,

    start_datetime TIMESTAMP NOT NULL,
    end_datetime TIMESTAMP NOT NULL,

    PRIMARY KEY (procedure_id, room_id, start_datetime),

    FOREIGN KEY (procedure_id)
        REFERENCES hospitalization_medical_procedure(procedure_id)
        ON DELETE CASCADE,

    FOREIGN KEY (room_id)
        REFERENCES procedure_room(room_id),

    CHECK (end_datetime > start_datetime)
);

CREATE TABLE entity_image (
    image_id SERIAL PRIMARY KEY,

    entity_type VARCHAR(50) NOT NULL,
    entity_id INT NOT NULL,

    image_url VARCHAR(500) NOT NULL,
    description TEXT NOT NULL,

    CHECK (entity_type IN (
        'STAFF',
        'DOCTOR',
        'NURSE',
        'ADMINISTRATIVE',
        'DEPARTMENT',
        'BED',
        'PATIENT',
        'HOSPITALIZATION',
        'TRIAGE_CASE',
        'PROCEDURE_ROOM',
        'DRUG'
    ))
);

--------------------------------------------------
--  Many-to-many Relationship Tables            
--------------------------------------------------

CREATE TABLE doctor_department (
    doctor_id INT NOT NULL,
    department_id INT NOT NULL,

    PRIMARY KEY (doctor_id, department_id),

    FOREIGN KEY (doctor_id)
        REFERENCES doctor(staff_id)
        ON DELETE CASCADE,

    FOREIGN KEY (department_id)
        REFERENCES department(department_id)
        ON DELETE CASCADE
);


CREATE TABLE duty_shift_staff (
    duty_shift_id INT NOT NULL,
    staff_id INT NOT NULL,

    PRIMARY KEY (duty_shift_id, staff_id),

    FOREIGN KEY (duty_shift_id)
        REFERENCES duty_shift(duty_shift_id)
        ON DELETE CASCADE,

    FOREIGN KEY (staff_id)
        REFERENCES staff(staff_id)
        ON DELETE CASCADE
);

CREATE TABLE drug_active_substance (
    drug_id INT NOT NULL,
    substance_id INT NOT NULL,

    PRIMARY KEY (drug_id, substance_id),

    FOREIGN KEY (drug_id)
        REFERENCES drug(drug_id)
        ON DELETE CASCADE,

    FOREIGN KEY (substance_id)
        REFERENCES active_substance(substance_id)
        ON DELETE CASCADE
);

CREATE TABLE allergy (
    patient_id INT NOT NULL,
    substance_id INT NOT NULL,

    PRIMARY KEY (patient_id, substance_id),

    FOREIGN KEY (patient_id)
        REFERENCES patient(patient_id)
        ON DELETE CASCADE,

    FOREIGN KEY (substance_id)
        REFERENCES active_substance(substance_id)
        ON DELETE CASCADE
);

CREATE TABLE assistant_procedure_staff (
    procedure_id INT NOT NULL,
    staff_id INT NOT NULL,
    role_in_procedure VARCHAR(100),

    PRIMARY KEY (procedure_id, staff_id),

    FOREIGN KEY (procedure_id)
        REFERENCES hospitalization_medical_procedure(procedure_id)
        ON DELETE CASCADE,

    FOREIGN KEY (staff_id)
        REFERENCES staff(staff_id)
        ON DELETE CASCADE
);

CREATE TABLE hospitalization_review (
    patient_id INT NOT NULL,
    hospitalization_id INT NOT NULL,

    nursing_care_score INT NOT NULL,
    cleanliness_score INT NOT NULL,
    food_score INT NOT NULL,
    overall_experience_score INT NOT NULL,
    review_date DATE NOT NULL,

    PRIMARY KEY (patient_id, hospitalization_id),

    FOREIGN KEY (patient_id)
        REFERENCES patient(patient_id)
        ON DELETE CASCADE,

    FOREIGN KEY (hospitalization_id)
        REFERENCES hospitalization(hospitalization_id)
        ON DELETE CASCADE,

    CHECK (nursing_care_score BETWEEN 1 AND 5),
    CHECK (cleanliness_score BETWEEN 1 AND 5),
    CHECK (food_score BETWEEN 1 AND 5),
    CHECK (overall_experience_score BETWEEN 1 AND 5)
);

CREATE TABLE doctor_review (
    patient_id INT NOT NULL,
    doctor_id INT NOT NULL,
    hospitalization_id INT NOT NULL,

    medical_care_score INT NOT NULL,
    review_date DATE NOT NULL,

    PRIMARY KEY (patient_id, doctor_id, hospitalization_id),

    FOREIGN KEY (patient_id)
        REFERENCES patient(patient_id)
        ON DELETE CASCADE,

    FOREIGN KEY (doctor_id)
        REFERENCES doctor(staff_id)
        ON DELETE CASCADE,

    FOREIGN KEY (hospitalization_id)
        REFERENCES hospitalization(hospitalization_id)
        ON DELETE CASCADE,

    CHECK (medical_care_score BETWEEN 1 AND 5)
);

--------------------------------------------------
--  Triggers            
--------------------------------------------------

/*
Rule:
A doctor cannot participate in a cyclic supervision hierarchy.
For example, if doctor A supervises doctor B, then doctor B cannot supervise doctor A.
*/

CREATE OR REPLACE FUNCTION check_supervisor_cycle()
RETURNS TRIGGER AS
$$
DECLARE
    cycle_found INT;
BEGIN

    IF NEW.supervisor_doc_id IS NULL THEN
        RETURN NEW;
    END IF;

    WITH RECURSIVE supervisor_chain AS (
        SELECT d.staff_id, d.supervisor_doc_id
        FROM doctor d
        WHERE d.staff_id = NEW.supervisor_doc_id

        UNION

        SELECT d.staff_id, d.supervisor_doc_id
        FROM doctor d
        JOIN supervisor_chain sc
            ON d.staff_id = sc.supervisor_doc_id
    )
    SELECT COUNT(*)
    INTO cycle_found
    FROM supervisor_chain
    WHERE staff_id = NEW.staff_id;

    IF cycle_found > 0 THEN
        RAISE EXCEPTION
        'Cyclic supervision hierarchy detected.';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_check_supervisor_cycle
BEFORE INSERT OR UPDATE OF supervisor_doc_id
ON doctor
FOR EACH ROW
EXECUTE FUNCTION check_supervisor_cycle();

/*
Rule:
Each duty shift must contain at least:
3 doctors, 6 nurses and 2 administrative employees.
The system must reject staffing configurations below these limits.
*/

CREATE OR REPLACE FUNCTION check_shift_staffing()
RETURNS TRIGGER AS
$$
DECLARE
    v_shift_id INT;

    doctor_count INT;
    nurse_count INT;
    admin_count INT;
BEGIN

    v_shift_id := COALESCE(NEW.duty_shift_id, OLD.duty_shift_id);

    SELECT COUNT(*)
    INTO doctor_count
    FROM duty_shift_staff dss
    JOIN doctor d
        ON dss.staff_id = d.staff_id
    WHERE dss.duty_shift_id = v_shift_id;

    SELECT COUNT(*)
    INTO nurse_count
    FROM duty_shift_staff dss
    JOIN nurse n
        ON dss.staff_id = n.staff_id
    WHERE dss.duty_shift_id = v_shift_id;

    SELECT COUNT(*)
    INTO admin_count
    FROM duty_shift_staff dss
    JOIN administrative a
        ON dss.staff_id = a.staff_id
    WHERE dss.duty_shift_id = v_shift_id;

    IF doctor_count < 3 THEN
        RAISE EXCEPTION
        'Each shift must contain at least 3 doctors.';
    END IF;

    IF nurse_count < 6 THEN
        RAISE EXCEPTION
        'Each shift must contain at least 6 nurses.';
    END IF;

    IF admin_count < 2 THEN
        RAISE EXCEPTION
        'Each shift must contain at least 2 administrative employees.';
    END IF;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_check_shift_staffing
AFTER INSERT OR DELETE
ON duty_shift_staff
FOR EACH ROW
EXECUTE FUNCTION check_shift_staffing();

/*
Rule:
The maximum allowed duty shifts per month are:
15 for doctors, 20 for nurses and 25 for administrative employees.
The system must prevent any insertion exceeding these limits.
*/

CREATE OR REPLACE FUNCTION check_monthly_shift_limits()
RETURNS TRIGGER AS
$$
DECLARE
    shift_count INT;
    shift_month INT;
    shift_year INT;
BEGIN

    SELECT
        EXTRACT(MONTH FROM ds.shift_date),
        EXTRACT(YEAR FROM ds.shift_date)
    INTO
        shift_month,
        shift_year
    FROM duty_shift ds
    WHERE ds.duty_shift_id = NEW.duty_shift_id;

    /*
    Doctor limit
    */
    IF EXISTS (
        SELECT 1
        FROM doctor d
        WHERE d.staff_id = NEW.staff_id
    ) THEN

        SELECT COUNT(*)
        INTO shift_count
        FROM duty_shift_staff dss
        JOIN duty_shift ds
            ON dss.duty_shift_id = ds.duty_shift_id
        WHERE dss.staff_id = NEW.staff_id
          AND EXTRACT(MONTH FROM ds.shift_date) = shift_month
          AND EXTRACT(YEAR FROM ds.shift_date) = shift_year;

        IF shift_count >= 15 THEN
            RAISE EXCEPTION
            'Doctors cannot exceed 15 shifts per month.';
        END IF;
    END IF;

    /*
    Nurse limit
    */
    IF EXISTS (
        SELECT 1
        FROM nurse n
        WHERE n.staff_id = NEW.staff_id
    ) THEN

        SELECT COUNT(*)
        INTO shift_count
        FROM duty_shift_staff dss
        JOIN duty_shift ds
            ON dss.duty_shift_id = ds.duty_shift_id
        WHERE dss.staff_id = NEW.staff_id
          AND EXTRACT(MONTH FROM ds.shift_date) = shift_month
          AND EXTRACT(YEAR FROM ds.shift_date) = shift_year;

        IF shift_count >= 20 THEN
            RAISE EXCEPTION
            'Nurses cannot exceed 20 shifts per month.';
        END IF;
    END IF;

    /*
    Administrative limit
    */
    IF EXISTS (
        SELECT 1
        FROM administrative a
        WHERE a.staff_id = NEW.staff_id
    ) THEN

        SELECT COUNT(*)
        INTO shift_count
        FROM duty_shift_staff dss
        JOIN duty_shift ds
            ON dss.duty_shift_id = ds.duty_shift_id
        WHERE dss.staff_id = NEW.staff_id
          AND EXTRACT(MONTH FROM ds.shift_date) = shift_month
          AND EXTRACT(YEAR FROM ds.shift_date) = shift_year;

        IF shift_count >= 25 THEN
            RAISE EXCEPTION
            'Administrative employees cannot exceed 25 shifts per month.';
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_check_monthly_shift_limits
BEFORE INSERT
ON duty_shift_staff
FOR EACH ROW
EXECUTE FUNCTION check_monthly_shift_limits();

/*
Rule:
Between two consecutive duty shifts of the same staff member,
there must be at least 8 hours of rest.
*/

CREATE OR REPLACE FUNCTION check_8_hour_rest()
RETURNS TRIGGER AS
$$
DECLARE
    new_start TIMESTAMP;
    new_end TIMESTAMP;
    conflict_exists BOOLEAN;
BEGIN
    SELECT
        ds.shift_date + ds.start_time,
        CASE
            WHEN ds.end_time <= ds.start_time
                THEN ds.shift_date + ds.end_time + INTERVAL '1 day'
            ELSE ds.shift_date + ds.end_time
        END
    INTO new_start, new_end
    FROM duty_shift ds
    WHERE ds.duty_shift_id = NEW.duty_shift_id;

    SELECT EXISTS (
        SELECT 1
        FROM duty_shift_staff dss
        JOIN duty_shift ds
            ON dss.duty_shift_id = ds.duty_shift_id
        CROSS JOIN LATERAL (
            SELECT
                ds.shift_date + ds.start_time AS old_start,
                CASE
                    WHEN ds.end_time <= ds.start_time
                        THEN ds.shift_date + ds.end_time + INTERVAL '1 day'
                    ELSE ds.shift_date + ds.end_time
                END AS old_end
        ) old_shift
        WHERE dss.staff_id = NEW.staff_id
          AND (
              ABS(EXTRACT(EPOCH FROM (new_start - old_shift.old_end))) < 8 * 3600
              OR
              ABS(EXTRACT(EPOCH FROM (old_shift.old_start - new_end))) < 8 * 3600
          )
    )
    INTO conflict_exists;

    IF conflict_exists THEN
        RAISE EXCEPTION
        'Staff member must have at least 8 hours of rest between consecutive shifts.';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_check_8_hour_rest
BEFORE INSERT
ON duty_shift_staff
FOR EACH ROW
EXECUTE FUNCTION check_8_hour_rest();

/*
Rule:
A prescription is not allowed if the prescribed drug contains an active
substance to which the patient has a recorded allergy.
*/

CREATE OR REPLACE FUNCTION check_prescription_allergy()
RETURNS TRIGGER AS
$$
DECLARE
    allergy_exists BOOLEAN;
BEGIN
    SELECT EXISTS (
        SELECT 1
        FROM drug_active_substance das
        JOIN allergy a
            ON a.substance_id = das.substance_id
        WHERE das.drug_id = NEW.drug_id
          AND a.patient_id = NEW.patient_id
    )
    INTO allergy_exists;

    IF allergy_exists THEN
        RAISE EXCEPTION
        'Prescription rejected: patient is allergic to an active substance of this drug.';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_check_prescription_allergy
BEFORE INSERT OR UPDATE
ON prescription
FOR EACH ROW
EXECUTE FUNCTION check_prescription_allergy();

/*
Rule:
Patients may submit hospitalization and doctor reviews only after the
corresponding hospitalization has been completed.
*/

CREATE OR REPLACE FUNCTION check_completed_hospitalization_review()
RETURNS TRIGGER AS
$$
DECLARE
    is_completed BOOLEAN;
BEGIN
    SELECT h.discharge_date IS NOT NULL
    INTO is_completed
    FROM hospitalization h
    WHERE h.hospitalization_id = NEW.hospitalization_id;

    IF NOT is_completed THEN
        RAISE EXCEPTION
        'Review rejected: hospitalization has not been completed yet.';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_check_completed_hospitalization_review
BEFORE INSERT OR UPDATE
ON hospitalization_review
FOR EACH ROW
EXECUTE FUNCTION check_completed_hospitalization_review();

CREATE TRIGGER trg_check_completed_doctor_review
BEFORE INSERT OR UPDATE
ON doctor_review
FOR EACH ROW
EXECUTE FUNCTION check_completed_hospitalization_review();

/*
Rule:
Two medical procedures cannot take place in the same procedure room
during overlapping time intervals.
*/

CREATE OR REPLACE FUNCTION check_overlapping_procedure_room()
RETURNS TRIGGER AS
$$
DECLARE
    conflict_exists BOOLEAN;
BEGIN
    SELECT EXISTS (
        SELECT 1
        FROM procedure_room_schedule prs
        WHERE prs.room_id = NEW.room_id
          AND prs.procedure_id <> NEW.procedure_id
          AND NEW.start_datetime < prs.end_datetime
          AND NEW.end_datetime > prs.start_datetime
    )
    INTO conflict_exists;

    IF conflict_exists THEN
        RAISE EXCEPTION
        'Procedure rejected: another procedure is already scheduled in this room during this time interval.';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_check_overlapping_procedure_room
BEFORE INSERT OR UPDATE
ON procedure_room_schedule
FOR EACH ROW
EXECUTE FUNCTION check_overlapping_procedure_room();

/*
Rule:
The same bed cannot be assigned to two hospitalizations whose time
intervals overlap. This prevents double occupancy of a bed.
*/

CREATE OR REPLACE FUNCTION check_overlapping_bed_hospitalizations()
RETURNS TRIGGER AS
$$
DECLARE
    conflict_exists BOOLEAN;
BEGIN
    SELECT EXISTS (
        SELECT 1
        FROM hospitalization h
        WHERE h.department_id = NEW.department_id
          AND h.bed_num = NEW.bed_num
          AND h.hospitalization_id <> NEW.hospitalization_id
          AND NEW.admission_date < COALESCE(h.discharge_date, TIMESTAMP '9999-12-31')
          AND COALESCE(NEW.discharge_date, TIMESTAMP '9999-12-31') > h.admission_date
    )
    INTO conflict_exists;

    IF conflict_exists THEN
        RAISE EXCEPTION
        'Hospitalization rejected: bed is already occupied during this time interval.';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_check_overlapping_bed_hospitalizations
BEFORE INSERT OR UPDATE
ON hospitalization
FOR EACH ROW
EXECUTE FUNCTION check_overlapping_bed_hospitalizations();