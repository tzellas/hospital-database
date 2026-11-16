# Design notes

Modelling assumptions and trade-offs behind the schema, the seed data and the queries. The data is a **reproducible synthetic workload**, not a dump of a real hospital.

## Contents

- [Data sources and cleaning](#data-sources-and-cleaning)
- [Synthetic data generation](#synthetic-data-generation)
- [Schema decisions](#schema-decisions)
- [Loading and running](#loading-and-running)
- [Known trade-offs](#known-trade-offs)

## Data sources and cleaning

- CSV files were normalized before loading: encoding cleanup, duplicate removal, formatting fixes, and filtering of invalid or inactive rows.
- Inconsistencies introduced by Excel → CSV conversions were fixed.
- Only obviously unrealistic values that violate constraints (for example negative ages) were corrected.
- **KEN** rows are used as hospitalization categories, each with a base cost and an average length of stay. Duplicate or corrupted KEN rows caused by extraction or formatting errors were fixed by hand.
- **Medicines.** Only products with `Product authorisation country = Greece` were used. The EMA export has no stable natural key, so `drug.drug_id` is a surrogate `SERIAL` primary key.
- **Active substances** were split on separators such as `,` and `|` only when those appear outside parentheses and brackets. Some composite drug labels needed manual parsing.
- **Procedures.** Official medical actions are classified into `SURGICAL`, `DIAGNOSTIC` and `THERAPEUTIC` by rule-based classification. Inactive procedures were excluded and duplicates removed.
- Default costs for procedures and lab tests are synthetic, produced by deterministic random generation.

## Synthetic data generation

- Generated and reference CSVs come from Python scripts with fixed seeds and fixed constants, so every run produces the same output.
- `patients.csv` and `emergency_contacts.csv` form the core identity layer of the patients.
- **Hospitalizations** are generated between `2025-03-20` and `2026-03-19`, using weighted patient reuse and department affinity rather than uniform randomness. Length of stay is influenced by the KEN code's `average_length_of_stay` but remains a bounded synthetic approximation. A hospitalization that cannot be placed legally in the time window, or that would produce invalid discharge logic, is skipped.
- **Triage cases** are generated so that a subset corresponds to hospitalizations (`REFERRED_FOR_HOSPITALIZATION`).
- **Allergies** are generated as `patient_id` ↔ `substance_id` relations, not at the level of a specific commercial drug.
- **Prescriptions** are generated only when the patient is not allergic to any active substance of the drug. Prescribing doctors are drawn from specialty- and department-compatible pools.
- **Reviews.** Hospitalization and doctor reviews are generated with coverage rates rather than for 100% of records. Doctor reviews link only to real `(patient_id, hospitalization_id)` pairs.
- **Duty shifts** cover the same period (`2025-03-20` to `2026-03-19`), with three shifts per day per department. `duty_shift_staff` stores the *actual* assignments of staff to shifts, not theoretical staffing requirements.

## Schema decisions

- **One identity table for staff.** All personnel live in `staff`; `doctor`, `nurse` and `administrative` are specializations sharing the same `staff_id`.
- **`doctor_department` is many-to-many.** A doctor can belong to more than one department.
- **ICD-10 category** is the base code before the decimal part: `A00.0` and `A00.1` both belong to category `A00`. It is a stored generated column on `icd10_diagnosis`.
- **Images** are supported through `entity_image`, which stores an `image_url` and a textual description for an entity identified by `entity_type` and `entity_id`. The table is part of the schema, but no seed rows are loaded into it.

## Loading and running

- All SQL and CSV files are UTF-8; `sql/load.sql` sets `\encoding UTF8`.
- `sql/load.sql` is executed from the repository root because its `\copy` paths are relative.
- Some queries can legitimately return zero rows when their condition is very strict or when the requested date range falls outside the generated window.

## Known trade-offs

- **Supervisors are assigned randomly at load time.** `sql/load.sql` picks supervisors with `ORDER BY random()` and does not seed it, so the supervision hierarchy (and therefore the output of query 13) differs between loads.
- **`entity_image` is polymorphic.** A reference by `entity_type` + `entity_id` cannot carry a foreign key, so that link is validated by a `CHECK` on the type list only.
- **Date-relative queries.** Queries 02 and 11 use `CURRENT_DATE`, so their results depend on the day they are run relative to the generated window.
- **Not every rule is a trigger.** The "at most three consecutive night shifts" rule is respected by the generator and checked by the post-load audit, but it is not enforced by a trigger.
- **Index coverage is minimal.** Only the three indexes that serve the review lookups (queries 04 and 06) were added beyond primary and unique keys. The plan for query 06 suggests an index on `hospitalization(patient_id)` as the next candidate.
