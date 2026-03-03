#!/usr/bin/env python3
"""Deep API test for Duozz Flow"""
import requests
import json
import os
import time

BASE_URL = "https://same-efficient-another-travis.trycloudflare.com"
results = []

def log(section, test, status, detail=""):
    results.append({"section": section, "test": test, "status": status, "detail": detail})
    icon = "✅" if status == "PASS" else "❌" if status == "FAIL" else "⚠️"
    print(f"{icon} [{section}] {test}: {detail}")

# ===== AUTH =====
print("=== AUTH ===")
r = requests.post(f"{BASE_URL}/api/v1/auth/login", json={"email":"demo@duozzflow.com","password":"demo123"}, timeout=10)
token = r.json().get("access_token","")
user = r.json().get("user",{})
headers = {"Authorization": f"Bearer {token}"}
log("AUTH", "Login", "PASS" if r.status_code == 200 else "FAIL", f"user={user.get('name','?')}, role={user.get('role','?')}")

# Test wrong password
r2 = requests.post(f"{BASE_URL}/api/v1/auth/login", json={"email":"demo@duozzflow.com","password":"wrongpass"}, timeout=10)
log("AUTH", "Wrong password rejected", "PASS" if r2.status_code in [400,401] else "FAIL", f"Status {r2.status_code}")

# Test /me
r3 = requests.get(f"{BASE_URL}/api/v1/auth/me", headers=headers, timeout=10)
log("AUTH", "GET /me", "PASS" if r3.status_code == 200 else "FAIL", f"Status {r3.status_code}")

# Test /me without token
r4 = requests.get(f"{BASE_URL}/api/v1/auth/me", timeout=10)
log("AUTH", "GET /me without token rejected", "PASS" if r4.status_code == 401 else "FAIL", f"Status {r4.status_code}")

# ===== PROJECTS =====
print("\n=== PROJECTS ===")
r = requests.get(f"{BASE_URL}/api/v1/projects", headers=headers, timeout=10)
projects = r.json().get("projects", [])
log("PROJECTS", "List projects", "PASS" if r.status_code == 200 else "FAIL", f"{len(projects)} projects")

if projects:
    pid = projects[0]["id"]
    pname = projects[0].get("name","?")

    # Get project detail
    r = requests.get(f"{BASE_URL}/api/v1/projects/{pid}", headers=headers, timeout=10)
    proj = r.json().get("project", {})
    log("PROJECTS", f"Get project '{pname}'", "PASS" if r.status_code == 200 else "FAIL", f"Status {r.status_code}")

    # Check project fields
    for field in ["id","name","description","status","deadline","created_by","created_at"]:
        has = field in proj
        log("PROJECTS", f"Field '{field}'", "PASS" if has else "WARN", f"{'present' if has else 'missing'}, value={str(proj.get(field,''))[:50]}")

    # Project members
    r = requests.get(f"{BASE_URL}/api/v1/projects/{pid}/members", headers=headers, timeout=10)
    if r.status_code == 200:
        members = r.json().get("members", [])
        log("PROJECTS", "Get members", "PASS", f"{len(members)} members")
    else:
        log("PROJECTS", "Get members", "FAIL", f"Status {r.status_code}: {r.text[:100]}")

    # Project tasks
    r = requests.get(f"{BASE_URL}/api/v1/projects/{pid}/tasks", headers=headers, timeout=10)
    if r.status_code == 200:
        tasks = r.json().get("tasks", [])
        log("PROJECTS", "Get project tasks", "PASS", f"{len(tasks)} tasks")
    else:
        log("PROJECTS", "Get project tasks", "FAIL", f"Status {r.status_code}: {r.text[:100]}")

    # Project deliveries
    r = requests.get(f"{BASE_URL}/api/v1/projects/{pid}/deliveries", headers=headers, timeout=10)
    log("PROJECTS", "Get project deliveries", "PASS" if r.status_code == 200 else "FAIL", f"Status {r.status_code}")

    # Create project test
    r = requests.post(f"{BASE_URL}/api/v1/projects", headers=headers, json={
        "name": "QA Test Project",
        "description": "Projeto criado pelo teste QA automatico",
        "deadline": "2026-04-01"
    }, timeout=10)
    if r.status_code == 201:
        test_project_id = r.json().get("project",{}).get("id")
        log("PROJECTS", "Create project", "PASS", f"id={test_project_id}")

        # Update project
        r = requests.put(f"{BASE_URL}/api/v1/projects/{test_project_id}", headers=headers, json={
            "name": "QA Test Project Updated",
            "description": "Descricao atualizada pelo teste"
        }, timeout=10)
        log("PROJECTS", "Update project", "PASS" if r.status_code == 200 else "FAIL", f"Status {r.status_code}")

        # Soft delete project
        r = requests.delete(f"{BASE_URL}/api/v1/projects/{test_project_id}", headers=headers, timeout=10)
        log("PROJECTS", "Soft delete project", "PASS" if r.status_code == 200 else "FAIL", f"Status {r.status_code}")
    else:
        log("PROJECTS", "Create project", "FAIL", f"Status {r.status_code}: {r.text[:200]}")

