-- Run with psql from the repo root. In pgAdmin, delete the \encoding line.
\encoding UTF8

/*
11 · Doctors behind the leader

Find all doctors who performed at least 5 fewer procedures than the
doctor with the most procedures in the current year.

Interpretation:
- Count the procedures each doctor performed as lead doctor
  in the current year.
- Find the maximum procedure count.
- Return the doctors for whom:
  max_procedure_count - doctor_procedure_count >= 5

Aliases:
doc = doctor
st  = staff
hmp = hospitalization_medical_procedure
prs = procedure_room_schedule
dpc = doctor_procedure_count
mpc = max_procedure_count
*/

WITH doctor_procedure_count AS (

    SELECT
        hmp.main_doctor_id AS doctor_id,

        -- Number of procedures the doctor performed as lead doctor
        -- in the current year
        COUNT(*) AS procedure_count

    FROM hospitalization_medical_procedure AS hmp

    JOIN procedure_room_schedule AS prs
        ON prs.procedure_id = hmp.procedure_id

    -- Keep only procedures of the current year
    WHERE EXTRACT(YEAR FROM prs.start_datetime) = EXTRACT(YEAR FROM CURRENT_DATE)

    GROUP BY
        hmp.main_doctor_id
),

max_procedure_count AS (

    SELECT
        -- Highest number of procedures performed by any doctor
        MAX(dpc.procedure_count) AS max_count

    FROM doctor_procedure_count AS dpc
)

SELECT
    -- Doctor details
    doc.staff_id AS doctor_id,
    st.first_name,
    st.last_name,
    doc.specialty,
    doc.rank,

    -- This doctor's procedure count
    dpc.procedure_count,

    -- The leading doctor's procedure count
    mpc.max_count AS max_procedure_count,

    -- Gap to the leader
    mpc.max_count - dpc.procedure_count AS difference_from_top

FROM doctor_procedure_count AS dpc

JOIN max_procedure_count AS mpc
    ON TRUE

JOIN doctor AS doc
    ON doc.staff_id = dpc.doctor_id

JOIN staff AS st
    ON st.staff_id = doc.staff_id

-- Keep only doctors with at least 5 fewer procedures than the leader.
WHERE mpc.max_count - dpc.procedure_count >= 5

ORDER BY
    difference_from_top DESC,
    dpc.procedure_count DESC,
    st.last_name,
    st.first_name;
