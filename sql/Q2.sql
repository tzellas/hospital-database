/*
Q02
Για συγκεκριμένη ειδικότητα ιατρού, βρίσκουμε:
- όλους τους ιατρούς αυτής της ειδικότητας
- αν είχαν τουλάχιστον μία εφημερία στο τρέχον έτος
- πόσες επεμβάσεις εκτέλεσαν ως κύριοι χειρουργοί στο τρέχον έτος

ΑΛΛΑΞΕ ΕΔΩ ΤΗΝ ΕΙΔΙΚΟΤΗΤΑ:
WHERE doc.specialty = 'Cardiology'

ALIASES:
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

        -- Αν υπάρχει έστω μία εγγραφή εδώ,
        -- σημαίνει ότι ο ιατρός είχε εφημερία στο τρέχον έτος.
        COUNT(*) AS duty_count

    FROM duty_shift_staff AS dss

    JOIN duty_shift AS ds
        ON ds.duty_shift_id = dss.duty_shift_id

    -- Κρατάμε μόνο εφημερίες του τρέχοντος έτους
    WHERE EXTRACT(YEAR FROM ds.shift_date) = EXTRACT(YEAR FROM CURRENT_DATE)

    GROUP BY
        dss.staff_id
),

procedure_count_current_year AS (

    SELECT
        hmp.main_doctor_id AS doctor_id,

        -- Μετράμε τις διαφορετικές επεμβάσεις στις οποίες
        -- ο ιατρός ήταν κύριος χειρουργός.
        COUNT(DISTINCT hmp.procedure_id) AS main_procedure_count

    FROM hospitalization_medical_procedure AS hmp

    JOIN procedure_room_schedule AS prs
        ON prs.procedure_id = hmp.procedure_id

    -- Κρατάμε μόνο επεμβάσεις που έγιναν μέσα στο τρέχον έτος
    WHERE EXTRACT(YEAR FROM prs.start_datetime) = EXTRACT(YEAR FROM CURRENT_DATE)

    GROUP BY
        hmp.main_doctor_id
)

SELECT
    -- Βασικά στοιχεία ιατρού
    doc.staff_id AS doctor_id,
    st.first_name,
    st.last_name,
    doc.specialty,
    doc.rank,

    -- Ένδειξη αν είχε εφημερία στο τρέχον έτος
    CASE
        WHEN dc.duty_count IS NULL THEN 'NO'
        ELSE 'YES'
    END AS had_duty_current_year,

    -- Πλήθος εφημεριών στο τρέχον έτος
    COALESCE(dc.duty_count, 0) AS duty_count_current_year,

    -- Πλήθος επεμβάσεων ως κύριος χειρουργός στο τρέχον έτος
    COALESCE(pc.main_procedure_count, 0) AS main_procedure_count_current_year

FROM doctor AS doc

JOIN staff AS st
    ON st.staff_id = doc.staff_id

-- LEFT JOIN για να μη χαθούν οι ιατροί που δεν είχαν εφημερία
LEFT JOIN duty_current_year AS dc
    ON dc.doctor_id = doc.staff_id

-- LEFT JOIN για να μη χαθούν οι ιατροί που δεν έκαναν επεμβάσεις
LEFT JOIN procedure_count_current_year AS pc
    ON pc.doctor_id = doc.staff_id

-- Εδώ βάζεις τη συγκεκριμένη ειδικότητα που ζητάς
WHERE doc.specialty = 'Cardiology'

ORDER BY
    pc.main_procedure_count DESC NULLS LAST,
    st.last_name,
    st.first_name;