# ===== TASKS =====
print("\n=== TASKS ===")

# Check if there's a general tasks list endpoint
r = requests.get(f"{BASE_URL}/api/v1/tasks", headers=headers, timeout=10)
log("TASKS", "GET /tasks (global list)", "PASS" if r.status_code == 200 else "FAIL", f"Status {r.status_code}: {r.text[:100]}")

if projects:
    pid = projects[0]["id"]
    r = requests.get(f"{BASE_URL}/api/v1/projects/{pid}/tasks", headers=headers, timeout=10)
    tasks = r.json().get("tasks", [])
    log("TASKS", f"Tasks in project '{projects[0].get('name','?')}'", "PASS", f"{len(tasks)} tasks")

    if tasks:
        tid = tasks[0]["id"]
        tname = tasks[0].get("title","?")

        # Get task detail
        r = requests.get(f"{BASE_URL}/api/v1/tasks/{tid}", headers=headers, timeout=10)
        task = r.json().get("task", {})
        log("TASKS", f"Get task '{tname}'", "PASS" if r.status_code == 200 else "FAIL", f"Status {r.status_code}")

        # Check task fields
        for field in ["id","title","description","status","priority","due_date","assignee_id","reporter_id","estimated_hours","actual_hours","tags","created_at"]:
            val = task.get(field)
            log("TASKS", f"Field '{field}'", "PASS" if val is not None else "INFO", f"value={str(val)[:50]}")

        # Task deliveries
        r = requests.get(f"{BASE_URL}/api/v1/tasks/{tid}/deliveries", headers=headers, timeout=10)
        if r.status_code == 200:
            task_deliveries = r.json().get("deliveries", r.json().get("data",[]))
            log("TASKS", f"Task deliveries", "PASS", f"{len(task_deliveries)} files")

            for d in task_deliveries:
                did = d.get("id")
                dtitle = d.get("title","?")
                dfmt = d.get("format")
                durl = d.get("file_url")
                dreq = d.get("requires_approval")
                log("TASKS", f"  File '{dtitle}'", "INFO", f"format={dfmt}, has_file={'Y' if durl else 'N'}, requires_approval={dreq}")

                # Test download URL
                r2 = requests.get(f"{BASE_URL}/api/v1/deliveries/{did}/download", headers=headers, timeout=10)
                dl = r2.json().get("download_url")
                if dl:
                    full_dl = dl if dl.startswith("http") else f"{BASE_URL}{dl}"
                    r3 = requests.head(full_dl, timeout=10, allow_redirects=True)
                    log("TASKS", f"  Download '{dtitle}'", "PASS" if r3.status_code == 200 else "FAIL", f"url={full_dl}, status={r3.status_code}")
                else:
                    log("TASKS", f"  Download '{dtitle}'", "FAIL" if durl else "INFO", f"no download_url, file_url={durl}")
        else:
            log("TASKS", "Task deliveries", "FAIL", f"Status {r.status_code}")

        # Status change
        r = requests.put(f"{BASE_URL}/api/v1/tasks/{tid}/status", headers=headers, json={"status": task.get("status","todo")}, timeout=10)
        log("TASKS", "Update task status", "PASS" if r.status_code == 200 else "FAIL", f"Status {r.status_code}")

        # Hours update
        r = requests.put(f"{BASE_URL}/api/v1/tasks/{tid}/hours", headers=headers, json={"actual_hours": task.get("actual_hours",0)}, timeout=10)
        log("TASKS", "Update task hours", "PASS" if r.status_code == 200 else "FAIL", f"Status {r.status_code}")

    # Create task test
    r = requests.post(f"{BASE_URL}/api/v1/projects/{pid}/tasks", headers=headers, json={
        "title": "QA Test Task",
        "description": "Tarefa criada pelo teste QA",
        "priority": "medium",
        "dueDate": "2026-04-01T00:00:00.000Z",
        "estimatedHours": 5
    }, timeout=10)
    if r.status_code == 201:
        test_task = r.json().get("task",{})
        test_task_id = test_task.get("id")
        log("TASKS", "Create task", "PASS", f"id={test_task_id}")

        # Verify dueDate was saved
        r = requests.get(f"{BASE_URL}/api/v1/tasks/{test_task_id}", headers=headers, timeout=10)
        saved_task = r.json().get("task",{})
        due = saved_task.get("due_date")
        log("TASKS", "Due date saved correctly", "PASS" if due else "FAIL", f"due_date={due}")

        # Delete test task
        r = requests.delete(f"{BASE_URL}/api/v1/tasks/{test_task_id}", headers=headers, timeout=10)
        log("TASKS", "Delete test task", "PASS" if r.status_code == 200 else "FAIL", f"Status {r.status_code}")
    else:
        log("TASKS", "Create task", "FAIL", f"Status {r.status_code}: {r.text[:200]}")

