>>SOURCE FORMAT FREE
*> =====================================================================
*> FIELDLEDGER - VALIDATE-OBSERVATIONS.cob
*> Loads and validates observations.csv: schema, O(log N) foreign-key
*> check against surveys, non-negative integer count, strict status
*> consistency (DETECTED => count > 0; NOT_DETECTED => count = 0),
*> and capacity limit (250,000 observations).
*> =====================================================================
IDENTIFICATION DIVISION.
PROGRAM-ID. VALIDATE-OBSERVATIONS.

ENVIRONMENT DIVISION.
INPUT-OUTPUT SECTION.
FILE-CONTROL.
    SELECT F-OBS ASSIGN TO DYNAMIC WS-FILE-PATH
        ORGANIZATION IS LINE SEQUENTIAL
        FILE STATUS IS WS-FS.

DATA DIVISION.
FILE SECTION.
FD F-OBS.
01 F-OBS-REC                PIC X(4096).

WORKING-STORAGE SECTION.
COPY "LIMITS.cpy".
COPY "RUN-CONFIG.cpy".
COPY "SURVEY-RECORD.cpy".
COPY "OBSERVATION-RECORD.cpy".
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
01 WS-SURV-POS              PIC 9(9) COMP-5.
01 WS-CNT-VAL               PIC S9(9) COMP-3.
01 WS-CNT-OK                PIC X(1).
01 WS-STATUS-STR            PIC X(32).

PROCEDURE DIVISION.
MAIN-VAL-OBS.
    MOVE 0   TO OBS-COUNT
    MOVE 0   TO OBS-RAW-ROWS
    MOVE 0   TO OBS-REJECTED-ROWS
    MOVE 0   TO OBS-DUP-ID-COUNT
    MOVE 0   TO OBS-DUP-KEY-COUNT
    MOVE 0   TO OBS-DETECTED-COUNT
    MOVE 0   TO OBS-NOT-DET-COUNT
    MOVE 0   TO OBS-TRANS-EXCL-COUNT
    MOVE "N" TO WS-LIMIT-HIT

    INITIALIZE CFG-REQ
    MOVE "JOIN-PATH"        TO CREQ-OP
    MOVE CFG-STUDY-PATH     TO CREQ-PATH-A
    MOVE "observations.csv" TO CREQ-PATH-B
    CALL "CONFIGURATION" USING CFG-REQ
    MOVE CREQ-PATH-OUT TO WS-FILE-PATH

    OPEN INPUT F-OBS
    IF WS-FS NOT = "00"
        INITIALIZE ERR-REQ
        MOVE "ADD" TO EREQ-OP
        MOVE "ERROR" TO EREQ-SEVERITY
        MOVE "FILE_MISSING" TO EREQ-CODE
        MOVE "observations.csv" TO EREQ-FILE
        MOVE 0 TO EREQ-ROW
        MOVE "file" TO EREQ-FIELD
        STRING "Cannot open required file observations.csv (file status " WS-FS ")"
               DELIMITED BY SIZE INTO EREQ-MESSAGE
        END-STRING
        CALL "ERROR-HANDLING" USING ERR-REQ
        GOBACK
    END-IF

    MOVE "N" TO WS-EOF
    MOVE 0   TO WS-ROW-NUM

    PERFORM UNTIL WS-EOF = "Y" OR WS-LIMIT-HIT = "Y"
        MOVE SPACES TO F-OBS-REC
        READ F-OBS
            AT END
                MOVE "Y" TO WS-EOF
            NOT AT END
                ADD 1 TO WS-ROW-NUM
                PERFORM PROCESS-LINE
        END-READ
    END-PERFORM

    CLOSE F-OBS

    IF WS-ROW-NUM = 0
        INITIALIZE ERR-REQ
        MOVE "ADD" TO EREQ-OP
        MOVE "ERROR" TO EREQ-SEVERITY
        MOVE "EMPTY_FILE" TO EREQ-CODE
        MOVE "observations.csv" TO EREQ-FILE
        MOVE 0 TO EREQ-ROW
        MOVE "file" TO EREQ-FIELD
        MOVE "Required file observations.csv is empty" TO EREQ-MESSAGE
        CALL "ERROR-HANDLING" USING ERR-REQ
    END-IF
    GOBACK.

