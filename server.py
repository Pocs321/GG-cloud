import http.server
import socketserver
import os
import markdown
from pathlib import Path

PORT = 5000
HOST = "0.0.0.0"

DOCS_DIR = Path("mlsa-k8s")

HTML_TEMPLATE = """<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>MLSA-K8S - Kubernetes Security Capstone</title>
    <style>
        * {{ box-sizing: border-box; margin: 0; padding: 0; }}
        body {{ font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: #0f172a; color: #e2e8f0; min-height: 100vh; }}
        .sidebar {{ width: 260px; background: #1e293b; height: 100vh; position: fixed; top: 0; left: 0; overflow-y: auto; padding: 24px 0; border-right: 1px solid #334155; }}
        .sidebar h2 {{ color: #38bdf8; font-size: 0.75rem; font-weight: 700; letter-spacing: 0.1em; text-transform: uppercase; padding: 0 20px 12px; border-bottom: 1px solid #334155; margin-bottom: 12px; }}
        .sidebar a {{ display: block; padding: 8px 20px; color: #94a3b8; text-decoration: none; font-size: 0.9rem; transition: all 0.15s; border-left: 3px solid transparent; }}
        .sidebar a:hover, .sidebar a.active {{ color: #38bdf8; background: #0f172a; border-left-color: #38bdf8; }}
        .sidebar .logo {{ padding: 0 20px 20px; margin-bottom: 8px; }}
        .sidebar .logo h1 {{ color: #f1f5f9; font-size: 1.1rem; font-weight: 700; }}
        .sidebar .logo p {{ color: #64748b; font-size: 0.75rem; margin-top: 4px; }}
        .main {{ margin-left: 260px; padding: 40px; max-width: 900px; }}
        .content {{ background: #1e293b; border-radius: 12px; padding: 40px; border: 1px solid #334155; }}
        .content h1 {{ color: #f1f5f9; font-size: 1.8rem; margin-bottom: 24px; padding-bottom: 16px; border-bottom: 1px solid #334155; }}
        .content h2 {{ color: #38bdf8; font-size: 1.3rem; margin: 28px 0 12px; }}
        .content h3 {{ color: #7dd3fc; font-size: 1.1rem; margin: 20px 0 10px; }}
        .content p {{ color: #cbd5e1; line-height: 1.7; margin-bottom: 14px; }}
        .content a {{ color: #38bdf8; }}
        .content pre {{ background: #0f172a; border: 1px solid #334155; border-radius: 8px; padding: 16px; overflow-x: auto; margin: 14px 0; }}
        .content code {{ font-family: 'JetBrains Mono', 'Fira Code', monospace; font-size: 0.85rem; color: #86efac; }}
        .content p code, .content li code {{ background: #0f172a; padding: 2px 6px; border-radius: 4px; color: #86efac; font-size: 0.85em; }}
        .content ul, .content ol {{ color: #cbd5e1; line-height: 1.7; margin: 10px 0 14px 24px; }}
        .content li {{ margin-bottom: 4px; }}
        .content table {{ width: 100%; border-collapse: collapse; margin: 14px 0; }}
        .content th {{ background: #0f172a; color: #38bdf8; padding: 10px 14px; text-align: left; font-size: 0.85rem; border: 1px solid #334155; }}
        .content td {{ padding: 8px 14px; border: 1px solid #334155; color: #cbd5e1; font-size: 0.9rem; }}
        .content tr:nth-child(even) td {{ background: #0f172a22; }}
        .content blockquote {{ border-left: 3px solid #38bdf8; padding: 12px 16px; background: #0f172a; margin: 14px 0; border-radius: 0 8px 8px 0; }}
        .badge {{ display: inline-block; padding: 4px 10px; border-radius: 20px; font-size: 0.75rem; font-weight: 600; margin: 3px; }}
        .badge-blue {{ background: #1e40af; color: #93c5fd; }}
        .hero {{ background: linear-gradient(135deg, #1e3a5f 0%, #0f2744 100%); border-radius: 12px; padding: 40px; margin-bottom: 28px; border: 1px solid #1d4ed8; }}
        .hero h1 {{ color: #f0f9ff; font-size: 2rem; margin-bottom: 12px; }}
        .hero p {{ color: #bae6fd; line-height: 1.7; }}
        .layers {{ display: grid; grid-template-columns: 1fr 1fr; gap: 16px; margin: 20px 0; }}
        .layer-card {{ background: #0f172a; border: 1px solid #334155; border-radius: 8px; padding: 16px; }}
        .layer-card h4 {{ color: #38bdf8; font-size: 0.9rem; margin-bottom: 8px; }}
        .layer-card p {{ color: #94a3b8; font-size: 0.85rem; line-height: 1.6; }}
        @media (max-width: 768px) {{ .sidebar {{ display: none; }} .main {{ margin-left: 0; padding: 20px; }} .layers {{ grid-template-columns: 1fr; }} }}
    </style>
</head>
<body>
    <nav class="sidebar">
        <div class="logo">
            <h1>MLSA-K8S</h1>
            <p>Kubernetes Security Capstone</p>
        </div>
        <h2>Navigation</h2>
        <a href="/" class="{home_active}">Overview</a>
        <a href="/architecture" class="{arch_active}">Architecture</a>
        <a href="/deployment" class="{deploy_active}">Deployment Guide</a>
        <a href="/threat-model" class="{threat_active}">Threat Model</a>
        <a href="/checklist" class="{check_active}">Deployment Checklist</a>
    </nav>
    <main class="main">
        {content}
    </main>
</body>
</html>"""

