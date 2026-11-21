>>SOURCE FORMAT FREE
*> =====================================================================
*> FIELDLEDGER - RUN-RECEIPT.cob
*> Verifies research-receipt.json against study.csv and reloads the
*> corresponding verified CSV outputs (baci-results.csv, site-summaries.csv,
*> data-quality.csv, validation-report.csv) for 'fieldledger report'.
*> Never regenerates reports from unidentified or mismatched data.
*> =====================================================================
IDENTIFICATION DIVISION.
PROGRAM-ID. RUN-RECEIPT.

ENVIRONMENT DIVISION.
INPUT-OUTPUT SECTION.
FILE-CONTROL.
    SELECT F-IN ASSIGN TO DYNAMIC WS-FILE-PATH
        ORGANIZATION IS LINE SEQUENTIAL
        FILE STATUS IS WS-FS.

DATA DIVISION.
FILE SECTION.
FD F-IN.
01 F-IN-REC                 PIC X(4096).

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
COPY "CSV-WORK.cpy".
COPY "UTILS-IFACE.cpy".

01 WS-FILE-PATH             PIC X(512).
01 WS-FS                    PIC XX.
01 WS-EOF                   PIC X(1).
01 WS-ROW-NUM               PIC 9(9) COMP-5.
01 WS-REC-LINE              PIC X(4096).
01 WS-TRIM                  PIC X(4096).
01 WS-KEY-NEEDLE            PIC X(64).
01 WS-EXTRACTED             PIC X(512).
01 WS-APP-OK                PIC X(1).
01 WS-REC-STUDY-ID          PIC X(64).
01 WS-REC-VAL-OUT           PIC X(32).
01 WS-POS                   PIC 9(6) COMP-5.
01 WS-LEN                   PIC 9(6) COMP-5.
01 WS-I                     PIC 9(6) COMP-5.
01 WS-OUT-I                 PIC 9(6) COMP-5.
01 WS-CH                    PIC X(1).
01 WS-ESC-NEXT              PIC X(1).
01 WS-DUP-OP                PIC X(24).
01 WS-PARSE-TMP             PIC X(64).

LINKAGE SECTION.
01 L-REC-OP                 PIC X(24).
01 L-REC-RC                 PIC S9(4) COMP-5.

PROCEDURE DIVISION USING L-REC-OP L-REC-RC.
MAIN-RECEIPT.
    MOVE FL-EXIT-OK TO L-REC-RC
    IF FUNCTION TRIM(L-REC-OP) NOT = "LOAD-FOR-REPORT"
        MOVE FL-EXIT-CLI-ERR TO L-REC-RC
        GOBACK
    END-IF

    *> Clear stores before loading authoritative study metadata & receipt
    INITIALIZE ERR-REQ
    MOVE "CLEAR" TO EREQ-OP
    CALL "ERROR-HANDLING" USING ERR-REQ

    MOVE 0 TO BACI-COUNT
    MOVE 0 TO SSUM-COUNT
    MOVE "N" TO SSUM-TRUNCATED
    MOVE "EFFORT_RATE_V1"        TO DMS-MODEL-ID
    MOVE "OBSERVATION_RATE_ONLY" TO DMS-STATE-ESTIMATED
    MOVE "FALSE"                 TO DMS-DETECTION-CORR
    MOVE "OCCUPANCY_EXT_V2"      TO DMS-OCCUPANCY-HOOK

    *> 1. Validate study.csv and sources.csv from --study for identity & provenance
    CALL "VALIDATE-STUDY"
    IF STUDY-LOADED NOT = "Y" OR ERR-ERROR-CNT > 0
        MOVE "Cannot generate report: study.csv in --study is missing or invalid."
            TO CFG-ERROR-MSG
        MOVE FL-EXIT-VAL-ERR TO L-REC-RC
        GOBACK
    END-IF

    CALL "VALIDATE-SOURCES"
    MOVE "INDEX-SOURCES" TO WS-DUP-OP
    CALL "DUPLICATE-DETECTION" USING WS-DUP-OP

    *> 2. Read and verify research-receipt.json
    PERFORM LOAD-AND-VERIFY-RECEIPT
    IF L-REC-RC NOT = FL-EXIT-OK
        GOBACK
    END-IF

    *> 3. Reload verified CSV outputs referenced by the receipt
    PERFORM LOAD-DATA-QUALITY-CSV
    IF L-REC-RC NOT = FL-EXIT-OK
        GOBACK
    END-IF

    PERFORM LOAD-VALIDATION-CSV
    IF L-REC-RC NOT = FL-EXIT-OK
        GOBACK
    END-IF

    PERFORM LOAD-BACI-CSV
    IF L-REC-RC NOT = FL-EXIT-OK
        GOBACK
    END-IF

    PERFORM LOAD-SITE-SUM-CSV
    GOBACK.

