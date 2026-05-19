/*
Q14
Βρίσκουμε ποιες κατηγορίες ICD-10 διαγνώσεων
είχαν τον ίδιο αριθμό εισαγωγών σε δύο συνεχόμενα έτη,
με τουλάχιστον 5 περιστατικά ανά έτος.

Ερμηνεία:
- Ως "εισαγωγές" χρησιμοποιούμε τη διάγνωση εισαγωγής
  της νοσηλείας.
- Ως "κατηγορία ICD-10" χρησιμοποιούμε το πρώτο γράμμα
  του ICD-10 κωδικού, π.χ. A, B, C, I, J κοκ
- Μετράμε περιστατικά ανά ICD-10 category και έτος.
- Συγκρίνουμε κάθε έτος με το αμέσως επόμενο έτος.
- Κρατάμε μόνο περιπτώσεις όπου:
  count_year_1 = count_year_2
  και και τα δύο counts είναι >= 5.

ALIASES:
h  = hospitalization
iy = icd_yearly_admissions
iy2 = icd_yearly_admissions για το επόμενο έτος
*/

WITH icd_yearly_admissions AS (

    SELECT
        -- Κατηγορία ICD-10:
        -- Παίρνουμε το πρώτο γράμμα του κωδικού.
        SUBSTRING(h.admission_icd10_code FROM 1 FOR 1) AS icd10_category,

        -- Έτος εισαγωγής
        EXTRACT(YEAR FROM h.admission_date)::INT AS admission_year,

        -- Πλήθος εισαγωγών για αυτή την ICD-10 κατηγορία στο συγκεκριμένο έτος
        COUNT(*) AS admission_count

    FROM hospitalization AS h

    -- Κρατάμε μόνο νοσηλείες με διάγνωση εισαγωγής
    WHERE h.admission_icd10_code IS NOT NULL

    GROUP BY
        SUBSTRING(h.admission_icd10_code FROM 1 FOR 1),
        EXTRACT(YEAR FROM h.admission_date)

    -- Θέλουμε τουλάχιστον 5 περιστατικά ανά έτος
    HAVING COUNT(*) >= 5
)

SELECT
    -- ICD-10 κατηγορία
    iy.icd10_category,

    -- Πρώτο έτος
    iy.admission_year AS first_year,

    -- Επόμενο συνεχόμενο έτος
    iy2.admission_year AS second_year,

    -- Πλήθος εισαγωγών στο πρώτο έτος
    iy.admission_count AS first_year_admission_count,

    -- Πλήθος εισαγωγών στο δεύτερο έτος
    iy2.admission_count AS second_year_admission_count

FROM icd_yearly_admissions AS iy

JOIN icd_yearly_admissions AS iy2
    ON iy2.icd10_category = iy.icd10_category

   -- Συγκρίνουμε μόνο συνεχόμενα έτη
   AND iy2.admission_year = iy.admission_year + 1

   -- Θέλουμε ίδιο αριθμό εισαγωγών στα δύο έτη
   AND iy2.admission_count = iy.admission_count

ORDER BY
    iy.icd10_category,
    iy.admission_year;