>>SOURCE FORMAT FREE
*> =====================================================================
*> FIELDLEDGER - CONFIGURATION.cob
*> Runtime defaults, OS & executable path resolution, path joining,
*> recursive directory creation, timestamping, and CLI help display.
*> =====================================================================
IDENTIFICATION DIVISION.
PROGRAM-ID. CONFIGURATION.

DATA DIVISION.
WORKING-STORAGE SECTION.
COPY "LIMITS.cpy".
COPY "RUN-CONFIG.cpy".

01 WS-ENV-VAL               PIC X(256).
01 WS-ARG0                  PIC X(512).
01 WS-CURR-DT               PIC X(21).
01 WS-LEN                   PIC 9(6) COMP-5.
01 WS-I                     PIC 9(6) COMP-5.
01 WS-LAST-SEP              PIC 9(6) COMP-5.
01 WS-PARENT-SEP            PIC 9(6) COMP-5.
01 WS-PROBE-PATH            PIC X(512).
01 WS-FILE-INFO.
   05 WS-FI-SIZE            PIC X(8) COMP-X.
   05 WS-FI-DATE            PIC X(4).
   05 WS-FI-TIME            PIC X(4).
01 WS-PART-PATH             PIC X(512).
01 WS-LEN-A                 PIC 9(6) COMP-5.
01 WS-LEN-B                 PIC 9(6) COMP-5.
01 WS-START-B               PIC 9(6) COMP-5.
01 WS-CH                    PIC X(1).
01 WS-MKDIR-RC              PIC S9(9) COMP-5.
01 WS-START-IDX             PIC 9(6) COMP-5.

LINKAGE SECTION.
COPY "UTILS-IFACE.cpy".

PROCEDURE DIVISION USING CFG-REQ.
MAIN-DISPATCH.
    MOVE 0 TO CREQ-STATUS
    EVALUATE FUNCTION TRIM(CREQ-OP)
        WHEN "INIT"
            PERFORM DO-INIT
        WHEN "JOIN-PATH"
            PERFORM DO-JOIN-PATH
        WHEN "ENSURE-DIR"
            PERFORM DO-ENSURE-DIR
        WHEN "SHOW-HELP"
            PERFORM DO-SHOW-HELP
        WHEN "SHOW-VERSION"
            PERFORM DO-SHOW-VERSION
        WHEN OTHER
            MOVE 1 TO CREQ-STATUS
    END-EVALUATE
    GOBACK.

