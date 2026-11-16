-- Loads every CSV in data/ into the schema created by sql/schema.sql.
--
-- Run from the repository root (the \copy paths are relative) and as a
-- superuser such as postgres: the bulk shift load below temporarily disables
-- all triggers on duty_shift_staff and audits the result afterwards.

-- Empty every table first so the script can be re-run on an existing database.
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
  ON d.i = s.i;

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

-- BEDS --
CREATE TEMP TABLE tmp_bed_data (
    i SERIAL PRIMARY KEY,
    bed_num VARCHAR(20) NOT NULL UNIQUE,
    bed_type VARCHAR(50) NOT NULL,
    status VARCHAR(50) NOT NULL,
    department VARCHAR(100) NOT NULL
);

\copy tmp_bed_data(bed_num, bed_type, status, department) FROM 'data/beds.csv' DELIMITER ',' CSV HEADER;

INSERT INTO bed(department_id, bed_num, bed_type, status)
SELECT
    d.department_id,
    m.bed_num,
    m.bed_type,
    m.status
FROM tmp_bed_data m
JOIN department d
  ON d.name = m.department;

-- DUTY_SHIFTS --
\copy duty_shift(department_id, shift_date, shift_type, start_time, end_time) FROM 'data/duty_shifts.csv' DELIMITER ',' CSV HEADER;



BEGIN;

ALTER TABLE duty_shift_staff DISABLE TRIGGER ALL;

CREATE TEMP TABLE tmp_doctor_shift_staff (
    shift_type VARCHAR(20),
    department_name VARCHAR(100),
    shift_date DATE,
    medical_license_num VARCHAR(50)
);

\copy tmp_doctor_shift_staff FROM 'data/doctor_shift_assignments_by_license.csv' DELIMITER ',' CSV HEADER;

INSERT INTO duty_shift_staff (duty_shift_id, staff_id)
SELECT ds.duty_shift_id, d.staff_id
FROM tmp_doctor_shift_staff t
JOIN department dep ON dep.name = t.department_name
JOIN duty_shift ds
    ON ds.department_id = dep.department_id
   AND ds.shift_date = t.shift_date
   AND ds.shift_type = t.shift_type
JOIN doctor d ON d.medical_license_num = t.medical_license_num;


CREATE TEMP TABLE tmp_nurse_shift_staff (
    shift_type VARCHAR(20),
    department_name VARCHAR(100),
    shift_date DATE,
    nurse_amka VARCHAR(20)
);

\copy tmp_nurse_shift_staff FROM 'data/nurse_shift_assignments_by_amka.csv' DELIMITER ',' CSV HEADER;

INSERT INTO duty_shift_staff (duty_shift_id, staff_id)
SELECT ds.duty_shift_id, s.staff_id
FROM tmp_nurse_shift_staff t
JOIN department dep ON dep.name = t.department_name
JOIN duty_shift ds
    ON ds.department_id = dep.department_id
   AND ds.shift_date = t.shift_date
   AND ds.shift_type = t.shift_type
JOIN staff s ON s.amka = t.nurse_amka
JOIN nurse n ON n.staff_id = s.staff_id;


CREATE TEMP TABLE tmp_admin_shift_staff (
    shift_type VARCHAR(20),
    department_name VARCHAR(100),
    shift_date DATE,
    admin_amka VARCHAR(20)
);

\copy tmp_admin_shift_staff FROM 'data/admin_shift_assignments_by_amka.csv' DELIMITER ',' CSV HEADER;

INSERT INTO duty_shift_staff (duty_shift_id, staff_id)
SELECT ds.duty_shift_id, s.staff_id
FROM tmp_admin_shift_staff t
JOIN department dep ON dep.name = t.department_name
JOIN duty_shift ds
    ON ds.department_id = dep.department_id
   AND ds.shift_date = t.shift_date
   AND ds.shift_type = t.shift_type
JOIN staff s ON s.amka = t.admin_amka
JOIN administrative a ON a.staff_id = s.staff_id;

ALTER TABLE duty_shift_staff ENABLE TRIGGER ALL;

COMMIT;

