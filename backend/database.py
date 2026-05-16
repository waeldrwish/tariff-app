import sqlite3
import os

DB_PATH = os.path.join(os.path.dirname(__file__), "tariff.db")


def get_db() -> sqlite3.Connection:
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn


def init_db():
    conn = get_db()
    cursor = conn.cursor()
    cursor.executescript("""
        CREATE TABLE IF NOT EXISTS tariff_items (
            id          INTEGER PRIMARY KEY AUTOINCREMENT,
            hs_code     TEXT NOT NULL,
            item_name   TEXT NOT NULL,
            duty_rate   TEXT DEFAULT '',
            total_fees  TEXT DEFAULT '',
            description TEXT DEFAULT '',
            source_file TEXT DEFAULT '',
            created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        );

        CREATE INDEX IF NOT EXISTS idx_hs_code   ON tariff_items(hs_code);
        CREATE INDEX IF NOT EXISTS idx_item_name ON tariff_items(item_name);

        CREATE TABLE IF NOT EXISTS uploaded_files (
            id          INTEGER PRIMARY KEY AUTOINCREMENT,
            filename    TEXT NOT NULL,
            item_count  INTEGER DEFAULT 0,
            uploaded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        );
    """)
    conn.commit()
    conn.close()
