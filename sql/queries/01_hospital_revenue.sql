-- Run with psql from the repo root. In pgAdmin, delete the \encoding line.
\encoding UTF8

/*
01 · Hospital revenue

Total revenue of completed hospitalizations, grouped by:
- department
- admission year
- KEN code
- patient insurer

Broken down into:
- base cost defined by the KEN code
- extra charge for stays longer than the KEN's average length of stay (ALOS)
- total revenue

Aliases:
h  = hospitalization
p  = patient
k  = ken
hc = hospitalization_costs
d  = department
*/

WITH hospitalization_costs AS (
    SELECT
        h.hospitalization_id,

        -- Department of the stay
        h.department_id,

        -- Year in which the patient was admitted
        EXTRACT(YEAR FROM h.admission_date)::INT AS admission_year,

        -- KEN code of the stay
        h.ken_code,

        -- Patient's insurer
        p.insurance_provider,

        -- Base cost defined by the KEN code
        k.base_cost,

        -- Length of stay in days.
        -- Cast to DATE so we count calendar days.
        (h.discharge_date::DATE - h.admission_date::DATE) AS actual_days,

        -- Average length of stay (ALOS) defined by the KEN code
        k.average_length_of_stay,

        -- Extra charge:
        -- if the actual days exceed the ALOS, charge for the extra days;
        -- otherwise the extra charge is 0.
        GREATEST(
            (h.discharge_date::DATE - h.admission_date::DATE)
            - k.average_length_of_stay,
            0
        ) * k.extra_daily_charge AS calculated_extra_charge

    FROM hospitalization h

    -- Get the patient's insurer
    JOIN patient p
        ON p.patient_id = h.patient_id

    -- Get the KEN pricing data
    JOIN ken k
        ON k.ken_code = h.ken_code

    -- Count completed stays only:
    -- without a discharge_date the final length of stay is unknown.
    WHERE h.discharge_date IS NOT NULL
)

SELECT
    -- Grouping columns
    d.name AS department_name,
    hc.admission_year,
    hc.ken_code,
    hc.insurance_provider,

    -- Number of stays in this group
    COUNT(*) AS hospitalization_count,

    -- Total base revenue from the KEN codes
    SUM(hc.base_cost) AS total_base_revenue,

    -- Total extra charges for stays beyond the ALOS
    SUM(hc.calculated_extra_charge) AS total_extra_revenue,

    -- Total revenue = base cost + extra charge
    SUM(hc.base_cost + hc.calculated_extra_charge) AS total_revenue

FROM hospitalization_costs hc

-- Get the department name
JOIN department d
    ON d.department_id = hc.department_id

GROUP BY
    d.name,
    hc.admission_year,
    hc.ken_code,
    hc.insurance_provider

ORDER BY
    d.name,
    hc.admission_year,
    hc.ken_code,
    hc.insurance_provider;
