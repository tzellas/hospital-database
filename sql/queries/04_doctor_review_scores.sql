-- Run with psql from the repo root. In pgAdmin, delete the \encoding line.
\encoding UTF8

/*
04 · Doctor review scores

For a given doctor, find:
- the average rating given by their patients for
  "quality of medical care"
- the average overall impression of the hospitalizations
  those patients had

"Quality of medical care" lives in doctor_review.
"Overall experience" lives in hospitalization_review.

CHANGE THE DOCTOR HERE:
WHERE doc.staff_id = 671

Aliases:
doc = doctor
st  = staff
dr  = doctor_review
hr  = hospitalization_review
*/

SELECT
    -- Doctor ID
    doc.staff_id AS doctor_id,

    -- Doctor details
    st.first_name,
    st.last_name,
    doc.specialty,
    doc.rank,

    -- Average medical-care rating
    AVG(dr.medical_care_score) AS avg_medical_care_score,

    -- Average overall hospitalization experience
    AVG(hr.overall_experience_score) AS avg_overall_experience_score,

    -- Number of reviews used
    COUNT(*) AS review_count

FROM doctor AS doc

JOIN staff AS st
    ON st.staff_id = doc.staff_id

JOIN doctor_review AS dr
    ON dr.doctor_id = doc.staff_id

JOIN hospitalization_review AS hr
    ON hr.patient_id = dr.patient_id
   AND hr.hospitalization_id = dr.hospitalization_id

-- The doctor to analyse
WHERE doc.staff_id = 671

GROUP BY
    doc.staff_id,
    st.first_name,
    st.last_name,
    doc.specialty,
    doc.rank;


/*
04 - EXPLAIN ANALYZE
Default plan.
*/

EXPLAIN ANALYZE
SELECT
    doc.staff_id AS doctor_id,
    st.first_name,
    st.last_name,
    doc.specialty,
    doc.rank,
    AVG(dr.medical_care_score) AS avg_medical_care_score,
    AVG(hr.overall_experience_score) AS avg_overall_experience_score,
    COUNT(*) AS review_count

FROM doctor AS doc

JOIN staff AS st
    ON st.staff_id = doc.staff_id

JOIN doctor_review AS dr
    ON dr.doctor_id = doc.staff_id

JOIN hospitalization_review AS hr
    ON hr.patient_id = dr.patient_id
   AND hr.hospitalization_id = dr.hospitalization_id

WHERE doc.staff_id = 671

GROUP BY
    doc.staff_id,
    st.first_name,
    st.last_name,
    doc.specialty,
    doc.rank;


/*
04 - EXPLAIN ANALYZE with hint-like forced index behaviour

PostgreSQL has no FORCE INDEX as MySQL does.
SET enable_seqscan = off pushes the optimizer to avoid sequential
scans and prefer index-based plans wherever possible.
*/

SET enable_seqscan = off;

EXPLAIN ANALYZE
SELECT
    doc.staff_id AS doctor_id,
    st.first_name,
    st.last_name,
    doc.specialty,
    doc.rank,
    AVG(dr.medical_care_score) AS avg_medical_care_score,
    AVG(hr.overall_experience_score) AS avg_overall_experience_score,
    COUNT(*) AS review_count

FROM doctor AS doc

JOIN staff AS st
    ON st.staff_id = doc.staff_id

JOIN doctor_review AS dr
    ON dr.doctor_id = doc.staff_id

JOIN hospitalization_review AS hr
    ON hr.patient_id = dr.patient_id
   AND hr.hospitalization_id = dr.hospitalization_id

WHERE doc.staff_id = 671

GROUP BY
    doc.staff_id,
    st.first_name,
    st.last_name,
    doc.specialty,
    doc.rank;

RESET enable_seqscan;


/*
Performance notes:
Two executions of the same query are compared: the default plan and a
variant with sequential scans disabled (a hint-like approach, since
PostgreSQL does not support FORCE INDEX). We compare the estimated cost
and the actual execution time reported by EXPLAIN ANALYZE.
With enough data and suitable indexes, an index-based plan can shorten
the lookup of one doctor's reviews.
*/
