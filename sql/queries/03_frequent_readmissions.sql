-- Run with psql from the repo root. In pgAdmin, delete the \encoding line.
\encoding UTF8

/*
03 · Frequent readmissions

Find the patients who were hospitalized more than 3 times
in the same department.

For each such patient and department, show:
- patient details
- the department
- the number of hospitalizations in that department
- the total cost of those hospitalizations

Aliases:
p = patient
h = hospitalization
d = department
*/

SELECT
    -- Patient details
    p.patient_id,
    p.first_name,
    p.last_name,
    p.amka,

    -- Department in which the patient was hospitalized more than 3 times
    d.department_id,
    d.name AS department_name,

    -- Number of the patient's hospitalizations in this department
    COUNT(*) AS hospitalization_count,

    -- Total cost of all those hospitalizations
    SUM(h.total_cost) AS total_hospitalization_cost

FROM patient AS p

JOIN hospitalization AS h
    ON h.patient_id = p.patient_id

JOIN department AS d
    ON d.department_id = h.department_id

GROUP BY
    p.patient_id,
    p.first_name,
    p.last_name,
    p.amka,
    d.department_id,
    d.name

-- Keep only the groups where the same patient has
-- more than 3 hospitalizations in the same department.
HAVING COUNT(*) > 3

ORDER BY
    hospitalization_count DESC,
    total_hospitalization_cost DESC,
    p.last_name,
    p.first_name;
