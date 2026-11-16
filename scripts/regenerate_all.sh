#!/usr/bin/env bash
# Rebuild every generated CSV in data/ from scratch.
#
# All generators are seeded, so the output is identical on every run
# (apart from line endings: Python writes CRLF, git stores LF).
# Order matters: later scripts read the CSVs written by earlier ones.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

scripts=(
  generate_hospitalizations.py
  generate_triage_cases.py
  generate_allergies.py
  generate_prescriptions.py
  generate_hospitalization_reviews.py
  generate_doctor_reviews.py
  generate_hospitalization_lab_test.py
  generate_procedures_with_surgeons.py
  generate_doctor_shift.py
  generate_nurse_shift.py
  generate_admin_shift.py
)

for s in "${scripts[@]}"; do
  echo ">> ${s}"
  python3 "scripts/${s}"
done