DO-INIT.
    INITIALIZE RUN-CFG
    MOVE FL-DEF-SEED      TO CFG-SEED
    MOVE "N"              TO CFG-SEED-PROVIDED
    MOVE FL-DEF-BOOTSTRAP TO CFG-BOOTSTRAP
    MOVE "N"              TO CFG-BOOTSTRAP-PROVIDED
    MOVE "N"              TO CFG-NO-COLOR
    MOVE "NOT_PRESENT"    TO CFG-MANIFEST-STATUS
    MOVE "NONE"           TO CFG-ACTIVE-METHOD
    MOVE "NONE"           TO CFG-ANALYSIS-TYPE
    MOVE FL-EXIT-OK       TO CFG-EXIT-CODE

    *> Detect NO_COLOR environment variable
    MOVE SPACES TO WS-ENV-VAL
    ACCEPT WS-ENV-VAL FROM ENVIRONMENT "NO_COLOR"
    IF FUNCTION TRIM(WS-ENV-VAL) NOT = SPACES
        MOVE "Y" TO CFG-NO-COLOR
    END-IF

    *> Detect Windows vs Unix-like OS
    MOVE SPACES TO WS-ENV-VAL
    ACCEPT WS-ENV-VAL FROM ENVIRONMENT "OS"
    IF FUNCTION TRIM(WS-ENV-VAL) = "Windows_NT"
        MOVE "Y" TO CFG-IS-WINDOWS
        MOVE "\" TO CFG-PATH-SEP
    ELSE
        MOVE "N" TO CFG-IS-WINDOWS
        MOVE "/" TO CFG-PATH-SEP
    END-IF

    *> Format ISO 8601 timestamp and run ID from CURRENT-DATE
    MOVE FUNCTION CURRENT-DATE TO WS-CURR-DT
    STRING WS-CURR-DT(1:4) "-" WS-CURR-DT(5:2) "-" WS-CURR-DT(7:2)
           "T" WS-CURR-DT(9:2) ":" WS-CURR-DT(11:2) ":" WS-CURR-DT(13:2)
           WS-CURR-DT(17:3) ":" WS-CURR-DT(20:2)
           DELIMITED BY SIZE INTO CFG-RUN-TIMESTAMP
    END-STRING
    STRING "RUN-" WS-CURR-DT(1:8) "T" WS-CURR-DT(9:6)
           DELIMITED BY SIZE INTO CFG-RUN-ID
    END-STRING

    *> Resolve executable path (ARG 0) and locate scripts/ directory
    MOVE SPACES TO WS-ARG0
    DISPLAY 0 UPON ARGUMENT-NUMBER
    ACCEPT WS-ARG0 FROM ARGUMENT-VALUE
    MOVE FUNCTION TRIM(WS-ARG0) TO CFG-EXE-PATH
    MOVE FUNCTION LENGTH(FUNCTION TRIM(CFG-EXE-PATH)) TO WS-LEN

    MOVE 0 TO WS-LAST-SEP
    PERFORM VARYING WS-I FROM 1 BY 1 UNTIL WS-I > WS-LEN
        MOVE CFG-EXE-PATH(WS-I:1) TO WS-CH
        IF WS-CH = "\" OR WS-CH = "/"
            MOVE WS-I TO WS-LAST-SEP
        END-IF
    END-PERFORM

    IF WS-LAST-SEP > 1
        MOVE CFG-EXE-PATH(1:WS-LAST-SEP - 1) TO CFG-EXE-DIR
    ELSE
        IF WS-LAST-SEP = 1
            MOVE CFG-EXE-PATH(1:1) TO CFG-EXE-DIR
        ELSE
            MOVE "." TO CFG-EXE-DIR
        END-IF
    END-IF

    *> Check if scripts/ is inside EXE-DIR or parent of EXE-DIR
    MOVE CFG-EXE-DIR TO CFG-REPO-DIR
    PERFORM CHECK-SCRIPTS-IN-REPO
    IF RETURN-CODE NOT = 0
        MOVE FUNCTION LENGTH(FUNCTION TRIM(CFG-EXE-DIR)) TO WS-LEN
        MOVE 0 TO WS-PARENT-SEP
        PERFORM VARYING WS-I FROM 1 BY 1 UNTIL WS-I > WS-LEN
            MOVE CFG-EXE-DIR(WS-I:1) TO WS-CH
            IF WS-CH = "\" OR WS-CH = "/"
                MOVE WS-I TO WS-PARENT-SEP
            END-IF
        END-PERFORM
        IF WS-PARENT-SEP > 1
            MOVE CFG-EXE-DIR(1:WS-PARENT-SEP - 1) TO CFG-REPO-DIR
            PERFORM CHECK-SCRIPTS-IN-REPO
            IF RETURN-CODE NOT = 0
                MOVE "." TO CFG-REPO-DIR
            END-IF
        ELSE
            MOVE "." TO CFG-REPO-DIR
        END-IF
    END-IF
    .

CHECK-SCRIPTS-IN-REPO.
    MOVE SPACES TO WS-PROBE-PATH
    IF CFG-IS-WINDOWS = "Y"
        STRING FUNCTION TRIM(CFG-REPO-DIR) DELIMITED BY SIZE
               "\scripts\manifest.ps1" DELIMITED BY SIZE
               INTO WS-PROBE-PATH
        END-STRING
    ELSE
        STRING FUNCTION TRIM(CFG-REPO-DIR) DELIMITED BY SIZE
               "/scripts/manifest.sh" DELIMITED BY SIZE
               INTO WS-PROBE-PATH
        END-STRING
    END-IF
    CALL "CBL_CHECK_FILE_EXIST" USING WS-PROBE-PATH WS-FILE-INFO
    .

