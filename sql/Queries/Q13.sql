\encoding UTF8
/*
Q13
Για κάθε ιατρό βρίσκουμε όλη την ιεραρχία εποπτείας του,
ξεκινώντας από τον άμεσο επόπτη και συνεχίζοντας
μέχρι να φτάσουμε σε ιατρό βαθμίδας 'Διευθυντής'
ή σε ιατρό που δεν έχει άλλο επόπτη.

Χρησιμοποιούμε Recursive CTE επειδή η σχέση supervisor
είναι αναδρομική

ALIASES:
doc = doctor που εξετάζουμε
st  = staff του ιατρού που εξετάζουμε
sup = doctor που είναι επόπτης
sst = staff του επόπτη
sh  = supervision_hierarchy
*/

WITH RECURSIVE supervision_hierarchy AS (

    /*
    ΒΑΣΙΚΟ ΒΗΜΑ:
    Παίρνουμε για κάθε ιατρό τον άμεσο επόπτη του.
    Αυτό είναι το επίπεδο 1.
    */
    SELECT
        doc.staff_id AS doctor_id,
        st.first_name AS doctor_first_name,
        st.last_name AS doctor_last_name,

        sup.staff_id AS supervisor_id,
        sst.first_name AS supervisor_first_name,
        sst.last_name AS supervisor_last_name,
        sup.rank AS supervisor_rank,

        1 AS hierarchy_level

    FROM doctor AS doc

    JOIN staff AS st
        ON st.staff_id = doc.staff_id

    JOIN doctor AS sup
        ON sup.staff_id = doc.supervisor_doc_id

    JOIN staff AS sst
        ON sst.staff_id = sup.staff_id

    WHERE doc.supervisor_doc_id IS NOT NULL


    UNION ALL


    /*
    ΑΝΑΔΡΟΜΙΚΟ ΒΗΜΑ:
    Για τον επόπτη που βρήκαμε στο προηγούμενο επίπεδο,
    ψάχνουμε τον δικό του επόπτη.
    Έτσι ανεβαίνουμε στην ιεραρχία.
    */
    SELECT
        sh.doctor_id,
        sh.doctor_first_name,
        sh.doctor_last_name,

        sup.staff_id AS supervisor_id,
        sst.first_name AS supervisor_first_name,
        sst.last_name AS supervisor_last_name,
        sup.rank AS supervisor_rank,

        sh.hierarchy_level + 1 AS hierarchy_level

    FROM supervision_hierarchy AS sh

    JOIN doctor AS current_sup
        ON current_sup.staff_id = sh.supervisor_id

    JOIN doctor AS sup
        ON sup.staff_id = current_sup.supervisor_doc_id

    JOIN staff AS sst
        ON sst.staff_id = sup.staff_id

    /*
    Σταματάμε όταν ο προηγούμενος επόπτης είναι Διευθυντής.
    Δηλαδή δεν συνεχίζουμε πάνω από Διευθυντή.
    */
    WHERE sh.supervisor_rank <> 'Διευθυντής'
)

SELECT
    -- Ιατρός για τον οποίο εμφανίζουμε την ιεραρχία
    sh.doctor_id,
    sh.doctor_first_name,
    sh.doctor_last_name,

    -- Επίπεδο στην ιεραρχία:
    -- 1 = άμεσος επόπτης
    -- 2 = επόπτης του επόπτη
    -- 3 = κ.ο.κ.
    sh.hierarchy_level,

    -- Επόπτης στο συγκεκριμένο επίπεδο
    sh.supervisor_id,
    sh.supervisor_first_name,
    sh.supervisor_last_name,
    sh.supervisor_rank

FROM supervision_hierarchy AS sh

ORDER BY
    sh.doctor_id,
    sh.hierarchy_level;
