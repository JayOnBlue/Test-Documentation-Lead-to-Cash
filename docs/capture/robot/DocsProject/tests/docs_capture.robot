*** Settings ***
Documentation    Captures every documentation screenshot against a real Salesforce org using
...              CumulusCI's SalesforcePlaywright library.
...
...              This suite is 100% manifest-driven: it reads docs/screenshot-manifest.json
...              (generated from the ```screenshot blocks in docs/business/**/*.md) and needs
...              NO editing when new screenshots are added to the docs.
...                - Entries with an `actions:` list are replayed step by step (App Launcher,
...                  typing, clicking New, ...) so the image depicts the exact documented action.
...                - Entries with only a url_pattern are captured by direct navigation
...                  ({recordId} is resolved automatically via SOQL).
...
...              Run:  cci task run capture_docs --org <org>
...              Images are written to docs/images/ (the doc site picks them up on the next
...              site build).

Resource         cumulusci/robotframework/SalesforcePlaywright.robot
Resource         ${CURDIR}/../resources/DocsProject.resource

Suite Setup      Run Keywords    Open Test Browser    size=1680x1050    AND    Set Doc Base Url    AND    Set Force Flag
Suite Teardown   Close Browser


*** Variables ***
# Default: skip screenshots that already exist. Override per run with:
#   cci task run capture_docs --org ci -o vars FORCE:True
${FORCE}         False


*** Test Cases ***
Capture Interactive Screenshots
    [Documentation]    Every manifest entry that declares an `actions:` list, replayed from a
    ...                clean Home page so each capture is order-independent. A failing entry
    ...                is reported but never blocks the remaining ones.
    ${dir}=          Images Dir Path
    @{shots}=        Interactive Screenshots
    FOR    ${shot}    IN    @{shots}
        Run Keyword And Continue On Failure    Capture Interactive Screenshot    ${shot}    ${dir}
    END

Capture Navigable Screenshots
    [Documentation]    Every remaining manifest entry (url_pattern, no actions), captured by
    ...                direct navigation with {recordId} resolved via SOQL.
    ${dir}=          Images Dir Path
    @{shots}=        Navigable Screenshots
    FOR    ${shot}    IN    @{shots}
        Run Keyword And Continue On Failure    Capture Navigable Screenshot    ${shot}    ${dir}
    END