PROCESS-LINE.
    INITIALIZE NORM-REQ
    MOVE F-OBS-REC TO RN-BUF
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
        MOVE "observations.csv" TO EREQ-FILE
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
            MOVE "observations.csv" TO EREQ-FILE
            MOVE WS-ROW-NUM TO EREQ-ROW
            MOVE "encoding" TO EREQ-FIELD
            MOVE RN-ERR-MSG TO EREQ-MESSAGE
            CALL "ERROR-HANDLING" USING ERR-REQ
            IF WS-ROW-NUM > 1
                ADD 1 TO OBS-RAW-ROWS
                ADD 1 TO OBS-REJECTED-ROWS
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
        MOVE "observations.csv" TO EREQ-FILE
        MOVE WS-ROW-NUM TO EREQ-ROW
        MOVE "record" TO EREQ-FIELD
        MOVE CSV-ERR-MSG TO EREQ-MESSAGE
        CALL "ERROR-HANDLING" USING ERR-REQ
        IF WS-ROW-NUM > 1
            ADD 1 TO OBS-RAW-ROWS
            ADD 1 TO OBS-REJECTED-ROWS
        END-IF
        EXIT PARAGRAPH
    END-IF

    IF WS-ROW-NUM = 1
        PERFORM CHECK-HEADER
        EXIT PARAGRAPH
    END-IF

    ADD 1 TO OBS-RAW-ROWS

    IF OBS-COUNT >= FL-MAX-OBSERVATIONS
        MOVE "Y" TO WS-LIMIT-HIT
        MOVE FL-EXIT-LIMIT-ERR TO CFG-EXIT-CODE
        INITIALIZE ERR-REQ
        MOVE "ADD" TO EREQ-OP
        MOVE "ERROR" TO EREQ-SEVERITY
        MOVE "RESOURCE_LIMIT" TO EREQ-CODE
        MOVE "observations.csv" TO EREQ-FILE
        MOVE WS-ROW-NUM TO EREQ-ROW
        MOVE "capacity" TO EREQ-FIELD
        MOVE "Observation record count exceeds documented v1.0.0 limit (250,000 observations)"
            TO EREQ-MESSAGE
        CALL "ERROR-HANDLING" USING ERR-REQ
        EXIT PARAGRAPH
    END-IF

    IF CSV-FIELD-CNT NOT = 5
        INITIALIZE ERR-REQ
        MOVE "ADD" TO EREQ-OP
        MOVE "ERROR" TO EREQ-SEVERITY
        MOVE "COLUMN_COUNT" TO EREQ-CODE
        MOVE "observations.csv" TO EREQ-FILE
        MOVE WS-ROW-NUM TO EREQ-ROW
        MOVE "record" TO EREQ-FIELD
        MOVE "Expected exactly 5 columns in observations.csv" TO EREQ-MESSAGE
        CALL "ERROR-HANDLING" USING ERR-REQ
        ADD 1 TO OBS-REJECTED-ROWS
        EXIT PARAGRAPH
    END-IF

    MOVE "Y" TO WS-ROW-OK
    MOVE 0   TO WS-SURV-POS
    MOVE 0   TO WS-CNT-VAL
    MOVE "N" TO WS-CNT-OK

    IF FUNCTION TRIM(CSV-F-VAL(1)) = SPACES
        MOVE "observation_id" TO WS-MISS-FIELD
        PERFORM ADD-MISSING-REQ
    END-IF

    *> Foreign key: survey_id
    IF FUNCTION TRIM(CSV-F-VAL(2)) = SPACES
        MOVE "survey_id" TO WS-MISS-FIELD
        PERFORM ADD-MISSING-REQ
    ELSE
        MOVE FUNCTION TRIM(CSV-F-VAL(2)) TO WS-SEARCH-KEY
        PERFORM BSEARCH-SURVEY
        IF WS-SURV-POS = 0
            MOVE "N" TO WS-ROW-OK
            INITIALIZE ERR-REQ
            MOVE "ADD" TO EREQ-OP
            MOVE "ERROR" TO EREQ-SEVERITY
            MOVE "FK_SURVEY_NOT_FOUND" TO EREQ-CODE
            MOVE "observations.csv" TO EREQ-FILE
            MOVE WS-ROW-NUM TO EREQ-ROW
            MOVE "survey_id" TO EREQ-FIELD
            STRING "Observation references unknown survey_id '"
                   FUNCTION TRIM(WS-SEARCH-KEY) "'"
                   DELIMITED BY SIZE INTO EREQ-MESSAGE
            END-STRING
            CALL "ERROR-HANDLING" USING ERR-REQ
        END-IF
    END-IF

    IF FUNCTION TRIM(CSV-F-VAL(3)) = SPACES
        MOVE "species_code" TO WS-MISS-FIELD
        PERFORM ADD-MISSING-REQ
    END-IF

    *> Count validation: non-negative integer
    IF FUNCTION TRIM(CSV-F-VAL(4)) = SPACES
        MOVE "count" TO WS-MISS-FIELD
        PERFORM ADD-MISSING-REQ
    ELSE
        INITIALIZE NUM-REQ
        MOVE "PARSE-INT" TO NREQ-OP
        MOVE FUNCTION TRIM(CSV-F-VAL(4)) TO NREQ-TEXT-IN
        MOVE 9   TO NREQ-MAX-INT-DIGITS
        MOVE "Y" TO NREQ-ALLOW-ZERO
        MOVE "N" TO NREQ-ALLOW-NEG
        CALL "NUMERIC-UTILS" USING NUM-REQ
        IF NREQ-VALID = "Y"
            MOVE NREQ-INT-VAL TO WS-CNT-VAL
            MOVE "Y"          TO WS-CNT-OK
        ELSE
            MOVE "N" TO WS-ROW-OK
            INITIALIZE ERR-REQ
            MOVE "ADD" TO EREQ-OP
            MOVE "ERROR" TO EREQ-SEVERITY
            MOVE "INVALID_COUNT" TO EREQ-CODE
            MOVE "observations.csv" TO EREQ-FILE
            MOVE WS-ROW-NUM TO EREQ-ROW
            MOVE "count" TO EREQ-FIELD
            MOVE NREQ-ERR-MSG TO EREQ-MESSAGE
            CALL "ERROR-HANDLING" USING ERR-REQ
        END-IF
    END-IF

    *> Observation status and cross-field rule validation
    MOVE FUNCTION TRIM(CSV-F-VAL(5)) TO WS-STATUS-STR
    IF WS-STATUS-STR NOT = "DETECTED" AND WS-STATUS-STR NOT = "NOT_DETECTED"
        MOVE "N" TO WS-ROW-OK
        INITIALIZE ERR-REQ
        MOVE "ADD" TO EREQ-OP
        MOVE "ERROR" TO EREQ-SEVERITY
        MOVE "INVALID_OBS_STATUS" TO EREQ-CODE
        MOVE "observations.csv" TO EREQ-FILE
        MOVE WS-ROW-NUM TO EREQ-ROW
        MOVE "observation_status" TO EREQ-FIELD
        STRING "Invalid observation_status '" FUNCTION TRIM(WS-STATUS-STR)
               "'; must be strictly DETECTED or NOT_DETECTED"
               DELIMITED BY SIZE INTO EREQ-MESSAGE
        END-STRING
        CALL "ERROR-HANDLING" USING ERR-REQ
    ELSE
        IF WS-CNT-OK = "Y"
            IF WS-STATUS-STR = "DETECTED" AND WS-CNT-VAL <= 0
                MOVE "N" TO WS-ROW-OK
                INITIALIZE ERR-REQ
                MOVE "ADD" TO EREQ-OP
                MOVE "ERROR" TO EREQ-SEVERITY
                MOVE "STATUS_COUNT_MISMATCH" TO EREQ-CODE
                MOVE "observations.csv" TO EREQ-FILE
                MOVE WS-ROW-NUM TO EREQ-ROW
                MOVE "observation_status" TO EREQ-FIELD
                MOVE "Observation status DETECTED requires count > 0"
                    TO EREQ-MESSAGE
                CALL "ERROR-HANDLING" USING ERR-REQ
            END-IF
            IF WS-STATUS-STR = "NOT_DETECTED" AND WS-CNT-VAL NOT = 0
                MOVE "N" TO WS-ROW-OK
                INITIALIZE ERR-REQ
                MOVE "ADD" TO EREQ-OP
                MOVE "ERROR" TO EREQ-SEVERITY
                MOVE "STATUS_COUNT_MISMATCH" TO EREQ-CODE
                MOVE "observations.csv" TO EREQ-FILE
                MOVE WS-ROW-NUM TO EREQ-ROW
                MOVE "observation_status" TO EREQ-FIELD
                MOVE "Observation status NOT_DETECTED requires count = 0"
                    TO EREQ-MESSAGE
                CALL "ERROR-HANDLING" USING ERR-REQ
            END-IF
        END-IF
    END-IF

    IF WS-ROW-OK = "Y"
        ADD 1 TO OBS-COUNT
        MOVE FUNCTION TRIM(CSV-F-VAL(1)) TO OBS-ID(OBS-COUNT)
        MOVE FUNCTION TRIM(CSV-F-VAL(2)) TO OBS-SURV-ID(OBS-COUNT)
        MOVE WS-SURV-POS                 TO OBS-SURV-IDX(OBS-COUNT)
        MOVE FUNCTION TRIM(CSV-F-VAL(3)) TO OBS-SPECIES(OBS-COUNT)
        MOVE WS-CNT-VAL                  TO OBS-COUNT-VAL(OBS-COUNT)
        MOVE WS-STATUS-STR               TO OBS-STATUS(OBS-COUNT)
        MOVE 0                           TO OBS-RATE(OBS-COUNT)
        MOVE WS-ROW-NUM                  TO OBS-ROW-NUM(OBS-COUNT)
        MOVE "Y"                         TO OBS-VALID(OBS-COUNT)

        IF WS-STATUS-STR = "DETECTED"
            ADD 1 TO OBS-DETECTED-COUNT
        ELSE
            ADD 1 TO OBS-NOT-DET-COUNT
        END-IF

        IF SURV-PERIOD(WS-SURV-POS) = "TRANSITION"
            ADD 1 TO OBS-TRANS-EXCL-COUNT
        END-IF
    ELSE
        ADD 1 TO OBS-REJECTED-ROWS
    END-IF
    .