LOAD-AND-VERIFY-RECEIPT.
    INITIALIZE CFG-REQ
    MOVE "JOIN-PATH"             TO CREQ-OP
    MOVE CFG-OUT-PATH            TO CREQ-PATH-A
    MOVE "research-receipt.json" TO CREQ-PATH-B
    CALL "CONFIGURATION" USING CFG-REQ
    MOVE CREQ-PATH-OUT TO WS-FILE-PATH

    OPEN INPUT F-IN
    IF WS-FS NOT = "00"
        STRING "Cannot open research-receipt.json in '"
               FUNCTION TRIM(CFG-OUT-PATH)
               "'; run 'analyze baci' before 'report'."
               DELIMITED BY SIZE INTO CFG-ERROR-MSG
        END-STRING
        MOVE FL-EXIT-INTEGRITY-ERR TO L-REC-RC
        EXIT PARAGRAPH
    END-IF

    MOVE "N" TO WS-APP-OK
    MOVE SPACES TO WS-REC-STUDY-ID
    MOVE SPACES TO WS-REC-VAL-OUT
    MOVE "N" TO WS-EOF

    PERFORM UNTIL WS-EOF = "Y"
        MOVE SPACES TO F-IN-REC
        READ F-IN
            AT END
                MOVE "Y" TO WS-EOF
            NOT AT END
                MOVE FUNCTION TRIM(F-IN-REC) TO WS-TRIM
                IF WS-TRIM(1:15) = '"application": '
                    PERFORM EXTRACT-JSON-STR
                    IF FUNCTION TRIM(WS-EXTRACTED) = "FIELDLEDGER"
                        MOVE "Y" TO WS-APP-OK
                    END-IF
                END-IF
                IF WS-TRIM(1:12) = '"study_id": '
                    PERFORM EXTRACT-JSON-STR
                    MOVE WS-EXTRACTED TO WS-REC-STUDY-ID
                END-IF
                IF WS-TRIM(1:10) = '"run_id": '
                    PERFORM EXTRACT-JSON-STR
                    MOVE WS-EXTRACTED TO CFG-RUN-ID
                END-IF
                IF WS-TRIM(1:13) = '"timestamp": '
                    PERFORM EXTRACT-JSON-STR
                    MOVE WS-EXTRACTED TO CFG-RUN-TIMESTAMP
                END-IF
                IF WS-TRIM(1:17) = '"analysis_type": '
                    PERFORM EXTRACT-JSON-STR
                    MOVE WS-EXTRACTED TO CFG-ANALYSIS-TYPE
                END-IF
                IF WS-TRIM(1:22) = '"validation_outcome": '
                    PERFORM EXTRACT-JSON-STR
                    MOVE WS-EXTRACTED TO WS-REC-VAL-OUT
                END-IF
                IF WS-TRIM(1:17) = '"active_method": '
                    PERFORM EXTRACT-JSON-STR
                    MOVE WS-EXTRACTED TO CFG-ACTIVE-METHOD
                END-IF
                IF WS-TRIM(1:18) = '"species_filter": '
                    PERFORM EXTRACT-JSON-STR
                    IF FUNCTION TRIM(WS-EXTRACTED) NOT = "null"
                        MOVE WS-EXTRACTED TO CFG-SPECIES-FILTER
                    END-IF
                END-IF
                IF WS-TRIM(1:10) = '"status": '
                    PERFORM EXTRACT-JSON-STR
                    MOVE WS-EXTRACTED TO CFG-MANIFEST-STATUS
                END-IF
                IF WS-TRIM(1:18) = '"generated_date": '
                    PERFORM EXTRACT-JSON-STR
                    IF FUNCTION TRIM(WS-EXTRACTED) NOT = "null"
                        MOVE WS-EXTRACTED TO CFG-MANIFEST-DATE
                    END-IF
                END-IF
                IF WS-TRIM(1:8) = '"seed": '
                    PERFORM EXTRACT-JSON-NUM
                    INITIALIZE NUM-REQ
                    MOVE "PARSE-INT" TO NREQ-OP
                    MOVE WS-EXTRACTED TO NREQ-TEXT-IN
                    MOVE 11 TO NREQ-MAX-INT-DIGITS
                    MOVE "Y" TO NREQ-ALLOW-ZERO
                    MOVE "N" TO NREQ-ALLOW-NEG
                    CALL "NUMERIC-UTILS" USING NUM-REQ
                    IF NREQ-VALID = "Y"
                        MOVE NREQ-INT-VAL TO CFG-SEED
                    END-IF
                END-IF
                IF WS-TRIM(1:14) = '"iterations": '
                    PERFORM EXTRACT-JSON-NUM
                    INITIALIZE NUM-REQ
                    MOVE "PARSE-INT" TO NREQ-OP
                    MOVE WS-EXTRACTED TO NREQ-TEXT-IN
                    MOVE 7 TO NREQ-MAX-INT-DIGITS
                    MOVE "Y" TO NREQ-ALLOW-ZERO
                    MOVE "N" TO NREQ-ALLOW-NEG
                    CALL "NUMERIC-UTILS" USING NUM-REQ
                    IF NREQ-VALID = "Y"
                        MOVE NREQ-INT-VAL TO CFG-BOOTSTRAP
                    END-IF
                END-IF
        END-READ
    END-PERFORM
    CLOSE F-IN

    IF WS-APP-OK NOT = "Y" OR FUNCTION TRIM(WS-REC-STUDY-ID) = SPACES
        MOVE "Malformed or unrecognised research-receipt.json; refusing to generate report."
            TO CFG-ERROR-MSG
        MOVE FL-EXIT-INTEGRITY-ERR TO L-REC-RC
        EXIT PARAGRAPH
    END-IF

    IF FUNCTION TRIM(WS-REC-STUDY-ID) NOT = FUNCTION TRIM(ST-STUDY-ID)
        STRING "Receipt mismatch: research-receipt.json belongs to study_id '"
               FUNCTION TRIM(WS-REC-STUDY-ID) "' but --study has study_id '"
               FUNCTION TRIM(ST-STUDY-ID) "'. Refusing to generate report."
               DELIMITED BY SIZE INTO CFG-ERROR-MSG
        END-STRING
        MOVE FL-EXIT-INTEGRITY-ERR TO L-REC-RC
        EXIT PARAGRAPH
    END-IF

    IF FUNCTION TRIM(WS-REC-VAL-OUT) NOT = "PASSED"
        MOVE "Refusing to generate analysis report: receipt validation_outcome is not PASSED."
            TO CFG-ERROR-MSG
        MOVE FL-EXIT-INTEGRITY-ERR TO L-REC-RC
        EXIT PARAGRAPH
    END-IF
    .

