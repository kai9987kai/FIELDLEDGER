>>SOURCE FORMAT FREE
*> =====================================================================
*> FIELDLEDGER - HTML-REPORTER.cob
*> Generates a self-contained, offline HTML5 scientific report
*> (report.html) with zero external JS/CSS/CDN dependencies, strict
*> HTML escaping on all inputs, and pure inline SVG BACI visualization.
*> =====================================================================
IDENTIFICATION DIVISION.
PROGRAM-ID. HTML-REPORTER.

ENVIRONMENT DIVISION.
INPUT-OUTPUT SECTION.
FILE-CONTROL.
    SELECT F-HTML ASSIGN TO DYNAMIC WS-FILE-PATH
        ORGANIZATION IS LINE SEQUENTIAL
        FILE STATUS IS WS-FS.

DATA DIVISION.
FILE SECTION.
FD F-HTML.
01 F-HTML-REC               PIC X(2048).

WORKING-STORAGE SECTION.
COPY "LIMITS.cpy".
COPY "RUN-CONFIG.cpy".
COPY "STUDY-RECORD.cpy".
COPY "SOURCE-RECORD.cpy".
COPY "SITE-RECORD.cpy".
COPY "SURVEY-RECORD.cpy".
COPY "OBSERVATION-RECORD.cpy".
COPY "ERROR-RECORD.cpy".
COPY "BACI-RESULT.cpy".
COPY "UTILS-IFACE.cpy".

01 WS-FILE-PATH             PIC X(512).
01 WS-FS                    PIC XX.
01 WS-WRITE-OK              PIC X(1).
01 WS-LINE                  PIC X(2048).
01 WS-I                     PIC 9(9) COMP-5.
01 WS-H1                    PIC X(1024).
01 WS-H2                    PIC X(1024).
01 WS-H3                    PIC X(1024).
01 WS-H4                    PIC X(1024).
01 WS-N1                    PIC X(32).
01 WS-N2                    PIC X(32).
01 WS-N3                    PIC X(32).
01 WS-N4                    PIC X(32).
01 WS-N5                    PIC X(32).
01 WS-N6                    PIC X(32).
01 WS-N7                    PIC X(32).
01 WS-CI-TXT                PIC X(96).
01 WS-WARN-FOUND            PIC X(1).

*> SVG chart geometry variables
01 WS-PLOT-CNT              PIC 9(4) COMP-5.
01 WS-SVG-H                 PIC 9(6) COMP-5.
01 WS-MAX-ABS               PIC S9(11)V9(6) COMP-3.
01 WS-ABS-V                 PIC S9(11)V9(6) COMP-3.
01 WS-Y-POS                 PIC 9(6) COMP-5.
01 WS-BAR-W                 PIC 9(6) COMP-5.
01 WS-BAR-X                 PIC 9(6) COMP-5.
01 WS-ZERO-X                PIC 9(6) COMP-5 VALUE 400.
01 WS-HALF-SPAN             PIC 9(6) COMP-5 VALUE 240.
01 WS-BAR-COLOR             PIC X(16).
01 WS-S-Y                   PIC X(16).
01 WS-S-X                   PIC X(16).
01 WS-S-W                   PIC X(16).
01 WS-S-H                   PIC X(16).
01 WS-S-TY                  PIC X(16).
01 WS-S-LX                  PIC X(16).

LINKAGE SECTION.
01 L-HTML-RC                PIC S9(4) COMP-5.

PROCEDURE DIVISION USING L-HTML-RC.
MAIN-HTML.
    MOVE FL-EXIT-OK TO L-HTML-RC
    MOVE "Y" TO WS-WRITE-OK

    INITIALIZE CFG-REQ
    MOVE "ENSURE-DIR" TO CREQ-OP
    MOVE CFG-OUT-PATH TO CREQ-PATH-A
    CALL "CONFIGURATION" USING CFG-REQ

    INITIALIZE CFG-REQ
    MOVE "JOIN-PATH"   TO CREQ-OP
    MOVE CFG-OUT-PATH  TO CREQ-PATH-A
    MOVE "report.html" TO CREQ-PATH-B
    CALL "CONFIGURATION" USING CFG-REQ
    MOVE CREQ-PATH-OUT TO WS-FILE-PATH

    OPEN OUTPUT F-HTML
    IF WS-FS NOT = "00"
        PERFORM MARK-FAIL
        MOVE FL-EXIT-IO-ERR TO L-HTML-RC
        GOBACK
    END-IF

    PERFORM WRITE-HEAD
    PERFORM WRITE-STUDY-SECTION
    PERFORM WRITE-PROVENANCE-SECTION
    PERFORM WRITE-VALIDATION-SECTION
    PERFORM WRITE-BACI-SECTION
    PERFORM WRITE-SVG-CHART
    PERFORM WRITE-SITES-SECTION
    PERFORM WRITE-WARNINGS-AND-LIMITS
    PERFORM WRITE-FOOTER

    CLOSE F-HTML
    IF WS-WRITE-OK = "N"
        MOVE FL-EXIT-IO-ERR TO L-HTML-RC
    END-IF
    GOBACK.

