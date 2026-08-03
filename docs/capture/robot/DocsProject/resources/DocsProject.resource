*** Settings ***
Documentation    Reusable keywords for capturing documentation screenshots.
...              Built on CumulusCI's SalesforcePlaywright library so steps are real
...              Salesforce UI interactions (App Launcher, tab navigation, record creation),
...              not just URL changes.
...
...              The heart of this file is two things:
...                1. Wait For Lightning Ready — a strict readiness gate that waits out not
...                   just spinners but Lightning's grey "stencil" skeletons, so a screenshot
...                   is never taken of a half-rendered page.
...                2. Run Doc Action — a dispatcher that executes one declarative action from
...                   a ```screenshot block's `actions:` list (see docs/business/TEMPLATE.md),
...                   so every interactive capture is driven by the docs themselves instead of
...                   hand-written test cases.
# Browser and cumulusci.robotframework.CumulusCI are deliberately NOT imported here.
# The suite that uses this file imports cumulusci/robotframework/SalesforcePlaywright.robot,
# which already imports both — Browser with `jsextension=.../cci_init.js` and CumulusCI
# with `${ORG}`. Re-importing them bare produced two warnings on every run:
#   "Suite 'Docs Capture' has already imported library 'Browser' with different
#    arguments. This import is ignored."
# The imports were ignored anyway (the first one wins, and it is the correct one), so
# dropping them changes no behavior and removes the noise. Library keywords resolve at
# the suite level, so this file's keywords still see both libraries.
Library          String
Library          Collections
Library          DateTime
Library          ${CURDIR}/DocsCapture.py


*** Variables ***
# Everything Lightning shows while content is still loading: spinners plus the grey
# skeleton "stencil" placeholders (the bars you see in a screenshot taken too early).
${LOADING_ARTIFACTS}    css=.slds-spinner, lightning-spinner, .stencil, .forceStencil, [class*="stencil" i], [class*="skeleton" i]
# Browser-operation timeout: navigation, login, waiting for an element to appear.
${READY_TIMEOUT}    45s
# How long to wait for LOADING_ARTIFACTS to clear before capturing anyway. Deliberately
# much shorter than READY_TIMEOUT: some Salesforce pages never reach zero, so this is the
# price paid per stubborn page, not a correctness threshold. At 45s it cost the
# 2026-07-30 run about 16 minutes of pure waiting. Override with -o vars ARTIFACT_TIMEOUT:30s
${ARTIFACT_TIMEOUT}    12s
# Per-click budget. Well below READY_TIMEOUT so a missing button costs seconds, not the
# 45s Playwright spends retrying before it gives up (2 captures lost that way on 2026-07-31).
${CLICK_TIMEOUT}    10s
# How many identical readings mean "this page is done changing" (see
# Wait For Loading Artifacts To Settle), and how long between readings.
${ARTIFACT_STABLE_POLLS}    ${2}
${ARTIFACT_POLL}    1s
# Per-attempt budget when locating a form field. Each strategy used to call `Fill Text`
# directly, which waits the full 45s browser timeout: three fields that were not on the
# form cost the 2026-08-03 run over two minutes and produced no images.
${FIELD_TIMEOUT}    4s
# Final settle after the page reports ready — lets images/fonts/late XHRs paint.
# Override per run with: -o vars SETTLE:3s
${SETTLE}        2s

# Browser window/viewport for every capture. The ${...} wrapping matters: it makes
# these real Python integers rather than strings, which is precisely what broke
# CumulusCI's own Open Test Browser (see Open Docs Browser below).
&{VIEWPORT}      width=${1680}    height=${1050}

# Proof that we are inside the authenticated Lightning app rather than on a login
# screen or a Classic page. Any one of these is enough — the app shell, the nav bar,
# or the standard page container that CumulusCI also looks for.
${LIGHTNING_SHELL}    css=div.slds-template__container, one-appnav, .oneHeader, .slds-global-header


*** Keywords ***
Open Docs Browser
    [Documentation]    Opens a logged-in browser for the capture suite.
    ...
    ...                This replaces CumulusCI's `Open Test Browser`, which cannot work
    ...                with robotframework-browser 20.x. SalesforcePlaywright.py does:
    ...
    ...                  width, height = size.split("x", 1)      # -> strings
    ...                  self.browser.new_context(viewport={"width": width, ...})
    ...
    ...                Playwright now validates that strictly, so the run died with
    ...                "browser.newContext: viewport.width: expected integer, got
    ...                string". It fails for ANY size, including CumulusCI's own
    ...                1280x1024 default, so dropping the size argument does not help —
    ...                the only fix is to build the context ourselves and pass real
    ...                integers (see &{VIEWPORT} above).
    ...
    ...                Everything else mirrors what Open Test Browser did: resolve the
    ...                org's auto-login URL from CumulusCI, honour the same ${BROWSER}
    ...                convention (a "headless" prefix means headless), and wait until
    ...                Salesforce has finished rendering before any capture runs.
    ${headless}=       Evaluate    "${BROWSER}".startswith("headless")
    ${type}=           Evaluate    "${BROWSER}".replace("headless", "", 1) or "chromium"
    # CumulusCI's convention calls it "chrome"; Playwright's engine is "chromium".
    ${type}=           Set Variable If    "${type}" == "chrome"    chromium    ${type}
    New Browser        ${type}    headless=${headless}
    New Context        viewport=${VIEWPORT}
    Set Browser Timeout    ${READY_TIMEOUT}
    Log In Through Frontdoor
    Wait For Lightning Ready
    Log Lightning Shell Presence

Log In Through Frontdoor
    [Arguments]        ${frontdoor}=${EMPTY}
    [Documentation]    Authenticates the browser and lands it on Lightning Home.
    ...
    ...                ${frontdoor} exists so this keyword can be exercised against a local
    ...                mock server in a test; leave it empty and the real URL is derived from
    ...                the CumulusCI org, which is what the capture suite does.
    ...
    ...                Why not CumulusCI's `Wait Until Salesforce Is Ready`: that keyword
    ...                navigates to frontdoor.jsp and then WAITS for Salesforce to
    ...                redirect to a URL matching `lightning_base_url + /lightning/`
    ...                (SalesforcePlaywright.py:164). Where frontdoor actually lands
    ...                depends on the user's default app and UI setting, so on this org it
    ...                never matched and the run died after 30s with "Timed out waiting
    ...                for a lightning page" — with no clue where it had landed.
    ...
    ...                Instead we ASK for the landing page: frontdoor accepts a retURL,
    ...                so authentication and destination happen in one deterministic
    ...                navigation. Readiness is then judged from the DOM (the Lightning
    ...                app shell) rather than from a URL pattern.
    # The frontdoor URL embeds the session id. Robot logs keyword arguments and
    # navigation targets, and log.html ships in the robot-results artifact, so keep
    # this one navigation out of the log entirely.
    ${log_level}=      Set Log Level    NONE
    IF    "${frontdoor}" == "${EMPTY}"
        ${info}=       Get Org Info
        ${frontdoor}=    Set Variable
        ...    ${info}[instance_url]/secur/frontdoor.jsp?sid=${info}[access_token]&retURL=%2Flightning%2Fpage%2Fhome
    END
    Run Keyword And Ignore Error    New Page    ${frontdoor}
    Set Log Level      ${log_level}

    # Confirm we are inside the Lightning app before anything is captured. Without this
    # an unauthenticated login page has no spinners either, so the readiness gate would
    # pass and every screenshot would be of the login screen.
    #
    # Judged from the URL PATH, not from a CSS selector. Salesforce serves /lightning/*
    # only to an authenticated session — anything else is redirected to a login page — so
    # the path is itself proof of login. The previous version waited for a
    # comma-separated "any one of these shell elements" selector, which resolves to
    # SEVERAL elements; Browser drives Playwright in strict mode and rejects a multi-match
    # selector outright, so it failed on a page that had logged in perfectly well
    # ("Home | Salesforce" at /lightning/page/home). Element counting below is immune to
    # that, because counting is not a strict operation.
    ${ok}=             Run Keyword And Return Status
    ...    Wait Until Keyword Succeeds    ${READY_TIMEOUT}    1s    Current Page Is Lightning
    IF    not ${ok}
        ${url}=        Get Url
        ${title}=      Get Title
        Take Screenshot    fullPage=True
        # Catenate into ONE string: `Fail` takes (msg, *tags), so continuation lines
        # passed straight to it would silently become test TAGS instead of message text.
        ${msg}=        Catenate    SEPARATOR=${SPACE}
        ...    Frontdoor login never reached a /lightning/ page. Landed on "${title}" at ${url}.
        ...    That is normally the login screen, meaning the pasted access token is not valid
        ...    for browser login (expired, or the org restricts session reuse) — mint a fresh one.
        ...    The screenshot above and log.html in the robot-results artifact show the page.
        Fail           ${msg}
    END
    Log Lightning Shell Presence

Current Page Is Lightning
    [Documentation]    Passes only once the browser has settled on a Lightning Experience
    ...                path. Compares the URL PATH rather than the whole URL on purpose: a
    ...                login redirect carries the intended destination in a query string
    ...                (`?ec=302&startURL=/lightning/page/home`), so a substring test
    ...                against the full URL would happily accept the login page itself.
    ${url}=            Get Url
    ${path}=           Evaluate    __import__('urllib.parse').parse.urlsplit($url).path
    Should Start With    ${path}    /lightning/    Not on a Lightning path yet (url=${url})

Log Lightning Shell Presence
    [Documentation]    Diagnostic only — never fails the run. Records how many Lightning
    ...                shell elements are present, so that if captures later fail on
    ...                selectors the log already says whether the app shell rendered at all.
    ...
    ...                Call this only AFTER `Wait For Lightning Ready`: taken any earlier it
    ...                counts a half-rendered page and warns about nothing.
    ${n}=              Get Element Count    ${LIGHTNING_SHELL}
    Log                Lightning shell elements matched: ${n} (${LIGHTNING_SHELL})
    IF    ${n} == 0
        # One positional argument, then one named. `Log` is (message, level=INFO, ...), so
        # two positionals would bind the second to `level` and collide with level=WARN —
        # "got multiple values for argument 'level'", which failed the 10:19 run.
        # Report what IS on the page rather than only what is missing. On 2026-07-30 this
        # warned on a page that captured 16 screenshots perfectly well, so the selector list
        # — not the page — is what needs updating; the element names below say to what.
        ${ok}    ${tags}=    Run Keyword And Ignore Error    Evaluate JavaScript    ${None}
        ...    () => [...new Set([...document.body.querySelectorAll('*')].map(e => e.tagName.toLowerCase()))].slice(0, 20).join(', ')
        ${present}=    Set Variable If    '${ok}' == 'PASS'    ${tags}    (could not be read)
        ${warning}=    Catenate    SEPARATOR=${SPACE}
        ...    Logged in to a Lightning URL, but none of the ${LIGHTNING_SHELL} selectors
        ...    matched. This is informational only — login is confirmed from the URL, and
        ...    captures proceed. Elements actually present: ${present}
        Log            ${warning}    level=WARN
    END
Set Doc Base Url
    [Documentation]    Remember the org's base URL (origin of the current page) for building record URLs.
    ${url}=          Get Url
    ${origin}=       Origin Of    ${url}
    Set Suite Variable    ${DOC_BASE}    ${origin}
    Log              Capture base URL: ${DOC_BASE}

Set Force Flag
    [Documentation]    Converts the ${FORCE} suite variable (always a string, e.g. from
    ...                "-o vars FORCE:True") into a real boolean ${FORCE_BOOL}.
    ${force_bool}=   Convert To Boolean    ${FORCE}
    Set Suite Variable    ${FORCE_BOOL}    ${force_bool}

# ---------------------------------------------------------------------------
# Readiness — the fix for screenshots of half-loaded pages
# ---------------------------------------------------------------------------

Page Has No Loading Artifacts
    [Documentation]    Fails while any spinner or stencil skeleton is still visible. Used as
    ...                the polled condition inside `Wait For Lightning Ready` — never call it
    ...                directly as an assertion, because a page is allowed to keep a spinner.
    ${count}=        Get Element Count    ${LOADING_ARTIFACTS} >> visible=true
    Should Be Equal As Integers    ${count}    0    Still loading: ${count} spinner/stencil element(s) visible

Wait For Lightning Ready
    [Documentation]    Waits for the page to settle, then lets the capture proceed either way.
    ...
    ...                Readiness is a BEST EFFORT, not a precondition. Real Salesforce pages
    ...                routinely keep a spinner or stencil on screen indefinitely — a chart
    ...                still fetching, a related list polling, a dashboard component that
    ...                never finishes — so "zero visible loading artifacts" is a state some
    ...                pages never reach. Treating it as a hard gate cost the 2026-07-30 run
    ...                21 captures and ~16 minutes: each one waited the full timeout and then
    ...                failed, producing no image at all.
    ...
    ...                A screenshot with a stray spinner is worth far more than no screenshot,
    ...                so a page that will not settle is captured anyway and the shortfall is
    ...                logged. The wait is also bounded by ${ARTIFACT_TIMEOUT} rather than the
    ...                45s browser timeout, to keep the cost of a stubborn page small.
    Run Keyword And Ignore Error    Wait Until Loading Is Complete
    ${remaining}=    Wait For Loading Artifacts To Settle
    IF    ${remaining} > 0
        ${note}=     Catenate    SEPARATOR=${SPACE}
        ...    Page still shows ${remaining} loading artifact(s) and the count has stopped
        ...    changing; capturing anyway. If the image looks half-rendered, raise
        ...    ${ARTIFACT_TIMEOUT} or narrow ${LOADING_ARTIFACTS} for this page.
        Log          ${note}    level=WARN
    END
    Sleep            ${SETTLE}

Wait For Loading Artifacts To Settle
    [Documentation]    Returns how many loading artifacts are still visible, waiting only for
    ...                as long as that number is still IMPROVING.
    ...
    ...                Waiting for zero and nothing else cost the 2026-08-03 run roughly six
    ...                minutes. Almost every page in this org keeps 5-7 stencil/spinner
    ...                elements on screen permanently, so the gate could never succeed and
    ...                each of ~30 captures paid the whole ${ARTIFACT_TIMEOUT} to learn
    ...                nothing. The distinction that matters: a page still loading has a count
    ...                that CHANGES, while a page as rendered as it will ever get has a count
    ...                that sits still.
    ...
    ...                So stop as soon as the count hits zero, or holds the same value for
    ...                ${ARTIFACT_STABLE_POLLS} consecutive polls. On a stubborn page that is
    ...                ~3s instead of 12s; on a genuinely loading page the count keeps moving
    ...                and the full budget is still available. Fidelity is unchanged — the
    ...                ${SETTLE} pause still follows either way.
    ${budget}=       Convert Time    ${ARTIFACT_TIMEOUT}    number
    ${polls}=        Evaluate    max(${ARTIFACT_STABLE_POLLS} + 1, int(${budget}))
    ${previous}=     Set Variable    ${-1}
    ${stable}=       Set Variable    ${0}
    ${count}=        Set Variable    ${0}
    FOR    ${poll}    IN RANGE    ${polls}
        ${count}=    Get Element Count    ${LOADING_ARTIFACTS} >> visible=true
        IF    ${count} == 0
            RETURN    ${0}
        END
        IF    ${count} == ${previous}
            ${stable}=    Evaluate    ${stable} + 1
        ELSE
            ${stable}=    Set Variable    ${0}
        END
        IF    ${stable} >= ${ARTIFACT_STABLE_POLLS}
            RETURN    ${count}
        END
        ${previous}=    Set Variable    ${count}
        Sleep           ${ARTIFACT_POLL}
    END
    RETURN           ${count}

# ---------------------------------------------------------------------------
# Record helpers
# ---------------------------------------------------------------------------

Record Id For Object
    [Documentation]    Return the Id of the most recent record for the object, via SOQL. Empty if none exist.
    [Arguments]      ${object}
    ${ok}    ${result}=    Run Keyword And Ignore Error    Soql Query    SELECT Id FROM ${object} ORDER BY CreatedDate DESC LIMIT 1
    Return From Keyword If    '${ok}' == 'FAIL'    ${EMPTY}
    ${records}=      Set Variable    ${result}[records]
    ${count}=        Get Length    ${records}
    Return From Keyword If    ${count} == 0    ${EMPTY}
    RETURN           ${records}[0][Id]

Resolve Capture Url
    [Documentation]    Turn a manifest url_pattern into a full URL, resolving {recordId} via SOQL.
    [Arguments]      ${pattern}
    ${needs_id}=     Run Keyword And Return Status    Should Contain    ${pattern}    {recordId}
    Return From Keyword If    not ${needs_id}    ${DOC_BASE}${pattern}
    ${object}=       Object Api Name    ${pattern}
    ${rid}=          Record Id For Object    ${object}
    Return From Keyword If    '${rid}' == '${EMPTY}'    ${EMPTY}
    ${resolved}=     Replace String    ${pattern}    {recordId}    ${rid}
    RETURN           ${DOC_BASE}${resolved}

# ---------------------------------------------------------------------------
# UI primitives used by the action dispatcher
# ---------------------------------------------------------------------------

Open The App Launcher
    [Documentation]    Open the App Launcher panel. Uses the library keyword if present, else clicks the waffle icon.
    ${ok}=           Run Keyword And Return Status    Open App Launcher
    IF    not ${ok}
        ${clicked}=    Run Keyword And Return Status    Click Doc Element    button[title="App Launcher"]
        IF    not ${clicked}
            Click Doc Element    .slds-icon-waffle
        END
    END
    Wait For Elements State    input[placeholder*="Search apps"]    visible    timeout=20s

Show App Launcher Search
    [Documentation]    Open the App Launcher (if not already open) and type a search term, then wait for results to render.
    [Arguments]      ${term}
    ${already_open}=    Run Keyword And Return Status    Wait For Elements State    input[placeholder*="Search apps"]    visible    timeout=1s
    IF    not ${already_open}
        Open The App Launcher
    END
    Fill Text        input[placeholder*="Search apps"]    ${term}
    # Was a strict `Wait Until Keyword Succeeds 15s ... Page Has No Loading Artifacts`, which
    # hard-failed 5 captures on 2026-07-31: the App Launcher panel keeps a spinner while its
    # results settle. Route through the soft gate like every other wait in this file, so no
    # readiness check can abort a capture on its own.
    Wait For Lightning Ready

Click Doc Element
    [Documentation]    A click that survives Salesforce's sticky headers and scroll panes.
    ...
    ...                Playwright refuses to click an element it judges "outside of the
    ...                viewport" and then retries until the browser timeout. On 2026-07-31 that
    ...                cost two captures 45 seconds each and produced no image, for buttons
    ...                that were present and visible the whole time — the log shows
    ...                "87 x waiting for element to be visible, enabled and stable ... element
    ...                is outside of the viewport".
    ...
    ...                Two attempts, weakest intervention first:
    ...                  1. scroll into view, then a normal click — the only tier that exercises
    ...                     real Salesforce pointer handling, so it must be tried first;
    ...                  2. a DOM-level el.click(), which always reaches the element's own
    ...                     handler. That is what a documentation screenshot needs: the app has
    ...                     to advance, not to receive a pixel-accurate mouse event.
    ...
    ...                Note there is deliberately NO force=True tier. `Click With Options
    ...                force=True` skips Playwright's actionability CHECK but still dispatches a
    ...                real pointer event at the element's centre, which a covering sticky
    ...                header swallows — so it reports success while achieving nothing. Verified
    ...                against the mock overlay page: the keyword passed and the button's
    ...                handler never ran, which makes its status worthless as a fallback signal.
    ...
    ...                `Click` in robotframework-browser 20.x takes only (selector, button).
    [Arguments]      ${selector}    ${timeout}=${CLICK_TIMEOUT}
    Wait For Elements State    ${selector}    visible    ${timeout}
    Run Keyword And Ignore Error    Scroll To Element    ${selector}
    ${clicked}=      Run Keyword And Return Status    Click    ${selector}
    IF    not ${clicked}
        Log          Normal click on ${selector} failed; dispatching el.click() instead.    level=WARN
        Evaluate JavaScript    ${selector}    (el) => el.click()
    END

Click App Launcher Result
    [Documentation]    Click a result (app tile or item link) inside the open App Launcher by its visible name.
    [Arguments]      ${name}
    ${scoped}=       Run Keyword And Return Status    Click Doc Element    one-app-launcher-menu a:has-text("${name}") >> nth=0
    IF    not ${scoped}
        Click Doc Element    a:has-text("${name}") >> nth=0
    END
    Wait For Lightning Ready

Open Tab From Navigation Bar
    [Documentation]    Click a tab by its visible label in the current app's navigation bar,
    ...                falling back to the "More" overflow menu when the tab isn't directly visible.
    [Arguments]      ${tab_label}
    ${direct}=       Run Keyword And Return Status
    ...    Click Doc Element    one-app-nav-bar-item-container a:has-text("${tab_label}") >> visible=true >> nth=0
    IF    not ${direct}
        # The overflow menu only exists when tabs are actually hidden. Clicking it blindly
        # cost a capture 45 seconds on 2026-07-31 waiting for a "More" button this app does
        # not have, so probe for it and report the real problem instead of timing out.
        ${overflow}=    Run Keyword And Return Status
        ...    Click Doc Element    one-app-nav-bar button:has-text("More")
        IF    not ${overflow}
            ${msg}=    Catenate    SEPARATOR=${SPACE}
            ...    Tab "${tab_label}" is not in the navigation bar and this app has no "More"
            ...    overflow menu. Either the tab is not in the app, or its label differs from
            ...    the docs. Check the `click_tab` action for this screenshot.
            Fail       ${msg}
        END
        Click Doc Element    .slds-dropdown a:has-text("${tab_label}") >> nth=0
    END
    Wait For Lightning Ready

Click New Action
    [Documentation]    Click the "New" action on the current list view and wait for the form (modal or full page).
    ${ok}=           Run Keyword And Return Status    Click Doc Element    button:has-text("New") >> visible=true >> nth=0
    IF    not ${ok}
        Click Doc Element    a[title="New"] >> nth=0
    END
    Run Keyword And Ignore Error    Wait Until Modal Is Open
    Wait For Lightning Ready

Fill Form Field
    [Documentation]    Fill a form field by API name, then by visible label, then as a picklist.
    ...
    ...                Every attempt is bounded by ${FIELD_TIMEOUT}. The previous version
    ...                called `Fill Text` directly, which waits the full 45s browser timeout
    ...                per attempt — on 2026-08-03 three fields that were not on the form
    ...                consumed over two minutes and produced no images. A field that is not
    ...                there should be reported in seconds, and the message should say what
    ...                to change rather than quoting a Playwright locator.
    [Arguments]      ${field}    ${value}
    @{selectors}=    Create List
    ...    input[name="${field}"] >> visible=true >> nth=0
    ...    textarea[name="${field}"] >> visible=true >> nth=0
    ...    lightning-input:has-text("${field}") input >> visible=true >> nth=0
    ...    lightning-textarea:has-text("${field}") textarea >> visible=true >> nth=0
    FOR    ${selector}    IN    @{selectors}
        ${filled}=    Run Keyword And Return Status    Fill Field If Present    ${selector}    ${value}
        IF    ${filled}    RETURN
    END
    # Not a text input at all? Lightning renders a picklist as a combobox button plus a
    # listbox, which `Fill Text` can never satisfy no matter how long it waits. Lead.Rating
    # is one of these, and it was among the 2026-08-03 failures.
    ${chosen}=       Run Keyword And Return Status    Choose Picklist Value    ${field}    ${value}
    IF    ${chosen}    RETURN
    ${msg}=          Catenate    SEPARATOR=${SPACE}
    ...    Could not find a field for "${field}" on this form — tried name="${field}", the
    ...    visible label, and a picklist. Either the form never opened, the field is not on
    ...    this layout/profile, or the docs give a label where the API name is needed. Fix the
    ...    `fill_field` action in the screenshot block that sets ${field}.
    Fail             ${msg}

Fill Field If Present
    [Documentation]    Wait a SHORT time for one candidate selector, then fill it. The wait is
    ...                what bounds the attempt; `Fill Text` on an already-visible element is
    ...                immediate.
    [Arguments]      ${selector}    ${value}
    Wait For Elements State    ${selector}    visible    ${FIELD_TIMEOUT}
    Fill Text        ${selector}    ${value}

Choose Picklist Value
    [Documentation]    Open a Lightning combobox by its label and pick an option by text.
    [Arguments]      ${field}    ${value}
    Click Doc Element    lightning-combobox:has-text("${field}") button >> visible=true >> nth=0
    ...    ${FIELD_TIMEOUT}
    Click Doc Element    lightning-base-combobox-item:has-text("${value}") >> visible=true >> nth=0
    ...    ${FIELD_TIMEOUT}

# ---------------------------------------------------------------------------
# The declarative-action dispatcher.
# One verb per entry in a ```screenshot block's `actions:` list — documented for
# authors in docs/business/TEMPLATE.md. Returns "ok", or "skip" when the action
# legitimately cannot run (e.g. open_record with no data in the org).
# ---------------------------------------------------------------------------

