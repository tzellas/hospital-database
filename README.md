# HospitalDatabase

Darabase setup instruuctions

from gitbash/linux style terminal. UTF_8 encoded file
create the database 
createdb -U postgres hospital_db

from project root
build the databse 
psql -U postgres -d hospital_db -f sql/install.sql

fill the database 
psql -U postgres -d hospital_db -f sql/load.sql

## Παραδοχές και Υποθέσεις Δεδομένων

| Κατηγορία | Παραδοχή / Υπόθεση |
|---|---|
| Γενικά | Όλα τα CSV αρχεία αποθηκεύονται σε UTF-8 encoding. Το `sql/load.sql` θέτει `\encoding UTF8`, ώστε η φόρτωση ελληνικών δεδομένων να είναι αναπαραγώγιμη. |
| Γενικά | Το `sql/load.sql` πρέπει να εκτελείται από τον root φάκελο του project, ώστε να λειτουργούν σωστά τα relative paths. |
| ETL / Preprocessing | Πριν τη φόρτωση στη βάση πραγματοποιήθηκε preprocessing: encoding normalization, duplicate removal, CSV normalization, filtering inactive rows, category extraction και parsing πολλαπλών δραστικών ουσιών. |
| ETL / Preprocessing | Κατά το preprocessing διορθώθηκαν formatting inconsistencies που προέκυψαν από μετατροπές Excel → CSV. |
| ETL / Preprocessing | Τα generated/reference CSV δημιουργούνται reproducibly μέσω Python ETL scripts. |
| ICD-10 | Ως ICD-10 category θεωρείται ο γενικός κωδικός πριν το τμήμα μετά την τελεία. Π.χ. `A00`, `A00.0`, `A00.1` ανήκουν στην κατηγορία `A00`. |
| ΚΕΝ | Duplicate/corrupted KEN rows που προέκυψαν από extraction formatting errors διορθώθηκαν χειροκίνητα ώστε να διατηρηθεί η μοναδικότητα των κωδικών. |
| Φάρμακα / EMA | Χρησιμοποιήθηκαν μόνο φάρμακα με `Product authorisation country = Greece`, ώστε το dataset να ανταποκρίνεται σε ελληνικό νοσοκομειακό περιβάλλον. |
| Φάρμακα / EMA | Δεν υπήρχε σταθερό μοναδικό EMA code στο export dataset, επομένως χρησιμοποιήθηκε surrogate primary key `drug_id SERIAL PRIMARY KEY`. |
| Φάρμακα / EMA | Οι δραστικές ουσίες διασπάστηκαν με separators `,` και `|`, μόνο όταν αυτά βρίσκονταν εκτός παρενθέσεων `()` και αγκυλών `[]`. |
| Φάρμακα / EMA | Ορισμένες σύνθετες χημικές ενώσεις και influenza strains απαιτούσαν χειροκίνητο parsing, επειδή δεν μπορούσαν να διασπαστούν αξιόπιστα μόνο με γενικούς κανόνες. |
| Φάρμακα / EMA | Το `drug_id` βασίζεται στη σειρά γραμμών του αρχικού `full_ema.csv`. Για αυτό διατηρήθηκε ίδια σειρά στα `drug.csv` και `drug_active_substances_stage.csv`. |
| Ιατρικές Πράξεις | Οι επίσημες κατηγορίες ιατρικών πράξεων δεν αντιστοιχούσαν άμεσα στις κατηγορίες της εκφώνησης (`SURGICAL`, `DIAGNOSTIC`, `THERAPEUTIC`). |
| Ιατρικές Πράξεις | Εφαρμόστηκε rule-based classification κατά το ETL preprocessing βάσει keywords στις περιγραφές των πράξεων. |
| Ιατρικές Πράξεις | Οι inactive πράξεις και εξετάσεις (`ΑΝΕΝΕΡΓΟΣ`) εξαιρέθηκαν από το dataset. |
| Ιατρικές Πράξεις | Τα duplicate αφαιρέθηκαν με deduplication. |
| Ιατρικές Πράξεις | Τα default costs των ιατρικών πράξεων και εργαστηριακών εξετάσεων δημιουργήθηκαν συνθετικά μέσω deterministic random generation με `random.seed(42)`, επειδή οι επίσημες πηγές δεν παρέχουν κόστος. |