>>SOURCE FORMAT FREE
*> =====================================================================
*> FIELDLEDGER - EVIDENCE-LEDGER.cob
*> Append-only audit ledger (evidence-ledger.csv) and platform-specific
*> SHA-256 integrity adapter integration (manifest / verify).
*> Note: Append-only logging provides an audit trail; it does NOT claim
*> cryptographic immutability on its own.
*> =====================================================================
IDENTIFICATION DIVISION.
PROGRAM-ID. EVIDENCE-LEDGER.

ENVIRONMENT DIVISION.
INPUT-OUTPUT SECTION.
FILE-CONTROL.
    SELECT F-LEDGER ASSIGN TO DYNAMIC WS-LEDGER-PATH
        ORGANIZATION IS LINE SEQUENTIAL
        FILE STATUS IS WS-FS.

DATA DIVISION.
FILE SECTION.
FD F-LEDGER.
01 F-LEDGER-REC             PIC X(2048).

WORKING-STORAGE SECTION.
COPY "LIMITS.cpy".
COPY "RUN-CONFIG.cpy".
COPY "STUDY-RECORD.cpy".
COPY "SOURCE-RECORD.cpy".
COPY "SITE-RECORD.cpy".
COPY "SURVEY-RECORD.cpy".
COPY "OBSERVATION-RECORD.cpy".
COPY "ERROR-RECORD.cpy".
COPY "UTILS-IFACE.cpy".

01 WS-LEDGER-PATH           PIC X(512).
01 WS-FS                    PIC XX.
01 WS-FILE-INFO.
   05 WS-FI-SIZE            PIC X(8) COMP-X.
   05 WS-FI-DATE            PIC X(4).
   05 WS-FI-TIME            PIC X(4).
01 WS-LINE                  PIC X(2048).
01 WS-POS                   PIC 9(6) COMP-5.
01 WS-REJ-TOTAL             PIC 9(9) COMP-5.
01 WS-VAL-OUTCOME           PIC X(16).
01 WS-OUT-FILES             PIC X(256).
01 WS-RECEIPT-NAME          PIC X(64).
01 WS-SCRIPT-PATH           PIC X(512).
01 WS-SYS-CMD               PIC X(1536).
01 WS-SYS-RC                PIC S9(9) COMP-5.
01 WS-SAFE-PATH             PIC X(1).
01 WS-I                     PIC 9(6) COMP-5.
01 WS-LEN                   PIC 9(6) COMP-5.
01 WS-CH                    PIC X(1).
01 WS-CSV-TMP               PIC X(512).

LINKAGE SECTION.
01 L-LED-OP                 PIC X(24).
01 L-LED-RC                 PIC S9(4) COMP-5.

PROCEDURE DIVISION USING L-LED-OP L-LED-RC.
MAIN-LEDGER.
    MOVE FL-EXIT-OK TO L-LED-RC
    EVALUATE FUNCTION TRIM(L-LED-OP)
        WHEN "APPEND-RUN"
            PERFORM DO-APPEND-RUN
        WHEN "RUN-MANIFEST"
            PERFORM DO-RUN-MANIFEST
        WHEN "RUN-VERIFY"
            PERFORM DO-RUN-VERIFY
        WHEN OTHER
            MOVE FL-EXIT-CLI-ERR TO L-LED-RC
    END-EVALUATE
    GOBACK.

