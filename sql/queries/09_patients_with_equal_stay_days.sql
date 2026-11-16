-- Run with psql from the repo root. In pgAdmin, delete the \encoding line.
\encoding UTF8

/*
09 · Patients with equal total stay days

Find the patients who were hospitalized for the same total number of
days within the same year, with a total stay of more than 15 days.

We do not return pairs of patients: each patient is shown separately,
but only if another patient in the same year has the same
total_stay_days.

Aliases:
h   = hospitalization
p   = patient
ps  = patient_stay_summary
dup = duplicate_stay_days
*/

WITH patient_stay_summary AS (

    SELECT
        h.patient_id,

        -- Year of the hospitalization
        EXTRACT(YEAR FROM h.admission_date)::INT AS hospitalization_year,

        -- Total days the patient spent in hospital in that year
        SUM(h.discharge_date::DATE - h.admission_date::DATE) AS total_stay_days

    FROM hospitalization AS h

    WHERE h.discharge_date IS NOT NULL

    GROUP BY
        h.patient_id,
        EXTRACT(YEAR FROM h.admission_date)

    HAVING SUM(h.discharge_date::DATE - h.admission_date::DATE) > 15
),

duplicate_stay_days AS (

    SELECT
        ps.hospitalization_year,
        ps.total_stay_days

    FROM patient_stay_summary AS ps

    GROUP BY
        ps.hospitalization_year,
        ps.total_stay_days

    -- Keep only day totals shared by more than one patient.
    HAVING COUNT(*) > 1
)

SELECT
    p.patient_id,
    p.first_name,
    p.last_name,
    p.amka,

    ps.hospitalization_year,
    ps.total_stay_days

FROM patient_stay_summary AS ps

JOIN duplicate_stay_days AS dup
    ON dup.hospitalization_year = ps.hospitalization_year
   AND dup.total_stay_days = ps.total_stay_days

JOIN patient AS p
    ON p.patient_id = ps.patient_id

ORDER BY
    ps.hospitalization_year,
    ps.total_stay_days DESC,
    p.last_name,
    p.first_name;
