"""
Atlas AI — Lightweight Flask Application for t3.micro
3-Tier: Frontend (HTML/JS) + Backend (Flask API) + Database (SQLite)

Stripped of heavy ML deps: no torch, transformers, faiss, sentence-transformers.
Keeps rule engine, dialogue manager, Groq AI (API-only), and audit logging.
"""

import json
import logging
import os
import sqlite3
import time
import uuid
from contextlib import contextmanager
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, Generator, List, Optional

from flask import Flask, jsonify, request, render_template, session
from flask_cors import CORS
from flask_session import Session

from src.core.config import AtlasConfig
from src.core.audit import audit_logger, AuditEvent, AuditEventType
from src.dialogue.enhanced_manager import EnhancedDialogueManager
from src.rule_engine.visa_recommender import get_visa_recommendation
from src.rule_engine.rules_base import ApplicantProfile
from src.gpt.groq_ai import groq_ai

# ── Flask App Setup ────────────────────────────────────────────────────────────

PROJECT_ROOT = Path(__file__).resolve().parent

app = Flask(
    __name__,
    template_folder=str(PROJECT_ROOT / "frontend" / "templates"),
    static_folder=str(PROJECT_ROOT / "frontend" / "static"),
)
app.secret_key = os.environ["FLASK_SECRET_KEY"]
app.config["SESSION_TYPE"] = "filesystem"
app.config["SESSION_PERMANENT"] = False
app.config["SESSION_USE_SIGNER"] = True
app.config["SESSION_FILE_DIR"] = str(AtlasConfig.BASE_DIR / "sessions")
Session(app)
CORS(app)

# ── Logging ────────────────────────────────────────────────────────────────────

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[logging.StreamHandler()],
)
logger = logging.getLogger(__name__)

# ── SQLite Database (lightweight, no external DB needed) ──────────────────────

DB_PATH = AtlasConfig.BASE_DIR / "data" / "atlas_lite.db"


def _ensure_db_dirs():
    DB_PATH.parent.mkdir(parents=True, exist_ok=True)


@contextmanager
def _db_connection() -> Generator[sqlite3.Connection, None, None]:
    _ensure_db_dirs()
    conn = sqlite3.connect(str(DB_PATH), check_same_thread=False)
    conn.row_factory = sqlite3.Row
    try:
        yield conn
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()


def init_db():
    """Initialize SQLite tables if they don't exist."""
    _ensure_db_dirs()
    with _db_connection() as conn:
        conn.executescript(
            """
            CREATE TABLE IF NOT EXISTS conversations (
                id TEXT PRIMARY KEY,
                session_id TEXT NOT NULL,
                role TEXT NOT NULL,
                content TEXT NOT NULL,
                intent TEXT,
                confidence REAL,
                created_at TEXT NOT NULL
            );
            CREATE TABLE IF NOT EXISTS eligibility_checks (
                id TEXT PRIMARY KEY,
                session_id TEXT NOT NULL,
                visa_type TEXT NOT NULL,
                profile_json TEXT NOT NULL,
                result_json TEXT NOT NULL,
                created_at TEXT NOT NULL
            );
            CREATE TABLE IF NOT EXISTS audit_events (
                id TEXT PRIMARY KEY,
                event_type TEXT NOT NULL,
                session_id TEXT,
                data TEXT,
                created_at TEXT NOT NULL
            );
            CREATE INDEX IF NOT EXISTS idx_conversations_session ON conversations(session_id);
            CREATE INDEX IF NOT EXISTS idx_eligibility_session ON eligibility_checks(session_id);
            CREATE INDEX IF NOT EXISTS idx_audit_session ON audit_events(session_id);
            """
        )
    logger.info("[DB] SQLite initialized at %s", DB_PATH)


def save_conversation(session_id: str, role: str, content: str, intent: str = None, confidence: float = None):
    with _db_connection() as conn:
        conn.execute(
            "INSERT INTO conversations (id, session_id, role, content, intent, confidence, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)",
            (str(uuid.uuid4()), session_id, role, content, intent, confidence, datetime.utcnow().isoformat()),
        )


