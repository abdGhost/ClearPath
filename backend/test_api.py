from fastapi.testclient import TestClient

from main import app


client = TestClient(app)


def _q(device_id: str = "test_device_1", display_name: str = "Tester"):
    return {"device_id": device_id, "display_name": display_name}


def test_health():
    r = client.get("/health")
    assert r.status_code == 200
    assert r.json()["status"] == "ok"


def test_summary_and_modes():
    q = _q("test_device_summary")
    r0 = client.get("/habit/summary", params=q)
    assert r0.status_code == 200
    client.post("/habit/crave-session", params=q, json={"mode": "breath_60s", "helped": True})
    client.post("/habit/crave-session", params=q, json={"mode": "breath_60s", "helped": False})
    client.post("/habit/crave-session", params=q, json={"mode": "distraction_task", "helped": True})

    r1 = client.get("/habit/modes", params=q)
    assert r1.status_code == 200
    modes = r1.json()
    assert isinstance(modes, list)
    assert len(modes) >= 1


def test_weekly_activity():
    q = _q("test_device_weekly")
    # Monday timestamp + one resist event.
    client.post(
        "/habit/crave-session",
        params=q,
        json={"mode": "breath_60s", "helped": True, "at": "2026-04-13T08:00:00+00:00"},
    )
    client.post("/habit/resist", params=q)
    r = client.get("/habit/weekly-activity", params=q)
    assert r.status_code == 200
    data = r.json()
    assert "monday_first" in data
    assert isinstance(data["monday_first"], list)
    assert len(data["monday_first"]) == 7
    assert sum(data["monday_first"]) >= 1


def test_preferences_conflict():
    q = _q("test_device_conflict")
    s = client.get("/habit/state", params=q).json()
    current_version = s["version"]
    ok = client.post(
        "/habit/preferences",
        params={**q, "if_version": current_version},
        json={"daily_spend": 20.0, "daily_hours": 2.0},
    )
    assert ok.status_code == 200
    bad = client.post(
        "/habit/preferences",
        params={**q, "if_version": current_version},
        json={"daily_spend": 22.0, "daily_hours": 2.0},
    )
    assert bad.status_code == 409
