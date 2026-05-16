"""
محلل ملفات PDF للتعرفة الجمركية.
يستخرج الجداول ويحوّلها إلى قوائم من القواميس.
"""

import re
import pdfplumber


# أنماط للتعرف على رقم HS Code (مثال: 0101.21.00 أو 01012100)
HS_PATTERN = re.compile(r"^\d{2,4}[\.\s]?\d{0,2}[\.\s]?\d{0,2}[\.\s]?\d{0,4}$")

# كلمات رأس الجدول التي يجب تجاهلها
HEADER_KEYWORDS = {
    "hs code", "rqm", "code", "رقم", "بند", "item", "description",
    "duty", "rate", "fees", "الصنف", "الرسم", "الرسوم", "البيان",
    "اسم", "وصف", "نسبة", "إجمالي",
}


def _clean(cell) -> str:
    if cell is None:
        return ""
    return " ".join(str(cell).split())


def _is_header(row: list[str]) -> bool:
    first = row[0].lower()
    return any(kw in first for kw in HEADER_KEYWORDS)


def _looks_like_hs(value: str) -> bool:
    return bool(HS_PATTERN.match(value.replace(" ", "").replace("\n", "")))


def _row_to_item(row: list[str]) -> dict | None:
    """تحويل صف الجدول إلى قاموس بيانات."""
    if len(row) < 2:
        return None

    hs_code = _clean(row[0])
    item_name = _clean(row[1])
    duty_rate = _clean(row[2]) if len(row) > 2 else ""
    total_fees = _clean(row[3]) if len(row) > 3 else ""
    description = _clean(row[4]) if len(row) > 4 else ""

    # بعض ملفات PDF تضع الاسم أولاً والرقم ثانياً
    if not _looks_like_hs(hs_code) and _looks_like_hs(item_name):
        hs_code, item_name = item_name, hs_code

    if not hs_code and not item_name:
        return None

    return {
        "hs_code": hs_code,
        "item_name": item_name,
        "duty_rate": duty_rate,
        "total_fees": total_fees,
        "description": description,
    }


def parse_tariff_pdf(file_path: str) -> list[dict]:
    """
    يفتح ملف PDF ويستخرج جميع الأصناف من جداوله.
    يُرجع قائمة من القواميس بحقول:
      hs_code, item_name, duty_rate, total_fees, description
    """
    items: list[dict] = []
    seen_codes: set[str] = set()

    with pdfplumber.open(file_path) as pdf:
        for page_num, page in enumerate(pdf.pages, start=1):
            tables = page.extract_tables(
                table_settings={
                    "vertical_strategy": "lines",
                    "horizontal_strategy": "lines",
                    "snap_tolerance": 5,
                }
            )

            # إذا لم يُعثر على جداول محددة جرّب استخراج النص كجدول
            if not tables:
                table = page.extract_table()
                if table:
                    tables = [table]

            for table in tables:
                if not table:
                    continue
                for row in table:
                    cleaned = [_clean(c) for c in row]
                    if _is_header(cleaned):
                        continue
                    item = _row_to_item(cleaned)
                    if item and item["hs_code"] not in seen_codes:
                        seen_codes.add(item["hs_code"])
                        items.append(item)

    return items