EXTRACT-JSON-STR.
    MOVE SPACES TO WS-EXTRACTED
    MOVE FUNCTION LENGTH(FUNCTION TRIM(WS-TRIM)) TO WS-LEN
    *> Find ':' then opening '"'
    MOVE 0 TO WS-POS
    PERFORM VARYING WS-I FROM 1 BY 1 UNTIL WS-I > WS-LEN
        IF WS-TRIM(WS-I:1) = ":"
            MOVE WS-I TO WS-POS
            EXIT PERFORM
        END-IF
    END-PERFORM
    IF WS-POS = 0
        EXIT PARAGRAPH
    END-IF
    ADD 1 TO WS-POS
    PERFORM UNTIL WS-POS > WS-LEN OR WS-TRIM(WS-POS:1) NOT = " "
        ADD 1 TO WS-POS
    END-PERFORM
    IF WS-POS > WS-LEN
        EXIT PARAGRAPH
    END-IF
    IF WS-TRIM(WS-POS:4) = "null"
        MOVE "null" TO WS-EXTRACTED
        EXIT PARAGRAPH
    END-IF
    IF WS-TRIM(WS-POS:1) NOT = '"'
        EXIT PARAGRAPH
    END-IF
    ADD 1 TO WS-POS
    MOVE 0 TO WS-OUT-I
    MOVE "N" TO WS-ESC-NEXT
    PERFORM VARYING WS-I FROM WS-POS BY 1 UNTIL WS-I > WS-LEN
        MOVE WS-TRIM(WS-I:1) TO WS-CH
        IF WS-ESC-NEXT = "Y"
            IF WS-OUT-I < 512
                ADD 1 TO WS-OUT-I
                MOVE WS-CH TO WS-EXTRACTED(WS-OUT-I:1)
            END-IF
            MOVE "N" TO WS-ESC-NEXT
        ELSE
            IF WS-CH = "\"
                MOVE "Y" TO WS-ESC-NEXT
            ELSE
                IF WS-CH = '"'
                    EXIT PERFORM
                ELSE
                    IF WS-OUT-I < 512
                        ADD 1 TO WS-OUT-I
                        MOVE WS-CH TO WS-EXTRACTED(WS-OUT-I:1)
                    END-IF
                END-IF
            END-IF
        END-IF
    END-PERFORM
    .

