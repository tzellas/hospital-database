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
    ON a.substance_name = s.active_substance

-- PATIENTS --
\copy patient(amka,first_name,last_name,father_name,age,gender,weight,height,address_street,address_num,postal_code,city,phone,email,occupation,nationality,insurance_provider) FROM 'data/patients.csv' DELIMITER ',' CSV HEADER;

-- EMERGENCY_CONTACTS --
\copy emergency_contact(patient_id,contact_num,first_name,last_name,age,relationship,phone,email) FROM 'data/emergency_contacts.csv' DELIMITER ',' CSV HEADER;

-- STAFF --
\copy staff(amka,first_name,last_name,age,email,phone,hire_date,staff_type) FROM 'data/staff.csv' DELIMITER ',' CSV HEADER;

-- DEPARTMENTS --
--\copy department(name,description,bed_count,floor,building,phone) FROM 'data/departments.csv' DELIMITER ',' CSV HEADER;