DO-APPEND-RUN.
    INITIALIZE CFG-REQ
    MOVE "ENSURE-DIR" TO CREQ-OP
    MOVE CFG-OUT-PATH TO CREQ-PATH-A
    CALL "CONFIGURATION" USING CFG-REQ

    INITIALIZE CFG-REQ
    MOVE "JOIN-PATH"           TO CREQ-OP
    MOVE CFG-OUT-PATH          TO CREQ-PATH-A
    MOVE "evidence-ledger.csv" TO CREQ-PATH-B
    CALL "CONFIGURATION" USING CFG-REQ
    MOVE CREQ-PATH-OUT TO WS-LEDGER-PATH

    CALL "CBL_CHECK_FILE_EXIST" USING WS-LEDGER-PATH WS-FILE-INFO
    IF RETURN-CODE NOT = 0
        OPEN OUTPUT F-LEDGER
        IF WS-FS NOT = "00"
            STRING "Failed to create evidence-ledger.csv (status " WS-FS ")"
                   DELIMITED BY SIZE INTO CFG-ERROR-MSG
            END-STRING
            MOVE FL-EXIT-IO-ERR TO L-LED-RC
            EXIT PARAGRAPH
        END-IF
        MOVE SPACES TO F-LEDGER-REC
        STRING "run_id,timestamp,software_version,compiler_version,study_id,"
               "command,analysis_type,study_path,out_path,active_method,"
               "species_filter,seed,bootstrap_iterations,sources_valid,"
               "sites_valid,surveys_valid,observations_valid,rejected_total,"
               "errors_count,warnings_count,validation_outcome,"
               "manifest_status,manifest_date,receipt_file,output_files"
               DELIMITED BY SIZE INTO F-LEDGER-REC
        END-STRING
        WRITE F-LEDGER-REC
        IF WS-FS NOT = "00"
            CLOSE F-LEDGER
            MOVE FL-EXIT-IO-ERR TO L-LED-RC
            EXIT PARAGRAPH
        END-IF
        CLOSE F-LEDGER
    END-IF

    COMPUTE WS-REJ-TOTAL = STUDY-REJECTED-ROWS + SRC-REJECTED-ROWS
                         + SITE-REJECTED-ROWS  + SURV-REJECTED-ROWS
                         + OBS-REJECTED-ROWS

    IF ERR-ERROR-CNT > 0
        MOVE "FAILED" TO WS-VAL-OUTCOME
        MOVE "NONE"   TO WS-RECEIPT-NAME
        MOVE "validation-report.csv;data-quality.csv" TO WS-OUT-FILES
    ELSE
        MOVE "PASSED" TO WS-VAL-OUTCOME
        IF FUNCTION TRIM(CFG-ANALYSIS-TYPE) = "BACI"
            MOVE "research-receipt.json" TO WS-RECEIPT-NAME
            MOVE "validation-report.csv;data-quality.csv;baci-results.csv;site-summaries.csv;research-receipt.json;report.md;report.html"
                TO WS-OUT-FILES
        ELSE
            MOVE "NONE" TO WS-RECEIPT-NAME
            MOVE "validation-report.csv;data-quality.csv" TO WS-OUT-FILES
        END-IF
    END-IF

    MOVE SPACES TO WS-LINE
    MOVE 1 TO WS-POS

    MOVE CFG-RUN-ID        TO WS-CSV-TMP PERFORM APPEND-CSV-FIRST
    MOVE CFG-RUN-TIMESTAMP TO WS-CSV-TMP PERFORM APPEND-CSV-NEXT
    MOVE FL-APP-VERSION    TO WS-CSV-TMP PERFORM APPEND-CSV-NEXT
    MOVE FL-COMPILER-LABEL TO WS-CSV-TMP PERFORM APPEND-CSV-NEXT
    IF FUNCTION TRIM(ST-STUDY-ID) = SPACES
        MOVE "UNKNOWN"     TO WS-CSV-TMP
    ELSE
        MOVE ST-STUDY-ID   TO WS-CSV-TMP
    END-IF
    PERFORM APPEND-CSV-NEXT
    MOVE CFG-COMMAND       TO WS-CSV-TMP PERFORM APPEND-CSV-NEXT
    MOVE CFG-ANALYSIS-TYPE TO WS-CSV-TMP PERFORM APPEND-CSV-NEXT
    MOVE CFG-STUDY-PATH    TO WS-CSV-TMP PERFORM APPEND-CSV-NEXT
    MOVE CFG-OUT-PATH      TO WS-CSV-TMP PERFORM APPEND-CSV-NEXT
    MOVE CFG-ACTIVE-METHOD TO WS-CSV-TMP PERFORM APPEND-CSV-NEXT
    IF FUNCTION TRIM(CFG-SPECIES-FILTER) = SPACES
        MOVE "ALL" TO WS-CSV-TMP
    ELSE
        MOVE CFG-SPECIES-FILTER TO WS-CSV-TMP
    END-IF
    PERFORM APPEND-CSV-NEXT

    MOVE CFG-SEED          TO NREQ-INT-VAL PERFORM APPEND-INT-NEXT
    MOVE CFG-BOOTSTRAP     TO NREQ-INT-VAL PERFORM APPEND-INT-NEXT
    MOVE SRC-COUNT         TO NREQ-INT-VAL PERFORM APPEND-INT-NEXT
    MOVE SITE-COUNT        TO NREQ-INT-VAL PERFORM APPEND-INT-NEXT
    MOVE SURV-COUNT        TO NREQ-INT-VAL PERFORM APPEND-INT-NEXT
    MOVE OBS-COUNT         TO NREQ-INT-VAL PERFORM APPEND-INT-NEXT
    MOVE WS-REJ-TOTAL      TO NREQ-INT-VAL PERFORM APPEND-INT-NEXT
    MOVE ERR-ERROR-CNT     TO NREQ-INT-VAL PERFORM APPEND-INT-NEXT
    MOVE ERR-WARN-CNT      TO NREQ-INT-VAL PERFORM APPEND-INT-NEXT

    MOVE WS-VAL-OUTCOME      TO WS-CSV-TMP PERFORM APPEND-CSV-NEXT
    MOVE CFG-MANIFEST-STATUS TO WS-CSV-TMP PERFORM APPEND-CSV-NEXT
    MOVE CFG-MANIFEST-DATE   TO WS-CSV-TMP PERFORM APPEND-CSV-NEXT
    MOVE WS-RECEIPT-NAME     TO WS-CSV-TMP PERFORM APPEND-CSV-NEXT
    MOVE WS-OUT-FILES        TO WS-CSV-TMP PERFORM APPEND-CSV-NEXT

    OPEN EXTEND F-LEDGER
    IF WS-FS NOT = "00"
        STRING "Failed to open evidence-ledger.csv for append (status " WS-FS ")"
               DELIMITED BY SIZE INTO CFG-ERROR-MSG
        END-STRING
        MOVE FL-EXIT-IO-ERR TO L-LED-RC
        EXIT PARAGRAPH
    END-IF

    MOVE WS-LINE TO F-LEDGER-REC
    WRITE F-LEDGER-REC
    IF WS-FS NOT = "00"
        CLOSE F-LEDGER
        STRING "Failed to append run record to evidence-ledger.csv (status "
               WS-FS ")" DELIMITED BY SIZE INTO CFG-ERROR-MSG
        END-STRING
        MOVE FL-EXIT-IO-ERR TO L-LED-RC
        EXIT PARAGRAPH
    END-IF
    CLOSE F-LEDGER
    .

