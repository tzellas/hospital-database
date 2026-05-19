TRUNCATE TABLE
active_substance,
administrative,
allergy,
assistant_procedure_staff,
bed,
department,
doctor,
doctor_department,
doctor_review,
drug,
drug_active_substance,
duty_shift,
duty_shift_staff,
emergency_contact,
entity_image,
hospitalization,
hospitalization_review,
icd10_diagnosis,
ken,
lab_test,
medical_procedure,
nurse,
patient,
prescription,
procedure_room,
procedure_room_schedule,
staff,
triage_case,
hospitalization_lab_test,
hospitalization_medical_procedure,
all_lab_tests,
all_medical_procedures
RESTART IDENTITY CASCADE;

\encoding UTF8

-- ICD10_DIAGNOSIS --
\copy icd10_diagnosis(icd10_code, description) FROM 'data/icd10.csv' WITH (FORMAT csv, DELIMITER ',', QUOTE '"', ENCODING 'UTF8'); 

-- KEN --
\copy ken(ken_code, description, base_cost, average_length_of_stay) FROM 'data/ken.csv' WITH (FORMAT csv, DELIMITER ',', QUOTE '"', ENCODING 'UTF8'); 

-- LAB_TESTS --
\copy all_lab_tests(test_code, description, default_cost) FROM 'data/lab_tests.csv' WITH (FORMAT csv, DELIMITER ',', QUOTE '"', ENCODING 'UTF8'); 

-- MEDICAL_PROCEDURES --
\copy all_medical_procedures(procedure_code, description, category, default_cost) FROM 'data/medical_procedures.csv' WITH (FORMAT csv, DELIMITER ',', QUOTE '"', ENCODING 'UTF8'); 

-- DRUGS --
\copy drug(ema_name, route_of_administration, marketing_authorisation_holder, pharmacovigilance_system_master_file_location, pharmacovigilance_enquiries_email_address, pharmacovigilance_enquiries_telephone_number) FROM 'data/drug.csv' WITH (FORMAT csv, DELIMITER ',', QUOTE '"', ENCODING 'UTF8', HEADER true);

-- ACTIVE_SUBSTANCES --
\copy active_substance(substance_name) FROM 'data/active_substances_unique.csv' WITH (FORMAT csv, DELIMITER ',', QUOTE '"', ENCODING 'UTF8'); 

-- DRUGS - ACTIVE_SUBSTANCES BRIDGE --
CREATE TEMP TABLE drug_active_substances_stage (
    drug_id INT,
    active_substance TEXT
);

\copy drug_active_substances_stage(drug_id, active_substance) FROM 'data/drug_active_substances_stage.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8');

INSERT INTO drug_active_substance(drug_id, substance_id)
SELECT DISTINCT
    s.drug_id,
    a.substance_id
FROM drug_active_substances_stage s
JOIN active_substance a
    ON a.substance_name = s.active_substance;

-- PATIENTS --
\copy patient(amka,first_name,last_name,father_name,age,gender,weight,height,address_street,address_num,postal_code,city,phone,email,occupation,nationality,insurance_provider) FROM 'data/patients.csv' DELIMITER ',' CSV HEADER;

-- EMERGENCY_CONTACTS --
\copy emergency_contact(patient_id,contact_num,first_name,last_name,age,relationship,phone,email) FROM 'data/emergency_contacts.csv' DELIMITER ',' CSV HEADER;

-- STAFF --
\copy staff(amka,first_name,last_name,age,email,phone,hire_date,staff_type) FROM 'data/staff.csv' DELIMITER ',' CSV HEADER;

-- DIRECTOR --
\copy doctor(staff_id,medical_license_num,specialty,rank,supervisor_doc_id) FROM 'data/directors.csv' DELIMITER ',' CSV HEADER;

-- DEPARTMENTS --
\copy department(name,description,bed_count,floor,building,phone,manager_id) FROM 'data/departments.csv' DELIMITER ',' CSV HEADER;

-- DOCTOR --
/* Doctor data are loaded in a temporary table except staff_id and supervisor_doc_id. The doctors that don't yet exist
(those that aren't directors) are created using a staff_id with from staff with DOCTOR staff_type.*/

CREATE TEMP TABLE tmp_doctor_data (
    i SERIAL PRIMARY KEY,
    medical_license_num VARCHAR(50),
    specialty VARCHAR(100),
    rank VARCHAR(50)
);

\copy tmp_doctor_data(medical_license_num, specialty, rank) FROM 'data/doctors.csv' DELIMITER ',' CSV HEADER;

