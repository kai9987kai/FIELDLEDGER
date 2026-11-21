>>SOURCE FORMAT FREE
*> =====================================================================
*> FIELDLEDGER - VALIDATE-STUDY.cob
*> Loads and validates study.csv (exact header, UTF-8, RFC 4180 CSV,
*> required fields, and exact single metadata record requirement).
*> =====================================================================
IDENTIFICATION DIVISION.
PROGRAM-ID. VALIDATE-STUDY.

ENVIRONMENT DIVISION.
INPUT-OUTPUT SECTION.
FILE-CONTROL.
    SELECT F-STUDY ASSIGN TO DYNAMIC WS-FILE-PATH
        ORGANIZATION IS LINE SEQUENTIAL
        FILE STATUS IS WS-FS.

DATA DIVISION.
FILE SECTION.
FD F-STUDY.
01 F-STUDY-REC              PIC X(4096).

WORKING-STORAGE SECTION.
COPY "LIMITS.cpy".
COPY "RUN-CONFIG.cpy".
COPY "STUDY-RECORD.cpy".
COPY "CSV-WORK.cpy".
COPY "UTILS-IFACE.cpy".

01 WS-FILE-PATH             PIC X(512).
01 WS-FS                    PIC XX.
01 WS-EOF                   PIC X(1).
01 WS-ROW-NUM               PIC 9(9) COMP-5.
01 WS-VALID-ROWS            PIC 9(9) COMP-5.
01 WS-HDR-OK                PIC X(1).
01 WS-ROW-OK                PIC X(1).
01 WS-DESIGN-UP             PIC X(64).
01 WS-MISS-FIELD            PIC X(40).

PROCEDURE DIVISION.
MAIN-VAL-STUDY.
    INITIALIZE STUDY-STORE
    MOVE "N" TO STUDY-LOADED

    INITIALIZE CFG-REQ
    MOVE "JOIN-PATH"    TO CREQ-OP
    MOVE CFG-STUDY-PATH TO CREQ-PATH-A
    MOVE "study.csv"    TO CREQ-PATH-B
    CALL "CONFIGURATION" USING CFG-REQ
    MOVE CREQ-PATH-OUT TO WS-FILE-PATH

    OPEN INPUT F-STUDY
    IF WS-FS NOT = "00"
        PERFORM ADD-MISSING-FILE-ERR
        GOBACK
    END-IF

    MOVE "N" TO WS-EOF
    MOVE 0   TO WS-ROW-NUM
    MOVE 0   TO WS-VALID-ROWS
    MOVE "N" TO WS-HDR-OK

    PERFORM UNTIL WS-EOF = "Y"
        MOVE SPACES TO F-STUDY-REC
        READ F-STUDY
            AT END
                MOVE "Y" TO WS-EOF
            NOT AT END
                ADD 1 TO WS-ROW-NUM
                PERFORM PROCESS-LINE
        END-READ
    END-PERFORM

    CLOSE F-STUDY

    IF WS-ROW-NUM = 0
        INITIALIZE ERR-REQ
        MOVE "ADD" TO EREQ-OP
        MOVE "ERROR" TO EREQ-SEVERITY
        MOVE "EMPTY_FILE" TO EREQ-CODE
        MOVE "study.csv" TO EREQ-FILE
        MOVE 0 TO EREQ-ROW
        MOVE "file" TO EREQ-FIELD
        MOVE "Required file study.csv is empty (missing header and metadata row)"
            TO EREQ-MESSAGE
        CALL "ERROR-HANDLING" USING ERR-REQ
    ELSE
        IF STUDY-RAW-ROWS = 0
            INITIALIZE ERR-REQ
            MOVE "ADD" TO EREQ-OP
            MOVE "ERROR" TO EREQ-SEVERITY
            MOVE "STUDY_MISSING_ROW" TO EREQ-CODE
            MOVE "study.csv" TO EREQ-FILE
            MOVE 0 TO EREQ-ROW
            MOVE "study_id" TO EREQ-FIELD
            MOVE "study.csv must contain exactly one study metadata record; found 0"
                TO EREQ-MESSAGE
            CALL "ERROR-HANDLING" USING ERR-REQ
        ELSE
            IF STUDY-RAW-ROWS > 1
                INITIALIZE ERR-REQ
                MOVE "ADD" TO EREQ-OP
                MOVE "ERROR" TO EREQ-SEVERITY
                MOVE "STUDY_MULTIPLE_ROWS" TO EREQ-CODE
                MOVE "study.csv" TO EREQ-FILE
                MOVE WS-ROW-NUM TO EREQ-ROW
                MOVE "study_id" TO EREQ-FIELD
                MOVE "Version 1 expects exactly one metadata record in study.csv; found multiple"
                    TO EREQ-MESSAGE
                CALL "ERROR-HANDLING" USING ERR-REQ
            END-IF
        END-IF
    END-IF
    GOBACK.

