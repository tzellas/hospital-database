import csv
import re
import random
import pandas as pd

input_file = "all_actions.xls"

medical_output_file = "medical_procedures.csv"
lab_output_file = "lab_tests.csv"

random.seed(42)

seen_medical_codes = set()
seen_lab_codes = set()

def clean_main_category(text):
    text = str(text).strip()
    return re.sub(r"^[Α-ΩA-Z]\.\s*", "", text).strip()

def get_main_category_letter(text):
    text = str(text).strip()
    match = re.match(r"^([Α-ΩA-Z])\.\s+\S+", text)
    return match.group(1) if match else None

def is_main_category(row_a, row_b, row_c):
    if pd.isna(row_a):
        return False
    text = str(row_a).strip()
    return bool(re.match(r"^[Α-ΩA-Z]\.\s+\S+", text)) and pd.isna(row_b) and pd.isna(row_c)

def is_subcategory(row_a, row_b, row_c):
    if pd.isna(row_a) or pd.isna(row_b):
        return False
    marker = str(row_a).strip()
    return bool(re.match(r"^[Α-ΩA-Z]\.\d+", marker)) and pd.isna(row_c)

def is_action_row(row_a, row_b, row_c):
    return pd.notna(row_b) and pd.notna(row_c)

def normalize_medical_category(description):
    text = description.upper()

    therapeutic_keywords = [
        "ΘΕΡΑΠΕΙΑ",
        "ΕΓΧΥΣΗ",
        "ΧΗΜΕΙΟΘΕΡΑΠΕΙΑ",
        "ΑΚΤΙΝΟΘΕΡΑΠΕΙΑ",
        "ΑΠΟΚΑΤΑΣΤΑΣΗ",
        "ΜΕΤΑΓΓΙΣΗ",
        "ΑΦΑΙΜΑΞΟΜΕΤΑΓΓΙΣΗ",
        "ΑΙΜΑ",
        "ΧΟΡΗΓΗΣΗ",
    ]

    diagnostic_keywords = [
        "ΒΙΟΨΙΑ",
        "ΔΙΑΓΝΩΣ",
        "ΑΓΓΕΙΟΓΡΑΦΙΑ",
        "ΠΑΡΑΚΕΝΤΗΣΗ",
        "ΚΑΘΕΤΗΡΙΑΣΜΟΣ",
        "ΕΝΔΟΣΚΟΠΗΣΗ",
    ]

    if any(word in text for word in therapeutic_keywords):
        return "THERAPEUTIC"

    if any(word in text for word in diagnostic_keywords):
        return "DIAGNOSTIC"

    return "SURGICAL"

def random_lab_cost():
    return round(random.uniform(5, 200), 2)

def random_medical_cost(category):
    if category == "SURGICAL":
        return round(random.uniform(500, 15000), 2)

    if category == "DIAGNOSTIC":
        return round(random.uniform(100, 2000), 2)

    return round(random.uniform(200, 5000), 2)

df = pd.read_excel(input_file, header=None)

medical_rows = []
lab_rows = []

main_category = None
main_category_letter = None
sub_category = None

for _, row in df.iterrows():
    col_a = row[0] if len(row) > 0 else None
    col_b = row[1] if len(row) > 1 else None
    col_c = row[2] if len(row) > 2 else None

    if is_main_category(col_a, col_b, col_c):
        main_category_letter = get_main_category_letter(col_a)
        main_category = clean_main_category(col_a)
        sub_category = None
        continue

    if is_subcategory(col_a, col_b, col_c):
        sub_category = str(col_b).strip()
        continue

    if is_action_row(col_a, col_b, col_c):
        code = str(col_b).strip()
        description = str(col_c).strip()
        
        if description.strip().upper() == "ΑΝΕΝΕΡΓΟΣ":
            continue

        full_text = " ".join(
            part for part in [main_category, sub_category, description]
            if part
        )

        if main_category_letter in {"Α", "Β", "A", "B"}:
            if code in seen_medical_codes:
                continue

            seen_medical_codes.add(code)
            category = normalize_medical_category(description)
            cost = random_medical_cost(category)

            medical_rows.append([code, description, category, cost])

        elif main_category_letter in {"Γ", "Δ", "Ε"}:
            if code in seen_lab_codes:
                continue

            seen_lab_codes.add(code)
            cost = random_lab_cost()

            lab_rows.append([code, description, cost])

with open(medical_output_file, "w", newline="", encoding="utf-8") as f:
    writer = csv.writer(f)
    writer.writerows(medical_rows)

with open(lab_output_file, "w", newline="", encoding="utf-8") as f:
    writer = csv.writer(f)
    writer.writerows(lab_rows)

print(f"Medical action rows: {len(medical_rows)}")
print(f"Lab test rows: {len(lab_rows)}")