Run Doc Action
    [Arguments]      ${action}
    ${verb}=         Set Variable    ${action}[verb]
    IF    '${verb}' == 'goto'
        Go To        ${DOC_BASE}${action}[arg]
        Wait For Lightning Ready
    ELSE IF    '${verb}' == 'open_app_launcher'
        Open The App Launcher
    ELSE IF    '${verb}' == 'search_app_launcher'
        Show App Launcher Search    ${action}[arg]
    ELSE IF    '${verb}' == 'click_app_launcher_result'
        Click App Launcher Result    ${action}[arg]
    ELSE IF    '${verb}' == 'click_tab'
        Open Tab From Navigation Bar    ${action}[arg]
    ELSE IF    '${verb}' == 'click_new'
        Click New Action
    ELSE IF    '${verb}' == 'fill_field'
        Fill Form Field    ${action}[field]    ${action}[value]
    ELSE IF    '${verb}' == 'click_button'
        Click Doc Element    button:has-text("${action}[arg]") >> visible=true >> nth=0
        Wait For Lightning Ready
    ELSE IF    '${verb}' == 'open_record'
        ${rid}=      Record Id For Object    ${action}[arg]
        IF    '${rid}' == '${EMPTY}'
            RETURN    skip
        END
        Go To        ${DOC_BASE}/lightning/r/${action}[arg]/${rid}/view
        Wait For Lightning Ready
    ELSE IF    '${verb}' == 'press'
        Keyboard Key    press    ${action}[arg]
        Sleep        0.5s
    ELSE IF    '${verb}' == 'wait'
        Sleep        ${action}[arg]s
    ELSE
        Fail         Unknown screenshot action verb "${verb}" — see docs/business/TEMPLATE.md for the supported list.
    END
    RETURN           ok

