\encoding UTF8
/*
Q15
Βρίσκουμε την κατανομή των περιστατικών triage ανά επίπεδο επείγοντος.

Για κάθε urgency_level εμφανίζουμε:
- πλήθος περιστατικών triage
- μέσο χρόνο αναμονής
- ποσοστό περιστατικών που οδήγησαν σε νοσηλεία
- κατανομή παραπομπών ανά τμήμα

Ερμηνεία:
- Χρόνος αναμονής = service_datetime - arrival_datetime
- Περιστατικό που οδήγησε σε νοσηλεία =
  outcome = 'REFERRED_FOR_HOSPITALIZATION'
- Παραπομπή ανά τμήμα = referred_department_id

ALIASES:
tc = triage_case
dep = department
*/

SELECT
    -- Επίπεδο επείγοντος triage
    tc.urgency_level,

    -- Περιγραφή επιπέδου επείγοντος για πιο καθαρό αποτέλεσμα
    CASE
        WHEN tc.urgency_level = 1 THEN 'Άμεσο'
        WHEN tc.urgency_level = 2 THEN 'Επείγον'
        WHEN tc.urgency_level = 3 THEN 'Επιτακτικό'
        WHEN tc.urgency_level = 4 THEN 'Λιγότερο επείγον'
        WHEN tc.urgency_level = 5 THEN 'Μη επείγον'
    END AS urgency_description,

    -- Τμήμα παραπομπής
    -- Αν το περιστατικό δεν οδήγησε σε νοσηλεία,
    -- τότε δεν υπάρχει τμήμα παραπομπής.
    dep.name AS referred_department_name,

    -- Πλήθος περιστατικών για αυτό το urgency level
    -- και αυτό το τμήμα παραπομπής
    COUNT(*) AS triage_case_count,

    -- Μέσος χρόνος αναμονής
    AVG(tc.service_datetime - tc.arrival_datetime) AS avg_waiting_time,

    -- Πλήθος περιστατικών που οδήγησαν σε νοσηλεία
    COUNT(*) FILTER (
        WHERE tc.outcome = 'REFERRED_FOR_HOSPITALIZATION'
    ) AS hospitalized_case_count,

    -- Ποσοστό περιστατικών που οδήγησαν σε νοσηλεία
    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE tc.outcome = 'REFERRED_FOR_HOSPITALIZATION'
        ) / COUNT(*),
        2
    ) AS hospitalization_percentage

FROM triage_case AS tc

LEFT JOIN department AS dep
    ON dep.department_id = tc.referred_department_id

-- Μετράμε μόνο περιστατικά που έχουν εξυπηρετηθεί,
-- ώστε να μπορεί να υπολογιστεί χρόνος αναμονής.
WHERE tc.service_datetime IS NOT NULL

GROUP BY
    tc.urgency_level,
    dep.name

ORDER BY
    tc.urgency_level,
    triage_case_count DESC,
    dep.name;