EXTRACT-JSON-NUM.
    MOVE SPACES TO WS-EXTRACTED
    MOVE FUNCTION LENGTH(FUNCTION TRIM(WS-TRIM)) TO WS-LEN
    MOVE 0 TO WS-POS
    PERFORM VARYING WS-I FROM 1 BY 1 UNTIL WS-I > WS-LEN
        IF WS-TRIM(WS-I:1) = ":"
            MOVE WS-I TO WS-POS
            EXIT PERFORM
        END-IF
    END-PERFORM
    IF WS-POS = 0
        EXIT PARAGRAPH
    END-IF
    ADD 1 TO WS-POS
    PERFORM UNTIL WS-POS > WS-LEN OR WS-TRIM(WS-POS:1) NOT = " "
        ADD 1 TO WS-POS
    END-PERFORM
    MOVE 0 TO WS-OUT-I
    PERFORM VARYING WS-I FROM WS-POS BY 1 UNTIL WS-I > WS-LEN
        MOVE WS-TRIM(WS-I:1) TO WS-CH
        IF (WS-CH >= "0" AND WS-CH <= "9") OR WS-CH = "-" OR WS-CH = "."
            IF WS-OUT-I < 64
                ADD 1 TO WS-OUT-I
                MOVE WS-CH TO WS-EXTRACTED(WS-OUT-I:1)
            END-IF
        ELSE
            EXIT PERFORM
        END-IF
    END-PERFORM
    .

LOAD-DATA-QUALITY-CSV.
    INITIALIZE CFG-REQ
    MOVE "JOIN-PATH"        TO CREQ-OP
    MOVE CFG-OUT-PATH       TO CREQ-PATH-A
    MOVE "data-quality.csv" TO CREQ-PATH-B
    CALL "CONFIGURATION" USING CFG-REQ
    MOVE CREQ-PATH-OUT TO WS-FILE-PATH

    OPEN INPUT F-IN
    IF WS-FS NOT = "00"
        MOVE "Missing data-quality.csv referenced by research-receipt.json."
            TO CFG-ERROR-MSG
        MOVE FL-EXIT-INTEGRITY-ERR TO L-REC-RC
        EXIT PARAGRAPH
    END-IF

    MOVE 0 TO SITE-COUNT SITE-IMPACT-TOTAL SITE-CONTROL-TOTAL
    MOVE 0 TO SURV-COUNT SURV-PRE-COUNT SURV-POST-COUNT SURV-TRANS-COUNT
    MOVE 0 TO OBS-COUNT OBS-DETECTED-COUNT OBS-NOT-DET-COUNT OBS-TRANS-EXCL-COUNT
    MOVE 0 TO STUDY-REJECTED-ROWS SRC-REJECTED-ROWS SITE-REJECTED-ROWS
              SURV-REJECTED-ROWS OBS-REJECTED-ROWS
    MOVE "N" TO WS-EOF
    MOVE 0   TO WS-ROW-NUM

    PERFORM UNTIL WS-EOF = "Y"
        MOVE SPACES TO F-IN-REC
        READ F-IN
            AT END MOVE "Y" TO WS-EOF
            NOT AT END
                ADD 1 TO WS-ROW-NUM
                IF WS-ROW-NUM > 1
                    PERFORM PARSE-CSV-LINE
                    IF CSV-OK AND CSV-FIELD-CNT >= 3
                        MOVE FUNCTION TRIM(CSV-F-VAL(3)) TO WS-PARSE-TMP
                        PERFORM PARSE-INT-TMP
                        EVALUATE FUNCTION TRIM(CSV-F-VAL(1))
                            WHEN "sites_valid"
                                MOVE NREQ-INT-VAL TO SITE-COUNT
                            WHEN "sites_impact"
                                MOVE NREQ-INT-VAL TO SITE-IMPACT-TOTAL
                            WHEN "sites_control"
                                MOVE NREQ-INT-VAL TO SITE-CONTROL-TOTAL
                            WHEN "surveys_valid"
                                MOVE NREQ-INT-VAL TO SURV-COUNT
                            WHEN "surveys_pre"
                                MOVE NREQ-INT-VAL TO SURV-PRE-COUNT
                            WHEN "surveys_post"
                                MOVE NREQ-INT-VAL TO SURV-POST-COUNT
                            WHEN "surveys_transition_excluded"
                                MOVE NREQ-INT-VAL TO SURV-TRANS-COUNT
                            WHEN "observations_valid"
                                MOVE NREQ-INT-VAL TO OBS-COUNT
                            WHEN "observations_detected"
                                MOVE NREQ-INT-VAL TO OBS-DETECTED-COUNT
                            WHEN "observations_explicit_zero"
                                MOVE NREQ-INT-VAL TO OBS-NOT-DET-COUNT
                            WHEN "observations_transition_excluded"
                                MOVE NREQ-INT-VAL TO OBS-TRANS-EXCL-COUNT
                            WHEN "records_rejected_total"
                                MOVE NREQ-INT-VAL TO OBS-REJECTED-ROWS
                        END-EVALUATE
                    END-IF
                END-IF
        END-READ
    END-PERFORM
    CLOSE F-IN
    .

