-- Run with psql from the repo root. In pgAdmin, delete the \encoding line.
\encoding UTF8

/*
07 · Substance allergies and drug coverage

For every active substance, find:
- how many patients have a recorded allergy to it
- how many drugs contain it

Results are sorted by:
- number of allergic patients (descending)

Aliases:
al  = allergy
acs = active_substance
das = drug_active_substance
drg = drug
*/

SELECT
    -- Active substance details
    acs.substance_id,
    acs.substance_name AS active_substance_name,

    -- Number of distinct patients with a recorded allergy
    COUNT(DISTINCT al.patient_id) AS allergic_patient_count,

    -- Number of distinct drugs containing the active substance
    COUNT(DISTINCT drg.drug_id) AS drug_count

FROM active_substance AS acs

-- Link to patient allergies
LEFT JOIN allergy AS al
    ON al.substance_id = acs.substance_id

-- Link the active substance to drugs
LEFT JOIN drug_active_substance AS das
    ON das.substance_id = acs.substance_id

LEFT JOIN drug AS drg
    ON drg.drug_id = das.drug_id

GROUP BY
    acs.substance_id,
    acs.substance_name

ORDER BY
    allergic_patient_count DESC,
    drug_count DESC,
    acs.substance_name;
