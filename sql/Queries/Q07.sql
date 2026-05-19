/*
Q07
Για κάθε δραστική ουσία βρίσκουμε:
- πόσοι ασθενείς έχουν δηλώσει αλλεργία σε αυτή
- πόσα φάρμακα την περιέχουν

Τα αποτελέσματα ταξινομούνται κατά:
- αριθμό αλλεργικών ασθενών (φθίνουσα σειρά)

ALIASES:
al = allergy
acs = active_substance
das = drug_active_substance
drg = drug
*/

SELECT
    -- Στοιχεία δραστικής ουσίας
    acs.active_substance_id,
    acs.name AS active_substance_name,

    -- Πλήθος διαφορετικών ασθενών που έχουν δηλώσει αλλεργία
    COUNT(DISTINCT al.patient_id) AS allergic_patient_count,

    -- Πλήθος διαφορετικών φαρμάκων που περιέχουν τη δραστική ουσία
    COUNT(DISTINCT drg.drug_id) AS drug_count

FROM active_substance AS acs

-- Σύνδεση με αλλεργίες ασθενών
LEFT JOIN allergy AS al
    ON al.active_substance_id = acs.active_substance_id

-- Σύνδεση δραστικής ουσίας με φάρμακα
LEFT JOIN drug_active_substance AS das
    ON das.active_substance_id = acs.active_substance_id

LEFT JOIN drug AS drg
    ON drg.drug_id = das.drug_id

GROUP BY
    acs.active_substance_id,
    acs.name

ORDER BY
    allergic_patient_count DESC,
    drug_count DESC,
    acs.name;