WRITE-HEAD.
    MOVE "<!DOCTYPE html>" TO WS-LINE PERFORM W-LN
    MOVE '<html lang="en">' TO WS-LINE PERFORM W-LN
    MOVE "<head>" TO WS-LINE PERFORM W-LN
    MOVE '  <meta charset="UTF-8">' TO WS-LINE PERFORM W-LN
    MOVE '  <meta name="viewport" content="width=device-width, initial-scale=1.0">'
        TO WS-LINE PERFORM W-LN
    MOVE ST-STUDY-TITLE TO WS-H1 PERFORM ESC-H1
    STRING "  <title>FIELDLEDGER Report - " FUNCTION TRIM(WS-H1) "</title>"
           DELIMITED BY SIZE INTO WS-LINE
    END-STRING
    PERFORM W-LN
    MOVE "  <style>" TO WS-LINE PERFORM W-LN
    MOVE "    :root{--bg:#f6f8fa;--card:#ffffff;--ink:#1b2430;--muted:#526071;--line:#d8e0e8;--accent:#1b5e4a;--warn:#8a4b08;--warnbg:#fff6e5;--info:#1d4e89;--infobg:#eef5fc;--neg:#9e2a2b;}"
        TO WS-LINE PERFORM W-LN
    MOVE "    body{font-family:system-ui,-apple-system,Segoe UI,Roboto,sans-serif;background:var(--bg);color:var(--ink);margin:0;padding:24px;line-height:1.5;}"
        TO WS-LINE PERFORM W-LN
    MOVE "    .wrap{max-width:1160px;margin:0 auto;}" TO WS-LINE PERFORM W-LN
    MOVE "    header{background:#122c26;color:#fff;padding:24px 28px;border-radius:10px;margin-bottom:20px;}"
        TO WS-LINE PERFORM W-LN
    MOVE "    header h1{margin:0 0 6px 0;font-size:1.55rem;}" TO WS-LINE PERFORM W-LN
    MOVE "    header p{margin:0;opacity:0.9;font-size:0.95rem;}" TO WS-LINE PERFORM W-LN
    MOVE "    .card{background:var(--card);border:1px solid var(--line);border-radius:10px;padding:18px 22px;margin-bottom:18px;}"
        TO WS-LINE PERFORM W-LN
    MOVE "    h2{margin:0 0 12px 0;font-size:1.15rem;color:#122c26;border-bottom:1px solid var(--line);padding-bottom:6px;}"
        TO WS-LINE PERFORM W-LN
    MOVE "    .grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(190px,1fr));gap:12px;margin-bottom:12px;}"
        TO WS-LINE PERFORM W-LN
    MOVE "    .kpi{background:#f9fbfc;border:1px solid var(--line);border-radius:8px;padding:10px 14px;}"
        TO WS-LINE PERFORM W-LN
    MOVE "    .kpi .lbl{font-size:0.78rem;color:var(--muted);text-transform:uppercase;letter-spacing:0.04em;}"
        TO WS-LINE PERFORM W-LN
    MOVE "    .kpi .val{font-size:1.25rem;font-weight:700;margin-top:2px;}"
        TO WS-LINE PERFORM W-LN
    MOVE "    table{width:100%;border-collapse:collapse;font-size:0.88rem;margin-top:8px;}"
        TO WS-LINE PERFORM W-LN
    MOVE "    th,td{border:1px solid var(--line);padding:7px 9px;text-align:left;vertical-align:top;}"
        TO WS-LINE PERFORM W-LN
    MOVE "    th{background:#f0f4f8;font-weight:600;}" TO WS-LINE PERFORM W-LN
    MOVE "    td.num,th.num{text-align:right;font-variant-numeric:tabular-nums;}"
        TO WS-LINE PERFORM W-LN
    MOVE "    .badge{display:inline-block;padding:2px 7px;border-radius:4px;font-size:0.76rem;font-weight:600;}"
        TO WS-LINE PERFORM W-LN
    MOVE "    .b-ok{background:#e6f4ea;color:#1b5e4a;}" TO WS-LINE PERFORM W-LN
    MOVE "    .b-warn{background:var(--warnbg);color:var(--warn);}" TO WS-LINE PERFORM W-LN
    MOVE "    .callout{border-left:4px solid var(--warn);background:var(--warnbg);padding:12px 15px;border-radius:6px;margin:10px 0;font-size:0.92rem;}"
        TO WS-LINE PERFORM W-LN
    MOVE "    .callout-info{border-left:4px solid var(--info);background:var(--infobg);padding:12px 15px;border-radius:6px;margin:10px 0;font-size:0.92rem;}"
        TO WS-LINE PERFORM W-LN
    MOVE "    code{background:#eef2f6;padding:1px 5px;border-radius:4px;font-size:0.86em;}"
        TO WS-LINE PERFORM W-LN
    MOVE "    .tbl-wrap{overflow-x:auto;}" TO WS-LINE PERFORM W-LN
    MOVE "    footer{color:var(--muted);font-size:0.82rem;text-align:center;margin-top:22px;}"
        TO WS-LINE PERFORM W-LN
    MOVE "  </style>" TO WS-LINE PERFORM W-LN
    MOVE "</head>" TO WS-LINE PERFORM W-LN
    MOVE '<body><div class="wrap">' TO WS-LINE PERFORM W-LN

    MOVE ST-STUDY-TITLE TO WS-H1 PERFORM ESC-H1
    MOVE ST-STUDY-ID    TO WS-H2 PERFORM ESC-H2
    MOVE CFG-RUN-ID     TO WS-H3 PERFORM ESC-H3
    MOVE CFG-RUN-TIMESTAMP TO WS-H4 PERFORM ESC-H4
    MOVE "<header>" TO WS-LINE PERFORM W-LN
    STRING "  <h1>FIELDLEDGER Scientific Report: " FUNCTION TRIM(WS-H1) "</h1>"
           DELIMITED BY SIZE INTO WS-LINE
    END-STRING
    PERFORM W-LN
    STRING "  <p>Study ID: <code>" FUNCTION TRIM(WS-H2)
           "</code> &middot; Run ID: <code>" FUNCTION TRIM(WS-H3)
           "</code> &middot; Timestamp: <code>" FUNCTION TRIM(WS-H4)
           "</code> &middot; Engine: FIELDLEDGER v" FL-APP-VERSION
           " (" FL-COMPILER-LABEL ")</p>"
           DELIMITED BY SIZE INTO WS-LINE
    END-STRING
    PERFORM W-LN
    MOVE "</header>" TO WS-LINE PERFORM W-LN
    .