def save_eligibility_check(session_id: str, visa_type: str, profile: dict, result: dict):
    with _db_connection() as conn:
        conn.execute(
            "INSERT INTO eligibility_checks (id, session_id, visa_type, profile_json, result_json, created_at) VALUES (?, ?, ?, ?, ?, ?)",
            (str(uuid.uuid4()), session_id, visa_type, json.dumps(profile), json.dumps(result), datetime.utcnow().isoformat()),
        )


def save_audit_event(event_type: str, session_id: str, data: dict):
    with _db_connection() as conn:
        conn.execute(
            "INSERT INTO audit_events (id, event_type, session_id, data, created_at) VALUES (?, ?, ?, ?, ?)",
            (str(uuid.uuid4()), event_type, session_id, json.dumps(data), datetime.utcnow().isoformat()),
        )


# ── Globals ────────────────────────────────────────────────────────────────────

enhanced_dm = EnhancedDialogueManager()
init_db()

# ── Routes ─────────────────────────────────────────────────────────────────────


@app.route("/")
def index():
    return render_template("index.html")


@app.route("/api/health", methods=["GET"])
def health_check():
    return jsonify({
        "status": "healthy",
        "service": "Atlas AI Lite",
        "groq_available": groq_ai.available,
        "timestamp": datetime.utcnow().isoformat(),
    })


@app.route("/api/greeting", methods=["GET"])
def get_greeting():
    return jsonify({
        "message": (
            "🗺️ **Hello! I'm Atlas AI, your friendly UK immigration assistant.**\n\n"
            "I'm here to help you navigate UK visas. Ask me anything about eligibility, "
            "documents, processing times, or fees.\n\n"
            "*This is informational guidance, not legal advice.*"
        ),
        "suggestions": [
            "What are the requirements for a Skilled Worker visa?",
            "How much salary do I need for a Skilled Worker visa?",
            "Can I switch from Student to Graduate visa?",
            "What documents do I need for Health and Care Worker visa?",
        ],
    })


@app.route("/api/chat", methods=["POST"])
def chat():
    data = request.get_json(force=True)
    user_message = (data.get("message") or "").strip()
    if not user_message:
        return jsonify({"error": "No message provided"}), 400

    session_id = session.get("session_id")
    if not session_id:
        session_id = str(uuid.uuid4())
        session["session_id"] = session_id

    start_time = time.time()
    save_conversation(session_id, "user", user_message)
    save_audit_event("message_received", session_id, {"message": user_message[:200]})

    try:
        # Priority 1: Groq AI with RAG (no local cost)
        if groq_ai.available:
            try:
                response_text = groq_ai.chat(user_message, use_rag=True)
                if response_text:
                    processing_time = (time.time() - start_time) * 1000
                    save_conversation(session_id, "assistant", response_text, intent="groq_rag", confidence=0.95)
                    save_audit_event("explanation_generated", session_id, {"source": "groq_rag"})
                    return jsonify({
                        "response": response_text,
                        "session_id": session_id,
                        "intent": "groq_rag_generated",
                        "confidence": 0.95,
                        "entities": {},
                        "profile": {},
                        "processing_time_ms": round(processing_time, 2),
                        "timestamp": datetime.utcnow().isoformat(),
                    })
            except Exception as exc:
                logger.warning("Groq AI failed: %s", exc)

        # Priority 2: Rule-based dialogue manager (offline-capable)
        result = enhanced_dm.process_message(session_id, user_message)
        response_text = result.get("response", "")
        processing_time = result.get("processing_time_ms", (time.time() - start_time) * 1000)

        save_conversation(
            session_id,
            "assistant",
            response_text,
            intent=result.get("intent"),
            confidence=result.get("confidence"),
        )
        save_audit_event("explanation_generated", session_id, {"source": "dialogue_manager", "intent": str(result.get("intent"))})

        return jsonify({
            "response": response_text,
            "session_id": session_id,
            "intent": result.get("intent"),
            "confidence": result.get("confidence", 0.0),
            "entities": result.get("entities", {}),
            "profile": result.get("profile", {}),
            "processing_time_ms": round(processing_time, 2),
            "timestamp": datetime.utcnow().isoformat(),
        })

    except Exception as exc:
        logger.error("Chat error: %s", exc)
        save_audit_event("error_occurred", session_id, {"error": str(exc)})
        return jsonify({
            "error": "An error occurred while processing your message.",
            "details": str(exc) if app.debug else None,
        }), 500


