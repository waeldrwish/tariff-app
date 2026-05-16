"""
سيرفر التعرفة الجمركية — FastAPI
تشغيل: uvicorn main:app --host 0.0.0.0 --port 8000 --reload
"""

import os
import shutil
from typing import Annotated

from fastapi import FastAPI, File, HTTPException, Query, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from database import get_db, init_db
from pdf_parser import parse_tariff_pdf

# ─────────────────────────── إعداد التطبيق ───────────────────────────

app = FastAPI(
    title="Customs Tariff API",
    description="API للتعرفة الجمركية — رفع PDF، بحث، تفاصيل الأصناف",
    version="1.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

UPLOAD_DIR = os.path.join(os.path.dirname(__file__), "uploads")
os.makedirs(UPLOAD_DIR, exist_ok=True)


@app.on_event("startup")
async def on_startup():
    init_db()


# ─────────────────────────── Admin Endpoints ───────────────────────────

@app.post("/admin/upload-pdf", summary="رفع ملف PDF وتحليله")
async def upload_pdf(file: UploadFile = File(...)):
    if not file.filename.lower().endswith(".pdf"):
        raise HTTPException(status_code=400, detail="يجب أن يكون الملف بصيغة PDF")

    file_path = os.path.join(UPLOAD_DIR, file.filename)

    # حفظ الملف على القرص
    with open(file_path, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)

    # تحليل الجداول داخل PDF
    try:
        items = parse_tariff_pdf(file_path)
    except Exception as exc:
        raise HTTPException(status_code=422, detail=f"فشل تحليل الملف: {exc}") from exc

    if not items:
        raise HTTPException(
            status_code=422,
            detail="لم يُعثر على جداول قابلة للقراءة داخل الملف. "
                   "تأكد أن PDF يحتوي على نصوص وليس صوراً مسحوبة ضوئياً.",
        )

    conn = get_db()
    cur = conn.cursor()

    # مسح البيانات القديمة المرتبطة بهذا الملف فقط
    cur.execute("DELETE FROM tariff_items WHERE source_file = ?", (file.filename,))

    cur.executemany(
        """
        INSERT INTO tariff_items (hs_code, item_name, duty_rate, total_fees, description, source_file)
        VALUES (:hs_code, :item_name, :duty_rate, :total_fees, :description, :source_file)
        """,
        [{**item, "source_file": file.filename} for item in items],
    )

    cur.execute(
        "INSERT INTO uploaded_files (filename, item_count) VALUES (?, ?)",
        (file.filename, len(items)),
    )

    conn.commit()
    conn.close()

    return {"message": f"تم استيراد {len(items)} صنف بنجاح", "count": len(items)}


@app.get("/admin/files", summary="قائمة الملفات المرفوعة")
async def list_files():
    conn = get_db()
    rows = conn.execute(
        "SELECT id, filename, item_count, uploaded_at FROM uploaded_files ORDER BY uploaded_at DESC"
    ).fetchall()
    conn.close()
    return [dict(r) for r in rows]


@app.delete("/admin/files/{file_id}", summary="حذف ملف وبياناته")
async def delete_file(file_id: int):
    conn = get_db()
    row = conn.execute(
        "SELECT filename FROM uploaded_files WHERE id = ?", (file_id,)
    ).fetchone()
    if not row:
        conn.close()
        raise HTTPException(status_code=404, detail="الملف غير موجود")

    filename = row["filename"]
    conn.execute("DELETE FROM tariff_items WHERE source_file = ?", (filename,))
    conn.execute("DELETE FROM uploaded_files WHERE id = ?", (file_id,))
    conn.commit()
    conn.close()

    # حذف الملف من القرص إن وُجد
    disk_path = os.path.join(UPLOAD_DIR, filename)
    if os.path.exists(disk_path):
        os.remove(disk_path)

    return {"message": f"تم حذف {filename} وبياناتها"}


# ─────────────────────────── User Endpoints ───────────────────────────

@app.get("/search", summary="البحث في أصناف التعرفة")
async def search_items(
    q: Annotated[str, Query(min_length=1, description="نص البحث — اسم أو رقم الصنف")],
    limit: int = Query(30, ge=1, le=100),
    offset: int = Query(0, ge=0),
):
    like = f"%{q}%"
    conn = get_db()
    rows = conn.execute(
        """
        SELECT id, hs_code, item_name, duty_rate, total_fees, description
        FROM tariff_items
        WHERE hs_code LIKE ? OR item_name LIKE ? OR description LIKE ?
        ORDER BY
            CASE WHEN hs_code = ? OR item_name = ? THEN 0 ELSE 1 END,
            item_name
        LIMIT ? OFFSET ?
        """,
        (like, like, like, q, q, limit, offset),
    ).fetchall()
    conn.close()
    return [dict(r) for r in rows]


@app.get("/items/{item_id}", summary="تفاصيل صنف محدد")
async def get_item(item_id: int):
    conn = get_db()
    row = conn.execute(
        "SELECT id, hs_code, item_name, duty_rate, total_fees, description FROM tariff_items WHERE id = ?",
        (item_id,),
    ).fetchone()
    conn.close()
    if not row:
        raise HTTPException(status_code=404, detail="الصنف غير موجود")
    return dict(row)


@app.get("/stats", summary="إحصائيات قاعدة البيانات")
async def get_stats():
    conn = get_db()
    total = conn.execute("SELECT COUNT(*) FROM tariff_items").fetchone()[0]
    files = conn.execute("SELECT COUNT(*) FROM uploaded_files").fetchone()[0]
    conn.close()
    return {"total_items": total, "total_files": files}


# ─────────────────────────── تشغيل مباشر ───────────────────────────

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
