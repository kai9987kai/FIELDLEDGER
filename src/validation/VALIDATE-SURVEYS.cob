>>SOURCE FORMAT FREE
*> =====================================================================
*> FIELDLEDGER - VALIDATE-SURVEYS.cob
*> Loads and validates surveys.csv: schema, O(log N) foreign-key checks
*> against sites and sources, ISO 8601 survey_date, positive survey
*> duration, PRE/POST/TRANSITION period classification, method catalog.
*> =====================================================================
IDENTIFICATION DIVISION.
PROGRAM-ID. VALIDATE-SURVEYS.

ENVIRONMENT DIVISION.
INPUT-OUTPUT SECTION.
FILE-CONTROL.
    SELECT F-SURVEYS ASSIGN TO DYNAMIC WS-FILE-PATH
        ORGANIZATION IS LINE SEQUENTIAL
        FILE STATUS IS WS-FS.

DATA DIVISION.
FILE SECTION.
FD F-SURVEYS.
01 F-SURV-REC               PIC X(4096).

WORKING-STORAGE SECTION.
COPY "LIMITS.cpy".
COPY "RUN-CONFIG.cpy".
COPY "SOURCE-RECORD.cpy".
COPY "SITE-RECORD.cpy".
COPY "SURVEY-RECORD.cpy".
COPY "CSV-WORK.cpy".
COPY "UTILS-IFACE.cpy".

01 WS-FILE-PATH             PIC X(512).
01 WS-FS                    PIC XX.
01 WS-EOF                   PIC X(1).
01 WS-ROW-NUM               PIC 9(9) COMP-5.
01 WS-ROW-OK                PIC X(1).
01 WS-MISS-FIELD            PIC X(40).
01 WS-LIMIT-HIT             PIC X(1).
01 WS-SEARCH-KEY            PIC X(64).
01 WS-LO                    PIC 9(9) COMP-5.
01 WS-HI                    PIC 9(9) COMP-5.
01 WS-MID                   PIC 9(9) COMP-5.
01 WS-FOUND-POS             PIC 9(9) COMP-5.
01 WS-SITE-POS              PIC 9(9) COMP-5.
01 WS-SRC-POS               PIC 9(9) COMP-5.
01 WS-SURV-ORD              PIC 9(9) COMP-5.
01 WS-SURV-PER              PIC X(12).
01 WS-SURV-MIN              PIC S9(7)V9(4) COMP-3.
01 WS-M-IDX                 PIC 9(4) COMP-5.
01 WS-M-FOUND               PIC X(1).
01 WS-M-NAME                PIC X(64).

