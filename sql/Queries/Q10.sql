\encoding UTF8 -- Όταν το τρέχουμε σε pgAdmin σβήνουμε αυτή τη γραμμή 

/*
Q10
Βρίσκουμε τα top-3 ζεύγη δραστικών ουσιών
που συνταγογραφήθηκαν ταυτόχρονα στον ίδιο ασθενή,
κατά την ίδια νοσηλεία.

Λογική:
- Κάθε prescription δίνει ένα drug σε έναν patient
  μέσα σε μία hospitalization.
- Κάθε drug μπορεί να έχει μία ή περισσότερες active substances.
- Ενώνουμε τις δραστικές ουσίες μεταξύ τους ανά ίδια νοσηλεία.
- Κρατάμε μόνο ζεύγη όπου substance_1 < substance_2
  για να μη μετράμε διπλά τα ίδια ζεύγη.
- Μετράμε πόσες φορές εμφανίζεται κάθε ζεύγος.
- Επιστρέφουμε τα top-3 συχνότερα ζεύγη.

ALIASES:
pr1 = prescription για την πρώτη συνταγογράφηση
pr2 = prescription για τη δεύτερη συνταγογράφηση
das1 = drug_active_substance για το πρώτο φάρμακο
das2 = drug_active_substance για το δεύτερο φάρμακο
as1 = active_substance για την πρώτη δραστική ουσία
as2 = active_substance για τη δεύτερη δραστική ουσία
*/

SELECT
    -- Πρώτη δραστική ουσία του ζεύγους
    as1.substance_id AS active_substance_1_id,
    as1.substance_name AS active_substance_1_name,

    -- Δεύτερη δραστική ουσία του ζεύγους
    as2.substance_id AS active_substance_2_id,
    as2.substance_name AS active_substance_2_name,

    -- Πόσες φορές εμφανίστηκε αυτός ο συνδυασμός
    -- στον ίδιο ασθενή και στην ίδια νοσηλεία
    COUNT(*) AS pair_frequency

FROM prescription AS pr1

JOIN prescription AS pr2
    ON pr2.patient_id = pr1.patient_id
   AND pr2.hospitalization_id = pr1.hospitalization_id

   -- Αποφεύγουμε να ενώσουμε την ίδια prescription με τον εαυτό της και αποφεύγουμε διπλό μέτρημα τύπου A-B και B-A.
   AND pr2.prescription_id > pr1.prescription_id

JOIN drug_active_substance AS das1
    ON das1.drug_id = pr1.drug_id

JOIN drug_active_substance AS das2
    ON das2.drug_id = pr2.drug_id

-- Κρατάμε μόνο διαφορετικές δραστικές ουσίες και αποφεύγουμε διπλά ζεύγη ουσιών.
JOIN active_substance AS as1
    ON as1.substance_id = das1.substance_id

JOIN active_substance AS as2
    ON as2.substance_id = das2.substance_id
   AND as2.substance_id > as1.substance_id

GROUP BY
    as1.substance_id,
    as1.substance_name,
    as2.substance_id,
    as2.substance_name

ORDER BY
    pair_frequency DESC,
    as1.substance_name,
    as2.substance_name

LIMIT 3;