HOME_CONTENT = """
<div class="hero">
    <h1>MLSA-K8S Security Platform</h1>
    <p>A 7-layer defense-in-depth security architecture on Google Kubernetes Engine (GKE), 
    designed to protect cloud-native applications from known Kubernetes threats.</p>
    <p style="margin-top:12px; color:#7dd3fc;">CMU-CS 451 Capstone &mdash; Team C2NE.03 &mdash; Duy Tan University</p>
</div>

<div class="content">
    <h1>Project Overview</h1>
    <p>The MLSA-K8S project implements a comprehensive, layered Kubernetes security model on GCP. 
    Each layer addresses a specific threat surface, from infrastructure-level hardening up through 
    observability and runtime monitoring.</p>

    <h2>Security Layers</h2>
    <div class="layers">
        <div class="layer-card">
            <h4>L1 &mdash; Infrastructure Security</h4>
            <p>CIS Benchmark compliance, Shielded GKE nodes, Node hardening, Secure Boot + Integrity Monitoring</p>
        </div>
        <div class="layer-card">
            <h4>L2 &mdash; Control Plane Security</h4>
            <p>RBAC, OPA/Gatekeeper admission policies, Kubernetes audit logging, Webhook access control</p>
        </div>
        <div class="layer-card">
            <h4>L3 &mdash; Identity & Secrets</h4>
            <p>Workload Identity, cert-manager, Istio mTLS (STRICT mode), Secret encryption at rest</p>
        </div>
        <div class="layer-card">
            <h4>L4 &mdash; Network Segmentation</h4>
            <p>NetworkPolicy default deny-all, Namespace isolation, Calico, Service-to-service mTLS</p>
        </div>
        <div class="layer-card">
            <h4>L5 &mdash; Supply Chain Security</h4>
            <p>Binary Authorization, Trivy vulnerability scanning, Cosign image signing, GCR registry</p>
        </div>
        <div class="layer-card">
            <h4>L6 &mdash; Workload Protection</h4>
            <p>Pod Security Admission (restricted), seccomp profiles, AppArmor, Falco runtime monitoring</p>
        </div>
        <div class="layer-card">
            <h4>L7 &mdash; Observability</h4>
            <p>NGINX Ingress + TLS, Prometheus metrics, Grafana dashboards, Loki log aggregation</p>
        </div>
        <div class="layer-card">
            <h4>GKE Cluster</h4>
            <p>Regional cluster in asia-southeast1 (Singapore), Kubernetes 1.29+, auto-upgrade enabled</p>
        </div>
    </div>

    <h2>Tech Stack</h2>
    <p>
        <span class="badge badge-blue">GKE (Google Kubernetes Engine)</span>
        <span class="badge badge-blue">Terraform</span>
        <span class="badge badge-blue">Istio</span>
        <span class="badge badge-blue">OPA Gatekeeper</span>
        <span class="badge badge-blue">Falco</span>
        <span class="badge badge-blue">cert-manager</span>
        <span class="badge badge-blue">Prometheus</span>
        <span class="badge badge-blue">Grafana</span>
        <span class="badge badge-blue">Loki</span>
        <span class="badge badge-blue">Calico</span>
        <span class="badge badge-blue">Trivy</span>
        <span class="badge badge-blue">NGINX Ingress</span>
    </p>

    <h2>Quick Links</h2>
    <ul>
        <li><a href="/architecture">Architecture Overview</a> &mdash; Cluster design and data flow diagrams</li>
        <li><a href="/deployment">Deployment Guide</a> &mdash; Step-by-step setup instructions</li>
        <li><a href="/threat-model">Threat Model</a> &mdash; Attack scenarios and mitigations</li>
        <li><a href="/checklist">Deployment Checklist</a> &mdash; Pre/post deployment verification</li>
    </ul>
</div>
"""