PROCEDURE DIVISION.
MAIN-VAL-SURVEYS.
    MOVE 0   TO SURV-COUNT
    MOVE 0   TO SURV-RAW-ROWS
    MOVE 0   TO SURV-REJECTED-ROWS
    MOVE 0   TO SURV-DUP-COUNT
    MOVE 0   TO SURV-PRE-COUNT
    MOVE 0   TO SURV-POST-COUNT
    MOVE 0   TO SURV-TRANS-COUNT
    MOVE 0   TO SURV-METHOD-COUNT
    MOVE "N" TO SURV-INDEX-BUILT
    MOVE "N" TO WS-LIMIT-HIT

    INITIALIZE CFG-REQ
    MOVE "JOIN-PATH"    TO CREQ-OP
    MOVE CFG-STUDY-PATH TO CREQ-PATH-A
    MOVE "surveys.csv"  TO CREQ-PATH-B
    CALL "CONFIGURATION" USING CFG-REQ
    MOVE CREQ-PATH-OUT TO WS-FILE-PATH

    OPEN INPUT F-SURVEYS
    IF WS-FS NOT = "00"
        INITIALIZE ERR-REQ
        MOVE "ADD" TO EREQ-OP
        MOVE "ERROR" TO EREQ-SEVERITY
        MOVE "FILE_MISSING" TO EREQ-CODE
        MOVE "surveys.csv" TO EREQ-FILE
        MOVE 0 TO EREQ-ROW
        MOVE "file" TO EREQ-FIELD
        STRING "Cannot open required file surveys.csv (file status " WS-FS ")"
               DELIMITED BY SIZE INTO EREQ-MESSAGE
        END-STRING
        CALL "ERROR-HANDLING" USING ERR-REQ
        GOBACK
    END-IF

    MOVE "N" TO WS-EOF
    MOVE 0   TO WS-ROW-NUM

    PERFORM UNTIL WS-EOF = "Y" OR WS-LIMIT-HIT = "Y"
        MOVE SPACES TO F-SURV-REC
        READ F-SURVEYS
            AT END
                MOVE "Y" TO WS-EOF
            NOT AT END
                ADD 1 TO WS-ROW-NUM
                PERFORM PROCESS-LINE
        END-READ
    END-PERFORM

    CLOSE F-SURVEYS

    IF WS-ROW-NUM = 0
        INITIALIZE ERR-REQ
        MOVE "ADD" TO EREQ-OP
        MOVE "ERROR" TO EREQ-SEVERITY
        MOVE "EMPTY_FILE" TO EREQ-CODE
        MOVE "surveys.csv" TO EREQ-FILE
        MOVE 0 TO EREQ-ROW
        MOVE "file" TO EREQ-FIELD
        MOVE "Required file surveys.csv is empty" TO EREQ-MESSAGE
        CALL "ERROR-HANDLING" USING ERR-REQ
    END-IF

    IF SURV-TRANS-COUNT > 0
        INITIALIZE ERR-REQ
        MOVE "ADD" TO EREQ-OP
        MOVE "WARNING" TO EREQ-SEVERITY
        MOVE "TRANSITION_SURVEYS" TO EREQ-CODE
        MOVE "surveys.csv" TO EREQ-FILE
        MOVE 0 TO EREQ-ROW
        MOVE "survey_date" TO EREQ-FIELD
        MOVE "One or more surveys occurred on the site reference_date (TRANSITION) and will be excluded from primary PRE/POST BACI"
            TO EREQ-MESSAGE
        CALL "ERROR-HANDLING" USING ERR-REQ
    END-IF
    GOBACK.

