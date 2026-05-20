\encoding UTF8 -- Όταν το τρέχουμε σε pgAdmin σβήνουμε αυτή τη γραμμή 

/*
Q11
Βρίσκουμε όλους τους ιατρούς που έχουν εκτελέσει
τουλάχιστον 5 λιγότερες επεμβάσεις από τον ιατρό
με τις περισσότερες επεμβάσεις στο τρέχον έτος.

Ερμηνεία:
- Μετράμε πόσες επεμβάσεις έκανε κάθε ιατρός
  ως κύριος χειρουργός στο τρέχον έτος.
- Βρίσκουμε το μέγιστο πλήθος επεμβάσεων.
- Επιστρέφουμε τους ιατρούς των οποίων:
  max_procedure_count - doctor_procedure_count >= 5

ALIASES:
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

        -- Πλήθος επεμβάσεων που έκανε ο ιατρός ως κύριος χειρουργός στο τρέχον έτος
        COUNT(*) AS procedure_count

    FROM hospitalization_medical_procedure AS hmp

    JOIN procedure_room_schedule AS prs
        ON prs.procedure_id = hmp.procedure_id

    -- Κρατάμε μόνο επεμβάσεις του τρέχοντος έτους
    WHERE EXTRACT(YEAR FROM prs.start_datetime) = EXTRACT(YEAR FROM CURRENT_DATE)

    GROUP BY
        hmp.main_doctor_id
),

max_procedure_count AS (

    SELECT
        -- Μέγιστος αριθμός επεμβάσεων που έχει κάνει κάποιος ιατρός
        MAX(dpc.procedure_count) AS max_count

    FROM doctor_procedure_count AS dpc
)

SELECT
    -- Στοιχεία ιατρού
    doc.staff_id AS doctor_id,
    st.first_name,
    st.last_name,
    doc.specialty,
    doc.rank,

    -- Πλήθος επεμβάσεων του συγκεκριμένου ιατρού
    dpc.procedure_count,

    -- Πλήθος επεμβάσεων του πρώτου ιατρού
    mpc.max_count AS max_procedure_count,

    -- Διαφορά από τον πρώτο ιατρό
    mpc.max_count - dpc.procedure_count AS difference_from_top

FROM doctor_procedure_count AS dpc

JOIN max_procedure_count AS mpc
    ON TRUE

JOIN doctor AS doc
    ON doc.staff_id = dpc.doctor_id

JOIN staff AS st
    ON st.staff_id = doc.staff_id

-- Κρατάμε όσους έχουν τουλάχιστον 5 λιγότερες επεμβάσεις από τον 
-- ιατρό με τις περισσότερες επεμβάσεις.
WHERE mpc.max_count - dpc.procedure_count >= 5

ORDER BY
    difference_from_top DESC,
    dpc.procedure_count DESC,
    st.last_name,
    st.first_name;
