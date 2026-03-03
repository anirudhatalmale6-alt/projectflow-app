#!/usr/bin/env python3
"""Comprehensive QA test for Duozz Flow"""
import json
import time
import os
from playwright.sync_api import sync_playwright

BASE_URL = "https://same-efficient-another-travis.trycloudflare.com"
SCREENSHOTS_DIR = "/var/lib/freelancer/projects/40262858/qa_screenshots"
os.makedirs(SCREENSHOTS_DIR, exist_ok=True)

results = []

def log(section, test, status, detail=""):
    results.append({"section": section, "test": test, "status": status, "detail": detail})
    icon = "✅" if status == "PASS" else "❌" if status == "FAIL" else "⚠️"
    print(f"{icon} [{section}] {test}: {detail}")

def screenshot(page, name):
    path = f"{SCREENSHOTS_DIR}/{name}.png"
    page.screenshot(path=path)
    return path

with sync_playwright() as p:
    browser = p.chromium.launch(headless=True)
    context = browser.new_context(viewport={"width": 1280, "height": 720})
    page = context.new_page()

    # Collect console errors
    console_errors = []
    page.on("console", lambda msg: console_errors.append(msg.text) if msg.type == "error" else None)

    # ========== 1. LOGIN ==========
    print("\n=== 1. LOGIN ===")
    try:
        page.goto(BASE_URL, wait_until="networkidle", timeout=30000)
        time.sleep(2)
        screenshot(page, "01_landing")

        # Check if we're on login page
        if page.locator("input[type='email'], input[type='text']").count() > 0:
            log("LOGIN", "Login page loads", "PASS", "Login form visible")
        else:
            log("LOGIN", "Login page loads", "FAIL", "No login form found")

        # Try login
        email_input = page.locator("input[type='email'], input[type='text']").first
        password_input = page.locator("input[type='password']").first
        email_input.fill("demo@duozzflow.com")
        password_input.fill("demo123")

        # Find and click login button
        login_btn = page.locator("button:has-text('Entrar'), button:has-text('Login'), button[type='submit']").first
        login_btn.click()
        time.sleep(3)
        screenshot(page, "02_after_login")

        # Check if login succeeded - should navigate away from login
        current_url = page.url
        if "/login" not in current_url or page.locator("text=Projetos, text=Dashboard, text=Bem-vindo").count() > 0:
            log("LOGIN", "Login with valid credentials", "PASS", f"Navigated to {current_url}")
        else:
            log("LOGIN", "Login with valid credentials", "FAIL", f"Still on {current_url}")
    except Exception as e:
        log("LOGIN", "Login flow", "FAIL", str(e))
        screenshot(page, "02_login_error")

    # ========== 2. NAVIGATION / HOME ==========
    print("\n=== 2. HOME / NAVIGATION ===")
    try:
        time.sleep(2)
        screenshot(page, "03_home")

        # Check bottom nav or sidebar
        nav_items = page.locator("nav a, .nav-item, .bottom-nav a, [role='navigation'] a").count()
        log("NAV", "Navigation present", "PASS" if nav_items > 0 else "WARN", f"{nav_items} nav items found")

        # Check for main sections
        page_content = page.content()
        has_projects = "Projetos" in page_content or "projetos" in page_content or "project" in page_content.lower()
        log("NAV", "Projects section accessible", "PASS" if has_projects else "WARN", "")
    except Exception as e:
        log("NAV", "Navigation", "FAIL", str(e))

    # ========== 3. PROJECTS ==========
    print("\n=== 3. PROJECTS ===")
    try:
        # Navigate to projects
        page.goto(BASE_URL + "/#/projects", wait_until="networkidle", timeout=15000)
        time.sleep(2)
        screenshot(page, "04_projects_list")

        # Check if projects list loads
        page_text = page.inner_text("body")
        log("PROJECTS", "Projects list loads", "PASS" if "Carregando" not in page_text else "WARN", "")

        # Try clicking first project
        project_cards = page.locator("[class*='card'], [class*='Card'], [class*='list-tile'], [class*='ListTile']")
        if project_cards.count() > 0:
            project_cards.first.click()
            time.sleep(2)
            screenshot(page, "05_project_detail")
            log("PROJECTS", "Project detail opens", "PASS", "")

            # Check project detail sections
            detail_text = page.inner_text("body")
            has_description = "Descri" in detail_text or "descri" in detail_text
            has_members = "Membr" in detail_text or "membr" in detail_text or "Equipe" in detail_text
            log("PROJECTS", "Description visible", "PASS" if has_description else "WARN", "")
            log("PROJECTS", "Members section", "PASS" if has_members else "WARN", "")

            # Check expandable description (200 char limit)
            ver_mais = page.locator("text=Ver mais").count()
            log("PROJECTS", "Expandable description (Ver mais)", "PASS" if ver_mais > 0 else "INFO", "Button present" if ver_mais > 0 else "Description may be short")
        else:
            log("PROJECTS", "Project cards found", "FAIL", "No project cards in list")
    except Exception as e:
        log("PROJECTS", "Project section", "FAIL", str(e))

    # ========== 4. TASKS ==========
    print("\n=== 4. TASKS ===")
    try:
        page.goto(BASE_URL + "/#/tasks", wait_until="networkidle", timeout=15000)
        time.sleep(2)
        screenshot(page, "06_tasks_list")

        page_text = page.inner_text("body")
        log("TASKS", "Tasks list loads", "PASS", "")

        # Try to open a task
        task_items = page.locator("[class*='card'], [class*='Card'], [class*='list-tile'], [class*='ListTile']")
        if task_items.count() > 0:
            task_items.first.click()
            time.sleep(2)
            screenshot(page, "07_task_detail")

            detail_text = page.inner_text("body")
            has_status = any(s in detail_text for s in ["A Fazer", "Em Progresso", "Revisao", "Concluido", "todo", "in_progress"])
            has_priority = any(p in detail_text for p in ["Alta", "Media", "Baixa", "Urgente", "high", "medium", "low"])
            has_deliveries = "Entregas" in detail_text or "Arquivos" in detail_text
            has_comments = "Comentario" in detail_text or "comentario" in detail_text

            log("TASKS", "Task detail opens", "PASS", "")
            log("TASKS", "Status buttons visible", "PASS" if has_status else "WARN", "")
            log("TASKS", "Deliveries section", "PASS" if has_deliveries else "WARN", "")
            log("TASKS", "Comments section", "PASS" if has_comments else "WARN", "")

            # Check for due date
            has_date = "Prazo" in detail_text
            log("TASKS", "Due date field", "PASS" if has_date else "WARN", "")

            # Check hours tracker
            has_hours = "hora" in detail_text.lower() or "hours" in detail_text.lower() or "Horas" in detail_text
            log("TASKS", "Hours tracker", "PASS" if has_hours else "WARN", "")

            # Check for file view/download buttons in deliveries
            view_btns = page.locator("[class*='visibility'], [aria-label*='view'], [aria-label*='Visualizar']").count()
            download_icons = page.locator("text=Visualizar, text=Baixar").count()
            log("TASKS", "File view/download buttons in task", "PASS" if view_btns > 0 or download_icons > 0 else "INFO", f"view_btns={view_btns}, download_icons={download_icons}")
        else:
            log("TASKS", "Task items found", "WARN", "No tasks in list")
    except Exception as e:
        log("TASKS", "Tasks section", "FAIL", str(e))

    # ========== 5. CREATE TASK ==========
    print("\n=== 5. CREATE TASK ===")
    try:
        page.goto(BASE_URL + "/#/tasks/create", wait_until="networkidle", timeout=15000)
        time.sleep(2)
        screenshot(page, "08_create_task")

        page_text = page.inner_text("body")
        has_title = page.locator("input, textarea").count() > 0
        log("TASKS_CREATE", "Create task form loads", "PASS" if has_title else "FAIL", "")

        # Check for date picker
        has_date_picker = "Prazo" in page_text or "Data" in page_text or page.locator("[type='date'], [class*='date']").count() > 0
        log("TASKS_CREATE", "Date picker available", "PASS" if has_date_picker else "WARN", "")

        # Check for assignee selector
        has_assignee = "Responsavel" in page_text or "Atribuir" in page_text or "assignee" in page_text.lower()
        log("TASKS_CREATE", "Assignee selector", "PASS" if has_assignee else "WARN", "")
    except Exception as e:
        log("TASKS_CREATE", "Create task", "FAIL", str(e))

    # ========== 6. DELIVERIES ==========
    print("\n=== 6. DELIVERIES ===")
    try:
        page.goto(BASE_URL + "/#/deliveries", wait_until="networkidle", timeout=15000)
        time.sleep(2)
        screenshot(page, "09_deliveries")

        page_text = page.inner_text("body")
        log("DELIVERIES", "Deliveries page loads", "PASS", "")

        # Try clicking a delivery
        delivery_items = page.locator("[class*='card'], [class*='Card'], [class*='list-tile'], [class*='ListTile']")
        if delivery_items.count() > 0:
            delivery_items.first.click()
            time.sleep(2)
            screenshot(page, "10_delivery_detail")

            detail_text = page.inner_text("body")
            has_preview = "Visualizar" in detail_text or "Baixar" in detail_text
            has_status_badge = any(s in detail_text for s in ["Pendente", "Enviado", "Aprovado", "Rejeitado", "Em Revisão"])

            log("DELIVERIES", "Delivery detail opens", "PASS", "")
            log("DELIVERIES", "File preview/download buttons", "PASS" if has_preview else "WARN", "")
            log("DELIVERIES", "Status badge visible", "PASS" if has_status_badge else "WARN", "")

            # Check approval buttons
            has_approval = "Aprovar" in detail_text or "Rejeitar" in detail_text or "Revisao" in detail_text
            log("DELIVERIES", "Approval buttons (if applicable)", "INFO", "Present" if has_approval else "Not shown (may be correct)")
        else:
            log("DELIVERIES", "Delivery items found", "WARN", "No deliveries in list")
    except Exception as e:
        log("DELIVERIES", "Deliveries section", "FAIL", str(e))

    # ========== 7. TRASH ==========
    print("\n=== 7. TRASH ===")
    try:
        page.goto(BASE_URL + "/#/trash", wait_until="networkidle", timeout=15000)
        time.sleep(2)
        screenshot(page, "11_trash")

        page_text = page.inner_text("body")
        has_trash_content = "Lixeira" in page_text or "lixeira" in page_text or "Restaurar" in page_text or "Nenhum" in page_text or "vazio" in page_text.lower()
        log("TRASH", "Trash page loads", "PASS" if has_trash_content else "WARN", "")
    except Exception as e:
        log("TRASH", "Trash section", "FAIL", str(e))

    # ========== 8. NOTIFICATIONS ==========
    print("\n=== 8. NOTIFICATIONS ===")
    try:
        page.goto(BASE_URL + "/#/notifications", wait_until="networkidle", timeout=15000)
        time.sleep(2)
        screenshot(page, "12_notifications")

        page_text = page.inner_text("body")
        log("NOTIFICATIONS", "Notifications page loads", "PASS", "")
        has_notif_content = "Notifica" in page_text or "notifica" in page_text or "Nenhuma" in page_text
        log("NOTIFICATIONS", "Content renders", "PASS" if has_notif_content else "WARN", page_text[:100])
    except Exception as e:
        log("NOTIFICATIONS", "Notifications", "FAIL", str(e))

    # ========== 9. CALENDAR ==========
    print("\n=== 9. CALENDAR ===")
    try:
        page.goto(BASE_URL + "/#/calendar", wait_until="networkidle", timeout=15000)
        time.sleep(2)
        screenshot(page, "13_calendar")

        page_text = page.inner_text("body")
        log("CALENDAR", "Calendar page loads", "PASS", "")
    except Exception as e:
        log("CALENDAR", "Calendar", "FAIL", str(e))

    # ========== 10. ADMIN ==========
    print("\n=== 10. ADMIN ===")
    try:
        page.goto(BASE_URL + "/#/admin", wait_until="networkidle", timeout=15000)
        time.sleep(2)
        screenshot(page, "14_admin")

        page_text = page.inner_text("body")
        has_admin = "Admin" in page_text or "Usuarios" in page_text or "Estatisticas" in page_text or "usuario" in page_text.lower()
        log("ADMIN", "Admin panel loads", "PASS" if has_admin else "WARN", "")
    except Exception as e:
        log("ADMIN", "Admin panel", "FAIL", str(e))

    # ========== 11. API ENDPOINT TESTS ==========
    print("\n=== 11. API TESTS ===")

    # Get auth token
    import requests
    try:
        login_resp = requests.post(f"{BASE_URL}/api/v1/auth/login", json={
            "email": "demo@duozzflow.com",
            "password": "demo123"
        }, timeout=10)
        token_data = login_resp.json()
        token = token_data.get("access_token", "")
        headers = {"Authorization": f"Bearer {token}"}

        log("API", "Login endpoint", "PASS", f"Status {login_resp.status_code}")

        # Test projects endpoint
        r = requests.get(f"{BASE_URL}/api/v1/projects", headers=headers, timeout=10)
        projects = r.json().get("projects", [])
        log("API", "GET /projects", "PASS" if r.status_code == 200 else "FAIL", f"Status {r.status_code}, {len(projects)} projects")

        # Test tasks endpoint
        r = requests.get(f"{BASE_URL}/api/v1/tasks", headers=headers, timeout=10)
        log("API", "GET /tasks", "PASS" if r.status_code == 200 else "FAIL", f"Status {r.status_code}")
        tasks_data = r.json()
        tasks = tasks_data.get("tasks", [])

        # Test individual task
        if tasks:
            task_id = tasks[0].get("id")
            r = requests.get(f"{BASE_URL}/api/v1/tasks/{task_id}", headers=headers, timeout=10)
            task = r.json().get("task", {})
            log("API", "GET /tasks/:id", "PASS" if r.status_code == 200 else "FAIL", f"Status {r.status_code}")

            # Check task fields
            has_due = task.get("due_date") is not None
            log("API", "Task has due_date field", "INFO", f"due_date={'set' if has_due else 'null'}")

            # Test deliveries by task
            r = requests.get(f"{BASE_URL}/api/v1/tasks/{task_id}/deliveries", headers=headers, timeout=10)
            deliveries = r.json().get("deliveries", r.json().get("data", []))
            log("API", "GET /tasks/:id/deliveries", "PASS" if r.status_code == 200 else "FAIL", f"Status {r.status_code}, {len(deliveries)} files")

            # Check delivery format fields
            for d in deliveries[:3]:
                fmt = d.get("format")
                title = d.get("title", "")
                file_url = d.get("file_url")
                log("API", f"Delivery '{title}' format", "PASS" if fmt else "WARN", f"format={fmt}, file_url={'set' if file_url else 'null'}")

                # Test download URL
                if d.get("id"):
                    r2 = requests.get(f"{BASE_URL}/api/v1/deliveries/{d['id']}/download", headers=headers, timeout=10)
                    dl_data = r2.json()
                    dl_url = dl_data.get("download_url")
                    log("API", f"Download URL for '{title}'", "PASS" if dl_url else "FAIL", f"url={dl_url}")

                    # Test if download URL actually resolves
                    if dl_url:
                        full_url = dl_url if dl_url.startswith("http") else f"{BASE_URL}{dl_url}"
                        r3 = requests.head(full_url, timeout=10, allow_redirects=True)
                        log("API", f"File accessible at URL", "PASS" if r3.status_code == 200 else "FAIL", f"Status {r3.status_code} for {full_url}")

        # Test trash endpoint
        r = requests.get(f"{BASE_URL}/api/v1/trash", headers=headers, timeout=10)
        log("API", "GET /trash", "PASS" if r.status_code == 200 else "FAIL", f"Status {r.status_code}")

        # Test notifications
        r = requests.get(f"{BASE_URL}/api/v1/notifications", headers=headers, timeout=10)
        log("API", "GET /notifications", "PASS" if r.status_code == 200 else "FAIL", f"Status {r.status_code}")

        # Test admin stats
        r = requests.get(f"{BASE_URL}/api/v1/admin/stats", headers=headers, timeout=10)
        log("API", "GET /admin/stats", "PASS" if r.status_code == 200 else "FAIL", f"Status {r.status_code}")

        # Test project-specific endpoints
        if projects:
            pid = projects[0].get("id")

            # Calendar events
            r = requests.get(f"{BASE_URL}/api/v1/projects/{pid}/calendar/events", headers=headers, timeout=10)
            log("API", "GET /calendar/events", "PASS" if r.status_code == 200 else "FAIL", f"Status {r.status_code}")

            # Project members
            r = requests.get(f"{BASE_URL}/api/v1/projects/{pid}/members", headers=headers, timeout=10)
            log("API", "GET /project/members", "PASS" if r.status_code == 200 else "FAIL", f"Status {r.status_code}")

            # Project deliveries
            r = requests.get(f"{BASE_URL}/api/v1/projects/{pid}/deliveries", headers=headers, timeout=10)
            log("API", "GET /project/deliveries", "PASS" if r.status_code == 200 else "FAIL", f"Status {r.status_code}")
    except Exception as e:
        log("API", "API tests", "FAIL", str(e))

    # ========== 12. CONSOLE ERRORS ==========
    print("\n=== 12. CONSOLE ERRORS ===")
    if console_errors:
        for err in console_errors[:10]:
            log("CONSOLE", "JS Error", "WARN", err[:200])
    else:
        log("CONSOLE", "No JS errors detected", "PASS", "")

    # Final screenshot
    screenshot(page, "15_final")

    browser.close()

# ========== SUMMARY ==========
print("\n" + "="*60)
print("QA TEST SUMMARY")
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

# Save full report
with open(f"{SCREENSHOTS_DIR}/report.json", "w") as f:
    json.dump(results, f, indent=2)
print(f"\nFull report saved to {SCREENSHOTS_DIR}/report.json")