def render_markdown(md_text: str) -> str:
    extensions = ['tables', 'fenced_code', 'toc', 'nl2br']
    try:
        return markdown.markdown(md_text, extensions=extensions)
    except Exception:
        return markdown.markdown(md_text)


def read_doc(filename: str) -> str:
    path = DOCS_DIR / "docs" / filename
    if path.exists():
        return path.read_text()
    checklist_path = DOCS_DIR / "DEPLOYMENT_CHECKLIST.md"
    if checklist_path.exists() and filename == "DEPLOYMENT_CHECKLIST.md":
        return checklist_path.read_text()
    return "# Not Found\n\nDocument not found."


def build_page(content: str, active: str = "home") -> str:
    return HTML_TEMPLATE.format(
        content=content,
        home_active="active" if active == "home" else "",
        arch_active="active" if active == "arch" else "",
        deploy_active="active" if active == "deploy" else "",
        threat_active="active" if active == "threat" else "",
        check_active="active" if active == "check" else "",
    )


class Handler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        path = self.path.rstrip("/") or "/"

        if path == "/":
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.end_headers()
            self.wfile.write(build_page(HOME_CONTENT, "home").encode())

        elif path == "/architecture":
            md = read_doc("architecture.md")
            html = f'<div class="content">{render_markdown(md)}</div>'
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.end_headers()
            self.wfile.write(build_page(html, "arch").encode())

        elif path == "/deployment":
            md = read_doc("deployment-guide.md")
            html = f'<div class="content">{render_markdown(md)}</div>'
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.end_headers()
            self.wfile.write(build_page(html, "deploy").encode())

        elif path == "/threat-model":
            md = read_doc("threat-model.md")
            html = f'<div class="content">{render_markdown(md)}</div>'
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.end_headers()
            self.wfile.write(build_page(html, "threat").encode())

        elif path == "/checklist":
            path_obj = DOCS_DIR / "DEPLOYMENT_CHECKLIST.md"
            md = path_obj.read_text() if path_obj.exists() else "# Not Found"
            html = f'<div class="content">{render_markdown(md)}</div>'
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.end_headers()
            self.wfile.write(build_page(html, "check").encode())

        else:
            self.send_response(404)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.end_headers()
            self.wfile.write(b"<h1>404 Not Found</h1>")

    def log_message(self, format, *args):
        print(f"[{self.address_string()}] {format % args}")


if __name__ == "__main__":
    with socketserver.TCPServer((HOST, PORT), Handler) as httpd:
        httpd.allow_reuse_address = True
        print(f"Server running at http://{HOST}:{PORT}")
        httpd.serve_forever()