INSERT INTO doctor (
    staff_id,
    medical_license_num,
    specialty,
    rank,
    supervisor_doc_id
)
SELECT
    s.staff_id,
    d.medical_license_num,
    d.specialty,
    d.rank,
    CASE
        WHEN d.rank = 'RESIDENT' THEN (
            SELECT d2.staff_id
            FROM doctor d2
            WHERE d2.rank IN ('CONSULTANT_B', 'CONSULTANT_A', 'DIRECTOR')
            ORDER BY random()
            LIMIT 1
        )
        ELSE NULL
    END
FROM (
    SELECT
        staff_id,
        ROW_NUMBER() OVER (ORDER BY staff_id) AS i
    FROM staff
    WHERE staff_type = 'DOCTOR'
      AND staff_id NOT IN (
          SELECT staff_id FROM doctor
      )
) s
JOIN tmp_doctor_data d
  ON d.i = s.i
WHERE s.i <= 65;

/* Here we assign supervisors based on rank to the consultants.*/
WITH supervisor_choices AS (
    SELECT
        d.staff_id AS doctor_id,
        (
            SELECT d2.staff_id
            FROM doctor d2
            WHERE d2.staff_id <> d.staff_id
              AND (
                  (d.rank = 'CONSULTANT_B' AND d2.rank IN ('CONSULTANT_A', 'DIRECTOR'))
                  OR
                  (d.rank = 'CONSULTANT_A' AND d2.rank = 'DIRECTOR')
              )
            ORDER BY random()
            LIMIT 1
        ) AS supervisor_id
    FROM doctor d
    WHERE d.rank IN ('CONSULTANT_B', 'CONSULTANT_A')
      AND d.supervisor_doc_id IS NULL
)
UPDATE doctor d
SET supervisor_doc_id = sc.supervisor_id
FROM supervisor_choices sc
WHERE d.staff_id = sc.doctor_id
  AND sc.supervisor_id IS NOT NULL;

/*Here we assign every doctor to a department based on a csv map of department and specialty.*/
CREATE TEMP TABLE tmp_dept_specialty_map (
    department_name VARCHAR(100),
    specialty VARCHAR(100)
);

\copy tmp_dept_specialty_map(department_name, specialty) FROM 'data/dept_specialty_map.csv' DELIMITER ',' CSV HEADER;

INSERT INTO doctor_department(doctor_id, department_id)
SELECT DISTINCT
    doc.staff_id,
    dep.department_id
FROM doctor doc
JOIN tmp_dept_specialty_map m
  ON m.specialty = doc.specialty
JOIN department dep
  ON dep.name = m.department_name
WHERE doc.rank <> 'DIRECTOR'
ON CONFLICT DO NOTHING;

/* We give the managers/directors a proper doctor - department relationship.*/
INSERT INTO doctor_department(doctor_id, department_id)
SELECT manager_id, department_id
FROM department
WHERE manager_id IS NOT NULL
ON CONFLICT DO NOTHING;

-- NURSE --
CREATE TEMP TABLE tmp_nurse_data (
    i SERIAL PRIMARY KEY,
    rank VARCHAR(50),
    department VARCHAR(100)
);

\copy tmp_nurse_data(rank, department) FROM 'data/nurse_department_rank.csv' DELIMITER ',' CSV HEADER;

INSERT INTO nurse(staff_id, rank, department_id)
SELECT
    s.staff_id,
    m.rank,
    d.department_id
FROM (
    SELECT staff_id,
        ROW_NUMBER() OVER (ORDER BY staff_id) AS i
    FROM staff
    WHERE staff_type = 'NURSE'
) s
JOIN tmp_nurse_data m
    ON s.i = m.i
JOIN department d
    ON d.name = m.department;

-- ADMINISTRATIVE --
CREATE TEMP TABLE tmp_admin_data (
    i SERIAL PRIMARY KEY,
    role VARCHAR(50),
    office VARCHAR(50) NOT NULL,
    department VARCHAR(100)
);

\copy tmp_admin_data(role, office, department) FROM 'data/administrative_department_roles.csv' DELIMITER ',' CSV HEADER;

INSERT INTO administrative(staff_id, role, office, department_id)
SELECT
    s.staff_id,
    m.role,
    m.office,
    d.department_id
FROM (
    SELECT staff_id,
        ROW_NUMBER() OVER (ORDER BY staff_id) AS i
    FROM staff
    WHERE staff_type = 'ADMINISTRATIVE'
) s
JOIN tmp_admin_data m
    ON s.i = m.i
JOIN department d
    ON d.name = m.department;