LOAD-VALIDATION-CSV.
    INITIALIZE ERR-REQ
    MOVE "CLEAR" TO EREQ-OP
    CALL "ERROR-HANDLING" USING ERR-REQ

    INITIALIZE CFG-REQ
    MOVE "JOIN-PATH"             TO CREQ-OP
    MOVE CFG-OUT-PATH            TO CREQ-PATH-A
    MOVE "validation-report.csv" TO CREQ-PATH-B
    CALL "CONFIGURATION" USING CFG-REQ
    MOVE CREQ-PATH-OUT TO WS-FILE-PATH

    OPEN INPUT F-IN
    IF WS-FS NOT = "00"
        MOVE "Missing validation-report.csv referenced by research-receipt.json."
            TO CFG-ERROR-MSG
        MOVE FL-EXIT-INTEGRITY-ERR TO L-REC-RC
        EXIT PARAGRAPH
    END-IF

    MOVE "N" TO WS-EOF
    MOVE 0   TO WS-ROW-NUM
    PERFORM UNTIL WS-EOF = "Y"
        MOVE SPACES TO F-IN-REC
        READ F-IN
            AT END MOVE "Y" TO WS-EOF
            NOT AT END
                ADD 1 TO WS-ROW-NUM
                IF WS-ROW-NUM > 1
                    PERFORM PARSE-CSV-LINE
                    IF CSV-OK AND CSV-FIELD-CNT >= 6
                        MOVE FUNCTION TRIM(CSV-F-VAL(4)) TO WS-PARSE-TMP
                        PERFORM PARSE-INT-TMP
                        INITIALIZE ERR-REQ
                        MOVE "ADD"                        TO EREQ-OP
                        MOVE FUNCTION TRIM(CSV-F-VAL(1))  TO EREQ-SEVERITY
                        MOVE FUNCTION TRIM(CSV-F-VAL(2))  TO EREQ-CODE
                        MOVE FUNCTION TRIM(CSV-F-VAL(3))  TO EREQ-FILE
                        MOVE NREQ-INT-VAL                 TO EREQ-ROW
                        MOVE FUNCTION TRIM(CSV-F-VAL(5))  TO EREQ-FIELD
                        MOVE FUNCTION TRIM(CSV-F-VAL(6))  TO EREQ-MESSAGE
                        CALL "ERROR-HANDLING" USING ERR-REQ
                    END-IF
                END-IF
        END-READ
    END-PERFORM
    CLOSE F-IN
    .

LOAD-BACI-CSV.
    INITIALIZE CFG-REQ
    MOVE "JOIN-PATH"        TO CREQ-OP
    MOVE CFG-OUT-PATH       TO CREQ-PATH-A
    MOVE "baci-results.csv" TO CREQ-PATH-B
    CALL "CONFIGURATION" USING CFG-REQ
    MOVE CREQ-PATH-OUT TO WS-FILE-PATH

    OPEN INPUT F-IN
    IF WS-FS NOT = "00"
        MOVE "Missing baci-results.csv referenced by research-receipt.json."
            TO CFG-ERROR-MSG
        MOVE FL-EXIT-INTEGRITY-ERR TO L-REC-RC
        EXIT PARAGRAPH
    END-IF

    MOVE 0 TO BACI-COUNT
    MOVE "N" TO WS-EOF
    MOVE 0   TO WS-ROW-NUM

    *> Note: baci-results.csv has 33 columns -> parse directly with custom splitter
    PERFORM UNTIL WS-EOF = "Y"
        MOVE SPACES TO F-IN-REC
        READ F-IN
            AT END MOVE "Y" TO WS-EOF
            NOT AT END
                ADD 1 TO WS-ROW-NUM
                IF WS-ROW-NUM = 1
                    IF F-IN-REC(1:25) NOT = "species_code,method,unit,"
                        CLOSE F-IN
                        MOVE "Invalid baci-results.csv header; refusing report."
                            TO CFG-ERROR-MSG
                        MOVE FL-EXIT-INTEGRITY-ERR TO L-REC-RC
                        EXIT PARAGRAPH
                    END-IF
                ELSE
                    IF FUNCTION TRIM(F-IN-REC) NOT = SPACES
                        AND BACI-COUNT < FL-MAX-SPECIES
                        PERFORM PARSE-BACI-ROW
                    END-IF
                END-IF
        END-READ
    END-PERFORM
    CLOSE F-IN
    .