WRITE-STUDY-SECTION.
    MOVE '<section class="card"><h2>1. Study Details</h2>' TO WS-LINE PERFORM W-LN
    MOVE '<div class="tbl-wrap"><table><tbody>' TO WS-LINE PERFORM W-LN

    MOVE ST-STUDY-DESIGN TO WS-H1 PERFORM ESC-H1
    STRING "<tr><th>Study Design</th><td>" FUNCTION TRIM(WS-H1) "</td></tr>"
           DELIMITED BY SIZE INTO WS-LINE
    END-STRING
    PERFORM W-LN

    MOVE ST-PRIMARY-OUTCOME TO WS-H1 PERFORM ESC-H1
    MOVE ST-PRIMARY-UNIT    TO WS-H2 PERFORM ESC-H2
    STRING "<tr><th>Primary Outcome &amp; Unit</th><td>" FUNCTION TRIM(WS-H1)
           " (<code>" FUNCTION TRIM(WS-H2) "</code>)</td></tr>"
           DELIMITED BY SIZE INTO WS-LINE
    END-STRING
    PERFORM W-LN

    MOVE ST-DESCRIPTION TO WS-H1 PERFORM ESC-H1
    STRING "<tr><th>Description</th><td>" FUNCTION TRIM(WS-H1) "</td></tr>"
           DELIMITED BY SIZE INTO WS-LINE
    END-STRING
    PERFORM W-LN

    MOVE CFG-ACTIVE-METHOD TO WS-H1 PERFORM ESC-H1
    STRING "<tr><th>Observation Method Policy</th><td><code>"
           FUNCTION TRIM(WS-H1)
           "</code> (incompatible methods are never silently pooled)</td></tr>"
           DELIMITED BY SIZE INTO WS-LINE
    END-STRING
    PERFORM W-LN

    MOVE "</tbody></table></div></section>" TO WS-LINE PERFORM W-LN
    .

WRITE-PROVENANCE-SECTION.
    MOVE '<section class="card"><h2>2. Data Provenance &amp; Integrity</h2>'
        TO WS-LINE PERFORM W-LN
    MOVE CFG-MANIFEST-STATUS TO WS-H1 PERFORM ESC-H1
    MOVE CFG-MANIFEST-DATE   TO WS-H2 PERFORM ESC-H2
    STRING '<div class="callout-info"><strong>Input SHA-256 Manifest:</strong> <code>'
           FUNCTION TRIM(WS-H1) "</code>"
           DELIMITED BY SIZE INTO WS-LINE
    END-STRING
    IF FUNCTION TRIM(WS-H2) NOT = SPACES
        STRING FUNCTION TRIM(WS-LINE) " (generated <code>"
               FUNCTION TRIM(WS-H2) "</code>)"
               DELIMITED BY SIZE INTO WS-LINE
        END-STRING
    END-IF
    STRING FUNCTION TRIM(WS-LINE)
           ". Source URLs record provenance metadata only and are not externally verified.</div>"
           DELIMITED BY SIZE INTO WS-LINE
    END-STRING
    PERFORM W-LN

    IF SRC-COUNT > 0
        MOVE '<div class="tbl-wrap"><table><thead><tr><th>Source ID</th><th>Type</th><th>Title</th><th>Organisation</th><th>Licence</th><th>Accessed</th></tr></thead><tbody>'
            TO WS-LINE PERFORM W-LN
        PERFORM VARYING WS-I FROM 1 BY 1 UNTIL WS-I > SRC-COUNT OR WS-I > 50
            MOVE SRC-ID(WS-I)    TO WS-H1 PERFORM ESC-H1
            MOVE SRC-TYPE(WS-I)  TO WS-H2 PERFORM ESC-H2
            MOVE SRC-TITLE(WS-I) TO WS-H3 PERFORM ESC-H3
            MOVE SRC-ORG(WS-I)   TO WS-H4 PERFORM ESC-H4
            STRING "<tr><td><code>" FUNCTION TRIM(WS-H1) "</code></td><td>"
                   FUNCTION TRIM(WS-H2) "</td><td>"
                   FUNCTION TRIM(WS-H3) "</td><td>"
                   FUNCTION TRIM(WS-H4) "</td><td>"
                   DELIMITED BY SIZE INTO WS-LINE
            END-STRING
            MOVE SRC-LICENCE(WS-I) TO WS-H1 PERFORM ESC-H1
            MOVE SRC-ACCESSED-DATE(WS-I) TO WS-H2 PERFORM ESC-H2
            STRING FUNCTION TRIM(WS-LINE) FUNCTION TRIM(WS-H1) "</td><td>"
                   FUNCTION TRIM(WS-H2) "</td></tr>"
                   DELIMITED BY SIZE INTO WS-LINE
            END-STRING
            PERFORM W-LN
        END-PERFORM
        MOVE "</tbody></table></div>" TO WS-LINE PERFORM W-LN
    END-IF
    MOVE "</section>" TO WS-LINE PERFORM W-LN
    .

