from flask_sqlalchemy import SQLAlchemy
from datetime import datetime, timezone

db = SQLAlchemy()


class DemoRequest(db.Model):
    """Stores every 'Request
    a Demo' form submission."""

    __tablename__ = "demo_requests"

    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(120), nullable=False)
    company = db.Column(db.String(200), nullable=False)
    email = db.Column(db.String(254), nullable=False)
    submitted_at = db.Column(
        db.DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        nullable=False,
    )

    def to_dict(self):
        """Serialise the record to a
        plain dict (for JSON responses)."""
        return {
            "id": self.id,
            "name": self.name,
            "company": self.company,
            "email": self.email,
            "submitted_at": self.submitted_at.isoformat(),
        }

    def __repr__(self):
        return f"<DemoRequest {self.id} – {self.email}>"
