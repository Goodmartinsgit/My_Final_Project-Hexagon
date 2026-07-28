import re
from flask import Blueprint, request, jsonify
from models import db, DemoRequest

demo_bp = Blueprint("demo", __name__)

# ── Helpers
EMAIL_RE = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")


def _validate_payload(data: dict) -> list[str]:
    """Return a list of validation error messages (empty = valid)."""
    errors = []

    name = (data.get("name") or "").strip()
    company = (data.get("company") or "").strip()
    email = (data.get("email") or "").strip()

    if not name:
        errors.append("Name is required.")
    elif len(name) > 120:
        errors.append("Name must be 120 characters or fewer.")

    if not company:
        errors.append("Company name is required.")
    elif len(company) > 200:
        errors.append("Company name must be 200 characters or fewer.")

    if not email:
        errors.append("Email is required.")
    elif not EMAIL_RE.match(email):
        errors.append("A valid email address is required.")
    elif len(email) > 254:
        errors.append("Email must be 254 characters or fewer.")

    return errors


# ── Routes
@demo_bp.route("/demo", methods=["POST"])
def submit_demo():
    """
    POST /api/demo
    Accepts JSON or form-encoded body with fields: name, company, email.
    Saves a new DemoRequest row and returns the saved record as JSON.
    """
    if request.is_json:
        data = request.get_json(silent=True) or {}
    else:
        data = request.form.to_dict()

    # ── Validation layer
    errors = _validate_payload(data)
    if errors:
        return jsonify({
            "success": False,
            "errors": errors}), 422

    # ── Data / persistence layer
    try:
        record = DemoRequest(
            name=data["name"].strip(),
            company=data["company"].strip(),
            email=data["email"].strip(),
        )
        db.session.add(record)
        db.session.commit()
    except Exception:
        db.session.rollback()
        # Don't leak DB internals to the client
        return jsonify({
            "success": False,
            "errors": ["Database error. Please try again."]
            }), 500

    return jsonify({"success": True, "data": record.to_dict()}), 201


@demo_bp.route("/demo", methods=["GET"])
def list_demos():
    """
    GET /api/demo
    Returns all demo requests (admin/internal
    use – protect this in production).
    """
    records = DemoRequest.query.order_by(
        DemoRequest.submitted_at.desc()
        ).all()
    return jsonify({
        "success": True,
        "data": [r.to_dict() for r in records]
        }), 200


@demo_bp.route("/health", methods=["GET"])
def health():
    """Simple liveness probe."""
    return jsonify({"status": "ok"}), 200
