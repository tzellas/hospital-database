\encoding UTF8 -- Όταν το τρέχουμε σε pgAdmin σβήνουμε αυτή τη γραμμή 

/*
Q12
Βρίσκουμε τον απαιτούμενο αριθμό προσωπικού
ανά τμήμα και ανά βάρδια για συγκεκριμένη εβδομάδα,
με ανάλυση ανά υποκλάση προσωπικού:

- Ιατροί ανά ειδικότητα
- Νοσηλευτές ανά βαθμίδα
- Διοικητικό προσωπικό ανά ρόλο

Ερμηνεία:
Το query μετρά το προσωπικό που έχει ήδη ανατεθεί
στις εφημερίες της συγκεκριμένης εβδομάδας.

ΑΛΛΑΖΟΥΜΕ ΕΔΩ ΤΗΝ ΕΒΔΟΜΑΔΑ:
WHERE ds.shift_date >= DATE '2026-03-09'
  AND ds.shift_date <  DATE '2026-03-16'

ALIASES:
ds  = duty_shift
dss = duty_shift_staff
dep = department
st  = staff
doc = doctor
nur = nurse
adm = administrative
*/

SELECT
    -- Τμήμα εφημερίας
    dep.department_id,
    dep.name AS department_name,

    -- Ημερομηνία και τύπος βάρδιας
    ds.shift_date,
    ds.shift_type,

    -- Κατηγορία προσωπικού
    st.staff_type,

    -- Υποκλάση προσωπικού:
    -- για doctors δείχνει specialty
    -- για nurses δείχνει rank
    -- για administrative δείχνει role
    CASE
        WHEN st.staff_type = 'DOCTOR' THEN doc.specialty
        WHEN st.staff_type = 'NURSE' THEN nur.rank
        WHEN st.staff_type = 'ADMINISTRATIVE' THEN adm.role
    END AS staff_subcategory,

    -- Απαιτούμενος  αριθμός προσωπικού για αυτή τη βάρδια, κατηγορία και υποκατηγορία.
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

-- Συγκεκριμένη εβδομάδα:
-- από 2026-05-04 έως πριν 2026-05-11
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