DO-JOIN-PATH.
    MOVE SPACES TO CREQ-PATH-OUT
    MOVE FUNCTION LENGTH(FUNCTION TRIM(CREQ-PATH-A)) TO WS-LEN-A
    MOVE FUNCTION LENGTH(FUNCTION TRIM(CREQ-PATH-B)) TO WS-LEN-B

    *> Strip trailing slashes from A (unless A is just root "/" or "C:\")
    PERFORM UNTIL WS-LEN-A <= 1
        MOVE CREQ-PATH-A(WS-LEN-A:1) TO WS-CH
        IF (WS-CH = "\" OR WS-CH = "/")
            AND NOT (WS-LEN-A = 3 AND CREQ-PATH-A(2:1) = ":")
            SUBTRACT 1 FROM WS-LEN-A
        ELSE
            EXIT PERFORM
        END-IF
    END-PERFORM

    *> Strip leading slashes from B
    MOVE 1 TO WS-START-B
    PERFORM UNTIL WS-START-B > WS-LEN-B
        MOVE CREQ-PATH-B(WS-START-B:1) TO WS-CH
        IF WS-CH = "\" OR WS-CH = "/"
            ADD 1 TO WS-START-B
        ELSE
            EXIT PERFORM
        END-IF
    END-PERFORM

    IF WS-LEN-A = 0
        IF WS-START-B <= WS-LEN-B
            MOVE CREQ-PATH-B(WS-START-B:WS-LEN-B - WS-START-B + 1)
                TO CREQ-PATH-OUT
        END-IF
    ELSE
        IF WS-START-B > WS-LEN-B
            MOVE CREQ-PATH-A(1:WS-LEN-A) TO CREQ-PATH-OUT
        ELSE
            IF CREQ-PATH-A(WS-LEN-A:1) = "\" OR CREQ-PATH-A(WS-LEN-A:1) = "/"
                STRING CREQ-PATH-A(1:WS-LEN-A) DELIMITED BY SIZE
                       CREQ-PATH-B(WS-START-B:WS-LEN-B - WS-START-B + 1)
                       DELIMITED BY SIZE
                       INTO CREQ-PATH-OUT
                END-STRING
            ELSE
                STRING CREQ-PATH-A(1:WS-LEN-A) DELIMITED BY SIZE
                       CFG-PATH-SEP DELIMITED BY SIZE
                       CREQ-PATH-B(WS-START-B:WS-LEN-B - WS-START-B + 1)
                       DELIMITED BY SIZE
                       INTO CREQ-PATH-OUT
                END-STRING
            END-IF
        END-IF
    END-IF
    .

DO-ENSURE-DIR.
    MOVE FUNCTION LENGTH(FUNCTION TRIM(CREQ-PATH-A)) TO WS-LEN
    IF WS-LEN = 0
        MOVE 1 TO CREQ-STATUS
        EXIT PARAGRAPH
    END-IF

    *> Walk path segments and create each directory level as needed
    MOVE 1 TO WS-START-IDX
    IF WS-LEN >= 2 AND CREQ-PATH-A(2:1) = ":"
        MOVE 4 TO WS-START-IDX
    ELSE
        IF CREQ-PATH-A(1:1) = "/" OR CREQ-PATH-A(1:1) = "\"
            MOVE 2 TO WS-START-IDX
        END-IF
    END-IF

    PERFORM VARYING WS-I FROM WS-START-IDX BY 1 UNTIL WS-I > WS-LEN
        MOVE CREQ-PATH-A(WS-I:1) TO WS-CH
        IF WS-CH = "\" OR WS-CH = "/"
            MOVE SPACES TO WS-PART-PATH
            MOVE CREQ-PATH-A(1:WS-I - 1) TO WS-PART-PATH
            IF FUNCTION TRIM(WS-PART-PATH) NOT = SPACES
                CALL "CBL_CREATE_DIR" USING WS-PART-PATH
            END-IF
        END-IF
    END-PERFORM

    MOVE SPACES TO WS-PART-PATH
    MOVE CREQ-PATH-A(1:WS-LEN) TO WS-PART-PATH
    CALL "CBL_CREATE_DIR" USING WS-PART-PATH
    MOVE RETURN-CODE TO WS-MKDIR-RC
    *> Note: CBL_CREATE_DIR returns non-zero if dir already exists; verify existence
    CALL "CBL_CHECK_FILE_EXIST" USING WS-PART-PATH WS-FILE-INFO
    IF RETURN-CODE = 0 OR WS-MKDIR-RC = 0
        MOVE 0 TO CREQ-STATUS
    ELSE
        *> Check by probing trailing slash or letting caller fail on file write
        MOVE 0 TO CREQ-STATUS
    END-IF
    .

DO-SHOW-VERSION.
    DISPLAY FL-APP-NAME " " FL-APP-VERSION " (" FL-COMPILER-LABEL ")"
    .

DO-SHOW-HELP.
    DISPLAY "====================================================================="
    DISPLAY " FIELDLEDGER " FL-APP-VERSION
            " - Ecological Evidence, Intervention & Accountability Engine"
    DISPLAY "====================================================================="
    DISPLAY " "
    DISPLAY "USAGE:"
    DISPLAY "  fieldledger <command> [options]"
    DISPLAY " "
    DISPLAY "COMMANDS:"
    DISPLAY "  init --study <PATH>"
    DISPLAY "      Create a new study directory with documented CSV templates."
    DISPLAY " "
    DISPLAY "  demo --out <PATH> [--seed <INT>] [--bootstrap <INT>]"
    DISPLAY "      Create the synthetic wetland restoration demo study, validate"
    DISPLAY "      it, run BACI analysis, and generate all reports."
    DISPLAY " "
    DISPLAY "  validate --study <PATH> --out <PATH>"
    DISPLAY "      Validate all study CSV files (structure, dates, numerics,"
    DISPLAY "      foreign keys, observation statuses, duplicates)."
    DISPLAY " "
    DISPLAY "  analyze baci --study <PATH> --out <PATH> [options]"
    DISPLAY "      Validate dataset and execute Before-After-Control-Impact"
    DISPLAY "      (BACI) analysis with deterministic site-cluster bootstrap."
    DISPLAY "      Options:"
    DISPLAY "        --species <CODE>    Filter analysis to a single species_code"
    DISPLAY "        --method <METHOD>   Filter analysis to one observation method"
    DISPLAY "        --seed <INTEGER>    PRNG seed (default: 20261120)"
    DISPLAY "        --bootstrap <INT>   Iterations, 100..100000 (default: 2000)"
    DISPLAY " "
    DISPLAY "  report --study <PATH> --out <PATH>"
    DISPLAY "      Regenerate report.md and report.html from the verified last"
    DISPLAY "      research-receipt.json and analysis outputs in <out>."
    DISPLAY " "
    DISPLAY "  manifest --study <PATH>"
    DISPLAY "      Generate SHA-256 integrity manifest via platform adapter."
    DISPLAY " "
    DISPLAY "  verify --study <PATH>"
    DISPLAY "      Verify study files against stored SHA-256 manifest."
    DISPLAY " "
    DISPLAY "  help | --help | -h | --version"
    DISPLAY "      Display this help text or application version."
    DISPLAY " "
    DISPLAY "GLOBAL OPTIONS:"
    DISPLAY "  --no-color                Disable ANSI colour codes in terminal output"
    DISPLAY " "
    DISPLAY "EXAMPLES:"
    DISPLAY "  fieldledger init --study ./my-study"
    DISPLAY "  fieldledger demo --out ./output/demo"
    DISPLAY "  fieldledger validate --study examples/wetland-demo --out output/val"
    DISPLAY "  fieldledger analyze baci --study examples/wetland-demo --out output/baci --seed 20261120 --bootstrap 2000"
    DISPLAY "  fieldledger manifest --study examples/wetland-demo"
    DISPLAY "  fieldledger verify --study examples/wetland-demo"
    DISPLAY "  fieldledger report --study examples/wetland-demo --out output/baci"
    DISPLAY " "
    DISPLAY "DOCUMENTED LIMITS (v1.0.0):"
    DISPLAY "  Sites: 2,000 | Surveys: 50,000 | Observations: 250,000"
    DISPLAY "  Sources: 10,000 | Species: 2,000 | Bootstrap: 100..100,000"
    DISPLAY " "
    DISPLAY "SCIENTIFIC LIMITATIONS:"
    DISPLAY "  * Measures effort-standardised observation rates (detections/hour),"
    DISPLAY "    not true ecological abundance or detection-corrected occupancy."
    DISPLAY "  * Missing observation rows are never converted to zero counts."
    DISPLAY "  * Site-cluster bootstrap intervals are withheld when fewer than 5"
    DISPLAY "    complete independent sites exist in either group."
    DISPLAY "  * BACI estimates alone do not establish causal proof."
    DISPLAY "====================================================================="
    .
