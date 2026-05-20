\encoding UTF8 -- Όταν το τρέχουμε σε pgAdmin σβήνουμε αυτή τη γραμμή 

/*
Q01
Συνολικά έσοδα νοσοκομείου ανά:
- τμήμα
- έτος
- ΚΕΝ κωδικό
- ασφαλιστικό φορέα

Ανάλυση:
- βασικό κόστος ΚΕΝ
- πρόσθετη χρέωση λόγω υπέρβασης ΜΔΝ
- συνολικό έσοδο

ALIASES:
h  = hospitalization
p  = patient
k  = ken
hc = hospitalization_costs
d  = department
*/

WITH hospitalization_costs AS (
    SELECT
        h.hospitalization_id,

        -- Τμήμα νοσηλείας
        h.department_id,

        -- Έτος εισαγωγής της νοσηλείας
        EXTRACT(YEAR FROM h.admission_date)::INT AS admission_year,

        -- ΚΕΝ της νοσηλείας
        h.ken_code,

        -- Ασφαλιστικός φορέας ασθενούς
        p.insurance_provider,

        -- Βασικό κόστος που ορίζει ο ΚΕΝ κωδικός
        k.base_cost,

        -- Υπολογισμός ημερών νοσηλείας.
        -- Χρησιμοποιούμε DATE για να μετρήσουμε ημερολογιακές ημέρες.
        (h.discharge_date::DATE - h.admission_date::DATE) AS actual_days,

        -- Προβλεπόμενη Μέση Διάρκεια Νοσηλείας από τον ΚΕΝ
        k.average_length_of_stay,

        -- Πρόσθετη χρέωση:
        -- Αν οι πραγματικές ημέρες > ΜΔΝ, χρεώνουμε τις επιπλέον ημέρες.
        -- Αλλιώς η πρόσθετη χρέωση είναι 0.
        GREATEST(
            (h.discharge_date::DATE - h.admission_date::DATE)
            - k.average_length_of_stay,
            0
        ) * k.extra_daily_charge AS calculated_extra_charge

    FROM hospitalization h

    -- Παίρνουμε τον ασφαλιστικό φορέα του ασθενούς
    JOIN patient p
        ON p.patient_id = h.patient_id

    -- Παίρνουμε τα οικονομικά στοιχεία του ΚΕΝ
    JOIN ken k
        ON k.ken_code = h.ken_code

    -- Μετράμε μόνο ολοκληρωμένες νοσηλείες,
    -- γιατί χωρίς discharge_date δεν ξέρουμε την τελική διάρκεια.
    WHERE h.discharge_date IS NOT NULL
)

SELECT
    -- Στοιχεία ομαδοποίησης
    d.name AS department_name,
    hc.admission_year,
    hc.ken_code,
    hc.insurance_provider,

    -- Πλήθος νοσηλειών για αυτή την ομάδα
    COUNT(*) AS hospitalization_count,

    -- Σύνολο βασικών εσόδων από ΚΕΝ
    SUM(hc.base_cost) AS total_base_revenue,

    -- Σύνολο πρόσθετων χρεώσεων λόγω υπέρβασης ΜΔΝ
    SUM(hc.calculated_extra_charge) AS total_extra_revenue,

    -- Συνολικό έσοδο = βασικό κόστος + πρόσθετη χρέωση
    SUM(hc.base_cost + hc.calculated_extra_charge) AS total_revenue

FROM hospitalization_costs hc

-- Παίρνουμε το όνομα του τμήματος
JOIN department d
    ON d.department_id = hc.department_id

GROUP BY
    d.name,
    hc.admission_year,
    hc.ken_code,
    hc.insurance_provider

ORDER BY
    d.name,
    hc.admission_year,
    hc.ken_code,
    hc.insurance_provider;