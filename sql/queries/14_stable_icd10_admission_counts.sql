-- Run with psql from the repo root. In pgAdmin, delete the \encoding line.
\encoding UTF8

/*
14 · Stable ICD-10 admission counts

Find the ICD-10 diagnosis categories that had the same number of
admissions in two consecutive years, with at least 5 cases per year.

Interpretation:
- "Admissions" are counted by the admission diagnosis of the
  hospitalization.
- The "ICD-10 category" is the first letter of the ICD-10 code,
  e.g. A, B, C, I, J and so on.
- We count cases per ICD-10 category and year.
- We compare each year with the immediately following year.
- We keep only the cases where
  count_year_1 = count_year_2
  and both counts are >= 5.

Aliases:
h   = hospitalization
iy  = icd_yearly_admissions
iy2 = icd_yearly_admissions for the following year
*/

WITH icd_yearly_admissions AS (

    SELECT
        -- ICD-10 category:
        -- the first letter of the code.
        SUBSTRING(h.admission_icd10_code FROM 1 FOR 1) AS icd10_category,

        -- Admission year
        EXTRACT(YEAR FROM h.admission_date)::INT AS admission_year,

        -- Number of admissions for this ICD-10 category in this year
        COUNT(*) AS admission_count

    FROM hospitalization AS h

    -- Keep only hospitalizations that have an admission diagnosis
    WHERE h.admission_icd10_code IS NOT NULL

    GROUP BY
        SUBSTRING(h.admission_icd10_code FROM 1 FOR 1),
        EXTRACT(YEAR FROM h.admission_date)

    -- We want at least 5 cases per year
    HAVING COUNT(*) >= 5
)

SELECT
    -- ICD-10 category
    iy.icd10_category,

    -- First year
    iy.admission_year AS first_year,

    -- Following consecutive year
    iy2.admission_year AS second_year,

    -- Number of admissions in the first year
    iy.admission_count AS first_year_admission_count,

    -- Number of admissions in the second year
    iy2.admission_count AS second_year_admission_count

FROM icd_yearly_admissions AS iy

JOIN icd_yearly_admissions AS iy2
    ON iy2.icd10_category = iy.icd10_category

   -- Compare consecutive years only
   AND iy2.admission_year = iy.admission_year + 1

   -- We want the same number of admissions in both years
   AND iy2.admission_count = iy.admission_count

ORDER BY
    iy.icd10_category,
    iy.admission_year;
