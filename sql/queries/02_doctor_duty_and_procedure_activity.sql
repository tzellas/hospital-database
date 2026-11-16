-- Run with psql from the repo root. In pgAdmin, delete the \encoding line.
\encoding UTF8

/*
02 · Doctor duty and procedure activity

For a given medical specialty, list:
- every doctor of that specialty
- whether they had at least one duty shift in the current year
- how many procedures they performed as lead doctor in the current year

CHANGE THE SPECIALTY HERE:
WHERE doc.specialty = 'Cardiology'

Aliases:
doc = doctor
st  = staff
ds  = duty_shift
dss = duty_shift_staff
hmp = hospitalization_medical_procedure
prs = procedure_room_schedule
dc  = duty_current_year
pc  = procedure_count_current_year
*/

WITH duty_current_year AS (

    SELECT
        dss.staff_id AS doctor_id,

        -- If a row exists here, the doctor had at least one
        -- duty shift in the current year.
        COUNT(*) AS duty_count

    FROM duty_shift_staff AS dss

    JOIN duty_shift AS ds
        ON ds.duty_shift_id = dss.duty_shift_id

    -- Keep only shifts of the current year
    WHERE EXTRACT(YEAR FROM ds.shift_date) = EXTRACT(YEAR FROM CURRENT_DATE)

    GROUP BY
        dss.staff_id
),

procedure_count_current_year AS (

    SELECT
        hmp.main_doctor_id AS doctor_id,

        -- Count the distinct procedures in which
        -- the doctor was the lead doctor.
        COUNT(DISTINCT hmp.procedure_id) AS main_procedure_count

    FROM hospitalization_medical_procedure AS hmp

    JOIN procedure_room_schedule AS prs
        ON prs.procedure_id = hmp.procedure_id

    -- Keep only procedures performed in the current year
    WHERE EXTRACT(YEAR FROM prs.start_datetime) = EXTRACT(YEAR FROM CURRENT_DATE)

    GROUP BY
        hmp.main_doctor_id
)

SELECT
    -- Basic doctor details
    doc.staff_id AS doctor_id,
    st.first_name,
    st.last_name,
    doc.specialty,
    doc.rank,

    -- Whether the doctor had a duty shift in the current year
    CASE
        WHEN dc.duty_count IS NULL THEN 'NO'
        ELSE 'YES'
    END AS had_duty_current_year,

    -- Number of duty shifts in the current year
    COALESCE(dc.duty_count, 0) AS duty_count_current_year,

    -- Number of procedures as lead doctor in the current year
    COALESCE(pc.main_procedure_count, 0) AS main_procedure_count_current_year

FROM doctor AS doc

JOIN staff AS st
    ON st.staff_id = doc.staff_id

-- LEFT JOIN so doctors without any duty shift are kept
LEFT JOIN duty_current_year AS dc
    ON dc.doctor_id = doc.staff_id

-- LEFT JOIN so doctors without any procedure are kept
LEFT JOIN procedure_count_current_year AS pc
    ON pc.doctor_id = doc.staff_id

-- Put the specialty you want here
WHERE doc.specialty = 'Cardiology'

ORDER BY
    pc.main_procedure_count DESC NULLS LAST,
    st.last_name,
    st.first_name;
