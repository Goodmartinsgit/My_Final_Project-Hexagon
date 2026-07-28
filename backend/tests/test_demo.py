"""
test_demo.py — tests for the /api/demo and /api/health endpoints.

Covers:
    - Successful demo request submission (POST /api/demo)
    - Input validation: missing fields, invalid email, field length limits
    - Listing submissions (GET /api/demo)
    - Health check (GET /api/health)
"""

import json


class TestHealth:
    """Tests for the /api/health liveness probe."""

    def test_health_returns_200(self, client):
        response = client.get("/api/health")
        assert response.status_code == 200

    def test_health_returns_ok_status(self, client):
        data = response = client.get("/api/health")
        data = json.loads(response.data)
        assert data["status"] == "ok"


class TestSubmitDemo:
    """Tests for POST /api/demo — demo request submission."""

    def _valid_payload(self):
        return {"name": "Jane Smith", "company": "Acme Ltd", "email": "jane@acme.com"}

    def test_successful_submission_returns_201(self, client):
        response = client.post(
            "/api/demo",
            data=json.dumps(self._valid_payload()),
            content_type="application/json",
        )
        assert response.status_code == 201

    def test_successful_submission_returns_success_true(self, client):
        response = client.post(
            "/api/demo",
            data=json.dumps(self._valid_payload()),
            content_type="application/json",
        )
        data = json.loads(response.data)
        assert data["success"] is True

    def test_successful_submission_echoes_payload(self, client):
        payload = self._valid_payload()
        response = client.post(
            "/api/demo",
            data=json.dumps(payload),
            content_type="application/json",
        )
        data = json.loads(response.data)
        record = data["data"]
        assert record["name"] == payload["name"]
        assert record["company"] == payload["company"]
        assert record["email"] == payload["email"]

    def test_successful_submission_includes_id_and_timestamp(self, client):
        response = client.post(
            "/api/demo",
            data=json.dumps(self._valid_payload()),
            content_type="application/json",
        )
        data = json.loads(response.data)
        record = data["data"]
        assert "id" in record
        assert isinstance(record["id"], int)
        assert "submitted_at" in record

    def test_accepts_form_encoded_body(self, client):
        response = client.post(
            "/api/demo",
            data=self._valid_payload(),
            content_type="application/x-www-form-urlencoded",
        )
        assert response.status_code == 201

    # ── Validation errors ──────────────────────────────────────────────────

    def test_missing_name_returns_422(self, client):
        payload = {"company": "Acme", "email": "jane@acme.com"}
        response = client.post(
            "/api/demo",
            data=json.dumps(payload),
            content_type="application/json",
        )
        assert response.status_code == 422

    def test_missing_name_includes_error_message(self, client):
        payload = {"company": "Acme", "email": "jane@acme.com"}
        response = client.post(
            "/api/demo",
            data=json.dumps(payload),
            content_type="application/json",
        )
        data = json.loads(response.data)
        assert data["success"] is False
        assert any("Name" in e for e in data["errors"])

    def test_missing_company_returns_422(self, client):
        payload = {"name": "Jane", "email": "jane@acme.com"}
        response = client.post(
            "/api/demo",
            data=json.dumps(payload),
            content_type="application/json",
        )
        assert response.status_code == 422

    def test_missing_email_returns_422(self, client):
        payload = {"name": "Jane", "company": "Acme"}
        response = client.post(
            "/api/demo",
            data=json.dumps(payload),
            content_type="application/json",
        )
        assert response.status_code == 422

    def test_invalid_email_format_returns_422(self, client):
        payload = {"name": "Jane", "company": "Acme", "email": "not-an-email"}
        response = client.post(
            "/api/demo",
            data=json.dumps(payload),
            content_type="application/json",
        )
        assert response.status_code == 422

    def test_name_exceeding_max_length_returns_422(self, client):
        payload = {
            "name": "A" * 121,
            "company": "Acme",
            "email": "jane@acme.com",
        }
        response = client.post(
            "/api/demo",
            data=json.dumps(payload),
            content_type="application/json",
        )
        assert response.status_code == 422

    def test_company_exceeding_max_length_returns_422(self, client):
        payload = {
            "name": "Jane",
            "company": "A" * 201,
            "email": "jane@acme.com",
        }
        response = client.post(
            "/api/demo",
            data=json.dumps(payload),
            content_type="application/json",
        )
        assert response.status_code == 422

    def test_empty_body_returns_422(self, client):
        response = client.post(
            "/api/demo",
            data=json.dumps({}),
            content_type="application/json",
        )
        assert response.status_code == 422
        data = json.loads(response.data)
        assert data["success"] is False
        assert len(data["errors"]) > 0

    def test_whitespace_only_name_returns_422(self, client):
        payload = {"name": "   ", "company": "Acme", "email": "jane@acme.com"}
        response = client.post(
            "/api/demo",
            data=json.dumps(payload),
            content_type="application/json",
        )
        assert response.status_code == 422


class TestListDemos:
    """Tests for GET /api/demo — listing submitted requests."""

    def test_list_returns_200(self, client):
        response = client.get("/api/demo")
        assert response.status_code == 200

    def test_list_returns_success_true(self, client):
        response = client.get("/api/demo")
        data = json.loads(response.data)
        assert data["success"] is True

    def test_list_data_is_a_list(self, client):
        response = client.get("/api/demo")
        data = json.loads(response.data)
        assert isinstance(data["data"], list)

    def test_submitted_record_appears_in_list(self, client):
        payload = {
            "name": "List Test User",
            "company": "List Corp",
            "email": "listtest@example.com",
        }
        client.post(
            "/api/demo",
            data=json.dumps(payload),
            content_type="application/json",
        )
        response = client.get("/api/demo")
        data = json.loads(response.data)
        emails = [r["email"] for r in data["data"]]
        assert "listtest@example.com" in emails