APPEND-CSV-FIRST.
    INITIALIZE NUM-REQ
    MOVE "ESC-CSV"  TO NREQ-OP
    MOVE WS-CSV-TMP TO NREQ-TEXT-IN
    CALL "NUMERIC-UTILS" USING NUM-REQ
    IF NREQ-OUT-LEN > 0
        MOVE NREQ-TEXT-OUT(1:NREQ-OUT-LEN) TO WS-LINE(WS-POS:NREQ-OUT-LEN)
        ADD NREQ-OUT-LEN TO WS-POS
    END-IF
    .

APPEND-CSV-NEXT.
    MOVE "," TO WS-LINE(WS-POS:1)
    ADD 1 TO WS-POS
    INITIALIZE NUM-REQ
    MOVE "ESC-CSV"  TO NREQ-OP
    MOVE WS-CSV-TMP TO NREQ-TEXT-IN
    CALL "NUMERIC-UTILS" USING NUM-REQ
    IF NREQ-OUT-LEN > 0 AND (WS-POS + NREQ-OUT-LEN) <= 2048
        MOVE NREQ-TEXT-OUT(1:NREQ-OUT-LEN) TO WS-LINE(WS-POS:NREQ-OUT-LEN)
        ADD NREQ-OUT-LEN TO WS-POS
    END-IF
    .