WRITE-VALIDATION-SECTION.
    MOVE '<section class="card"><h2>3. Validation &amp; Survey Statistics</h2>'
        TO WS-LINE PERFORM W-LN
    MOVE '<div class="grid">' TO WS-LINE PERFORM W-LN

    MOVE ERR-ERROR-CNT TO NREQ-INT-VAL PERFORM FMT-I1
    STRING '<div class="kpi"><div class="lbl">Validation Errors</div><div class="val">'
           FUNCTION TRIM(WS-N1) "</div></div>"
           DELIMITED BY SIZE INTO WS-LINE
    END-STRING
    PERFORM W-LN

    MOVE SITE-COUNT TO NREQ-INT-VAL PERFORM FMT-I1
    MOVE SITE-IMPACT-TOTAL TO NREQ-INT-VAL PERFORM FMT-I2
    MOVE SITE-CONTROL-TOTAL TO NREQ-INT-VAL PERFORM FMT-I3
    STRING '<div class="kpi"><div class="lbl">Sites (Imp / Ctrl)</div><div class="val">'
           FUNCTION TRIM(WS-N1) " (" FUNCTION TRIM(WS-N2) "/"
           FUNCTION TRIM(WS-N3) ")</div></div>"
           DELIMITED BY SIZE INTO WS-LINE
    END-STRING
    PERFORM W-LN

    MOVE SURV-COUNT TO NREQ-INT-VAL PERFORM FMT-I1
    MOVE SURV-TRANS-COUNT TO NREQ-INT-VAL PERFORM FMT-I2
    STRING '<div class="kpi"><div class="lbl">Surveys (Transition Excl)</div><div class="val">'
           FUNCTION TRIM(WS-N1) " (" FUNCTION TRIM(WS-N2) ")</div></div>"
           DELIMITED BY SIZE INTO WS-LINE
    END-STRING
    PERFORM W-LN

    MOVE OBS-COUNT TO NREQ-INT-VAL PERFORM FMT-I1
    MOVE OBS-NOT-DET-COUNT TO NREQ-INT-VAL PERFORM FMT-I2
    STRING '<div class="kpi"><div class="lbl">Observations (Explicit Zero)</div><div class="val">'
           FUNCTION TRIM(WS-N1) " (" FUNCTION TRIM(WS-N2) ")</div></div>"
           DELIMITED BY SIZE INTO WS-LINE
    END-STRING
    PERFORM W-LN

    MOVE "</div></section>" TO WS-LINE PERFORM W-LN
    .

WRITE-BACI-SECTION.
    MOVE '<section class="card"><h2>4. BACI Results &amp; Statistical Uncertainty</h2>'
        TO WS-LINE PERFORM W-LN
    MOVE '<div class="tbl-wrap"><table><thead><tr>' TO WS-LINE PERFORM W-LN
    MOVE '<th>Species</th><th>Method</th><th class="num">Imp Sites</th><th class="num">Ctrl Sites</th><th class="num">Imp PRE</th><th class="num">Imp POST</th><th class="num">Ctrl PRE</th><th class="num">Ctrl POST</th><th class="num">Imp Chg</th><th class="num">Ctrl Chg</th><th class="num">BACI Est</th><th class="num">Coverage</th><th class="num">Missing</th><th>95% Bootstrap CI</th><th>LOSO Sensitivity</th>'
        TO WS-LINE PERFORM W-LN
    MOVE "</tr></thead><tbody>" TO WS-LINE PERFORM W-LN

    PERFORM VARYING WS-I FROM 1 BY 1 UNTIL WS-I > BACI-COUNT
        MOVE BR-SPECIES(WS-I) TO WS-H1 PERFORM ESC-H1
        MOVE BR-METHOD(WS-I)  TO WS-H2 PERFORM ESC-H2
        MOVE BR-IMP-SITES(WS-I)  TO NREQ-INT-VAL PERFORM FMT-I1
        MOVE BR-CTRL-SITES(WS-I) TO NREQ-INT-VAL PERFORM FMT-I2
        STRING "<tr><td><code>" FUNCTION TRIM(WS-H1) "</code></td><td>"
               FUNCTION TRIM(WS-H2) '</td><td class="num">'
               FUNCTION TRIM(WS-N1) '</td><td class="num">'
               FUNCTION TRIM(WS-N2) "</td>"
               DELIMITED BY SIZE INTO WS-LINE
        END-STRING
        PERFORM W-LN

        IF BR-CALCULABLE(WS-I) = "Y"
            MOVE BR-IMP-PRE-MEAN(WS-I)   TO NREQ-DEC-VAL PERFORM FMT-D1
            MOVE BR-IMP-POST-MEAN(WS-I)  TO NREQ-DEC-VAL PERFORM FMT-D2
            MOVE BR-CTRL-PRE-MEAN(WS-I)  TO NREQ-DEC-VAL PERFORM FMT-D3
            MOVE BR-CTRL-POST-MEAN(WS-I) TO NREQ-DEC-VAL PERFORM FMT-D4
            MOVE BR-IMP-CHANGE(WS-I)     TO NREQ-DEC-VAL PERFORM FMT-D5
            MOVE BR-CTRL-CHANGE(WS-I)    TO NREQ-DEC-VAL PERFORM FMT-D6
            MOVE BR-BACI-EST(WS-I)       TO NREQ-DEC-VAL PERFORM FMT-D7
        ELSE
            MOVE "NA" TO WS-N1 WS-N2 WS-N3 WS-N4 WS-N5 WS-N6 WS-N7
        END-IF
        STRING '<td class="num">' FUNCTION TRIM(WS-N1)
               '</td><td class="num">' FUNCTION TRIM(WS-N2)
               '</td><td class="num">' FUNCTION TRIM(WS-N3)
               '</td><td class="num">' FUNCTION TRIM(WS-N4)
               '</td><td class="num">' FUNCTION TRIM(WS-N5)
               '</td><td class="num">' FUNCTION TRIM(WS-N6)
               '</td><td class="num"><strong>' FUNCTION TRIM(WS-N7)
               "</strong></td>"
               DELIMITED BY SIZE INTO WS-LINE
        END-STRING
        PERFORM W-LN

        INITIALIZE NUM-REQ
        MOVE "FMT-DEC2" TO NREQ-OP
        MOVE BR-COVERAGE-PCT(WS-I) TO NREQ-DEC-VAL
        CALL "NUMERIC-UTILS" USING NUM-REQ
        MOVE FUNCTION TRIM(NREQ-TEXT-OUT) TO WS-N1
        MOVE BR-OBS-MISSING(WS-I) TO NREQ-INT-VAL PERFORM FMT-I2

        MOVE SPACES TO WS-CI-TXT
        IF FUNCTION TRIM(BR-CI-STATUS(WS-I)) = "REPORTED"
            MOVE BR-CI-LOW(WS-I)  TO NREQ-DEC-VAL PERFORM FMT-D3
            MOVE BR-CI-HIGH(WS-I) TO NREQ-DEC-VAL PERFORM FMT-D4
            STRING '<span class="badge b-ok">[' FUNCTION TRIM(WS-N3)
                   ", " FUNCTION TRIM(WS-N4) "]</span>"
                   DELIMITED BY SIZE INTO WS-CI-TXT
            END-STRING
        ELSE
            MOVE BR-CI-STATUS(WS-I) TO WS-H3 PERFORM ESC-H3
            STRING '<span class="badge b-warn">' FUNCTION TRIM(WS-H3) "</span>"
                   DELIMITED BY SIZE INTO WS-CI-TXT
            END-STRING
        END-IF

        MOVE SPACES TO WS-H4
        IF FUNCTION TRIM(BR-LOSO-STATUS(WS-I)) = "COMPUTED"
            MOVE BR-LOSO-MIN(WS-I) TO NREQ-DEC-VAL PERFORM FMT-D5
            MOVE BR-LOSO-MAX(WS-I) TO NREQ-DEC-VAL PERFORM FMT-D6
            MOVE BR-LOSO-SITE(WS-I) TO WS-H3 PERFORM ESC-H3
            STRING "[" FUNCTION TRIM(WS-N5) ", " FUNCTION TRIM(WS-N6)
                   "] (infl: <code>" FUNCTION TRIM(WS-H3) "</code>)"
                   DELIMITED BY SIZE INTO WS-H4
            END-STRING
        ELSE
            MOVE "INSUFFICIENT" TO WS-H4
        END-IF

        STRING '<td class="num">' FUNCTION TRIM(WS-N1)
               '%</td><td class="num">' FUNCTION TRIM(WS-N2)
               "</td><td>" FUNCTION TRIM(WS-CI-TXT)
               "</td><td>" FUNCTION TRIM(WS-H4) "</td></tr>"
               DELIMITED BY SIZE INTO WS-LINE
        END-STRING
        PERFORM W-LN
    END-PERFORM

    MOVE "</tbody></table></div>" TO WS-LINE PERFORM W-LN
    .

