*** Settings ***
Documentation     Executes the capture suite's browser keywords against a local mock org, so
...               that keyword bugs surface here instead of in a GitHub Actions run against a
...               real Salesforce org.
...
...               This needs no org, no token and no network. Run it after ANY edit to
...               DocsProject.resource:
...
...               |  python -m robot --outputdir /tmp/selftest docs/capture/selftest/login_selftest.robot
...
...               Every test here corresponds to a failure that actually reached CI:
...                 - viewport passed to Playwright as strings          (2026-07-29)
...                 - multi-match selector under strict mode            (2026-07-29)
...                 - `Log` given two positional arguments + level=     (2026-07-30)
...
...               Not covered: anything that needs real Salesforce (selectors on live pages,
...               SOQL record lookup). Those still only fail in CI, which is why the run
...               report itemises them per screenshot.

Library           Browser
Library           Process
Resource          ${CURDIR}/../robot/DocsProject/resources/DocsProject.resource

Suite Setup       Start Mock Org
Suite Teardown    Stop Mock Org


*** Variables ***
${PORT}           8917
${BASE}           http://127.0.0.1:${PORT}


*** Test Cases ***
Viewport Is Passed To Playwright As Integers
    [Documentation]    CumulusCI's Open Test Browser splits "WIDTHxHEIGHT" and forwards the
    ...                halves as strings, which robotframework-browser 20.x rejects. Our own
    ...                &{VIEWPORT} must therefore hold real ints.
    ${w}=    Get From Dictionary    ${VIEWPORT}    width
    ${h}=    Get From Dictionary    ${VIEWPORT}    height
    Should Be True    isinstance($w, int) and isinstance($h, int)
    New Context       viewport=${VIEWPORT}
    Log To Console    \nviewport accepted: width=${w} height=${h}

Browser Variable Resolves To A Headless Engine In CI
    ${headless}=    Evaluate    "headlesschrome".startswith("headless")
    ${engine}=      Evaluate    "headlesschrome".replace("headless", "", 1) or "chromium"
    ${engine}=      Set Variable If    "${engine}" == "chrome"    chromium    ${engine}
    Should Be True    ${headless}
    Should Be Equal   ${engine}    chromium

Frontdoor Login Reaches Lightning
    [Documentation]    The real keyword, the real readiness gate, the real diagnostic.
    New Context    viewport=${VIEWPORT}
    Log In Through Frontdoor    ${BASE}/secur/frontdoor.jsp?sid=FAKE-NOT-A-REAL-TOKEN
    Wait For Lightning Ready
    Log Lightning Shell Presence
    ${title}=    Get Title
    Should Be Equal    ${title}    Home | Salesforce

Frontdoor Login Fails Clearly When The Session Is Rejected
    [Documentation]    The auth-failure redirect carries /lightning/page/home in its QUERY
    ...                STRING, so a substring test on the whole URL would accept the login
    ...                page. The check compares the URL path for exactly this reason.
    New Context    viewport=${VIEWPORT}
    ${status}    ${error}=    Run Keyword And Ignore Error
    ...    Log In Through Frontdoor    ${BASE}/badfrontdoor
    Should Be Equal    ${status}    FAIL
    Should Contain     ${error}    never reached a /lightning/ page
    Should Contain     ${error}    Login | Salesforce

Shell Diagnostic Survives A Zero Count
    [Documentation]    Regression test for 2026-07-30: on a Lightning page where no shell
    ...                selector matches, the diagnostic takes its WARN branch. That branch
    ...                previously called `Log` with two positional arguments AND level=WARN,
    ...                failing the whole suite setup with "got multiple values for argument".
    New Context    viewport=${VIEWPORT}
    New Page       ${BASE}/lightning/noshell
    ${n}=    Get Element Count    ${LIGHTNING_SHELL}
    Should Be Equal As Integers    ${n}    0
    Log Lightning Shell Presence

Shell Selector Counts Without Tripping Strict Mode
    [Documentation]    Regression test for 2026-07-29: ${LIGHTNING_SHELL} matches several
    ...                elements on a real Lightning page. Counting is safe; WAITING on it is
    ...                not, because Playwright runs strict and rejects a multi-match.
    New Context    viewport=${VIEWPORT}
    New Page       ${BASE}/lightning/page/home
    ${n}=    Get Element Count    ${LIGHTNING_SHELL}
    Should Be True    ${n} > 1
    ${status}    ${error}=    Run Keyword And Ignore Error
    ...    Wait For Elements State    ${LIGHTNING_SHELL}    visible    2s
    Should Be Equal    ${status}    FAIL
    Should Contain     ${error}    strict mode violation
    Log To Console    counted ${n} shell elements; strict wait correctly refuses them

Loading Artifact Probe Reports A Visible Spinner
    [Documentation]    `Page Has No Loading Artifacts` is the POLLED CONDITION, so it must
    ...                still fail while a spinner is up. What must not fail is the gate that
    ...                polls it — see the next test.
    New Context    viewport=${VIEWPORT}
    New Page       ${BASE}/spinner
    ${status}    ${error}=    Run Keyword And Ignore Error    Page Has No Loading Artifacts
    Should Be Equal    ${status}    FAIL
    Should Contain     ${error}    Still loading

Readiness Gate Captures Anyway When A Spinner Never Clears
    [Documentation]    Regression test for 2026-07-30: 21 screenshots produced NO IMAGE because
    ...                the gate treated a permanently visible spinner as fatal, after waiting
    ...                the full 45s each time (~16 minutes of the run). Readiness is best
    ...                effort now: the page is captured and the shortfall is logged.
    ...
    ...                ARTIFACT_TIMEOUT is shortened here only to keep the self-test quick —
    ...                the branch under test is the timeout path itself.
    Set Test Variable    ${ARTIFACT_TIMEOUT}    3s
    New Context    viewport=${VIEWPORT}
    New Page       ${BASE}/spinner
    Wait For Lightning Ready
    ${still_spinning}=    Get Element Count    ${LOADING_ARTIFACTS} >> visible=true
    Should Be True    ${still_spinning} > 0    the mock page should still be showing a spinner
    Take Screenshot    filename=${OUTPUT DIR}/captured-despite-spinner    fullPage=${False}
    Log To Console    \ncaptured an image with ${still_spinning} spinner(s) still on screen

Readiness Gate Ignores A Hidden Spinner
    [Documentation]    Salesforce leaves display:none spinners in the DOM. Gating on their
    ...                presence rather than visibility would stall every capture.
    New Context    viewport=${VIEWPORT}
    New Page       ${BASE}/hiddenspinner
    ${in_dom}=     Get Element Count    ${LOADING_ARTIFACTS}
    ${visible}=    Get Element Count    ${LOADING_ARTIFACTS} >> visible=true
    Should Be True    ${in_dom} > 0
    Should Be Equal As Integers    ${visible}    0
    Page Has No Loading Artifacts


*** Keywords ***
Start Mock Org
    ${process}=    Start Process    python    ${CURDIR}/mock_salesforce.py    ${PORT}    alias=mock
    Wait Until Keyword Succeeds    15s    1s    Mock Org Is Serving
    New Browser    chromium    headless=${True}
    Set Browser Timeout    ${READY_TIMEOUT}

Mock Org Is Serving
    ${status}=    Evaluate
    ...    __import__('urllib.request').request.urlopen('${BASE}/lightning/page/home', timeout=2).status
    Should Be Equal As Integers    ${status}    200

Stop Mock Org
    Run Keyword And Ignore Error    Close Browser
    Run Keyword And Ignore Error    Terminate Process    mock    kill=${True}
