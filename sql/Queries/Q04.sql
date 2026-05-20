-- Όταν το τρέχουμε σε pgAdmin σβήνουμε αυτή τη γραμμή 
\encoding UTF8 
/*
Q04
Για συγκεκριμένο ιατρό, βρίσκουμε:
- τον μέσο όρο αξιολογήσεων των ασθενών του
  στο κριτήριο "Ποιότητα ιατρικής φροντίδας"
- τη μέση συνολική εντύπωση νοσηλείας
  από τις αντίστοιχες νοσηλείες

Η "Ποιότητα ιατρικής φροντίδας" βρίσκεται στον πίνακα doctor_review.
Η "Συνολική εντύπωση νοσηλείας" βρίσκεται στον πίνακα hospitalization_review.

ΑΛΛΑΞΕ ΕΔΩ ΤΟΝ ΙΑΤΡΟ:
WHERE doc.staff_id = 1

ALIASES:
doc = doctor
st  = staff
dr  = doctor_review
hr  = hospitalization_review
*/

SELECT
    -- ID ιατρού
    doc.staff_id AS doctor_id,

    -- Στοιχεία ιατρού
    st.first_name,
    st.last_name,
    doc.specialty,
    doc.rank,

    -- Μέσος όρος αξιολόγησης ιατρικής φροντίδας
    AVG(dr.medical_care_score) AS avg_medical_care_score,

    -- Μέσος όρος συνολικής εμπειρίας νοσηλείας
    AVG(hr.overall_experience_score) AS avg_overall_experience_score,

    -- Πλήθος αξιολογήσεων που χρησιμοποιήθηκαν
    COUNT(*) AS review_count

FROM doctor AS doc

JOIN staff AS st
    ON st.staff_id = doc.staff_id

JOIN doctor_review AS dr
    ON dr.doctor_id = doc.staff_id

JOIN hospitalization_review AS hr
    ON hr.patient_id = dr.patient_id
   AND hr.hospitalization_id = dr.hospitalization_id

-- Εδώ βάζουμε τον συγκεκριμένο ιατρό
WHERE doc.staff_id = 671

GROUP BY
    doc.staff_id,
    st.first_name,
    st.last_name,
    doc.specialty,
    doc.rank;


/*
Q04 - EXPLAIN ANALYZE
Κανονική έκδοση.
*/

EXPLAIN ANALYZE
SELECT
    doc.staff_id AS doctor_id,
    st.first_name,
    st.last_name,
    doc.specialty,
    doc.rank,
    AVG(dr.medical_care_score) AS avg_medical_care_score,
    AVG(hr.overall_experience_score) AS avg_overall_experience_score,
    COUNT(*) AS review_count

FROM doctor AS doc

JOIN staff AS st
    ON st.staff_id = doc.staff_id

JOIN doctor_review AS dr
    ON dr.doctor_id = doc.staff_id

JOIN hospitalization_review AS hr
    ON hr.patient_id = dr.patient_id
   AND hr.hospitalization_id = dr.hospitalization_id

WHERE doc.staff_id = 671

GROUP BY
    doc.staff_id,
    st.first_name,
    st.last_name,
    doc.specialty,
    doc.rank;


/*
Q04 - EXPLAIN ANALYZE με hint-like forced index behavior

Στο PostgreSQL δεν υπάρχει FORCE INDEX όπως στη MySQL.
Με το SET enable_seqscan = off πιέζουμε τον optimizer
να αποφύγει sequential scan και να προτιμήσει index-based plan,
όπου είναι δυνατόν.
*/

SET enable_seqscan = off;

EXPLAIN ANALYZE
SELECT
    doc.staff_id AS doctor_id,
    st.first_name,
    st.last_name,
    doc.specialty,
    doc.rank,
    AVG(dr.medical_care_score) AS avg_medical_care_score,
    AVG(hr.overall_experience_score) AS avg_overall_experience_score,
    COUNT(*) AS review_count

FROM doctor AS doc

JOIN staff AS st
    ON st.staff_id = doc.staff_id

JOIN doctor_review AS dr
    ON dr.doctor_id = doc.staff_id

JOIN hospitalization_review AS hr
    ON hr.patient_id = dr.patient_id
   AND hr.hospitalization_id = dr.hospitalization_id

WHERE doc.staff_id = 671

GROUP BY
    doc.staff_id,
    st.first_name,
    st.last_name,
    doc.specialty,
    doc.rank;

RESET enable_seqscan;


/*
Για το report : 
Στο Q04 συγκρίθηκαν δύο εκτελέσεις του ίδιου ερωτήματος: η κανονική 
έκδοση και μία εναλλακτική έκδοση με απενεργοποιημένο το sequential scan. 
Η δεύτερη έκδοση λειτουργεί ως PostgreSQL hint-like προσέγγιση,
αφού η PostgreSQL δεν υποστηρίζει FORCE INDEX όπως η MySQL. 
Συγκρίναμε το estimated cost και το actual execution time από το EXPLAIN ANALYZE. 
Αν η βάση έχει αρκετά δεδομένα και κατάλληλα indexes, η index-based εκτέλεση 
μπορεί να μειώσει τον χρόνο αναζήτησης των αξιολογήσεων συγκεκριμένου ιατρού.
*/