WRITE-SVG-CHART.
    *> Inline pure-SVG bar chart of calculable BACI estimates (up to 25 strata)
    MOVE 0 TO WS-PLOT-CNT
    MOVE 1 TO WS-MAX-ABS
    PERFORM VARYING WS-I FROM 1 BY 1 UNTIL WS-I > BACI-COUNT OR WS-PLOT-CNT >= 25
        IF BR-CALCULABLE(WS-I) = "Y"
            ADD 1 TO WS-PLOT-CNT
            COMPUTE WS-ABS-V = FUNCTION ABS(BR-BACI-EST(WS-I))
            IF WS-ABS-V > WS-MAX-ABS
                MOVE WS-ABS-V TO WS-MAX-ABS
            END-IF
        END-IF
    END-PERFORM

    IF WS-PLOT-CNT = 0
        MOVE "</section>" TO WS-LINE PERFORM W-LN
        EXIT PARAGRAPH
    END-IF

    COMPUTE WS-SVG-H = 56 + (WS-PLOT-CNT * 34)
    MOVE WS-SVG-H TO NREQ-INT-VAL PERFORM FMT-I1
    MOVE WS-N1 TO WS-S-H

    MOVE '<h3>BACI Point Estimates (detections / observer-hour)</h3>'
        TO WS-LINE PERFORM W-LN
    STRING '<svg width="780" height="' FUNCTION TRIM(WS-S-H)
           '" viewBox="0 0 780 ' FUNCTION TRIM(WS-S-H)
           '" role="img" aria-label="BACI estimates bar chart" '
           'style="max-width:100%;height:auto;background:#fcfdff;border:1px solid #d8e0e8;border-radius:8px;">'
           DELIMITED BY SIZE INTO WS-LINE
    END-STRING
    PERFORM W-LN

    *> Vertical zero baseline at x=400
    STRING '  <line x1="400" y1="18" x2="400" y2="' FUNCTION TRIM(WS-S-H)
           '" stroke="#526071" stroke-width="1.5" stroke-dasharray="4,3"/>'
           DELIMITED BY SIZE INTO WS-LINE
    END-STRING
    PERFORM W-LN
    MOVE '  <text x="400" y="13" text-anchor="middle" font-size="11" fill="#526071">0 (No differential change)</text>'
        TO WS-LINE PERFORM W-LN

    MOVE 0 TO WS-PLOT-CNT
    PERFORM VARYING WS-I FROM 1 BY 1 UNTIL WS-I > BACI-COUNT OR WS-PLOT-CNT >= 25
        IF BR-CALCULABLE(WS-I) = "Y"
            ADD 1 TO WS-PLOT-CNT
            COMPUTE WS-Y-POS = 26 + ((WS-PLOT-CNT - 1) * 34)
            COMPUTE WS-ABS-V = FUNCTION ABS(BR-BACI-EST(WS-I))
            COMPUTE WS-BAR-W ROUNDED = (WS-ABS-V / WS-MAX-ABS) * WS-HALF-SPAN
            IF WS-BAR-W < 2 AND WS-ABS-V > 0
                MOVE 2 TO WS-BAR-W
            END-IF
            IF BR-BACI-EST(WS-I) >= 0
                MOVE WS-ZERO-X TO WS-BAR-X
                MOVE "#1b5e4a" TO WS-BAR-COLOR
                COMPUTE WS-I = WS-I
            ELSE
                COMPUTE WS-BAR-X = WS-ZERO-X - WS-BAR-W
                MOVE "#9e2a2b" TO WS-BAR-COLOR
            END-IF

            MOVE WS-Y-POS TO NREQ-INT-VAL PERFORM FMT-I1 MOVE WS-N1 TO WS-S-Y
            COMPUTE WS-Y-POS = WS-Y-POS + 14
            MOVE WS-Y-POS TO NREQ-INT-VAL PERFORM FMT-I1 MOVE WS-N1 TO WS-S-TY
            MOVE WS-BAR-X TO NREQ-INT-VAL PERFORM FMT-I1 MOVE WS-N1 TO WS-S-X
            MOVE WS-BAR-W TO NREQ-INT-VAL PERFORM FMT-I1 MOVE WS-N1 TO WS-S-W

            MOVE BR-SPECIES(WS-I) TO WS-H1 PERFORM ESC-H1
            MOVE BR-BACI-EST(WS-I) TO NREQ-DEC-VAL PERFORM FMT-D2

            STRING '  <text x="12" y="' FUNCTION TRIM(WS-S-TY)
                   '" font-size="12" fill="#1b2430">'
                   FUNCTION TRIM(WS-H1) "</text>"
                   DELIMITED BY SIZE INTO WS-LINE
            END-STRING
            PERFORM W-LN

            STRING '  <rect x="' FUNCTION TRIM(WS-S-X)
                   '" y="' FUNCTION TRIM(WS-S-Y)
                   '" width="' FUNCTION TRIM(WS-S-W)
                   '" height="20" rx="3" fill="' FUNCTION TRIM(WS-BAR-COLOR)
                   '"/>'
                   DELIMITED BY SIZE INTO WS-LINE
            END-STRING
            PERFORM W-LN

            IF BR-BACI-EST(WS-I) >= 0
                COMPUTE WS-BAR-X = WS-ZERO-X + WS-BAR-W + 6
                MOVE WS-BAR-X TO NREQ-INT-VAL PERFORM FMT-I1 MOVE WS-N1 TO WS-S-LX
                STRING '  <text x="' FUNCTION TRIM(WS-S-LX)
                       '" y="' FUNCTION TRIM(WS-S-TY)
                       '" font-size="11" font-weight="600" fill="#1b2430">+'
                       FUNCTION TRIM(WS-N2) "</text>"
                       DELIMITED BY SIZE INTO WS-LINE
                END-STRING
            ELSE
                COMPUTE WS-BAR-X = WS-ZERO-X + 6
                MOVE WS-BAR-X TO NREQ-INT-VAL PERFORM FMT-I1 MOVE WS-N1 TO WS-S-LX
                STRING '  <text x="' FUNCTION TRIM(WS-S-LX)
                       '" y="' FUNCTION TRIM(WS-S-TY)
                       '" font-size="11" font-weight="600" fill="#9e2a2b">'
                       FUNCTION TRIM(WS-N2) "</text>"
                       DELIMITED BY SIZE INTO WS-LINE
                END-STRING
            END-IF
            PERFORM W-LN
        END-IF
    END-PERFORM

    MOVE "</svg></section>" TO WS-LINE PERFORM W-LN
    .

