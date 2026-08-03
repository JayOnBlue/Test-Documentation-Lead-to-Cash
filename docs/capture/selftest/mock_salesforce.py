"""A stand-in for the parts of Salesforce that the capture suite's login path touches.

Why this exists: the suite's browser keywords can only be proven by RUNNING them, and
running them used to mean dispatching a GitHub Actions workflow against a real org. Three
consecutive CI runs were burned on keyword bugs that a local execution would have caught in
seconds (a viewport passed as strings, a multi-match selector under Playwright's strict
mode, and `Log` given two positional arguments). This server closes that loop.

Routes mirror real Salesforce behaviour:
  /secur/frontdoor.jsp   302 -> /lightning/page/home     (a session that authenticates)
  /badfrontdoor          302 -> /?ec=302&startURL=...    (a session that does NOT)
  /lightning/page/home   the Lightning app shell, several shell elements present
  /lightning/noshell     a Lightning URL with NO shell elements (zero-count branch)
  /spinner               shell + a VISIBLE spinner       (readiness must block)
  /hiddenspinner         shell + a display:none spinner  (readiness must ignore it)
  anything else          the login screen
"""
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer

PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 8917

# Deliberately more than one match for ${LIGHTNING_SHELL}: that is what a real Lightning
# page looks like, and it is what tripped Playwright's strict mode.
SHELL = (
    '<div class="slds-global-header">global header</div>'
    '<div class="oneHeader">one header</div>'
    '<one-appnav>nav</one-appnav>'
    '<div class="slds-template__container">content</div>'
)


# Sets the document title when clicked, so a test can prove the click landed.
BUTTON = '<button id="t" onclick="document.title=\'CLICKED\'">Edit</button>'

# A Lightning picklist: a combobox button plus a listbox item. `Fill Text` can never
# satisfy this shape, which is why Fill Form Field has a picklist strategy.
PICKLIST = (
    '<lightning-combobox><label>Rating</label><button>Select</button></lightning-combobox>'
    '<lightning-base-combobox-item onclick="document.title=\'PICKED\'">Hot'
    '</lightning-base-combobox-item>'
)


def page(title, body):
    return f"<!doctype html><html><head><title>{title}</title></head><body>{body}</body></html>"


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        path = self.path
        if path.startswith("/secur/frontdoor.jsp"):
            return self._redirect("/lightning/page/home")
        if path.startswith("/badfrontdoor"):
            return self._redirect("/?ec=302&startURL=/lightning/page/home")

        if path.startswith("/spinner"):
            body = page("Home | Salesforce", '<div class="slds-spinner">loading</div>' + SHELL)
        elif path.startswith("/hiddenspinner"):
            body = page("Home | Salesforce", '<div class="slds-spinner" style="display:none">x</div>' + SHELL)
        elif path.startswith("/belowfold"):
            # A button 3000px down: Playwright must scroll before it can click.
            body = page("Home | Salesforce", SHELL + '<div style="height:3000px"></div>' + BUTTON)
        elif path.startswith("/overlay"):
            # A button fully covered by a fixed overlay: a normal click is refused because
            # something else intercepts the pointer, and only force=True gets through.
            body = page("Home | Salesforce", SHELL + BUTTON
                        + '<div style="position:fixed;inset:0;background:rgba(0,0,0,.1)"></div>')
        elif path.startswith("/permanent-stencils"):
            # Five stencils that never go away — what nearly every real page in this org
            # looks like. The readiness gate must notice the count is static and move on.
            body = page("Home | Salesforce", SHELL + ('<div class="stencil">x</div>' * 5))
        elif path.startswith("/emptyform"):
            # A "New" modal with no matching field, to prove a missing field fails fast.
            body = page("Home | Salesforce", SHELL + '<div class="slds-modal"><input name="Other"></div>')
        elif path.startswith("/picklistform"):
            body = page("Home | Salesforce", SHELL + PICKLIST)
        elif path.startswith("/navbar-no-more"):
            # An app nav bar that has no "More" overflow menu and not the wanted tab.
            body = page("Home | Salesforce", SHELL
                        + '<one-app-nav-bar><one-app-nav-bar-item-container>'
                        + '<a href="#">Home</a></one-app-nav-bar-item-container></one-app-nav-bar>')
        elif path.startswith("/lightning/noshell"):
            body = page("Home | Salesforce", '<div id="unrecognised-theme">content</div>')
        elif path.startswith("/lightning/"):
            body = page("Home | Salesforce", SHELL)
        else:
            body = page("Login | Salesforce", '<form><input id="username"><input id="password" type="password"></form>')

        encoded = body.encode()
        self.send_response(200)
        self.send_header("Content-Type", "text/html")
        self.send_header("Content-Length", str(len(encoded)))
        self.end_headers()
        self.wfile.write(encoded)

    def _redirect(self, location):
        self.send_response(302)
        self.send_header("Location", location)
        self.send_header("Content-Length", "0")
        self.end_headers()

    def log_message(self, *args):
        pass  # keep the Robot console readable


if __name__ == "__main__":
    HTTPServer(("127.0.0.1", PORT), Handler).serve_forever()
