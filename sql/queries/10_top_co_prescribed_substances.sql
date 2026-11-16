-- Run with psql from the repo root. In pgAdmin, delete the \encoding line.
\encoding UTF8

/*
10 · Top co-prescribed substances

Find the top-3 pairs of active substances prescribed together
to the same patient during the same hospitalization.

Logic:
- Each prescription gives one drug to one patient
  within one hospitalization.
- Each drug can have one or more active substances.
- We join the substances to each other within the same hospitalization.
- We keep only pairs where substance_1 < substance_2,
  so the same pair is not counted twice.
- We count how many times each pair occurs.
- We return the 3 most frequent pairs.

Aliases:
pr1  = prescription (first prescription)
pr2  = prescription (second prescription)
das1 = drug_active_substance (first drug)
das2 = drug_active_substance (second drug)
as1  = active_substance (first substance)
as2  = active_substance (second substance)
*/

SELECT
    -- First active substance of the pair
    as1.substance_id AS active_substance_1_id,
    as1.substance_name AS active_substance_1_name,

    -- Second active substance of the pair
    as2.substance_id AS active_substance_2_id,
    as2.substance_name AS active_substance_2_name,

    -- How many times this combination occurred
    -- for the same patient and the same hospitalization
    COUNT(*) AS pair_frequency

FROM prescription AS pr1

JOIN prescription AS pr2
    ON pr2.patient_id = pr1.patient_id
   AND pr2.hospitalization_id = pr1.hospitalization_id

   -- Avoid joining a prescription with itself and avoid
   -- double counting A-B and B-A.
   AND pr2.prescription_id > pr1.prescription_id

JOIN drug_active_substance AS das1
    ON das1.drug_id = pr1.drug_id

JOIN drug_active_substance AS das2
    ON das2.drug_id = pr2.drug_id

-- Keep only different substances and avoid duplicate substance pairs.
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