@app.route("/api/reset", methods=["POST"])
def reset_session():
    session.clear()
    return jsonify({"message": "Session cleared successfully."})


@app.route("/api/visas", methods=["GET"])
def list_visas():
    visas = [
        {"type": "skilled_worker", "name": "Skilled Worker Visa", "description": "For workers with a job offer from a UK licensed sponsor", "requirements": ["Sponsorship", "Salary threshold (£38,700)", "English language", "Eligible occupation"]},
        {"type": "health_care_worker", "name": "Health and Care Worker Visa", "description": "For NHS and adult social care workers", "requirements": ["Sponsorship from NHS/care provider", "Eligible health occupation", "Professional qualifications"]},
        {"type": "graduate", "name": "Graduate Visa", "description": "For UK university graduates to work post-study", "requirements": ["UK degree", "Current Student visa", "Study completion confirmation"]},
        {"type": "global_talent", "name": "Global Talent Visa", "description": "For leaders in academia, research, digital technology, and arts", "requirements": ["Endorsement from competent body", "Exceptional talent or promise"]},
        {"type": "student", "name": "Student Visa", "description": "For individuals who want to study in the UK", "requirements": ["CAS from licensed sponsor", "English proficiency", "Maintenance funds"]},
        {"type": "family", "name": "Family Visa", "description": "For partners and family members of UK residents", "requirements": ["Minimum income £18,600", "Genuine relationship", "English A1 level"]},
    ]
    return jsonify(visas)


@app.route("/api/eligibility", methods=["POST"])
def check_eligibility():
    data = request.get_json(force=True)
    visa_type = data.get("visa_type", "skilled_worker")

    profile = ApplicantProfile(
        job_title=data.get("job_title"),
        salary_annual=float(data.get("salary_annual") or 0),
        has_sponsor=data.get("has_sponsor"),
        country_of_origin=data.get("country_of_origin"),
        english_proficiency=data.get("english_proficiency"),
        age=data.get("age"),
        qualification=data.get("qualification"),
        visa_type=visa_type,
    )

    recommendation = get_visa_recommendation(profile)
    top = recommendation.get("recommended_visa")
    result = {
        "visa_type": visa_type,
        "verdict": top.verdict if top else "unknown",
        "summary": top.summary if top else "Unable to determine eligibility.",
        "score": top.score if top else 0,
        "matched_criteria": top.matched_criteria if top else [],
        "missing_criteria": top.missing_criteria if top else [],
        "all_options": [
            {
                "visa_type": r.visa_type,
                "verdict": r.verdict,
                "score": r.score,
                "summary": r.summary,
            }
            for r in recommendation.get("all_options", [])
        ],
    }

    save_eligibility_check(session.get("session_id", "unknown"), visa_type, data, result)
    save_audit_event("eligibility_determined", session.get("session_id", "unknown"), {"visa_type": visa_type, "verdict": result["verdict"]})
    return jsonify(result)


@app.route("/api/stats", methods=["GET"])
def get_stats():
    session_id = session.get("session_id")
    with _db_connection() as conn:
        cur = conn.execute("SELECT COUNT(*) AS c FROM conversations WHERE session_id = ?", (session_id,))
        messages = cur.fetchone()["c"]
        cur = conn.execute("SELECT COUNT(*) AS c FROM eligibility_checks WHERE session_id = ?", (session_id,))
        checks = cur.fetchone()["c"]
    return jsonify({"session_id": session_id, "messages": messages, "eligibility_checks": checks})


if __name__ == "__main__":
    logger.info("Starting Atlas AI Lite...")
    logger.info("Groq available: %s", groq_ai.available)
    app.run(host=AtlasConfig.FLASK_HOST, port=AtlasConfig.FLASK_PORT, debug=AtlasConfig.FLASK_DEBUG)