WRITE-SITES-SECTION.
    MOVE '<section class="card"><h2>5. Site-Level Summaries</h2>' TO WS-LINE PERFORM W-LN
    MOVE '<div class="tbl-wrap"><table><thead><tr>' TO WS-LINE PERFORM W-LN
    MOVE '<th>Species</th><th>Method</th><th>Site</th><th>Role</th><th class="num">PRE (Obs/Surv)</th><th class="num">POST (Obs/Surv)</th><th class="num">Explicit Zero</th><th class="num">Missing</th><th class="num">PRE Mean</th><th class="num">POST Mean</th><th class="num">Site Change</th><th>Status</th>'
        TO WS-LINE PERFORM W-LN
    MOVE "</tr></thead><tbody>" TO WS-LINE PERFORM W-LN

    PERFORM VARYING WS-I FROM 1 BY 1 UNTIL WS-I > SSUM-COUNT OR WS-I > 200
        MOVE SS-SPECIES(WS-I)   TO WS-H1 PERFORM ESC-H1
        MOVE SS-METHOD(WS-I)    TO WS-H2 PERFORM ESC-H2
        MOVE SS-SITE-ID(WS-I)   TO WS-H3 PERFORM ESC-H3
        MOVE SS-SITE-ROLE(WS-I) TO WS-H4 PERFORM ESC-H4
        STRING "<tr><td><code>" FUNCTION TRIM(WS-H1) "</code></td><td>"
               FUNCTION TRIM(WS-H2) "</td><td><code>"
               FUNCTION TRIM(WS-H3) "</code></td><td>"
               FUNCTION TRIM(WS-H4) "</td>"
               DELIMITED BY SIZE INTO WS-LINE
        END-STRING
        PERFORM W-LN

        MOVE SS-PRE-OBS(WS-I)      TO NREQ-INT-VAL PERFORM FMT-I1
        MOVE SS-PRE-SURVEYS(WS-I)  TO NREQ-INT-VAL PERFORM FMT-I2
        MOVE SS-POST-OBS(WS-I)     TO NREQ-INT-VAL PERFORM FMT-I3
        MOVE SS-POST-SURVEYS(WS-I) TO NREQ-INT-VAL PERFORM FMT-I4
        MOVE SS-ZERO-OBS(WS-I)     TO NREQ-INT-VAL PERFORM FMT-I5
        MOVE SS-MISSING-OBS(WS-I)  TO NREQ-INT-VAL PERFORM FMT-I6
        STRING '<td class="num">' FUNCTION TRIM(WS-N1) "/" FUNCTION TRIM(WS-N2)
               '</td><td class="num">' FUNCTION TRIM(WS-N3) "/" FUNCTION TRIM(WS-N4)
               '</td><td class="num">' FUNCTION TRIM(WS-N5)
               '</td><td class="num">' FUNCTION TRIM(WS-N6) "</td>"
               DELIMITED BY SIZE INTO WS-LINE
        END-STRING
        PERFORM W-LN

        IF SS-PRE-OBS(WS-I) > 0
            MOVE SS-PRE-MEAN(WS-I) TO NREQ-DEC-VAL PERFORM FMT-D1
        ELSE
            MOVE "NA" TO WS-N1
        END-IF
        IF SS-POST-OBS(WS-I) > 0
            MOVE SS-POST-MEAN(WS-I) TO NREQ-DEC-VAL PERFORM FMT-D2
        ELSE
            MOVE "NA" TO WS-N2
        END-IF
        IF FUNCTION TRIM(SS-STATUS(WS-I)) = "COMPLETE"
            MOVE SS-SITE-CHANGE(WS-I) TO NREQ-DEC-VAL PERFORM FMT-D3
        ELSE
            MOVE "NA" TO WS-N3
        END-IF
        MOVE SS-STATUS(WS-I) TO WS-H1 PERFORM ESC-H1
        STRING '<td class="num">' FUNCTION TRIM(WS-N1)
               '</td><td class="num">' FUNCTION TRIM(WS-N2)
               '</td><td class="num">' FUNCTION TRIM(WS-N3)
               "</td><td><code>" FUNCTION TRIM(WS-H1) "</code></td></tr>"
               DELIMITED BY SIZE INTO WS-LINE
        END-STRING
        PERFORM W-LN
    END-PERFORM
    MOVE "</tbody></table></div></section>" TO WS-LINE PERFORM W-LN
    .