# ===== DELIVERIES =====
print("\n=== DELIVERIES ===")
if projects:
    pid = projects[0]["id"]
    r = requests.get(f"{BASE_URL}/api/v1/projects/{pid}/deliveries", headers=headers, timeout=10)
    deliveries = r.json().get("deliveries",[])
    log("DELIVERIES", "List project deliveries", "PASS", f"{len(deliveries)} deliveries")

    # Get all deliveries across all tasks
    all_deliveries = []
    for proj in projects[:3]:
        r = requests.get(f"{BASE_URL}/api/v1/projects/{proj['id']}/tasks", headers=headers, timeout=10)
        ptasks = r.json().get("tasks",[])
        for t in ptasks:
            r = requests.get(f"{BASE_URL}/api/v1/tasks/{t['id']}/deliveries", headers=headers, timeout=10)
            td = r.json().get("deliveries", r.json().get("data",[]))
            all_deliveries.extend(td)

    log("DELIVERIES", "Total deliveries across tasks", "INFO", f"{len(all_deliveries)} files")

    for d in all_deliveries[:5]:
        did = d.get("id")
        dtitle = d.get("title","?")
        # Test individual delivery detail
        r = requests.get(f"{BASE_URL}/api/v1/deliveries/{did}", headers=headers, timeout=10)
        log("DELIVERIES", f"Detail '{dtitle}'", "PASS" if r.status_code == 200 else "FAIL", f"Status {r.status_code}")

        # Check approval buttons logic
        status = d.get("status")
        req_approval = d.get("requires_approval")
        log("DELIVERIES", f"  Status/approval", "INFO", f"status={status}, requires_approval={req_approval}")

# ===== TRASH =====
print("\n=== TRASH ===")
r = requests.get(f"{BASE_URL}/api/v1/trash", headers=headers, timeout=10)
if r.status_code == 200:
    trash_data = r.json()
    trash_items = trash_data.get("items", trash_data.get("deliveries", []))
    log("TRASH", "Get trash", "PASS", f"{len(trash_items)} items")

    # Check for mixed types
    types_found = set()
    for item in trash_items:
        t = item.get("_type", "delivery")
        types_found.add(t)
    log("TRASH", "Item types in trash", "INFO", f"types={types_found}")
else:
    log("TRASH", "Get trash", "FAIL", f"Status {r.status_code}: {r.text[:100]}")

# ===== NOTIFICATIONS =====
print("\n=== NOTIFICATIONS ===")
r = requests.get(f"{BASE_URL}/api/v1/notifications", headers=headers, timeout=10)
if r.status_code == 200:
    notifs = r.json().get("notifications",[])
    log("NOTIFICATIONS", "Get notifications", "PASS", f"{len(notifs)} notifications")
    if notifs:
        n = notifs[0]
        log("NOTIFICATIONS", "Sample notification", "INFO", f"type={n.get('type')}, title={n.get('title','?')[:40]}, read={n.get('read')}")
else:
    log("NOTIFICATIONS", "Get notifications", "FAIL", f"Status {r.status_code}")

