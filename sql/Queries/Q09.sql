/*
Q09
Βρίσκουμε ποιοι ασθενείς νοσηλεύτηκαν
τον ίδιο συνολικό αριθμό ημερών μέσα στο ίδιο έτος,
με συνολική διάρκεια άνω των 15 ημερών.

Δεν εμφανίζουμε ζεύγη ασθενών.
Εμφανίζουμε κάθε ασθενή ξεχωριστά,
αλλά μόνο αν υπάρχει και άλλος ασθενής
στο ίδιο έτος με ίδιο total_stay_days.

ALIASES:
h   = hospitalization
p   = patient
ps  = patient_stay_summary
dup = duplicate_stay_days
*/

WITH patient_stay_summary AS (

    SELECT
        h.patient_id,

        -- Έτος νοσηλείας
        EXTRACT(YEAR FROM h.admission_date)::INT AS hospitalization_year,

        -- Συνολικές ημέρες νοσηλείας ασθενούς στο συγκεκριμένο έτος
        SUM(h.discharge_date::DATE - h.admission_date::DATE) AS total_stay_days

    FROM hospitalization AS h

    WHERE h.discharge_date IS NOT NULL

    GROUP BY
        h.patient_id,
        EXTRACT(YEAR FROM h.admission_date)

    HAVING SUM(h.discharge_date::DATE - h.admission_date::DATE) > 15
),

duplicate_stay_days AS (

    SELECT
        ps.hospitalization_year,
        ps.total_stay_days

    FROM patient_stay_summary AS ps

    GROUP BY
        ps.hospitalization_year,
        ps.total_stay_days

    -- Κρατάμε μόνο αριθμούς ημερών που εμφανίζονται
    -- σε περισσότερους από έναν ασθενείς.
    HAVING COUNT(*) > 1
)

SELECT
    p.patient_id,
    p.first_name,
    p.last_name,
    p.amka,

    ps.hospitalization_year,
    ps.total_stay_days

FROM patient_stay_summary AS ps

JOIN duplicate_stay_days AS dup
    ON dup.hospitalization_year = ps.hospitalization_year
   AND dup.total_stay_days = ps.total_stay_days

JOIN patient AS p
    ON p.patient_id = ps.patient_id

ORDER BY
    ps.hospitalization_year,
    ps.total_stay_days DESC,
    p.last_name,
    p.first_name;