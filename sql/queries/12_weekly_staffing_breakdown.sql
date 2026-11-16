-- Run with psql from the repo root. In pgAdmin, delete the \encoding line.
\encoding UTF8

/*
12 · Weekly staffing breakdown

Find the staff headcount per department and per shift for a given
week, broken down by staff subclass:

- doctors by specialty
- nurses by rank
- administrative staff by role

Interpretation:
The query counts the staff already assigned to the duty shifts
of that week.

CHANGE THE WEEK HERE:
WHERE ds.shift_date >= DATE '2026-03-09'
  AND ds.shift_date <  DATE '2026-03-16'

Aliases:
ds  = duty_shift
dss = duty_shift_staff
dep = department
st  = staff
doc = doctor
nur = nurse
adm = administrative
*/

SELECT
    -- Department of the duty shift
    dep.department_id,
    dep.name AS department_name,

    -- Date and type of the shift
    ds.shift_date,
    ds.shift_type,

    -- Staff category
    st.staff_type,

    -- Staff subclass:
    -- for doctors it shows the specialty
    -- for nurses it shows the rank
    -- for administrative staff it shows the role
    CASE
        WHEN st.staff_type = 'DOCTOR' THEN doc.specialty
        WHEN st.staff_type = 'NURSE' THEN nur.rank
        WHEN st.staff_type = 'ADMINISTRATIVE' THEN adm.role
    END AS staff_subcategory,

    -- Staff headcount for this shift, category and subcategory.
    COUNT(*) AS required_staff_count

FROM duty_shift AS ds

JOIN department AS dep
    ON dep.department_id = ds.department_id

JOIN duty_shift_staff AS dss
    ON dss.duty_shift_id = ds.duty_shift_id

JOIN staff AS st
    ON st.staff_id = dss.staff_id

LEFT JOIN doctor AS doc
    ON doc.staff_id = st.staff_id

LEFT JOIN nurse AS nur
    ON nur.staff_id = st.staff_id

LEFT JOIN administrative AS adm
    ON adm.staff_id = st.staff_id

-- The week to analyse
-- (start date inclusive, end date exclusive)
WHERE ds.shift_date >= DATE '2026-03-09'
  AND ds.shift_date <  DATE '2026-03-16'

GROUP BY
    dep.department_id,
    dep.name,
    ds.shift_date,
    ds.shift_type,
    st.staff_type,
    CASE
        WHEN st.staff_type = 'DOCTOR' THEN doc.specialty
        WHEN st.staff_type = 'NURSE' THEN nur.rank
        WHEN st.staff_type = 'ADMINISTRATIVE' THEN adm.role
    END

ORDER BY
    dep.name,
    ds.shift_date,
    ds.shift_type,
    st.staff_type,
    staff_subcategory;
