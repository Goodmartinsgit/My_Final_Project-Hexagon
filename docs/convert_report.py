import os
import subprocess
import sys

def main():
    md_path = r"c:\Users\DELL XPS\Desktop\Hexagon_Final_Project\docs\architecture_report.md"
    html_path = r"c:\Users\DELL XPS\Desktop\Hexagon_Final_Project\docs\architecture_report.html"
    pdf_path = r"c:\Users\DELL XPS\Desktop\Hexagon_Final_Project\docs\architecture_report.pdf"

    with open(md_path, "r", encoding="utf-8") as f:
        md_content = f.read()

    # Replace local file URL with relative path for local rendering
    md_content = md_content.replace(
        "file:///C:/Users/DELL%20XPS/.gemini/antigravity-ide/brain/5ebbdec1-a667-40f5-98c0-53f9559c1a88/architecture_diagram.png",
        "architecture_diagram.png"
    )

    try:
        import markdown
    except ImportError:
        subprocess.run([sys.executable, "-m", "pip", "install", "markdown"], check=True)
        import markdown

    html_body = markdown.markdown(md_content, extensions=["tables", "fenced_code"])

    css = """
    body {
        font-family: 'Segoe UI', Arial, sans-serif;
        line-height: 1.6;
        color: #1a1a1a;
        max-width: 900px;
        margin: 0 auto;
        padding: 40px;
    }
    h1, h2, h3, h4 {
        color: #0f2b48;
        margin-top: 1.4em;
        margin-bottom: 0.5em;
        page-break-after: avoid;
    }
    h1 {
        font-size: 2.2em;
        border-bottom: 3px solid #047aed;
        padding-bottom: 8px;
    }
    h2 {
        font-size: 1.5em;
        border-bottom: 1px solid #ccc;
        padding-bottom: 6px;
    }
    table {
        border-collapse: collapse;
        width: 100%;
        margin: 20px 0;
        page-break-inside: avoid;
    }
    th, td {
        border: 1px solid #d0d7de;
        padding: 10px 12px;
        text-align: left;
        font-size: 0.95em;
    }
    th {
        background-color: #047aed;
        color: #ffffff;
    }
    tr:nth-child(even) {
        background-color: #f6f8fa;
    }
    code {
        background-color: #afb8c133;
        padding: 2px 6px;
        border-radius: 4px;
        font-family: ui-monospace, SFMono-Regular, Consolas, monospace;
        font-size: 0.88em;
    }
    pre {
        background-color: #161b22;
        color: #e6edf3;
        padding: 16px;
        border-radius: 6px;
        overflow-x: auto;
        font-family: ui-monospace, SFMono-Regular, Consolas, monospace;
        page-break-inside: avoid;
    }
    pre code {
        background-color: transparent;
        color: inherit;
        padding: 0;
    }
    img {
        max-width: 100%;
        height: auto;
        display: block;
        margin: 25px auto;
        border-radius: 6px;
        box-shadow: 0 4px 12px rgba(0,0,0,0.15);
    }
    hr {
        border: none;
        border-top: 1px solid #d0d7de;
        margin: 30px 0;
    }
    .cover-header {
        text-align: center;
        padding: 20px 0 40px 0;
        border-bottom: 2px solid #047aed;
    }
    """

    full_html = f"""<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<title>PayBridge Architecture Report</title>
<style>{css}</style>
</head>
<body>
{html_body}
</body>
</html>"""

    with open(html_path, "w", encoding="utf-8") as f:
        f.write(full_html)

    print("Generated architecture_report.html successfully!")

    # Now attempt PDF generation via Microsoft Edge or Chrome Headless
    edge_paths = [
        r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
        r"C:\Program Files\Microsoft\Edge\Application\msedge.exe",
        r"C:\Program Files\Google\Chrome\Application\chrome.exe",
        r"C:\Program Files (x86)\Google\Chrome\Application\chrome.exe",
    ]

    browser_bin = None
    for bpath in edge_paths:
        if os.path.exists(bpath):
            browser_bin = bpath
            break

    if browser_bin:
        print(f"Using browser: {browser_bin}")
        cmd = [
            browser_bin,
            "--headless",
            "--disable-gpu",
            f"--print-to-pdf={pdf_path}",
            "--no-pdf-header-footer",
            html_path
        ]
        res = subprocess.run(cmd, capture_output=True, text=True)
        if os.path.exists(pdf_path) and os.path.getsize(pdf_path) > 0:
            print(f"Successfully generated PDF: {pdf_path} (Size: {os.path.getsize(pdf_path)} bytes)")
        else:
            print(f"Browser PDF generation error: {res.stderr}")
    else:
        print("No headless browser found for PDF conversion.")

if __name__ == "__main__":
    main()
