\encoding UTF8 -- Όταν το τρέχουμε σε pgAdmin σβήνουμε αυτή τη γραμμή 

/*
Q08
Βρίσκουμε το προσωπικό
(ιατρούς, νοσηλευτές και διοικητικούς υπαλλήλους)
που ΔΕΝ έχει προγραμματισμένη εφημερία
σε συγκεκριμένη ημερομηνία και τμήμα.

ΑΛΛΑZOYME ΕΔΩ ΗΜΕΡΟΜΗΝΙΑ ΚΑΙ ΤΜΗΜΑ:
DATE '2026-05-10'
AND ds.department_id = 3

ALIASES:
st  = staff
doc = doctor
nur = nurse
adm = administrative
dss = duty_shift_staff
ds  = duty_shift
*/

SELECT
    -- Βασικά στοιχεία προσωπικού
    st.staff_id,
    st.first_name,
    st.last_name,
    st.staff_type,
    st.email,
    st.phone,

    -- Πληροφορίες ανά κατηγορία προσωπικού
    doc.specialty,
    doc.rank AS doctor_rank,

    nur.rank AS nurse_rank,

    adm.role AS administrative_role

FROM staff AS st

-- Στοιχεία ιατρού (αν το μέλος προσωπικού είναι ιατρός)
LEFT JOIN doctor AS doc
    ON doc.staff_id = st.staff_id

-- Στοιχεία νοσηλευτή
LEFT JOIN nurse AS nur
    ON nur.staff_id = st.staff_id

-- Στοιχεία διοικητικού προσωπικού
LEFT JOIN administrative AS adm
    ON adm.staff_id = st.staff_id

-- Κρατάμε μόνο το προσωπικό που ΔΕΝ εμφανίζεται
-- σε εφημερία για το συγκεκριμένο τμήμα και ημερομηνία.
WHERE st.staff_id NOT IN (

    SELECT
        dss.staff_id

    FROM duty_shift_staff AS dss

    JOIN duty_shift AS ds
        ON ds.duty_shift_id = dss.duty_shift_id

    WHERE ds.shift_date = DATE '2026-05-10'
      AND ds.department_id = 3
)

ORDER BY
    st.staff_type,
    st.last_name,
    st.first_name;
