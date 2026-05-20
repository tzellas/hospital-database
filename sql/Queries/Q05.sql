\encoding UTF8 -- Όταν το τρέχουμε σε pgAdmin σβήνουμε αυτή τη γραμμή 

/*
Q05
Βρίσκουμε τους νέους ιατρούς, δηλαδή ιατρούς με ηλικία < 35,
που έχουν εκτελέσει τις περισσότερες χειρουργικές επεμβάσεις
ως κύριοι χειρουργοί.

Μετράμε μόνο ιατρικές πράξεις με κατηγορία = 'χειρουργική'
και μόνο όταν ο ιατρός είναι main_doctor_id.

ALIASES:
doc = doctor
st  = staff
hmp = hospitalization_medical_procedure
mp  = medical_procedure
*/

SELECT
    -- ID ιατρού
    doc.staff_id AS doctor_id,

    -- Στοιχεία ιατρού
    st.first_name,
    st.last_name,
    st.age,
    doc.specialty,
    doc.rank,

    -- Πλήθος χειρουργικών επεμβάσεων ως κύριος χειρουργός
    COUNT(*) AS main_surgery_count

FROM doctor AS doc

JOIN staff AS st
    ON st.staff_id = doc.staff_id

JOIN hospitalization_medical_procedure AS hmp
    ON hmp.main_doctor_id = doc.staff_id

JOIN all_medical_procedures AS mp
    ON mp.procedure_code = hmp.procedure_code

-- Κρατάμε μόνο νέους ιατρούς
WHERE st.age < 35

  -- Κρατάμε μόνο χειρουργικές επεμβάσεις
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