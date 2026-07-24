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
Library          Browser
Library          String
Library          Collections
Library          cumulusci.robotframework.CumulusCI
Library          ${CURDIR}/DocsCapture.py


*** Variables ***
# Everything Lightning shows while content is still loading: spinners plus the grey
# skeleton "stencil" placeholders (the bars you see in a screenshot taken too early).
${LOADING_ARTIFACTS}    css=.slds-spinner, lightning-spinner, .stencil, .forceStencil, [class*="stencil" i], [class*="skeleton" i]
# How long Wait For Lightning Ready will keep waiting for those to clear.
${READY_TIMEOUT}    45s
# Final settle after the page reports ready — lets images/fonts/late XHRs paint.
# Override per run with: -o vars SETTLE:3s
${SETTLE}        2s


*** Keywords ***
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
    [Documentation]    Fails while any spinner or stencil skeleton is still visible.
    ${count}=        Get Element Count    ${LOADING_ARTIFACTS} >> visible=true
    Should Be Equal As Integers    ${count}    0    Still loading: ${count} spinner/stencil element(s) visible

Wait For Lightning Ready
    [Documentation]    Strict readiness gate, in three stages: (1) CumulusCI's own
    ...                Lightning loading wait, (2) poll until zero visible spinners AND
    ...                zero visible stencil skeletons, (3) a short settle so late paints
    ...                (images, fonts, list rows) land. Screenshots must only be taken
    ...                after this keyword.
    Run Keyword And Ignore Error    Wait Until Loading Is Complete
    Wait Until Keyword Succeeds    ${READY_TIMEOUT}    1s    Page Has No Loading Artifacts
    Sleep            ${SETTLE}

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
        ${clicked}=    Run Keyword And Return Status    Click    button[title="App Launcher"]
        IF    not ${clicked}
            Click    .slds-icon-waffle
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
    Wait Until Keyword Succeeds    15s    1s    Page Has No Loading Artifacts
    Sleep            1.5s

Click App Launcher Result
    [Documentation]    Click a result (app tile or item link) inside the open App Launcher by its visible name.
    [Arguments]      ${name}
    ${scoped}=       Run Keyword And Return Status    Click    one-app-launcher-menu a:has-text("${name}") >> nth=0
    IF    not ${scoped}
        Click        a:has-text("${name}") >> nth=0
    END
    Wait For Lightning Ready

Open Tab From Navigation Bar
    [Documentation]    Click a tab by its visible label in the current app's navigation bar,
    ...                falling back to the "More" overflow menu when the tab isn't directly visible.
    [Arguments]      ${tab_label}
    ${direct}=       Run Keyword And Return Status    Click    one-app-nav-bar-item-container a:has-text("${tab_label}") >> visible=true >> nth=0
    IF    not ${direct}
        Click        one-app-nav-bar button:has-text("More")
        Click        .slds-dropdown a:has-text("${tab_label}") >> nth=0
    END
    Wait For Lightning Ready

Click New Action
    [Documentation]    Click the "New" action on the current list view and wait for the form (modal or full page).
    ${ok}=           Run Keyword And Return Status    Click    button:has-text("New") >> visible=true >> nth=0
    IF    not ${ok}
        Click        a[title="New"] >> nth=0
    END
    Run Keyword And Ignore Error    Wait Until Modal Is Open
    Wait For Lightning Ready

Fill Form Field
    [Documentation]    Fill an input by field API name (input[name=...]), falling back to the visible label.
    [Arguments]      ${field}    ${value}
    ${by_name}=      Run Keyword And Return Status    Fill Text    input[name="${field}"] >> visible=true    ${value}
    IF    not ${by_name}
        Fill Text    lightning-input:has-text("${field}") input >> visible=true >> nth=0    ${value}
    END

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
        Click        button:has-text("${action}[arg]") >> visible=true >> nth=0
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