WRITE-WARNINGS-AND-LIMITS.
    MOVE '<section class="card"><h2>6. Warnings, Limitations &amp; Reproducibility</h2>'
        TO WS-LINE PERFORM W-LN
    MOVE "<h3>Warnings</h3><ul>" TO WS-LINE PERFORM W-LN
    MOVE "N" TO WS-WARN-FOUND
    PERFORM VARYING WS-I FROM 1 BY 1 UNTIL WS-I > ERR-COUNT
        IF ERR-SEVERITY(WS-I) = "WARNING"
            MOVE "Y" TO WS-WARN-FOUND
            MOVE ERR-CODE(WS-I)    TO WS-H1 PERFORM ESC-H1
            MOVE ERR-MESSAGE(WS-I) TO WS-H2 PERFORM ESC-H2
            STRING "<li><strong><code>" FUNCTION TRIM(WS-H1)
                   "</code></strong>: " FUNCTION TRIM(WS-H2) "</li>"
                   DELIMITED BY SIZE INTO WS-LINE
            END-STRING
            PERFORM W-LN
        END-IF
    END-PERFORM
    IF WS-WARN-FOUND = "N"
        MOVE "<li>No warnings recorded.</li>" TO WS-LINE PERFORM W-LN
    END-IF
    MOVE "</ul>" TO WS-LINE PERFORM W-LN

    MOVE '<div class="callout"><strong>Scientific Limitations (v1.0.0):</strong><ul>'
        TO WS-LINE PERFORM W-LN
    MOVE "<li>Reports effort-standardised observation rates (<code>detections_per_hour</code>), NOT true ecological abundance and NOT detection-probability-corrected occupancy.</li>"
        TO WS-LINE PERFORM W-LN
    MOVE "<li>Missing observation rows are preserved as missingness and are NEVER silently treated as zero counts.</li>"
        TO WS-LINE PERFORM W-LN
    MOVE "<li>BACI estimates alone do NOT establish causal proof; causal attribution depends on control comparability, parallel trends, and absence of differential confounding.</li>"
        TO WS-LINE PERFORM W-LN
    MOVE "<li>Site-cluster bootstrap 95% intervals are withheld when fewer than 5 complete independent sites exist in either group; p-values are never manufactured.</li>"
        TO WS-LINE PERFORM W-LN
    MOVE "</ul></div>" TO WS-LINE PERFORM W-LN

    MOVE CFG-SEED TO NREQ-INT-VAL PERFORM FMT-I1
    MOVE CFG-BOOTSTRAP TO NREQ-INT-VAL PERFORM FMT-I2
    STRING "<p><strong>Reproducibility:</strong> Deterministic Park-Miller LCG seed <code>"
           FUNCTION TRIM(WS-N1) "</code>, bootstrap iterations <code>"
           FUNCTION TRIM(WS-N2) "</code>, receipt <code>research-receipt.json</code>, "
           "append-only ledger <code>evidence-ledger.csv</code>.</p>"
           DELIMITED BY SIZE INTO WS-LINE
    END-STRING
    PERFORM W-LN
    MOVE "</section>" TO WS-LINE PERFORM W-LN
    .