ADD-MISSING-FILE-ERR.
    INITIALIZE ERR-REQ
    MOVE "ADD" TO EREQ-OP
    MOVE "ERROR" TO EREQ-SEVERITY
    MOVE "FILE_MISSING" TO EREQ-CODE
    MOVE "study.csv" TO EREQ-FILE
    MOVE 0 TO EREQ-ROW
    MOVE "file" TO EREQ-FIELD
    STRING "Cannot open required file study.csv (file status " WS-FS ")"
           DELIMITED BY SIZE INTO EREQ-MESSAGE
    END-STRING
    CALL "ERROR-HANDLING" USING ERR-REQ
    .

PROCESS-LINE.
    INITIALIZE NORM-REQ
    MOVE F-STUDY-REC TO RN-BUF
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
        MOVE "study.csv" TO EREQ-FILE
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
            MOVE "study.csv" TO EREQ-FILE
            MOVE WS-ROW-NUM TO EREQ-ROW
            MOVE "encoding" TO EREQ-FIELD
            MOVE RN-ERR-MSG TO EREQ-MESSAGE
            CALL "ERROR-HANDLING" USING ERR-REQ
            IF WS-ROW-NUM > 1
                ADD 1 TO STUDY-RAW-ROWS
                ADD 1 TO STUDY-REJECTED-ROWS
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
        MOVE "study.csv" TO EREQ-FILE
        MOVE WS-ROW-NUM TO EREQ-ROW
        MOVE "record" TO EREQ-FIELD
        MOVE CSV-ERR-MSG TO EREQ-MESSAGE
        CALL "ERROR-HANDLING" USING ERR-REQ
        IF WS-ROW-NUM > 1
            ADD 1 TO STUDY-RAW-ROWS
            ADD 1 TO STUDY-REJECTED-ROWS
        END-IF
        EXIT PARAGRAPH
    END-IF

    IF WS-ROW-NUM = 1
        PERFORM CHECK-HEADER
        EXIT PARAGRAPH
    END-IF

    ADD 1 TO STUDY-RAW-ROWS
    MOVE "Y" TO WS-ROW-OK

    IF CSV-FIELD-CNT NOT = 6
        INITIALIZE ERR-REQ
        MOVE "ADD" TO EREQ-OP
        MOVE "ERROR" TO EREQ-SEVERITY
        MOVE "COLUMN_COUNT" TO EREQ-CODE
        MOVE "study.csv" TO EREQ-FILE
        MOVE WS-ROW-NUM TO EREQ-ROW
        MOVE "record" TO EREQ-FIELD
        MOVE "Expected exactly 6 columns in study.csv" TO EREQ-MESSAGE
        CALL "ERROR-HANDLING" USING ERR-REQ
        ADD 1 TO STUDY-REJECTED-ROWS
        EXIT PARAGRAPH
    END-IF

    IF FUNCTION TRIM(CSV-F-VAL(1)) = SPACES
        MOVE "N" TO WS-ROW-OK
        MOVE "study_id" TO WS-MISS-FIELD
        PERFORM REPORT-REQ-FIELD
    END-IF
    IF FUNCTION TRIM(CSV-F-VAL(2)) = SPACES
        MOVE "N" TO WS-ROW-OK
        MOVE "study_title" TO WS-MISS-FIELD
        PERFORM REPORT-REQ-FIELD
    END-IF
    IF FUNCTION TRIM(CSV-F-VAL(3)) = SPACES
        MOVE "N" TO WS-ROW-OK
        MOVE "study_design" TO WS-MISS-FIELD
        PERFORM REPORT-REQ-FIELD
    END-IF
    IF FUNCTION TRIM(CSV-F-VAL(4)) = SPACES
        MOVE "N" TO WS-ROW-OK
        MOVE "primary_outcome" TO WS-MISS-FIELD
        PERFORM REPORT-REQ-FIELD
    END-IF
    IF FUNCTION TRIM(CSV-F-VAL(5)) = SPACES
        MOVE "N" TO WS-ROW-OK
        MOVE "primary_outcome_unit" TO WS-MISS-FIELD
        PERFORM REPORT-REQ-FIELD
    END-IF

    IF WS-ROW-OK = "Y" AND STUDY-RAW-ROWS = 1
        MOVE FUNCTION TRIM(CSV-F-VAL(1)) TO ST-STUDY-ID
        MOVE FUNCTION TRIM(CSV-F-VAL(2)) TO ST-STUDY-TITLE
        MOVE FUNCTION TRIM(CSV-F-VAL(3)) TO ST-STUDY-DESIGN
        MOVE FUNCTION TRIM(CSV-F-VAL(4)) TO ST-PRIMARY-OUTCOME
        MOVE FUNCTION TRIM(CSV-F-VAL(5)) TO ST-PRIMARY-UNIT
        MOVE FUNCTION TRIM(CSV-F-VAL(6)) TO ST-DESCRIPTION
        MOVE "Y" TO STUDY-LOADED

        MOVE FUNCTION UPPER-CASE(FUNCTION TRIM(ST-STUDY-DESIGN)) TO WS-DESIGN-UP
        IF WS-DESIGN-UP NOT = "BACI"
            INITIALIZE ERR-REQ
            MOVE "ADD" TO EREQ-OP
            MOVE "WARNING" TO EREQ-SEVERITY
            MOVE "STUDY_DESIGN_NOTE" TO EREQ-CODE
            MOVE "study.csv" TO EREQ-FILE
            MOVE WS-ROW-NUM TO EREQ-ROW
            MOVE "study_design" TO EREQ-FIELD
            STRING "study_design is '" FUNCTION TRIM(ST-STUDY-DESIGN)
                   "' rather than 'BACI'; verify BACI assumptions before analysis"
                   DELIMITED BY SIZE INTO EREQ-MESSAGE
            END-STRING
            CALL "ERROR-HANDLING" USING ERR-REQ
        END-IF
    ELSE
        IF WS-ROW-OK = "N"
            ADD 1 TO STUDY-REJECTED-ROWS
        END-IF
    END-IF
    .

