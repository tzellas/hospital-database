-- Όταν το τρέχουμε σε pgAdmin σβήνουμε αυτή τη γραμμή 
\encoding UTF8 

/*
Q06
Για συγκεκριμένο ασθενή, βρίσκουμε:
- το ιστορικό νοσηλειών του
- τη διάγνωση εισαγωγής ICD-10
- τη διάγνωση εξόδου ICD-10
- το συνολικό κόστος ανά νοσηλεία
- τον μέσο όρο αξιολόγησης ανά νοσηλεία

Αλλάζουμε εδω τον ασθενή:
WHERE p.patient_id = 1

ALIASES:
p       = patient
h       = hospitalization
d       = department
icd_in  = icd10_diagnosis για διάγνωση εισαγωγής
icd_out = icd10_diagnosis για διάγνωση εξόδου
hr      = hospitalization_review
*/

SELECT
    -- Στοιχεία ασθενούς
    p.patient_id,
    p.first_name,
    p.last_name,
    p.amka,

    -- Στοιχεία νοσηλείας
    h.hospitalization_id,
    d.name AS department_name,
    h.admission_date,
    h.discharge_date,

    -- ICD-10 διάγνωση εισαγωγής
    h.admission_icd10_code,
    icd_in.description AS admission_diagnosis_description,

    -- ICD-10 διάγνωση εξόδου
    h.discharge_icd10_code,
    icd_out.description AS discharge_diagnosis_description,

    -- Συνολικό κόστος της συγκεκριμένης νοσηλείας
    h.total_cost,

    -- Μέσος όρος αξιολόγησης της νοσηλείας
    -- Υπολογίζεται από τα 4 κριτήρια του hospitalization_review.
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

-- Εδώ βάζεις τον συγκεκριμένο ασθενή
WHERE p.patient_id = 1

ORDER BY
    h.admission_date;

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
Q06 - EXPLAIN ANALYZE με hint-like προσέγγιση

Η PostgreSQL δεν έχει FORCE INDEX όπως η MySQL.
Με το enable_seqscan = off πιέζουμε τον optimizer
να αποφύγει sequential scans και να προτιμήσει indexes.
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