# Test mark as read
r = requests.put(f"{BASE_URL}/api/v1/notifications/read-all", headers=headers, timeout=10)
log("NOTIFICATIONS", "Mark all read", "PASS" if r.status_code == 200 else "FAIL", f"Status {r.status_code}")

# ===== CALENDAR =====
print("\n=== CALENDAR ===")
if projects:
    pid = projects[0]["id"]
    r = requests.get(f"{BASE_URL}/api/v1/projects/{pid}/calendar/events", headers=headers, timeout=10)
    if r.status_code == 200:
        events = r.json().get("events",[])
        log("CALENDAR", "Get events", "PASS", f"{len(events)} events")
    else:
        log("CALENDAR", "Get events", "FAIL", f"Status {r.status_code}")

    # Create event test
    r = requests.post(f"{BASE_URL}/api/v1/projects/{pid}/calendar/events", headers=headers, json={
        "title": "QA Test Event",
        "start_date": "2026-04-01T10:00:00.000Z",
        "end_date": "2026-04-01T11:00:00.000Z"
    }, timeout=10)
    if r.status_code == 201:
        event_id = r.json().get("event",{}).get("id")
        log("CALENDAR", "Create event", "PASS", f"id={event_id}")
        # Delete test event
        r = requests.delete(f"{BASE_URL}/api/v1/calendar/events/{event_id}", headers=headers, timeout=10)
        log("CALENDAR", "Delete event", "PASS" if r.status_code == 200 else "FAIL", f"Status {r.status_code}")
    else:
        log("CALENDAR", "Create event", "FAIL", f"Status {r.status_code}: {r.text[:200]}")

# ===== COMMENTS =====
print("\n=== COMMENTS ===")
if projects:
    pid = projects[0]["id"]
    r = requests.get(f"{BASE_URL}/api/v1/projects/{pid}/tasks", headers=headers, timeout=10)
    tasks = r.json().get("tasks",[])
    if tasks:
        tid = tasks[0]["id"]
        # Get task comments
        r = requests.get(f"{BASE_URL}/api/v1/tasks/{tid}/comments", headers=headers, timeout=10)
        log("COMMENTS", "Get task comments", "PASS" if r.status_code == 200 else "FAIL", f"Status {r.status_code}")

        # Create comment
        r = requests.post(f"{BASE_URL}/api/v1/tasks/{tid}/comments", headers=headers, json={
            "content": "QA test comment - can be deleted"
        }, timeout=10)
        if r.status_code == 201:
            cid = r.json().get("comment",{}).get("id")
            log("COMMENTS", "Create comment", "PASS", f"id={cid}")
            # Delete comment
            r = requests.delete(f"{BASE_URL}/api/v1/comments/{cid}", headers=headers, timeout=10)
            log("COMMENTS", "Delete comment", "PASS" if r.status_code == 200 else "FAIL", f"Status {r.status_code}")
        else:
            log("COMMENTS", "Create comment", "FAIL", f"Status {r.status_code}: {r.text[:200]}")

# ===== ADMIN =====
print("\n=== ADMIN ===")
r = requests.get(f"{BASE_URL}/api/v1/admin/stats", headers=headers, timeout=10)
if r.status_code == 200:
    stats = r.json()
    log("ADMIN", "Get stats", "PASS", f"data keys: {list(stats.keys())[:5]}")
else:
    log("ADMIN", "Get stats", "FAIL", f"Status {r.status_code}")

r = requests.get(f"{BASE_URL}/api/v1/admin/users", headers=headers, timeout=10)
if r.status_code == 200:
    users = r.json().get("users",[])
    log("ADMIN", "List users", "PASS", f"{len(users)} users")
    for u in users[:5]:
        log("ADMIN", f"  User '{u.get('name','?')}'", "INFO", f"role={u.get('role')}, email={u.get('email','?')}")
else:
    log("ADMIN", "List users", "FAIL", f"Status {r.status_code}")

r = requests.get(f"{BASE_URL}/api/v1/admin/audit-log", headers=headers, timeout=10)
log("ADMIN", "Audit log", "PASS" if r.status_code == 200 else "FAIL", f"Status {r.status_code}")

# ===== CLIENTS =====
print("\n=== CLIENTS ===")
r = requests.get(f"{BASE_URL}/api/v1/clients", headers=headers, timeout=10)
if r.status_code == 200:
    clients = r.json().get("clients",[])
    log("CLIENTS", "List clients", "PASS", f"{len(clients)} clients")