PARSE-BACI-ROW.
    INITIALIZE NORM-REQ
    MOVE F-IN-REC TO RN-BUF
    MOVE "N" TO RN-IS-FIRST-LINE
    CALL "RECORD-NORMALISER" USING NORM-REQ
    IF RN-LEN = 0
        EXIT PARAGRAPH
    END-IF

    ADD 1 TO BACI-COUNT
    INITIALIZE BACI-ITEM(BACI-COUNT)

    MOVE 1 TO WS-POS
    PERFORM NEXT-B-FIELD MOVE WS-EXTRACTED TO BR-SPECIES(BACI-COUNT)
    PERFORM NEXT-B-FIELD MOVE WS-EXTRACTED TO BR-METHOD(BACI-COUNT)
    PERFORM NEXT-B-FIELD MOVE WS-EXTRACTED TO BR-UNIT(BACI-COUNT)
    PERFORM NEXT-B-FIELD MOVE WS-EXTRACTED(1:1) TO BR-CALCULABLE(BACI-COUNT)
    PERFORM NEXT-B-INT   MOVE NREQ-INT-VAL TO BR-IMP-SITES(BACI-COUNT)
    PERFORM NEXT-B-INT   MOVE NREQ-INT-VAL TO BR-CTRL-SITES(BACI-COUNT)
    PERFORM NEXT-B-INT   MOVE NREQ-INT-VAL TO BR-EXCL-IMP-SITES(BACI-COUNT)
    PERFORM NEXT-B-INT   MOVE NREQ-INT-VAL TO BR-EXCL-CTRL-SITES(BACI-COUNT)
    PERFORM NEXT-B-DEC   MOVE NREQ-DEC-VAL TO BR-IMP-PRE-MEAN(BACI-COUNT)
    PERFORM NEXT-B-DEC   MOVE NREQ-DEC-VAL TO BR-IMP-POST-MEAN(BACI-COUNT)
    PERFORM NEXT-B-DEC   MOVE NREQ-DEC-VAL TO BR-CTRL-PRE-MEAN(BACI-COUNT)
    PERFORM NEXT-B-DEC   MOVE NREQ-DEC-VAL TO BR-CTRL-POST-MEAN(BACI-COUNT)
    PERFORM NEXT-B-DEC   MOVE NREQ-DEC-VAL TO BR-IMP-CHANGE(BACI-COUNT)
    PERFORM NEXT-B-DEC   MOVE NREQ-DEC-VAL TO BR-CTRL-CHANGE(BACI-COUNT)
    PERFORM NEXT-B-DEC   MOVE NREQ-DEC-VAL TO BR-BACI-EST(BACI-COUNT)
    PERFORM NEXT-B-INT   MOVE NREQ-INT-VAL TO BR-SURVEYS-USED(BACI-COUNT)
    PERFORM NEXT-B-INT   MOVE NREQ-INT-VAL TO BR-SURVEYS-ELIGIBLE(BACI-COUNT)
    PERFORM NEXT-B-INT   MOVE NREQ-INT-VAL TO BR-OBS-USED(BACI-COUNT)
    PERFORM NEXT-B-INT   MOVE NREQ-INT-VAL TO BR-OBS-EXPLICIT-ZERO(BACI-COUNT)
    PERFORM NEXT-B-INT   MOVE NREQ-INT-VAL TO BR-OBS-MISSING(BACI-COUNT)
    PERFORM NEXT-B-INT   MOVE NREQ-INT-VAL TO BR-OBS-TRANS-EXCL(BACI-COUNT)
    PERFORM NEXT-B-DEC   MOVE NREQ-DEC-VAL TO BR-COVERAGE-PCT(BACI-COUNT)
    PERFORM NEXT-B-INT   MOVE NREQ-INT-VAL TO BR-BOOT-SEED(BACI-COUNT)
    PERFORM NEXT-B-INT   MOVE NREQ-INT-VAL TO BR-BOOT-ITERS(BACI-COUNT)
    PERFORM NEXT-B-INT   MOVE NREQ-INT-VAL TO BR-BOOT-REPS(BACI-COUNT)
    PERFORM NEXT-B-FIELD MOVE WS-EXTRACTED TO BR-CI-STATUS(BACI-COUNT)
    PERFORM NEXT-B-DEC   MOVE NREQ-DEC-VAL TO BR-CI-LOW(BACI-COUNT)
    PERFORM NEXT-B-DEC   MOVE NREQ-DEC-VAL TO BR-CI-HIGH(BACI-COUNT)
    PERFORM NEXT-B-FIELD MOVE WS-EXTRACTED TO BR-LOSO-STATUS(BACI-COUNT)
    PERFORM NEXT-B-DEC   MOVE NREQ-DEC-VAL TO BR-LOSO-MIN(BACI-COUNT)
    PERFORM NEXT-B-DEC   MOVE NREQ-DEC-VAL TO BR-LOSO-MAX(BACI-COUNT)
    PERFORM NEXT-B-FIELD MOVE WS-EXTRACTED TO BR-LOSO-SITE(BACI-COUNT)
    PERFORM NEXT-B-FIELD MOVE WS-EXTRACTED TO BR-WARNINGS(BACI-COUNT)
    .

