-- Όταν το τρέχουμε σε pgAdmin σβήνουμε αυτή τη γραμμή 
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

WITH level_stats AS (

    SELECT
        tc.urgency_level,

        -- Συνολικό πλήθος triage περιστατικών στο συγκεκριμένο επίπεδο
        COUNT(*) AS total_triage_cases,

        -- Μέσος χρόνος αναμονής.
        -- Το AVG αγνοεί NULL τιμές, άρα αν κάποιο service_datetime είναι NULL,
        -- δεν επηρεάζει τον μέσο όρο.
        AVG(tc.service_datetime - tc.arrival_datetime) AS avg_waiting_time,

        -- Πλήθος περιστατικών που οδήγησαν σε νοσηλεία
        COUNT(*) FILTER (
            WHERE tc.outcome = 'REFERRED_FOR_HOSPITALIZATION'
        ) AS hospitalized_cases,

        -- Ποσοστό περιστατικών που οδήγησαν σε νοσηλεία
        ROUND(
            100.0 * COUNT(*) FILTER (
                WHERE tc.outcome = 'REFERRED_FOR_HOSPITALIZATION'
            ) / COUNT(*),
            2
        ) AS hospitalization_percentage

    FROM triage_case AS tc

    GROUP BY
        tc.urgency_level
),

referral_distribution AS (

    SELECT
        tc.urgency_level,

        -- Τμήμα στο οποίο παραπέμφθηκε το περιστατικό
        dep.name AS referred_department_name,

        -- Πλήθος παραπομπών στο συγκεκριμένο τμήμα
        COUNT(*) AS referral_count

    FROM triage_case AS tc

    JOIN department AS dep
        ON dep.department_id = tc.referred_department_id

    -- Εδώ κρατάμε μόνο όσα οδήγησαν σε νοσηλεία,
    -- γιατί μόνο αυτά έχουν νόημα ως referrals.
    WHERE tc.outcome = 'REFERRED_FOR_HOSPITALIZATION'

    GROUP BY
        tc.urgency_level,
        dep.name
)

SELECT
    -- Επίπεδο επείγοντος
    ls.urgency_level,

    CASE
        WHEN ls.urgency_level = 1 THEN 'Άμεσο'
        WHEN ls.urgency_level = 2 THEN 'Επείγον'
        WHEN ls.urgency_level = 3 THEN 'Επιτακτικό'
        WHEN ls.urgency_level = 4 THEN 'Λιγότερο επείγον'
        WHEN ls.urgency_level = 5 THEN 'Μη επείγον'
    END AS urgency_description,

    -- Συνολικά στοιχεία ανά επίπεδο
    ls.total_triage_cases,
    ls.avg_waiting_time,
    ls.hospitalized_cases,
    ls.hospitalization_percentage,

    -- Κατανομή παραπομπών ανά τμήμα
    rd.referred_department_name,
    COALESCE(rd.referral_count, 0) AS referral_count

FROM level_stats AS ls

LEFT JOIN referral_distribution AS rd
    ON rd.urgency_level = ls.urgency_level

ORDER BY
    ls.urgency_level,
    referral_count DESC,
    rd.referred_department_name;