else:
    log("CLIENTS", "List clients", "FAIL", f"Status {r.status_code}")

# ===== CHECK ROUTES =====
print("\n=== ROUTE CHECKS ===")
# Test various potential endpoints for 404s
test_routes = [
    ("GET", "/api/v1/tasks", "Global tasks list"),
    ("GET", "/api/v1/deliveries", "Global deliveries list"),
    ("GET", "/api/v1/clients", "Clients list"),
    ("GET", "/api/v1/notifications", "Notifications"),
    ("GET", "/api/v1/trash", "Trash"),
    ("GET", "/api/v1/admin/stats", "Admin stats"),
    ("GET", "/api/v1/admin/users", "Admin users"),
    ("GET", "/api/v1/admin/audit-log", "Audit log"),
]
for method, route, label in test_routes:
    r = requests.request(method, f"{BASE_URL}{route}", headers=headers, timeout=10)
    log("ROUTES", f"{method} {route} ({label})", "PASS" if r.status_code in [200,201] else "FAIL", f"Status {r.status_code}")

# ===== FILE UPLOAD TEST =====
print("\n=== FILE UPLOAD ===")
if projects and tasks:
    pid = projects[0]["id"]
    r = requests.get(f"{BASE_URL}/api/v1/projects/{pid}/tasks", headers=headers, timeout=10)
    tasks = r.json().get("tasks",[])
    if tasks:
        tid = tasks[0]["id"]
        # Upload a test file
        test_content = b"QA Test file content - PDF simulation"
        files = {"file": ("test_qa_file.pdf", test_content, "application/pdf")}
        data = {"title": "test_qa_file.pdf", "requires_approval": "false"}
        r = requests.post(f"{BASE_URL}/api/v1/tasks/{tid}/deliveries", headers=headers, files=files, data=data, timeout=15)
        if r.status_code == 201:
            new_delivery = r.json().get("delivery",{})
            new_did = new_delivery.get("id")
            new_fmt = new_delivery.get("format")
            log("UPLOAD", "Upload file to task", "PASS", f"id={new_did}, format={new_fmt}")
            log("UPLOAD", "Format auto-detected", "PASS" if new_fmt == "pdf" else "FAIL", f"Expected 'pdf', got '{new_fmt}'")

            # Test download
            r2 = requests.get(f"{BASE_URL}/api/v1/deliveries/{new_did}/download", headers=headers, timeout=10)
            dl_url = r2.json().get("download_url")
            if dl_url:
                full_url = dl_url if dl_url.startswith("http") else f"{BASE_URL}{dl_url}"
                r3 = requests.get(full_url, timeout=10)
                log("UPLOAD", "Download uploaded file", "PASS" if r3.status_code == 200 else "FAIL", f"Status {r3.status_code}, content_length={len(r3.content)}")
            else:
                log("UPLOAD", "Download URL", "FAIL", "No download_url returned")

            # Cleanup - delete test file
            r = requests.delete(f"{BASE_URL}/api/v1/deliveries/{new_did}", headers=headers, timeout=10)
            log("UPLOAD", "Delete test file", "PASS" if r.status_code == 200 else "WARN", f"Status {r.status_code}")
        else:
            log("UPLOAD", "Upload file", "FAIL", f"Status {r.status_code}: {r.text[:200]}")

# ===== SUMMARY =====
print("\n" + "="*60)
print("API TEST SUMMARY")
print("="*60)
passes = sum(1 for r in results if r["status"] == "PASS")
fails = sum(1 for r in results if r["status"] == "FAIL")
warns = sum(1 for r in results if r["status"] == "WARN")
infos = sum(1 for r in results if r["status"] == "INFO")
print(f"✅ PASS: {passes}")
print(f"❌ FAIL: {fails}")
print(f"⚠️  WARN: {warns}")
print(f"ℹ️  INFO: {infos}")
print()

if fails > 0:
    print("FAILURES:")
    for r in results:
        if r["status"] == "FAIL":
            print(f"  ❌ [{r['section']}] {r['test']}: {r['detail']}")

if warns > 0:
    print("\nWARNINGS:")
    for r in results:
        if r["status"] == "WARN":
            print(f"  ⚠️  [{r['section']}] {r['test']}: {r['detail']}")

with open("/var/lib/freelancer/projects/40262858/qa_screenshots/api_report.json", "w") as f:
    json.dump(results, f, indent=2)
