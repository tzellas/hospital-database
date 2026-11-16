-- Run with psql from the repo root. In pgAdmin, delete the \encoding line.
\encoding UTF8

/*
13 · Supervision hierarchy

For every doctor, find their whole supervision chain, starting from
the direct supervisor and continuing until we reach a doctor of rank
'DIRECTOR' or a doctor with no further supervisor.

We use a recursive CTE because the supervisor relationship is
recursive.

Aliases:
doc = the doctor being examined
st  = staff row of the doctor being examined
sup = doctor who is the supervisor
sst = staff row of the supervisor
sh  = supervision_hierarchy
*/

WITH RECURSIVE supervision_hierarchy AS (

    /*
    BASE STEP:
    Take each doctor's direct supervisor.
    This is level 1.
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
    RECURSIVE STEP:
    For the supervisor found at the previous level,
    look up that supervisor's own supervisor.
    This is how we climb the hierarchy.
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
    Stop when the previous supervisor is a Director:
    we do not climb above a Director.
    */
    WHERE sh.supervisor_rank <> 'DIRECTOR'
)

SELECT
    -- Doctor whose hierarchy we are showing
    sh.doctor_id,
    sh.doctor_first_name,
    sh.doctor_last_name,

    -- Level in the hierarchy:
    -- 1 = direct supervisor
    -- 2 = supervisor of the supervisor
    -- 3 = and so on
    sh.hierarchy_level,

    -- Supervisor at this level
    sh.supervisor_id,
    sh.supervisor_first_name,
    sh.supervisor_last_name,
    sh.supervisor_rank

FROM supervision_hierarchy AS sh

ORDER BY
    sh.doctor_id,
    sh.hierarchy_level;