-- POST-LOAD AUDIT --
-- The triggers were disabled for the bulk load, so the staffing rules are
-- re-checked here. Each query lists violations of one rule:
-- an empty result means the data is clean.

-- 1. exact staffing: 3 doctors, 6 nurses, 2 admins
SELECT dep.name, ds.shift_date, ds.shift_type,
       COUNT(doc.staff_id) doctors,
       COUNT(n.staff_id) nurses,
       COUNT(a.staff_id) admins
FROM duty_shift ds
JOIN department dep ON dep.department_id = ds.department_id
LEFT JOIN duty_shift_staff dss ON dss.duty_shift_id = ds.duty_shift_id
LEFT JOIN doctor doc ON doc.staff_id = dss.staff_id
LEFT JOIN nurse n ON n.staff_id = dss.staff_id
LEFT JOIN administrative a ON a.staff_id = dss.staff_id
GROUP BY dep.name, ds.shift_date, ds.shift_type
HAVING COUNT(doc.staff_id) <> 3
    OR COUNT(n.staff_id) <> 6
    OR COUNT(a.staff_id) <> 2;

-- 2. monthly limits
SELECT s.staff_id, s.staff_type,
       DATE_TRUNC('month', ds.shift_date)::date AS month,
       COUNT(*) shifts
FROM duty_shift_staff dss
JOIN duty_shift ds ON ds.duty_shift_id = dss.duty_shift_id
JOIN staff s ON s.staff_id = dss.staff_id
GROUP BY s.staff_id, s.staff_type, DATE_TRUNC('month', ds.shift_date)
HAVING (s.staff_type = 'DOCTOR' AND COUNT(*) > 15)
    OR (s.staff_type = 'NURSE' AND COUNT(*) > 20)
    OR (s.staff_type = 'ADMINISTRATIVE' AND COUNT(*) > 25);

-- 3. minimum 8h rest
WITH x AS (
  SELECT dss.staff_id,
         ds.shift_date,
         ds.shift_type,
         ds.shift_date + ds.start_time AS start_ts,
         CASE WHEN ds.end_time <= ds.start_time
              THEN ds.shift_date + ds.end_time + INTERVAL '1 day'
              ELSE ds.shift_date + ds.end_time
         END AS end_ts
  FROM duty_shift_staff dss
  JOIN duty_shift ds ON ds.duty_shift_id = dss.duty_shift_id
),
y AS (
  SELECT *, LAG(end_ts) OVER (PARTITION BY staff_id ORDER BY start_ts) prev_end
  FROM x
)
SELECT *
FROM y
WHERE prev_end IS NOT NULL
  AND start_ts - prev_end < INTERVAL '8 hours';

-- 4. max 3 consecutive nights
WITH nights AS (
  SELECT dss.staff_id,
         ds.shift_date,
         ds.shift_date - ROW_NUMBER() OVER (
           PARTITION BY dss.staff_id ORDER BY ds.shift_date
         )::int AS grp
  FROM duty_shift_staff dss
  JOIN duty_shift ds ON ds.duty_shift_id = dss.duty_shift_id
  WHERE ds.shift_type = 'NIGHT'
),
streaks AS (
  SELECT staff_id, MIN(shift_date) start_date, MAX(shift_date) end_date, COUNT(*) nights
  FROM nights
  GROUP BY staff_id, grp
)
SELECT *
FROM streaks
WHERE nights > 3;

-- 5. resident doctor always with senior
SELECT dep.name, ds.shift_date, ds.shift_type
FROM duty_shift ds
JOIN department dep ON dep.department_id = ds.department_id
JOIN duty_shift_staff dss ON dss.duty_shift_id = ds.duty_shift_id
JOIN doctor d ON d.staff_id = dss.staff_id
GROUP BY dep.name, ds.shift_date, ds.shift_type
HAVING COUNT(*) FILTER (WHERE d.rank = 'RESIDENT') > 0
   AND COUNT(*) FILTER (WHERE d.rank IN ('CONSULTANT_A', 'DIRECTOR')) = 0;

