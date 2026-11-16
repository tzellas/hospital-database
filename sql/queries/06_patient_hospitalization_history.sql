-- Run with psql from the repo root. In pgAdmin, delete the \encoding line.
\encoding UTF8

/*
06 · Patient hospitalization history

For a given patient, find:
- their hospitalization history
- the ICD-10 admission diagnosis
- the ICD-10 discharge diagnosis
- the total cost of each hospitalization
- the average review score of each hospitalization

CHANGE THE PATIENT HERE:
WHERE p.patient_id = 1

Aliases:
p       = patient
h       = hospitalization
d       = department
icd_in  = icd10_diagnosis for the admission diagnosis
icd_out = icd10_diagnosis for the discharge diagnosis
hr      = hospitalization_review
*/

SELECT
    -- Patient details
    p.patient_id,
    p.first_name,
    p.last_name,
    p.amka,

    -- Hospitalization details
    h.hospitalization_id,
    d.name AS department_name,
    h.admission_date,
    h.discharge_date,

    -- ICD-10 admission diagnosis
    h.admission_icd10_code,
    icd_in.description AS admission_diagnosis_description,

    -- ICD-10 discharge diagnosis
    h.discharge_icd10_code,
    icd_out.description AS discharge_diagnosis_description,

    -- Total cost of this hospitalization
    h.total_cost,

    -- Average review score of the hospitalization,
    -- computed from the 4 criteria of hospitalization_review.
    (
        hr.nursing_care_score
        + hr.cleanliness_score
        + hr.food_score
        + hr.overall_experience_score
    ) / 4.0 AS avg_hospitalization_review_score

FROM patient AS p

JOIN hospitalization AS h
    ON h.patient_id = p.patient_id

JOIN department AS d
    ON d.department_id = h.department_id

JOIN icd10_diagnosis AS icd_in
    ON icd_in.icd10_code = h.admission_icd10_code

LEFT JOIN icd10_diagnosis AS icd_out
    ON icd_out.icd10_code = h.discharge_icd10_code

LEFT JOIN hospitalization_review AS hr
    ON hr.patient_id = h.patient_id
   AND hr.hospitalization_id = h.hospitalization_id

-- The patient to analyse
WHERE p.patient_id = 1

ORDER BY
    h.admission_date;


/*
06 - EXPLAIN ANALYZE
Default plan.
*/

EXPLAIN ANALYZE
SELECT
    p.patient_id,
    p.first_name,
    p.last_name,
    p.amka,
    h.hospitalization_id,
    d.name AS department_name,
    h.admission_date,
    h.discharge_date,
    h.admission_icd10_code,
    icd_in.description AS admission_diagnosis_description,
    h.discharge_icd10_code,
    icd_out.description AS discharge_diagnosis_description,
    h.total_cost,
    (
        hr.nursing_care_score
        + hr.cleanliness_score
        + hr.food_score
        + hr.overall_experience_score
    ) / 4.0 AS avg_hospitalization_review_score

FROM patient AS p
JOIN hospitalization AS h
    ON h.patient_id = p.patient_id
JOIN department AS d
    ON d.department_id = h.department_id
JOIN icd10_diagnosis AS icd_in
    ON icd_in.icd10_code = h.admission_icd10_code
LEFT JOIN icd10_diagnosis AS icd_out
    ON icd_out.icd10_code = h.discharge_icd10_code
LEFT JOIN hospitalization_review AS hr
    ON hr.patient_id = h.patient_id
   AND hr.hospitalization_id = h.hospitalization_id

WHERE p.patient_id = 1

ORDER BY
    h.admission_date;


/*
06 - EXPLAIN ANALYZE with a hint-like approach

PostgreSQL has no FORCE INDEX as MySQL does.
SET enable_seqscan = off pushes the optimizer to avoid sequential
scans and prefer indexes.
*/

SET enable_seqscan = off;

EXPLAIN ANALYZE
SELECT
    p.patient_id,
    p.first_name,
    p.last_name,
    p.amka,
    h.hospitalization_id,
    d.name AS department_name,
    h.admission_date,
    h.discharge_date,
    h.admission_icd10_code,
    icd_in.description AS admission_diagnosis_description,
    h.discharge_icd10_code,
    icd_out.description AS discharge_diagnosis_description,
    h.total_cost,
    (
        hr.nursing_care_score
        + hr.cleanliness_score
        + hr.food_score
        + hr.overall_experience_score
    ) / 4.0 AS avg_hospitalization_review_score

FROM patient AS p
JOIN hospitalization AS h
    ON h.patient_id = p.patient_id
JOIN department AS d
    ON d.department_id = h.department_id
JOIN icd10_diagnosis AS icd_in
    ON icd_in.icd10_code = h.admission_icd10_code
LEFT JOIN icd10_diagnosis AS icd_out
    ON icd_out.icd10_code = h.discharge_icd10_code
LEFT JOIN hospitalization_review AS hr
    ON hr.patient_id = h.patient_id
   AND hr.hospitalization_id = h.hospitalization_id

WHERE p.patient_id = 1

ORDER BY
    h.admission_date;

RESET enable_seqscan;