BSEARCH-SURVEY.
    MOVE 0 TO WS-SURV-POS
    IF SURV-COUNT = 0
        EXIT PARAGRAPH
    END-IF
    MOVE 1 TO WS-LO
    MOVE SURV-COUNT TO WS-HI
    PERFORM UNTIL WS-LO > WS-HI
        COMPUTE WS-MID = WS-LO + FUNCTION INTEGER((WS-HI - WS-LO) / 2)
        IF SURVI-KEY(WS-MID) = WS-SEARCH-KEY
            MOVE SURVI-POS(WS-MID) TO WS-SURV-POS
            EXIT PERFORM
        ELSE
            IF SURVI-KEY(WS-MID) < WS-SEARCH-KEY
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
    IF CSV-FIELD-CNT = 5
        AND FUNCTION TRIM(CSV-F-VAL(1)) = "observation_id"
        AND FUNCTION TRIM(CSV-F-VAL(2)) = "survey_id"
        AND FUNCTION TRIM(CSV-F-VAL(3)) = "species_code"
        AND FUNCTION TRIM(CSV-F-VAL(4)) = "count"
        AND FUNCTION TRIM(CSV-F-VAL(5)) = "observation_status"
        CONTINUE
    ELSE
        INITIALIZE ERR-REQ
        MOVE "ADD" TO EREQ-OP
        MOVE "ERROR" TO EREQ-SEVERITY
        MOVE "HEADER_MISMATCH" TO EREQ-CODE
        MOVE "observations.csv" TO EREQ-FILE
        MOVE 1 TO EREQ-ROW
        MOVE "header" TO EREQ-FIELD
        MOVE "Expected header: observation_id,survey_id,species_code,count,observation_status"
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
    MOVE "observations.csv" TO EREQ-FILE
    MOVE WS-ROW-NUM TO EREQ-ROW
    MOVE WS-MISS-FIELD TO EREQ-FIELD
    STRING "Required field '" FUNCTION TRIM(WS-MISS-FIELD) "' is empty"
           DELIMITED BY SIZE INTO EREQ-MESSAGE
    END-STRING
    CALL "ERROR-HANDLING" USING ERR-REQ
    .