LOAD-SITE-SUM-CSV.
    INITIALIZE CFG-REQ
    MOVE "JOIN-PATH"          TO CREQ-OP
    MOVE CFG-OUT-PATH         TO CREQ-PATH-A
    MOVE "site-summaries.csv" TO CREQ-PATH-B
    CALL "CONFIGURATION" USING CFG-REQ
    MOVE CREQ-PATH-OUT TO WS-FILE-PATH

    OPEN INPUT F-IN
    IF WS-FS NOT = "00"
        EXIT PARAGRAPH
    END-IF

    MOVE 0 TO SSUM-COUNT
    MOVE "N" TO WS-EOF
    MOVE 0   TO WS-ROW-NUM

    PERFORM UNTIL WS-EOF = "Y"
        MOVE SPACES TO F-IN-REC
        READ F-IN
            AT END MOVE "Y" TO WS-EOF
            NOT AT END
                ADD 1 TO WS-ROW-NUM
                IF WS-ROW-NUM > 1 AND FUNCTION TRIM(F-IN-REC) NOT = SPACES
                    AND SSUM-COUNT < FL-MAX-SITE-SUMS
                    INITIALIZE NORM-REQ
                    MOVE F-IN-REC TO RN-BUF
                    MOVE "N" TO RN-IS-FIRST-LINE
                    CALL "RECORD-NORMALISER" USING NORM-REQ
                    IF RN-LEN > 0
                        ADD 1 TO SSUM-COUNT
                        INITIALIZE SSUM-ITEM(SSUM-COUNT)
                        MOVE 1 TO WS-POS
                        PERFORM NEXT-B-FIELD MOVE WS-EXTRACTED TO SS-SPECIES(SSUM-COUNT)
                        PERFORM NEXT-B-FIELD MOVE WS-EXTRACTED TO SS-METHOD(SSUM-COUNT)
                        PERFORM NEXT-B-FIELD MOVE WS-EXTRACTED TO SS-SITE-ID(SSUM-COUNT)
                        PERFORM NEXT-B-FIELD MOVE WS-EXTRACTED TO SS-SITE-ROLE(SSUM-COUNT)
                        PERFORM NEXT-B-INT   MOVE NREQ-INT-VAL TO SS-PRE-SURVEYS(SSUM-COUNT)
                        PERFORM NEXT-B-INT   MOVE NREQ-INT-VAL TO SS-POST-SURVEYS(SSUM-COUNT)
                        PERFORM NEXT-B-INT   MOVE NREQ-INT-VAL TO SS-TRANS-SURVEYS(SSUM-COUNT)
                        PERFORM NEXT-B-INT   MOVE NREQ-INT-VAL TO SS-PRE-OBS(SSUM-COUNT)
                        PERFORM NEXT-B-INT   MOVE NREQ-INT-VAL TO SS-POST-OBS(SSUM-COUNT)
                        PERFORM NEXT-B-INT   MOVE NREQ-INT-VAL TO SS-TRANS-OBS(SSUM-COUNT)
                        PERFORM NEXT-B-INT   MOVE NREQ-INT-VAL TO SS-ZERO-OBS(SSUM-COUNT)
                        PERFORM NEXT-B-INT   MOVE NREQ-INT-VAL TO SS-MISSING-OBS(SSUM-COUNT)
                        PERFORM NEXT-B-DEC   MOVE NREQ-DEC-VAL TO SS-PRE-MEAN(SSUM-COUNT)
                        PERFORM NEXT-B-DEC   MOVE NREQ-DEC-VAL TO SS-POST-MEAN(SSUM-COUNT)
                        PERFORM NEXT-B-DEC   MOVE NREQ-DEC-VAL TO SS-SITE-CHANGE(SSUM-COUNT)
                        PERFORM NEXT-B-DEC   MOVE NREQ-DEC-VAL TO SS-COVERAGE-PCT(SSUM-COUNT)
                        PERFORM NEXT-B-FIELD MOVE WS-EXTRACTED TO SS-STATUS(SSUM-COUNT)
                    END-IF
                END-IF
        END-READ
    END-PERFORM
    CLOSE F-IN
    .