APPEND-INT-NEXT.
    MOVE "," TO WS-LINE(WS-POS:1)
    ADD 1 TO WS-POS
    MOVE "FMT-INT" TO NREQ-OP
    CALL "NUMERIC-UTILS" USING NUM-REQ
    IF NREQ-OUT-LEN > 0 AND (WS-POS + NREQ-OUT-LEN) <= 2048
        MOVE NREQ-TEXT-OUT(1:NREQ-OUT-LEN) TO WS-LINE(WS-POS:NREQ-OUT-LEN)
        ADD NREQ-OUT-LEN TO WS-POS
    END-IF
    .

DO-RUN-MANIFEST.
    PERFORM CHECK-PATH-SAFETY
    IF WS-SAFE-PATH = "N"
        MOVE FL-EXIT-CLI-ERR TO L-LED-RC
        EXIT PARAGRAPH
    END-IF

    MOVE SPACES TO WS-SCRIPT-PATH
    MOVE SPACES TO WS-SYS-CMD
    IF CFG-IS-WINDOWS = "Y"
        STRING FUNCTION TRIM(CFG-REPO-DIR) "\scripts\manifest.ps1"
               DELIMITED BY SIZE INTO WS-SCRIPT-PATH
        END-STRING
        CALL "CBL_CHECK_FILE_EXIST" USING WS-SCRIPT-PATH WS-FILE-INFO
        IF RETURN-CODE NOT = 0
            STRING "Integrity adapter script not found: "
                   FUNCTION TRIM(WS-SCRIPT-PATH)
                   DELIMITED BY SIZE INTO CFG-ERROR-MSG
            END-STRING
            MOVE FL-EXIT-IO-ERR TO L-LED-RC
            EXIT PARAGRAPH
        END-IF
        STRING 'powershell -NoProfile -ExecutionPolicy Bypass -File "'
               FUNCTION TRIM(WS-SCRIPT-PATH) '" -StudyPath "'
               FUNCTION TRIM(CFG-STUDY-PATH) '"'
               DELIMITED BY SIZE INTO WS-SYS-CMD
        END-STRING
    ELSE
        STRING FUNCTION TRIM(CFG-REPO-DIR) "/scripts/manifest.sh"
               DELIMITED BY SIZE INTO WS-SCRIPT-PATH
        END-STRING
        CALL "CBL_CHECK_FILE_EXIST" USING WS-SCRIPT-PATH WS-FILE-INFO
        IF RETURN-CODE NOT = 0
            STRING "Integrity adapter script not found: "
                   FUNCTION TRIM(WS-SCRIPT-PATH)
                   DELIMITED BY SIZE INTO CFG-ERROR-MSG
            END-STRING
            MOVE FL-EXIT-IO-ERR TO L-LED-RC
            EXIT PARAGRAPH
        END-IF
        STRING 'sh "' FUNCTION TRIM(WS-SCRIPT-PATH) '" "'
               FUNCTION TRIM(CFG-STUDY-PATH) '"'
               DELIMITED BY SIZE INTO WS-SYS-CMD
        END-STRING
    END-IF

    CALL "SYSTEM" USING FUNCTION TRIM(WS-SYS-CMD)
    MOVE RETURN-CODE TO WS-SYS-RC
    IF WS-SYS-RC NOT = 0
        MOVE "SHA-256 manifest generation failed." TO CFG-ERROR-MSG
        MOVE FL-EXIT-INTEGRITY-ERR TO L-LED-RC
    ELSE
        MOVE FL-EXIT-OK TO L-LED-RC
    END-IF
    .

