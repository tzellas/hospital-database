-- Run with psql from the repo root. In pgAdmin, delete the \encoding line.
\encoding UTF8

/*
08 · Staff not on duty

Find the staff members
(doctors, nurses and administrative employees)
who are NOT scheduled for a duty shift
on a given date and department.

CHANGE THE DATE AND DEPARTMENT HERE:
DATE '2025-12-10'
AND ds.department_id = 3

The seed data covers shifts from 2025-03-20 to 2026-03-19, so use a date
in that range; outside it nobody is scheduled and everyone is returned.

Aliases:
st  = staff
doc = doctor
nur = nurse
adm = administrative
dss = duty_shift_staff
ds  = duty_shift
*/

SELECT
    -- Basic staff details
    st.staff_id,
    st.first_name,
    st.last_name,
    st.staff_type,
    st.email,
    st.phone,

    -- Details per staff category
    doc.specialty,
    doc.rank AS doctor_rank,

    nur.rank AS nurse_rank,

    adm.role AS administrative_role

FROM staff AS st

-- Doctor details (if the staff member is a doctor)
LEFT JOIN doctor AS doc
    ON doc.staff_id = st.staff_id

-- Nurse details
LEFT JOIN nurse AS nur
    ON nur.staff_id = st.staff_id

-- Administrative staff details
LEFT JOIN administrative AS adm
    ON adm.staff_id = st.staff_id

-- Keep only staff who do NOT appear in a duty shift
-- for the given department and date.
WHERE st.staff_id NOT IN (

    SELECT
        dss.staff_id

    FROM duty_shift_staff AS dss

    JOIN duty_shift AS ds
        ON ds.duty_shift_id = dss.duty_shift_id

    WHERE ds.shift_date = DATE '2025-12-10'
      AND ds.department_id = 3
)

ORDER BY
    st.staff_type,
    st.last_name,
    st.first_name;
