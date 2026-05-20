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
for f in sql/Queries/Q*.sql; do base="$(basename "$f" .sql)"; psql -U postgres -d hospital_db -P pager=off -f "$f" -o "sql/Queries/${base}_out.txt"; done
```
## Παραδοχές και Υποθέσεις Δεδομένων

Ο παρακάτω πίνακας συγκεντρώνει τις βασικές παραδοχές που χρησιμοποιήθηκαν τόσο στη μοντελοποίηση όσο και στην παραγωγή / φόρτωση των δεδομένων. Η τρίτη στήλη εξηγεί γιατί κάθε παραδοχή είναι ουσιαστική για να βγαίνουν συνεπή τα CSV, να φορτώνεται σωστά η βάση και να ερμηνεύονται ορθά τα αποτελέσματα των queries.

| Κατηγορία | Παραδοχή / Υπόθεση | Γιατί είναι σημαντική |
|---|---|---|
| Γενικά | Όλα τα CSV αρχεία θεωρούνται UTF-8 και το `sql/load.sql` θέτει `\encoding UTF8`. | Εξασφαλίζεται σωστή φόρτωση ελληνικών χαρακτήρων, KEN περιγραφών και κειμενικών πεδίων χωρίς αλλοίωση encoding. |
| Γενικά | Το `sql/load.sql` εκτελείται από τον root φάκελο του project. | Όλα τα `\copy` βασίζονται σε relative paths, άρα διαφορετικός φάκελος εκτέλεσης οδηγεί σε αποτυχία φόρτωσης ή λάθος αρχεία. |
| Γενικά | Το dataset αντιμετωπίζεται ως αναπαραγώγιμο synthetic workload και όχι ως πραγματικό επιχειρησιακό dump. | Αυτό επιτρέπει deterministic generators, ελεγχόμενο όγκο δεδομένων και καθαρές επεξηγήσεις για ακραία ή σπάνια patterns στα queries. |
| ETL / Preprocessing | Πριν τη φόρτωση έγινε normalization των CSV: encoding cleanup, duplicate removal, formatting fixes και filtering μη έγκυρων / ανενεργών rows. | Χωρίς αυτό το βήμα θα υπήρχαν conflicts σε keys, κατεστραμμένα rows και εσφαλμένες συνδέσεις μεταξύ οντοτήτων. |
| ETL / Preprocessing | Διορθώθηκαν ασυνέπειες που προέκυψαν από μετατροπές Excel → CSV. | Τα αρχεία προέρχονται από ετερογενείς πηγές και χωρίς καθάρισμα θα υπήρχαν broken delimiters, λάθος headers και parsing errors. |
| ETL / Preprocessing | Τα generated/reference CSV δημιουργούνται από Python scripts με fixed seeds και fixed constants. | Τα ίδια inputs δίνουν σταθερά outputs, άρα τα load runs και τα query αποτελέσματα μπορούν να αναπαραχθούν. |
| Ασθενείς | Τα αρχεία `patients.csv` και `emergency_contacts.csv` αποτελούν το βασικό identity layer των ασθενών. | Όλα τα downstream δεδομένα, όπως νοσηλείες, αλλεργίες, reviews και triage cases, εξαρτώνται από έγκυρους patient ids. |
| Ασθενείς | Διορθώνονται μόνο προφανώς μη ρεαλιστικές τιμές που παραβιάζουν constraints, όπως αρνητικές ηλικίες. | Προστατεύεται η ακεραιότητα του schema χωρίς να αλλοιώνεται αχρείαστα ο χαρακτήρας του synthetic dataset. |
| ICD-10 | Ως ICD-10 category θεωρείται ο βασικός κωδικός πριν από το υποδεκαδικό μέρος. Π.χ. `A00.0` και `A00.1` ανήκουν στην κατηγορία `A00`. | Έτσι υποστηρίζονται ομαδοποιήσεις όπως του `Q14` σε επίπεδο diagnosis category και όχι υπερβολικά λεπτομερούς κωδικού. |
| ΚΕΝ | Τα KEN rows χρησιμοποιούνται ως κατηγορίες νοσηλείας με base cost και average length of stay. | Το KEN τροφοδοτεί τόσο το οικονομικό σκέλος της νοσηλείας όσο και τη λογική δημιουργίας διάρκειας stay. |
| ΚΕΝ | Duplicate ή corrupted KEN rows που προέκυψαν από extraction/formatting errors διορθώθηκαν χειροκίνητα. | Η μοναδικότητα του `ken_code` είναι απαραίτητη για σωστές αναφορές κόστους και συνεπείς joins από τις νοσηλείες. |
| Φάρμακα / EMA | Χρησιμοποιήθηκαν μόνο προϊόντα με `Product authorisation country = Greece`. | Έτσι το φαρμακευτικό υποσύνολο παραμένει συμβατό με ελληνικό νοσοκομειακό περιβάλλον, όπως ζητά το project. |
| Φάρμακα / EMA | Επειδή δεν υπήρχε σταθερό natural key στο EMA export, χρησιμοποιήθηκε surrogate key `drug_id SERIAL PRIMARY KEY`. | Απλοποιείται η σύνδεση prescription και active substance data και αποφεύγονται ασταθή ή μη μοναδικά identifiers. |
| Φάρμακα / EMA | Οι δραστικές ουσίες διασπάστηκαν με separators όπως `,` και `|` μόνο όταν αυτά βρίσκονταν εκτός παρενθέσεων / αγκυλών. | Χωρίς αυτή την παραδοχή θα προέκυπταν λάθος active substances και κατά συνέπεια λάθος allergy/prescription conflicts. |
| Φάρμακα / EMA | Ορισμένα σύνθετα drug labels απαιτούσαν χειροκίνητο parsing. | Οι γενικοί κανόνες δεν αρκούν πάντα για χημικά σύνθετα strings ή influenza strains, άρα χρειάστηκε ελεγχόμενη ανθρώπινη παρέμβαση. |
| Αλλεργίες | Οι αλλεργίες παράγονται ως σχέσεις `patient_id`–`substance_id` και όχι στο επίπεδο συγκεκριμένου εμπορικού φαρμάκου. | Αυτό ταιριάζει με το ιατρικό νόημα των allergies και επιτρέπει αξιόπιστο έλεγχο συμβατότητας με δραστικές ουσίες συνταγών. |
| Ιατρικές Πράξεις | Οι επίσημες πράξεις ταξινομήθηκαν στις κατηγορίες `SURGICAL`, `DIAGNOSTIC`, `THERAPEUTIC` με rule-based classification. | Οι πρωτογενείς πηγές δεν έδιναν ακριβώς την κατηγοριοποίηση της εκφώνησης, άρα απαιτήθηκε χαρτογράφηση για να λειτουργήσουν queries όπως το `Q05`. |
| Ιατρικές Πράξεις | Εξαιρέθηκαν ανενεργές πράξεις και αφαιρέθηκαν duplicates. | Αποφεύγονται ψευδείς πράξεις, inflated counts και noise στις αναλύσεις procedures/lab tests. |
| Ιατρικές Πράξεις | Τα default costs για πράξεις και εργαστηριακές εξετάσεις δημιουργούνται συνθετικά με deterministic random generation. | Οι πηγές δεν παρέχουν ολοκληρωμένο cost model, αλλά τα queries και τα οικονομικά πεδία απαιτούν αριθμητικές τιμές συνεπείς και επαναλήψιμες. |
| Νοσηλείες | Οι νοσηλείες παράγονται στο διάστημα `2025-03-20` έως `2026-03-19`. | Αυτό εξηγεί γιατί year-based queries δεν καλύπτουν πλήρη ημερολογιακά έτη και γιατί κάποιες εβδομάδες εκτός range επιστρέφουν 0 rows. |
| Νοσηλείες | Η δημιουργία νοσηλειών γίνεται με weighted patient reuse και department affinity, όχι με πλήρως ομοιόμορφη τυχαιότητα. | Έτσι προκύπτουν φυσικότερα repeated hospitalizations ανά ασθενή/τμήμα, χωρίς να χρειάζονται hardcoded forced cases. |
| Νοσηλείες | Η διάρκεια νοσηλείας επηρεάζεται από το `average_length_of_stay` του KEN αλλά παραμένει bounded synthetic approximation. | Διατηρείται σύνδεση με το KEN χωρίς να δημιουργούνται υπερβολικά μεγάλες ή ανεξέλεγκτες διάρκειες που θα έσπαγαν bed capacity constraints. |
| Νοσηλείες | Αν μια νοσηλεία δεν μπορεί να τοποθετηθεί νόμιμα στο διαθέσιμο time window ή προκαλεί invalid discharge logic, παραλείπεται. | Αυτό είναι κρίσιμο για να αποφεύγονται bed overlaps και invalid intervals που παραβιάζουν τα database constraints. |
| Triage | Τα triage cases παράγονται έτσι ώστε ένα υποσύνολο τους να αντιστοιχεί σε νοσηλείες (`REFERRED`). | Έτσι δημιουργείται συνεπής ροή από την επείγουσα προσέλευση προς την εισαγωγή στο νοσοκομείο, χωρίς orphan triage relations. |
| Συνταγογράφηση | Οι συνταγές παράγονται μόνο όταν ο ασθενής δεν είναι αλλεργικός στις δραστικές ουσίες του φαρμάκου. | Το dataset παραμένει ιατρικά λογικό και δεν δημιουργούνται μαζικά prescriptions που θα ήταν αμέσως invalid από allergy logic. |
| Συνταγογράφηση | Οι ιατροί που γράφουν prescriptions επιλέγονται από ειδικότητες και department-compatible pools. | Βοηθά να είναι πιο πειστικές οι αναθέσεις ιατρών και να ταιριάζουν καλύτερα με τα downstream review/procedure queries. |
| Reviews | Τα hospitalization και doctor reviews παράγονται με coverage rates και όχι για το 100% των εγγραφών. | Είναι πιο ρεαλιστικό να μην αξιολογούν όλοι οι ασθενείς κάθε νοσηλεία ή γιατρό και εξηγεί γιατί ορισμένα review queries μπορεί να είναι sparse. |
| Reviews | Τα doctor reviews συνδέονται μόνο με πραγματικά `(patient_id, hospitalization_id)` ζεύγη. | Αυτό αποτρέπει orphan reviews και εξασφαλίζει ότι τα aggregates των queries βασίζονται σε υπαρκτές νοσηλείες. |
| Προσωπικό | Όλο το προσωπικό ζει στον πίνακα `staff`, ενώ `doctor`, `nurse` και `administrative_staff` είναι εξειδικεύσεις του ίδιου `staff_id`. | Είναι βασική σχεδιαστική παραδοχή για τα joins των queries και εξηγεί γιατί πολλά queries ενώνουν subtype tables με τον κοινό πίνακα προσωπικού. |
| Ιατροί | Η σχέση `doctor_department` είναι many-to-many. Ένας ιατρός μπορεί να συνδέεται με περισσότερα από ένα τμήματα. | Αυτό κάνει πιο ρεαλιστική τη μοντελοποίηση ειδικοτήτων και συνεργασιών, αλλά επίσης εξηγεί γιατί ορισμένα scheduling tasks γίνονται πιο σύνθετα. |
| Βάρδιες | Το `duty_shift` καλύπτει επίσης το διάστημα `2025-03-20` έως `2026-03-19`, σε τρεις βάρδιες ανά ημέρα και ανά τμήμα. | Είναι σημαντικό για week-based queries όπως το `Q12`, γιατί ημερομηνίες εκτός αυτού του εύρους δεν μπορούν να επιστρέψουν δεδομένα. |
| Βάρδιες | Το `duty_shift_staff` αποθηκεύει actual assignments προσωπικού σε βάρδιες, όχι θεωρητικές απαιτήσεις staffing. | Αυτό επηρεάζει άμεσα την ερμηνεία του `Q12`: το query δείχνει προγραμματισμένο προσωπικό, όχι αφηρημένο demand model. |
| Οντότητες με εικόνες | Η απαίτηση της εκφώνησης για εικόνες καλύπτεται από τον πίνακα `entity_image` με `image_url` και λεκτική περιγραφή. | Έτσι το schema μπορεί να υποστηρίξει μελλοντική ιστοσελίδα χωρίς να απαιτείται διαφορετική δομή ανά οντότητα για την αποθήκευση εικόνων. |
| Queries | Ορισμένα queries μπορούν νόμιμα να επιστρέφουν 0 rows αν το condition είναι πολύ αυστηρό ή αν το ζητούμενο date range είναι εκτός του generated window. | Είναι σημαντικό για την ερμηνεία αποτελεσμάτων όπως του `Q14`, ώστε το κενό αποτέλεσμα να μην θεωρείται αυτομάτως bug. |