DO-RUN-VERIFY.
    PERFORM CHECK-PATH-SAFETY
    IF WS-SAFE-PATH = "N"
        MOVE FL-EXIT-CLI-ERR TO L-LED-RC
        EXIT PARAGRAPH
    END-IF

    MOVE SPACES TO WS-SCRIPT-PATH
    MOVE SPACES TO WS-SYS-CMD
    IF CFG-IS-WINDOWS = "Y"
        STRING FUNCTION TRIM(CFG-REPO-DIR) "\scripts\verify.ps1"
               DELIMITED BY SIZE INTO WS-SCRIPT-PATH
        END-STRING
        CALL "CBL_CHECK_FILE_EXIST" USING WS-SCRIPT-PATH WS-FILE-INFO
        IF RETURN-CODE NOT = 0
            STRING "Integrity verification script not found: "
                   FUNCTION TRIM(WS-SCRIPT-PATH)
                   DELIMITED BY SIZE INTO CFG-ERROR-MSG
            END-STRING
            MOVE FL-EXIT-IO-ERR TO L-LED-RC
            EXIT PARAGRAPH
        END-IF
        STRING 'powershell -NoProfile -ExecutionPolicy Bypass -File "'
               FUNCTION TRIM(WS-SCRIPT-PATH) '" -StudyPath "'
               FUNCTION TRIM(CFG-STUDY-PATH) '"'
               DELIMITED BY SIZE INTO WS-SYS-CMD
        END-STRING
    ELSE
        STRING FUNCTION TRIM(CFG-REPO-DIR) "/scripts/verify.sh"
               DELIMITED BY SIZE INTO WS-SCRIPT-PATH
        END-STRING
        CALL "CBL_CHECK_FILE_EXIST" USING WS-SCRIPT-PATH WS-FILE-INFO
        IF RETURN-CODE NOT = 0
            STRING "Integrity verification script not found: "
                   FUNCTION TRIM(WS-SCRIPT-PATH)
                   DELIMITED BY SIZE INTO CFG-ERROR-MSG
            END-STRING
            MOVE FL-EXIT-IO-ERR TO L-LED-RC
            EXIT PARAGRAPH
        END-IF
        STRING 'sh "' FUNCTION TRIM(WS-SCRIPT-PATH) '" "'
               FUNCTION TRIM(CFG-STUDY-PATH) '"'
               DELIMITED BY SIZE INTO WS-SYS-CMD
        END-STRING
    END-IF

    CALL "SYSTEM" USING FUNCTION TRIM(WS-SYS-CMD)
    MOVE RETURN-CODE TO WS-SYS-RC
    IF WS-SYS-RC NOT = 0
        MOVE "SHA-256 manifest verification FAILED: study files do not match manifest."
            TO CFG-ERROR-MSG
        MOVE FL-EXIT-INTEGRITY-ERR TO L-LED-RC
    ELSE
        MOVE FL-EXIT-OK TO L-LED-RC
    END-IF
    .

CHECK-PATH-SAFETY.
    MOVE "Y" TO WS-SAFE-PATH
    MOVE FUNCTION LENGTH(FUNCTION TRIM(CFG-STUDY-PATH)) TO WS-LEN
    PERFORM VARYING WS-I FROM 1 BY 1 UNTIL WS-I > WS-LEN
        MOVE CFG-STUDY-PATH(WS-I:1) TO WS-CH
        IF WS-CH = '"' OR WS-CH = "`" OR WS-CH = ";" OR WS-CH = "|"
            OR WS-CH = "&" OR WS-CH = "$"
            MOVE "N" TO WS-SAFE-PATH
            MOVE "Study path contains unsafe shell metacharacters"
                TO CFG-ERROR-MSG
            EXIT PERFORM
        END-IF
    END-PERFORM
    .