PROCESS-LINE.
    INITIALIZE NORM-REQ
    MOVE F-SURV-REC TO RN-BUF
    IF WS-ROW-NUM = 1
        MOVE "Y" TO RN-IS-FIRST-LINE
    ELSE
        MOVE "N" TO RN-IS-FIRST-LINE
    END-IF
    CALL "RECORD-NORMALISER" USING NORM-REQ

    IF RN-STATUS = 01
        INITIALIZE ERR-REQ
        MOVE "ADD" TO EREQ-OP
        MOVE "INFO" TO EREQ-SEVERITY
        MOVE "UTF8_BOM" TO EREQ-CODE
        MOVE "surveys.csv" TO EREQ-FILE
        MOVE WS-ROW-NUM TO EREQ-ROW
        MOVE "encoding" TO EREQ-FIELD
        MOVE RN-ERR-MSG TO EREQ-MESSAGE
        CALL "ERROR-HANDLING" USING ERR-REQ
    ELSE
        IF RN-STATUS >= 02
            INITIALIZE ERR-REQ
            MOVE "ADD" TO EREQ-OP
            MOVE "ERROR" TO EREQ-SEVERITY
            MOVE "ENCODING_ERROR" TO EREQ-CODE
            MOVE "surveys.csv" TO EREQ-FILE
            MOVE WS-ROW-NUM TO EREQ-ROW
            MOVE "encoding" TO EREQ-FIELD
            MOVE RN-ERR-MSG TO EREQ-MESSAGE
            CALL "ERROR-HANDLING" USING ERR-REQ
            IF WS-ROW-NUM > 1
                ADD 1 TO SURV-RAW-ROWS
                ADD 1 TO SURV-REJECTED-ROWS
            END-IF
            EXIT PARAGRAPH
        END-IF
    END-IF

    IF RN-LEN = 0
        EXIT PARAGRAPH
    END-IF

    INITIALIZE CSV-REQ
    MOVE RN-BUF TO CSV-LINE
    MOVE RN-LEN TO CSV-LINE-LEN
    CALL "CSV-READER" USING CSV-REQ
    IF NOT CSV-OK
        INITIALIZE ERR-REQ
        MOVE "ADD" TO EREQ-OP
        MOVE "ERROR" TO EREQ-SEVERITY
        MOVE "CSV_MALFORMED" TO EREQ-CODE
        MOVE "surveys.csv" TO EREQ-FILE
        MOVE WS-ROW-NUM TO EREQ-ROW
        MOVE "record" TO EREQ-FIELD
        MOVE CSV-ERR-MSG TO EREQ-MESSAGE
        CALL "ERROR-HANDLING" USING ERR-REQ
        IF WS-ROW-NUM > 1
            ADD 1 TO SURV-RAW-ROWS
            ADD 1 TO SURV-REJECTED-ROWS
        END-IF
        EXIT PARAGRAPH
    END-IF

    IF WS-ROW-NUM = 1
        PERFORM CHECK-HEADER
        EXIT PARAGRAPH
    END-IF

    ADD 1 TO SURV-RAW-ROWS

    IF SURV-COUNT >= FL-MAX-SURVEYS
        MOVE "Y" TO WS-LIMIT-HIT
        MOVE FL-EXIT-LIMIT-ERR TO CFG-EXIT-CODE
        INITIALIZE ERR-REQ
        MOVE "ADD" TO EREQ-OP
        MOVE "ERROR" TO EREQ-SEVERITY
        MOVE "RESOURCE_LIMIT" TO EREQ-CODE
        MOVE "surveys.csv" TO EREQ-FILE
        MOVE WS-ROW-NUM TO EREQ-ROW
        MOVE "capacity" TO EREQ-FIELD
        MOVE "Survey record count exceeds documented v1.0.0 limit (50,000 surveys)"
            TO EREQ-MESSAGE
        CALL "ERROR-HANDLING" USING ERR-REQ
        EXIT PARAGRAPH
    END-IF

    IF CSV-FIELD-CNT NOT = 7
        INITIALIZE ERR-REQ
        MOVE "ADD" TO EREQ-OP
        MOVE "ERROR" TO EREQ-SEVERITY
        MOVE "COLUMN_COUNT" TO EREQ-CODE
        MOVE "surveys.csv" TO EREQ-FILE
        MOVE WS-ROW-NUM TO EREQ-ROW
        MOVE "record" TO EREQ-FIELD
        MOVE "Expected exactly 7 columns in surveys.csv" TO EREQ-MESSAGE
        CALL "ERROR-HANDLING" USING ERR-REQ
        ADD 1 TO SURV-REJECTED-ROWS
        EXIT PARAGRAPH
    END-IF

    MOVE "Y" TO WS-ROW-OK
    MOVE 0   TO WS-SITE-POS
    MOVE 0   TO WS-SRC-POS
    MOVE 0   TO WS-SURV-ORD
    MOVE SPACES TO WS-SURV-PER
    MOVE 0   TO WS-SURV-MIN

    IF FUNCTION TRIM(CSV-F-VAL(1)) = SPACES
        MOVE "survey_id" TO WS-MISS-FIELD
        PERFORM ADD-MISSING-REQ
    END-IF

    *> Foreign key: site_id
    IF FUNCTION TRIM(CSV-F-VAL(2)) = SPACES
        MOVE "site_id" TO WS-MISS-FIELD
        PERFORM ADD-MISSING-REQ
    ELSE
        MOVE FUNCTION TRIM(CSV-F-VAL(2)) TO WS-SEARCH-KEY
        PERFORM BSEARCH-SITE
        IF WS-FOUND-POS = 0
            MOVE "N" TO WS-ROW-OK
            INITIALIZE ERR-REQ
            MOVE "ADD" TO EREQ-OP
            MOVE "ERROR" TO EREQ-SEVERITY
            MOVE "FK_SITE_NOT_FOUND" TO EREQ-CODE
            MOVE "surveys.csv" TO EREQ-FILE
            MOVE WS-ROW-NUM TO EREQ-ROW
            MOVE "site_id" TO EREQ-FIELD
            STRING "Survey references unknown site_id '"
                   FUNCTION TRIM(WS-SEARCH-KEY) "'"
                   DELIMITED BY SIZE INTO EREQ-MESSAGE
            END-STRING
            CALL "ERROR-HANDLING" USING ERR-REQ
        ELSE
            MOVE WS-FOUND-POS TO WS-SITE-POS
        END-IF
    END-IF

    *> Temporal validation: survey_date vs site reference_date
    IF FUNCTION TRIM(CSV-F-VAL(3)) = SPACES
        MOVE "survey_date" TO WS-MISS-FIELD
        PERFORM ADD-MISSING-REQ
    ELSE
        INITIALIZE DATE-REQ
        MOVE "VALIDATE" TO DREQ-OP
        MOVE FUNCTION TRIM(CSV-F-VAL(3)) TO DREQ-DATE-A
        CALL "DATE-UTILS" USING DATE-REQ
        IF DREQ-VALID = "Y"
            MOVE DREQ-ORD-A TO WS-SURV-ORD
            IF WS-SITE-POS > 0
                IF WS-SURV-ORD < SITE-REF-ORD(WS-SITE-POS)
                    MOVE "PRE" TO WS-SURV-PER
                ELSE
                    IF WS-SURV-ORD > SITE-REF-ORD(WS-SITE-POS)
                        MOVE "POST" TO WS-SURV-PER
                    ELSE
                        MOVE "TRANSITION" TO WS-SURV-PER
                    END-IF
                END-IF
            END-IF
        ELSE
            MOVE "N" TO WS-ROW-OK
            INITIALIZE ERR-REQ
            MOVE "ADD" TO EREQ-OP
            MOVE "ERROR" TO EREQ-SEVERITY
            MOVE "INVALID_DATE" TO EREQ-CODE
            MOVE "surveys.csv" TO EREQ-FILE
            MOVE WS-ROW-NUM TO EREQ-ROW
            MOVE "survey_date" TO EREQ-FIELD
            MOVE DREQ-ERR-MSG TO EREQ-MESSAGE
            CALL "ERROR-HANDLING" USING ERR-REQ
        END-IF
    END-IF

    *> Numerical validation: survey_minutes > 0
    IF FUNCTION TRIM(CSV-F-VAL(4)) = SPACES
        MOVE "survey_minutes" TO WS-MISS-FIELD
        PERFORM ADD-MISSING-REQ
    ELSE
        INITIALIZE NUM-REQ
        MOVE "PARSE-DEC" TO NREQ-OP
        MOVE FUNCTION TRIM(CSV-F-VAL(4)) TO NREQ-TEXT-IN
        MOVE 7   TO NREQ-MAX-INT-DIGITS
        MOVE 4   TO NREQ-MAX-DEC-DIGITS
        MOVE "N" TO NREQ-ALLOW-ZERO
        MOVE "N" TO NREQ-ALLOW-NEG
        CALL "NUMERIC-UTILS" USING NUM-REQ
        IF NREQ-VALID = "Y"
            MOVE NREQ-DEC-VAL TO WS-SURV-MIN
        ELSE
            MOVE "N" TO WS-ROW-OK
            INITIALIZE ERR-REQ
            MOVE "ADD" TO EREQ-OP
            MOVE "ERROR" TO EREQ-SEVERITY
            MOVE "INVALID_NUMERIC" TO EREQ-CODE
            MOVE "surveys.csv" TO EREQ-FILE
            MOVE WS-ROW-NUM TO EREQ-ROW
            MOVE "survey_minutes" TO EREQ-FIELD
            MOVE NREQ-ERR-MSG TO EREQ-MESSAGE
            CALL "ERROR-HANDLING" USING ERR-REQ
        END-IF
    END-IF

    IF FUNCTION TRIM(CSV-F-VAL(5)) = SPACES
        MOVE "method" TO WS-MISS-FIELD
        PERFORM ADD-MISSING-REQ
    END-IF
    IF FUNCTION TRIM(CSV-F-VAL(6)) = SPACES
        MOVE "observer_id" TO WS-MISS-FIELD
        PERFORM ADD-MISSING-REQ
    END-IF

    *> Foreign key: source_id
    IF FUNCTION TRIM(CSV-F-VAL(7)) = SPACES
        MOVE "source_id" TO WS-MISS-FIELD
        PERFORM ADD-MISSING-REQ
    ELSE
        MOVE FUNCTION TRIM(CSV-F-VAL(7)) TO WS-SEARCH-KEY
        PERFORM BSEARCH-SOURCE
        IF WS-FOUND-POS = 0
            MOVE "N" TO WS-ROW-OK
            INITIALIZE ERR-REQ
            MOVE "ADD" TO EREQ-OP
            MOVE "ERROR" TO EREQ-SEVERITY
            MOVE "FK_SOURCE_NOT_FOUND" TO EREQ-CODE
            MOVE "surveys.csv" TO EREQ-FILE
            MOVE WS-ROW-NUM TO EREQ-ROW
            MOVE "source_id" TO EREQ-FIELD
            STRING "Survey references unknown source_id '"
                   FUNCTION TRIM(WS-SEARCH-KEY) "'"
                   DELIMITED BY SIZE INTO EREQ-MESSAGE
            END-STRING
            CALL "ERROR-HANDLING" USING ERR-REQ
        ELSE
            MOVE WS-FOUND-POS TO WS-SRC-POS
        END-IF
    END-IF

    IF WS-ROW-OK = "Y"
        ADD 1 TO SURV-COUNT
        MOVE FUNCTION TRIM(CSV-F-VAL(1)) TO SURV-ID(SURV-COUNT)
        MOVE FUNCTION TRIM(CSV-F-VAL(2)) TO SURV-SITE-ID(SURV-COUNT)
        MOVE WS-SITE-POS                 TO SURV-SITE-IDX(SURV-COUNT)
        MOVE FUNCTION TRIM(CSV-F-VAL(3)) TO SURV-DATE(SURV-COUNT)
        MOVE WS-SURV-ORD                 TO SURV-DATE-ORD(SURV-COUNT)
        MOVE WS-SURV-PER                 TO SURV-PERIOD(SURV-COUNT)
        MOVE WS-SURV-MIN                 TO SURV-MINUTES(SURV-COUNT)
        MOVE FUNCTION TRIM(CSV-F-VAL(5)) TO SURV-METHOD(SURV-COUNT)
        MOVE FUNCTION TRIM(CSV-F-VAL(6)) TO SURV-OBSERVER-ID(SURV-COUNT)
        MOVE FUNCTION TRIM(CSV-F-VAL(7)) TO SURV-SOURCE-ID(SURV-COUNT)
        MOVE WS-SRC-POS                  TO SURV-SOURCE-IDX(SURV-COUNT)
        MOVE WS-ROW-NUM                  TO SURV-ROW-NUM(SURV-COUNT)
        MOVE "Y"                         TO SURV-VALID(SURV-COUNT)

        EVALUATE WS-SURV-PER
            WHEN "PRE"
                ADD 1 TO SURV-PRE-COUNT
            WHEN "POST"
                ADD 1 TO SURV-POST-COUNT
            WHEN "TRANSITION"
                ADD 1 TO SURV-TRANS-COUNT
        END-EVALUATE

        MOVE SURV-METHOD(SURV-COUNT) TO WS-M-NAME
        PERFORM REGISTER-METHOD
    ELSE
        ADD 1 TO SURV-REJECTED-ROWS
    END-IF
    .