CHECK-HEADER.
    IF CSV-FIELD-CNT = 6
        AND FUNCTION TRIM(CSV-F-VAL(1)) = "study_id"
        AND FUNCTION TRIM(CSV-F-VAL(2)) = "study_title"
        AND FUNCTION TRIM(CSV-F-VAL(3)) = "study_design"
        AND FUNCTION TRIM(CSV-F-VAL(4)) = "primary_outcome"
        AND FUNCTION TRIM(CSV-F-VAL(5)) = "primary_outcome_unit"
        AND FUNCTION TRIM(CSV-F-VAL(6)) = "study_description"
        MOVE "Y" TO WS-HDR-OK
    ELSE
        INITIALIZE ERR-REQ
        MOVE "ADD" TO EREQ-OP
        MOVE "ERROR" TO EREQ-SEVERITY
        MOVE "HEADER_MISMATCH" TO EREQ-CODE
        MOVE "study.csv" TO EREQ-FILE
        MOVE 1 TO EREQ-ROW
        MOVE "header" TO EREQ-FIELD
        MOVE "Expected header: study_id,study_title,study_design,primary_outcome,primary_outcome_unit,study_description"
            TO EREQ-MESSAGE
        CALL "ERROR-HANDLING" USING ERR-REQ
    END-IF
    .

REPORT-REQ-FIELD.
    INITIALIZE ERR-REQ
    MOVE "ADD" TO EREQ-OP
    MOVE "ERROR" TO EREQ-SEVERITY
    MOVE "MISSING_REQUIRED" TO EREQ-CODE
    MOVE "study.csv" TO EREQ-FILE
    MOVE WS-ROW-NUM TO EREQ-ROW
    MOVE WS-MISS-FIELD TO EREQ-FIELD
    STRING "Required field '" FUNCTION TRIM(WS-MISS-FIELD) "' is empty"
           DELIMITED BY SIZE INTO EREQ-MESSAGE
    END-STRING
    CALL "ERROR-HANDLING" USING ERR-REQ
    .
