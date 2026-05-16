# تطبيق التعرفة الجمركية — Customs Tariff App

## هيكل المشروع

```
tarrig/
├── backend/                  ← سيرفر Python + FastAPI
│   ├── main.py               ← نقاط الـ API
│   ├── database.py           ← إعداد SQLite
│   ├── pdf_parser.py         ← قراءة جداول PDF
│   ├── requirements.txt
│   └── uploads/              ← ملفات PDF المرفوعة
│
└── mobile/                   ← تطبيق Flutter
    ├── lib/
    │   ├── main.dart
    │   ├── models/
    │   │   └── tariff_item.dart
    │   ├── services/
    │   │   └── api_service.dart
    │   └── screens/
    │       ├── search_screen.dart       ← الشاشة الرئيسية
    │       ├── item_details_screen.dart ← تفاصيل الصنف
    │       └── admin_screen.dart        ← لوحة المسؤول
    └── pubspec.yaml
```

---

## 1. تشغيل السيرفر الخلفي

```bash
cd backend

# إنشاء بيئة افتراضية
python -m venv venv
source venv/bin/activate        # Linux/Mac
# venv\Scripts\activate         # Windows

# تثبيت المتطلبات
pip install -r requirements.txt

# تشغيل السيرفر
uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

يمكنك فتح: http://localhost:8000/docs  لتجربة الـ API مباشرة.

---

## 2. تشغيل تطبيق Flutter

```bash
cd mobile

# تثبيت الحزم
flutter pub get

# تشغيل على محاكي أو هاتف حقيقي
flutter run
```

---

## 3. ربط التطبيق بالسيرفر

| الحالة | العنوان المطلوب |
|--------|----------------|
| محاكي Android | `http://10.0.2.2:8000` |
| هاتف حقيقي على Wi-Fi | `http://192.168.x.x:8000` (IP الكمبيوتر) |
| iOS Simulator | `http://localhost:8000` |

> من شاشة **المسؤول** في التطبيق، غيّر رابط السيرفر ثم اضغط **حفظ**.

---

## 4. نقاط الـ API

| الطريقة | المسار | الوصف |
|---------|--------|-------|
| `POST` | `/admin/upload-pdf` | رفع ملف PDF وتحليله |
| `GET`  | `/admin/files` | قائمة الملفات المرفوعة |
| `DELETE` | `/admin/files/{id}` | حذف ملف |
| `GET`  | `/search?q=...` | البحث في الأصناف |
| `GET`  | `/items/{id}` | تفاصيل صنف |
| `GET`  | `/stats` | إحصائيات |

---

## 5. ملاحظات هامة عن ملفات PDF

- يجب أن يحتوي PDF على **جداول نصية** (وليس صور مسح ضوئي).
- ترتيب الأعمدة المتوقع: `HS Code | اسم الصنف | رسم الصنف | الرسم الكامل | الوصف`
- إذا كانت بنية جداول ملفك مختلفة، عدّل دالة `_row_to_item` في `pdf_parser.py`.
