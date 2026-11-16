-- Run with psql from the repo root. In pgAdmin, delete the \encoding line.
\encoding UTF8

/*
05 · Top young surgeons

Find the young doctors (age < 35) who performed the most surgical
procedures as lead surgeon.

Only procedures with category = 'SURGICAL' are counted, and only when
the doctor is main_doctor_id.

Aliases:
doc = doctor
st  = staff
hmp = hospitalization_medical_procedure
mp  = all_medical_procedures
*/

SELECT
    -- Doctor ID
    doc.staff_id AS doctor_id,

    -- Doctor details
    st.first_name,
    st.last_name,
    st.age,
    doc.specialty,
    doc.rank,

    -- Number of surgeries as lead surgeon
    COUNT(*) AS main_surgery_count

FROM doctor AS doc

JOIN staff AS st
    ON st.staff_id = doc.staff_id

JOIN hospitalization_medical_procedure AS hmp
    ON hmp.main_doctor_id = doc.staff_id

JOIN all_medical_procedures AS mp
    ON mp.procedure_code = hmp.procedure_code

-- Keep only young doctors
WHERE st.age < 35

  -- Keep only surgical procedures
  AND mp.category = 'SURGICAL'

GROUP BY
    doc.staff_id,
    st.first_name,
    st.last_name,
    st.age,
    doc.specialty,
    doc.rank

ORDER BY
    main_surgery_count DESC,
    st.last_name,
    st.first_name;