REGISTER-METHOD.
    MOVE "N" TO WS-M-FOUND
    PERFORM VARYING WS-M-IDX FROM 1 BY 1 UNTIL WS-M-IDX > SURV-METHOD-COUNT
        IF SM-NAME(WS-M-IDX) = WS-M-NAME
            ADD 1 TO SM-SURV-CNT(WS-M-IDX)
            MOVE "Y" TO WS-M-FOUND
            EXIT PERFORM
        END-IF
    END-PERFORM
    IF WS-M-FOUND = "N"
        IF SURV-METHOD-COUNT < FL-MAX-METHODS
            ADD 1 TO SURV-METHOD-COUNT
            MOVE WS-M-NAME TO SM-NAME(SURV-METHOD-COUNT)
            MOVE 1         TO SM-SURV-CNT(SURV-METHOD-COUNT)
        END-IF
    END-IF
    .

BSEARCH-SITE.
    MOVE 0 TO WS-FOUND-POS
    IF SITE-COUNT = 0
        EXIT PARAGRAPH
    END-IF
    MOVE 1 TO WS-LO
    MOVE SITE-COUNT TO WS-HI
    PERFORM UNTIL WS-LO > WS-HI
        COMPUTE WS-MID = WS-LO + FUNCTION INTEGER((WS-HI - WS-LO) / 2)
        IF SITEI-KEY(WS-MID) = WS-SEARCH-KEY
            MOVE SITEI-POS(WS-MID) TO WS-FOUND-POS
            EXIT PERFORM
        ELSE
            IF SITEI-KEY(WS-MID) < WS-SEARCH-KEY
                COMPUTE WS-LO = WS-MID + 1
            ELSE
                IF WS-MID <= 1
                    EXIT PERFORM
                END-IF
                COMPUTE WS-HI = WS-MID - 1
            END-IF
        END-IF
    END-PERFORM
    .