# ---------------------------------------------------------------------------
# Capture entry points (used by the test suite)
# ---------------------------------------------------------------------------

Capture Navigable Screenshot
    [Documentation]    Navigate to one manifest entry's url_pattern and save docs/images/<id>.png,
    ...                unless it's already captured and ${FORCE_BOOL} is not set.
    [Arguments]      ${shot}    ${dir}
    ${id}=           Set Variable    ${shot}[id]
    IF    not ${FORCE_BOOL}
        ${exists}=    Screenshot Exists    ${id}
        IF    ${exists}
            Log      Skipping ${id} — already captured (pass -o vars FORCE:True to recapture)
            RETURN
        END
    END
    ${pattern}=      Set Variable    ${shot}[url_pattern]
    ${url}=          Resolve Capture Url    ${pattern}
    IF    '${url}' == '${EMPTY}'
        Log          Skipping ${id} — no sample record for its object    WARN
        RETURN
    END
    Go To            ${url}
    Wait For Lightning Ready
    Take Screenshot    filename=${dir}/${id}    fullPage=${False}
    Log              Captured ${id}

Capture Interactive Screenshot
    [Documentation]    Replay one manifest entry's declared `actions` from a clean Home page,
    ...                then save docs/images/<id>.png. Skips (with a WARN, leaving the site's
    ...                "Screenshot pending" placeholder) if an action reports there is nothing
    ...                to act on — e.g. open_record with no data in the org.
    [Arguments]      ${shot}    ${dir}
    ${id}=           Set Variable    ${shot}[id]
    IF    not ${FORCE_BOOL}
        ${exists}=    Screenshot Exists    ${id}
        IF    ${exists}
            Log      Skipping ${id} — already captured (pass -o vars FORCE:True to recapture)
            RETURN
        END
    END
    # Every interactive sequence starts from the same place, so captures are
    # order-independent and reproducible run to run.
    Go To            ${DOC_BASE}/lightning/page/home
    Wait For Lightning Ready
    @{actions}=      Normalized Actions    ${shot}
    FOR    ${action}    IN    @{actions}
        ${status}=    Run Doc Action    ${action}
        IF    '${status}' == 'skip'
            Log      Skipping ${id} — "${action}[verb]" had nothing to act on (no sample record in this org?)    WARN
            RETURN
        END
    END
    Take Screenshot    filename=${dir}/${id}    fullPage=${False}
    Log              Captured ${id}