NEXT-B-FIELD.
    MOVE SPACES TO WS-EXTRACTED
    MOVE 0 TO WS-OUT-I
    IF WS-POS > RN-LEN
        EXIT PARAGRAPH
    END-IF
    IF RN-BUF(WS-POS:1) = '"'
        ADD 1 TO WS-POS
        PERFORM UNTIL WS-POS > RN-LEN
            IF RN-BUF(WS-POS:1) = '"'
                IF WS-POS < RN-LEN AND RN-BUF(WS-POS + 1:1) = '"'
                    IF WS-OUT-I < 512
                        ADD 1 TO WS-OUT-I
                        MOVE '"' TO WS-EXTRACTED(WS-OUT-I:1)
                    END-IF
                    ADD 2 TO WS-POS
                ELSE
                    ADD 1 TO WS-POS
                    IF WS-POS <= RN-LEN AND RN-BUF(WS-POS:1) = ","
                        ADD 1 TO WS-POS
                    END-IF
                    EXIT PERFORM
                END-IF
            ELSE
                IF WS-OUT-I < 512
                    ADD 1 TO WS-OUT-I
                    MOVE RN-BUF(WS-POS:1) TO WS-EXTRACTED(WS-OUT-I:1)
                END-IF
                ADD 1 TO WS-POS
            END-IF
        END-PERFORM
    ELSE
        PERFORM UNTIL WS-POS > RN-LEN
            IF RN-BUF(WS-POS:1) = ","
                ADD 1 TO WS-POS
                EXIT PERFORM
            ELSE
                IF WS-OUT-I < 512
                    ADD 1 TO WS-OUT-I
                    MOVE RN-BUF(WS-POS:1) TO WS-EXTRACTED(WS-OUT-I:1)
                END-IF
                ADD 1 TO WS-POS
            END-IF
        END-PERFORM
    END-IF
    .

NEXT-B-INT.
    PERFORM NEXT-B-FIELD
    MOVE FUNCTION TRIM(WS-EXTRACTED) TO WS-PARSE-TMP
    PERFORM PARSE-INT-TMP
    .

NEXT-B-DEC.
    PERFORM NEXT-B-FIELD
    MOVE 0 TO NREQ-DEC-VAL
    IF FUNCTION TRIM(WS-EXTRACTED) = "NA" OR FUNCTION TRIM(WS-EXTRACTED) = SPACES
        EXIT PARAGRAPH
    END-IF
    INITIALIZE NUM-REQ
    MOVE "PARSE-DEC" TO NREQ-OP
    MOVE FUNCTION TRIM(WS-EXTRACTED) TO NREQ-TEXT-IN
    MOVE 11 TO NREQ-MAX-INT-DIGITS
    MOVE 6  TO NREQ-MAX-DEC-DIGITS
    MOVE "Y" TO NREQ-ALLOW-ZERO
    MOVE "Y" TO NREQ-ALLOW-NEG
    CALL "NUMERIC-UTILS" USING NUM-REQ
    .

PARSE-INT-TMP.
    INITIALIZE NUM-REQ
    MOVE "PARSE-INT" TO NREQ-OP
    MOVE WS-PARSE-TMP TO NREQ-TEXT-IN
    MOVE 11 TO NREQ-MAX-INT-DIGITS
    MOVE "Y" TO NREQ-ALLOW-ZERO
    MOVE "Y" TO NREQ-ALLOW-NEG
    CALL "NUMERIC-UTILS" USING NUM-REQ
    .

PARSE-CSV-LINE.
    INITIALIZE NORM-REQ
    MOVE F-IN-REC TO RN-BUF
    MOVE "N" TO RN-IS-FIRST-LINE
    CALL "RECORD-NORMALISER" USING NORM-REQ
    INITIALIZE CSV-REQ
    MOVE RN-BUF TO CSV-LINE
    MOVE RN-LEN TO CSV-LINE-LEN
    CALL "CSV-READER" USING CSV-REQ
    .
