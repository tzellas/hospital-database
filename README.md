# HospitalDatabase

## Database Setup Instructions

Run the following commands from a Git Bash / Linux-style terminal.

> All SQL and CSV files are expected to be UTF-8 encoded.

### 1. Clone the repository

```bash
git clone <repository-url>
cd HospitalDatabase
```

### 2. Prerequisites

You need:

- `PostgreSQL` with `psql` and `createdb` available in your terminal
- `Python 3` available as `python`

### 3. Create the database

```bash
createdb -U postgres hospital_db
```

### 4. Optionally regenerate the generated CSV files

If you want to rebuild the synthetic/generated data from the current Python scripts, run:

```bash
for s in data/generate_hospitalizations.py data/generate_triage_cases.py data/generate_allergies.py data/generate_prescriptions.py data/generate_hospitalization_reviews.py data/generate_doctor_reviews.py data/generate_hospitalization_lab_test.py data/generate_procedures_with_surgeons.py data/generate_doctor_shift.py data/generate_nurse_shift.py data/generate_admin_shift.py; do python "$s"; done
```

This step is optional if the CSV files already exist and you want to load them as they are.

### 5. Build the database schema

Run from the project root:

```bash
psql -U postgres -d hospital_db -f sql/install.sql
```

### 6. Load the database data

Run from the project root:

```bash
psql -U postgres -d hospital_db -f sql/load.sql
```

### 7. Optionally run all query files

```bash
for f in sql/Queries/Q*.sql
do
  base="$(basename "$f" .sql)"
  psql -U postgres -d hospital_db -P pager=off -f "$f" -o "sql/Queries/${base}_out.txt"
done
```

## Παραδοχές και Υποθέσεις Δεδομένων

Ο παρακάτω πίνακας συγκεντρώνει τις βασικές παραδοχές που χρησιμοποιήθηκαν τόσο στη μοντελοποίηση όσο και στην παραγωγή / φόρτωση των δεδομένων.

| Παραδοχή / Υπόθεση |
|---|
| 1. Όλα τα CSV αρχεία θεωρούνται UTF-8 και το `sql/load.sql` θέτει `\encoding UTF8`. |
| 2. Το `sql/load.sql` εκτελείται από τον root φάκελο του project. |
| 3. Το dataset αντιμετωπίζεται ως αναπαραγώγιμο synthetic workload και όχι ως πραγματικό επιχειρησιακό dump. |
| 4. Πριν τη φόρτωση έγινε normalization των CSV: encoding cleanup, duplicate removal, formatting fixes και filtering μη έγκυρων / ανενεργών rows. |
| 5. Διορθώθηκαν ασυνέπειες που προέκυψαν από μετατροπές Excel → CSV. |
| 6. Τα generated/reference CSV δημιουργούνται από Python scripts με fixed seeds και fixed constants. |
| 7. Τα αρχεία `patients.csv` και `emergency_contacts.csv` αποτελούν το βασικό identity layer των ασθενών. |
| 8. Διορθώνονται μόνο προφανώς μη ρεαλιστικές τιμές που παραβιάζουν constraints, όπως αρνητικές ηλικίες. |
| 9. Ως ICD-10 category θεωρείται ο βασικός κωδικός πριν από το υποδεκαδικό μέρος. Π.χ. `A00.0` και `A00.1` ανήκουν στην κατηγορία `A00`. |
| 10. Τα KEN rows χρησιμοποιούνται ως κατηγορίες νοσηλείας με base cost και average length of stay. |
| 11. Duplicate ή corrupted KEN rows που προέκυψαν από extraction/formatting errors διορθώθηκαν χειροκίνητα. |
| 12. Χρησιμοποιήθηκαν μόνο προϊόντα με `Product authorisation country = Greece`. |
| 13. Επειδή δεν υπήρχε σταθερό natural key στο EMA export, χρησιμοποιήθηκε surrogate key `drug_id SERIAL PRIMARY KEY`. |
| 14. Οι δραστικές ουσίες διασπάστηκαν με separators όπως `,` και `|` μόνο όταν αυτά βρίσκονταν εκτός παρενθέσεων / αγκυλών. |
| 15. Ορισμένα σύνθετα drug labels απαιτούσαν χειροκίνητο parsing. |
| 16. Οι αλλεργίες παράγονται ως σχέσεις `patient_id`–`substance_id` και όχι στο επίπεδο συγκεκριμένου εμπορικού φαρμάκου. |
| 17. Οι επίσημες πράξεις ταξινομήθηκαν στις κατηγορίες `SURGICAL`, `DIAGNOSTIC`, `THERAPEUTIC` με rule-based classification. |
| 18. Εξαιρέθηκαν ανενεργές πράξεις και αφαιρέθηκαν duplicates. |
| 19. Τα default costs για πράξεις και εργαστηριακές εξετάσεις δημιουργούνται συνθετικά με deterministic random generation. |
| 20. Οι νοσηλείες παράγονται στο διάστημα `2025-03-20` έως `2026-03-19`. |
| 21. Η δημιουργία νοσηλειών γίνεται με weighted patient reuse και department affinity, όχι με πλήρως ομοιόμορφη τυχαιότητα. |
| 22. Η διάρκεια νοσηλείας επηρεάζεται από το `average_length_of_stay` του KEN αλλά παραμένει bounded synthetic approximation. |
| 23. Αν μια νοσηλεία δεν μπορεί να τοποθετηθεί νόμιμα στο διαθέσιμο time window ή προκαλεί invalid discharge logic, παραλείπεται. |
| 24. Τα triage cases παράγονται έτσι ώστε ένα υποσύνολο τους να αντιστοιχεί σε νοσηλείες (`REFERRED`). |
| 25. Οι συνταγές παράγονται μόνο όταν ο ασθενής δεν είναι αλλεργικός στις δραστικές ουσίες του φαρμάκου. |
| 26. Οι ιατροί που γράφουν prescriptions επιλέγονται από ειδικότητες και department-compatible pools. |
| 27. Τα hospitalization και doctor reviews παράγονται με coverage rates και όχι για το 100% των εγγραφών. |
| 28. Τα doctor reviews συνδέονται μόνο με πραγματικά `(patient_id, hospitalization_id)` ζεύγη. |
| 29. Όλο το προσωπικό ζει στον πίνακα `staff`, ενώ `doctor`, `nurse` και `administrative_staff` είναι εξειδικεύσεις του ίδιου `staff_id`. |
| 30. Η σχέση `doctor_department` είναι many-to-many. Ένας ιατρός μπορεί να συνδέεται με περισσότερα από ένα τμήματα. |
| 31. Το `duty_shift` καλύπτει επίσης το διάστημα `2025-03-20` έως `2026-03-19`, σε τρεις βάρδιες ανά ημέρα και ανά τμήμα. |
| 32. Το `duty_shift_staff` αποθηκεύει actual assignments προσωπικού σε βάρδιες, όχι θεωρητικές απαιτήσεις staffing. |
| 33. Η απαίτηση της εκφώνησης για εικόνες καλύπτεται από τον πίνακα `entity_image` με `image_url` και λεκτική περιγραφή. |
| 34. Ορισμένα queries μπορούν νόμιμα να επιστρέφουν 0 rows αν το condition είναι πολύ αυστηρό ή αν το ζητούμενο date range είναι εκτός του generated window. |