WRITE-FOOTER.
    MOVE '<footer>Self-contained offline report generated by FIELDLEDGER v1.0.0 (GnuCOBOL 3.2.0). Zero external scripts or CDNs.</footer>'
        TO WS-LINE PERFORM W-LN
    MOVE "</div></body></html>" TO WS-LINE PERFORM W-LN
    .

ESC-H1. INITIALIZE NUM-REQ MOVE "ESC-HTML" TO NREQ-OP MOVE WS-H1 TO NREQ-TEXT-IN CALL "NUMERIC-UTILS" USING NUM-REQ MOVE NREQ-TEXT-OUT TO WS-H1.
ESC-H2. INITIALIZE NUM-REQ MOVE "ESC-HTML" TO NREQ-OP MOVE WS-H2 TO NREQ-TEXT-IN CALL "NUMERIC-UTILS" USING NUM-REQ MOVE NREQ-TEXT-OUT TO WS-H2.
ESC-H3. INITIALIZE NUM-REQ MOVE "ESC-HTML" TO NREQ-OP MOVE WS-H3 TO NREQ-TEXT-IN CALL "NUMERIC-UTILS" USING NUM-REQ MOVE NREQ-TEXT-OUT TO WS-H3.
ESC-H4. INITIALIZE NUM-REQ MOVE "ESC-HTML" TO NREQ-OP MOVE WS-H4 TO NREQ-TEXT-IN CALL "NUMERIC-UTILS" USING NUM-REQ MOVE NREQ-TEXT-OUT TO WS-H4.

FMT-I1. MOVE "FMT-INT" TO NREQ-OP CALL "NUMERIC-UTILS" USING NUM-REQ MOVE FUNCTION TRIM(NREQ-TEXT-OUT) TO WS-N1.
FMT-I2. MOVE "FMT-INT" TO NREQ-OP CALL "NUMERIC-UTILS" USING NUM-REQ MOVE FUNCTION TRIM(NREQ-TEXT-OUT) TO WS-N2.
FMT-I3. MOVE "FMT-INT" TO NREQ-OP CALL "NUMERIC-UTILS" USING NUM-REQ MOVE FUNCTION TRIM(NREQ-TEXT-OUT) TO WS-N3.
FMT-I4. MOVE "FMT-INT" TO NREQ-OP CALL "NUMERIC-UTILS" USING NUM-REQ MOVE FUNCTION TRIM(NREQ-TEXT-OUT) TO WS-N4.
FMT-I5. MOVE "FMT-INT" TO NREQ-OP CALL "NUMERIC-UTILS" USING NUM-REQ MOVE FUNCTION TRIM(NREQ-TEXT-OUT) TO WS-N5.
FMT-I6. MOVE "FMT-INT" TO NREQ-OP CALL "NUMERIC-UTILS" USING NUM-REQ MOVE FUNCTION TRIM(NREQ-TEXT-OUT) TO WS-N6.
FMT-D1. MOVE "FMT-DEC6" TO NREQ-OP CALL "NUMERIC-UTILS" USING NUM-REQ MOVE FUNCTION TRIM(NREQ-TEXT-OUT) TO WS-N1.
FMT-D2. MOVE "FMT-DEC6" TO NREQ-OP CALL "NUMERIC-UTILS" USING NUM-REQ MOVE FUNCTION TRIM(NREQ-TEXT-OUT) TO WS-N2.
FMT-D3. MOVE "FMT-DEC6" TO NREQ-OP CALL "NUMERIC-UTILS" USING NUM-REQ MOVE FUNCTION TRIM(NREQ-TEXT-OUT) TO WS-N3.
FMT-D4. MOVE "FMT-DEC6" TO NREQ-OP CALL "NUMERIC-UTILS" USING NUM-REQ MOVE FUNCTION TRIM(NREQ-TEXT-OUT) TO WS-N4.
FMT-D5. MOVE "FMT-DEC6" TO NREQ-OP CALL "NUMERIC-UTILS" USING NUM-REQ MOVE FUNCTION TRIM(NREQ-TEXT-OUT) TO WS-N5.
FMT-D6. MOVE "FMT-DEC6" TO NREQ-OP CALL "NUMERIC-UTILS" USING NUM-REQ MOVE FUNCTION TRIM(NREQ-TEXT-OUT) TO WS-N6.
FMT-D7. MOVE "FMT-DEC6" TO NREQ-OP CALL "NUMERIC-UTILS" USING NUM-REQ MOVE FUNCTION TRIM(NREQ-TEXT-OUT) TO WS-N7.

W-LN.
    IF WS-WRITE-OK = "N"
        EXIT PARAGRAPH
    END-IF
    MOVE WS-LINE TO F-HTML-REC
    WRITE F-HTML-REC
    IF WS-FS NOT = "00"
        PERFORM MARK-FAIL
    END-IF
    MOVE SPACES TO WS-LINE
    .

MARK-FAIL.
    MOVE "N" TO WS-WRITE-OK
    STRING "Failed writing report.html (status " WS-FS ")"
           DELIMITED BY SIZE INTO CFG-ERROR-MSG
    END-STRING
    .