-- 6. doctors work only in departments they belong to
SELECT dep.name, d.medical_license_num, d.specialty
FROM duty_shift_staff dss
JOIN duty_shift ds ON ds.duty_shift_id = dss.duty_shift_id
JOIN department dep ON dep.department_id = ds.department_id
JOIN doctor d ON d.staff_id = dss.staff_id
LEFT JOIN doctor_department dd
  ON dd.doctor_id = d.staff_id
 AND dd.department_id = dep.department_id
WHERE dd.doctor_id IS NULL;

-- 7. nurses work only in their own department
SELECT dep.name, s.staff_id, s.amka
FROM duty_shift_staff dss
JOIN duty_shift ds ON ds.duty_shift_id = dss.duty_shift_id
JOIN department dep ON dep.department_id = ds.department_id
JOIN staff s ON s.staff_id = dss.staff_id
JOIN nurse n ON n.staff_id = s.staff_id
WHERE n.department_id <> dep.department_id;

-- 8. administrative staff work only in their own department
SELECT dep.name, s.staff_id, s.amka
FROM duty_shift_staff dss
JOIN duty_shift ds ON ds.duty_shift_id = dss.duty_shift_id
JOIN department dep ON dep.department_id = ds.department_id
JOIN staff s ON s.staff_id = dss.staff_id
JOIN administrative a ON a.staff_id = s.staff_id
WHERE a.department_id <> dep.department_id;

-- HOSPITALIZATIONS --
\copy hospitalization(patient_id,department_id,bed_num,admission_date,discharge_date,admission_icd10_code,discharge_icd10_code,ken_code,total_cost,extra_charge) FROM 'data/hospitalizations.csv' DELIMITER ',' CSV HEADER;

-- TRIAGE CASES --
\copy triage_case(patient_id,triage_nurse_id,arrival_datetime,service_datetime,symptoms,urgency_level,outcome,referred_department_id,hospitalization_id) FROM 'data/triage_cases.csv' DELIMITER ',' CSV HEADER;

-- PROCEDURE_ROOMS --
\copy procedure_room(room_name, room_type) FROM 'data/procedure_rooms.csv' DELIMITER ',' CSV HEADER;

-- HOSPITALIZATION LAB TESTS --
\copy hospitalization_lab_test(hospitalization_id,ordered_by_doctor_id,test_code,test_date,result_text,result_value,result_unit,actual_cost) FROM 'data/hospitalization_lab_tests.csv' DELIMITER ',' CSV HEADER;

-- ALLERGIES --
\copy allergy(patient_id,substance_id) FROM 'data/allergies.csv' DELIMITER ',' CSV HEADER;

-- HOSPITALIZATION_MEDICAL_PROCEDURE --
\copy hospitalization_medical_procedure(hospitalization_id,procedure_code,main_doctor_id,actual_duration_minutes,actual_cost) FROM 'data/hospitalization_medical_procedures.csv' DELIMITER ',' CSV HEADER;

-- PROCEDURE_ROOM_SCHEDULE --
\copy procedure_room_schedule(procedure_id,room_id,start_datetime,end_datetime) FROM 'data/procedure_room_schedule.csv' DELIMITER ',' CSV HEADER;

-- ASSISTANT_PROCEDURE_STAFF --
\copy assistant_procedure_staff(procedure_id,staff_id,role_in_procedure) FROM 'data/assistant_procedure_staff.csv' DELIMITER ',' CSV HEADER;

-- PRESCRIPTIONS --
\copy prescription(hospitalization_id,patient_id,doctor_id,drug_id,dosage,frequency,start_date,end_date) FROM 'data/prescriptions.csv' DELIMITER ',' CSV HEADER;

-- HOSPITALIZATION_REVIEW --
\copy hospitalization_review(patient_id,hospitalization_id,nursing_care_score,cleanliness_score,food_score,overall_experience_score,review_date) FROM 'data/hospitalization_reviews.csv' DELIMITER ',' CSV HEADER;

-- DOCTOR_REVIEW --
\copy doctor_review(patient_id,doctor_id,hospitalization_id,medical_care_score,review_date) FROM 'data/doctor_reviews.csv' DELIMITER ',' CSV HEADER;