BSEARCH-SOURCE.
    MOVE 0 TO WS-FOUND-POS
    IF SRC-COUNT = 0
        EXIT PARAGRAPH
    END-IF
    MOVE 1 TO WS-LO
    MOVE SRC-COUNT TO WS-HI
    PERFORM UNTIL WS-LO > WS-HI
        COMPUTE WS-MID = WS-LO + FUNCTION INTEGER((WS-HI - WS-LO) / 2)
        IF SRCI-KEY(WS-MID) = WS-SEARCH-KEY
            MOVE SRCI-POS(WS-MID) TO WS-FOUND-POS
            EXIT PERFORM
        ELSE
            IF SRCI-KEY(WS-MID) < WS-SEARCH-KEY
                COMPUTE WS-LO = WS-MID + 1
            ELSE
                IF WS-MID <= 1
                    EXIT PERFORM
                END-IF
                COMPUTE WS-HI = WS-MID - 1
            END-IF
        END-IF
    END-PERFORM
    .

CHECK-HEADER.
    IF CSV-FIELD-CNT = 7
        AND FUNCTION TRIM(CSV-F-VAL(1)) = "survey_id"
        AND FUNCTION TRIM(CSV-F-VAL(2)) = "site_id"
        AND FUNCTION TRIM(CSV-F-VAL(3)) = "survey_date"
        AND FUNCTION TRIM(CSV-F-VAL(4)) = "survey_minutes"
        AND FUNCTION TRIM(CSV-F-VAL(5)) = "method"
        AND FUNCTION TRIM(CSV-F-VAL(6)) = "observer_id"
        AND FUNCTION TRIM(CSV-F-VAL(7)) = "source_id"
        CONTINUE
    ELSE
        INITIALIZE ERR-REQ
        MOVE "ADD" TO EREQ-OP
        MOVE "ERROR" TO EREQ-SEVERITY
        MOVE "HEADER_MISMATCH" TO EREQ-CODE
        MOVE "surveys.csv" TO EREQ-FILE
        MOVE 1 TO EREQ-ROW
        MOVE "header" TO EREQ-FIELD
        MOVE "Expected header: survey_id,site_id,survey_date,survey_minutes,method,observer_id,source_id"
            TO EREQ-MESSAGE
        CALL "ERROR-HANDLING" USING ERR-REQ
    END-IF
    .

ADD-MISSING-REQ.
    MOVE "N" TO WS-ROW-OK
    INITIALIZE ERR-REQ
    MOVE "ADD" TO EREQ-OP
    MOVE "ERROR" TO EREQ-SEVERITY
    MOVE "MISSING_REQUIRED" TO EREQ-CODE
    MOVE "surveys.csv" TO EREQ-FILE
    MOVE WS-ROW-NUM TO EREQ-ROW
    MOVE WS-MISS-FIELD TO EREQ-FIELD
    STRING "Required field '" FUNCTION TRIM(WS-MISS-FIELD) "' is empty"
           DELIMITED BY SIZE INTO EREQ-MESSAGE
    END-STRING
    CALL "ERROR-HANDLING" USING ERR-REQ
    .
