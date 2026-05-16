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
triage_case
RESTART IDENTITY CASCADE;

\encoding UTF8

-- ICD10_DIAGNOSIS --
\copy icd10_diagnosis(icd10_code, description) FROM 'data/icd10.csv' WITH (FORMAT csv, DELIMITER ',', QUOTE '"', ENCODING 'UTF8'); 

-- KEN --
\copy ken(ken_code, description, base_cost, average_length_of_stay) FROM 'data/ken.csv' WITH (FORMAT csv, DELIMITER ',', QUOTE '"', ENCODING 'UTF8'); 

