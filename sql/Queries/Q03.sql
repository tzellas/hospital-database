\encoding UTF8 -- Όταν το τρέχουμε σε pgAdmin σβήνουμε αυτή τη γραμμή 
/*
Q03
Βρίσκουμε ποιοι ασθενείς έχουν νοσηλευτεί περισσότερες από 3 φορές
στο ίδιο τμήμα.

Για κάθε τέτοιον ασθενή και τμήμα εμφανίζουμε:
- στοιχεία ασθενούς
- τμήμα
- πλήθος νοσηλειών στο συγκεκριμένο τμήμα
- συνολικό κόστος νοσηλείας

ALIASES:
p = patient
h = hospitalization
d = department
*/

SELECT
    -- Στοιχεία ασθενούς
    p.patient_id,
    p.first_name,
    p.last_name,
    p.amka,

    -- Τμήμα στο οποίο ο ασθενής νοσηλεύτηκε πάνω από 3 φορές
    d.department_id,
    d.name AS department_name,

    -- Πλήθος νοσηλειών του ασθενούς στο συγκεκριμένο τμήμα
    COUNT(*) AS hospitalization_count,

    -- Συνολικό κόστος όλων αυτών των νοσηλειών
    SUM(h.total_cost) AS total_hospitalization_cost

FROM patient AS p

JOIN hospitalization AS h
    ON h.patient_id = p.patient_id

JOIN department AS d
    ON d.department_id = h.department_id

GROUP BY
    p.patient_id,
    p.first_name,
    p.last_name,
    p.amka,
    d.department_id,
    d.name

-- Κρατάμε μόνο τις ομάδες όπου ο ίδιος ασθενής
-- έχει περισσότερες από 3 νοσηλείες στο ίδιο τμήμα.
HAVING COUNT(*) > 3

ORDER BY
    hospitalization_count DESC,
    total_hospitalization_cost DESC,
    p.last_name,
    p.first_name;