>>SOURCE FORMAT FREE
*> =====================================================================
*> FIELDLEDGER - ERROR-HANDLING.cob
*> Structured validation error, warning, and diagnostic manager.
*> =====================================================================
IDENTIFICATION DIVISION.
PROGRAM-ID. ERROR-HANDLING.

DATA DIVISION.
WORKING-STORAGE SECTION.
COPY "LIMITS.cpy".
COPY "ERROR-RECORD.cpy".

01 WS-I                     PIC 9(9) COMP-5.
01 WS-SHOWN                 PIC 9(9) COMP-5.
01 WS-ROW-TXT               PIC Z(8)9.
01 WS-ERR-TXT               PIC Z(8)9.
01 WS-WRN-TXT               PIC Z(8)9.
01 WS-INF-TXT               PIC Z(8)9.
01 WS-OVF-TXT               PIC Z(8)9.

LINKAGE SECTION.
COPY "UTILS-IFACE.cpy".

PROCEDURE DIVISION USING ERR-REQ.
MAIN-DISPATCH.
    EVALUATE FUNCTION TRIM(EREQ-OP)
        WHEN "CLEAR"
            PERFORM DO-CLEAR
        WHEN "ADD"
            PERFORM DO-ADD
        WHEN "PRINT-SUMMARY"
            PERFORM DO-PRINT-SUMMARY
        WHEN OTHER
            CONTINUE
    END-EVALUATE
    GOBACK.

DO-CLEAR.
    MOVE 0 TO ERR-COUNT
    MOVE 0 TO ERR-ERROR-CNT
    MOVE 0 TO ERR-WARN-CNT
    MOVE 0 TO ERR-INFO-CNT
    MOVE 0 TO ERR-OVERFLOW-CNT
    .

DO-ADD.
    EVALUATE FUNCTION TRIM(EREQ-SEVERITY)
        WHEN "ERROR"
            ADD 1 TO ERR-ERROR-CNT
        WHEN "WARNING"
            ADD 1 TO ERR-WARN-CNT
        WHEN OTHER
            ADD 1 TO ERR-INFO-CNT
    END-EVALUATE

    IF ERR-COUNT < FL-MAX-ERRORS
        ADD 1 TO ERR-COUNT
        MOVE EREQ-SEVERITY TO ERR-SEVERITY(ERR-COUNT)
        MOVE EREQ-CODE     TO ERR-CODE(ERR-COUNT)
        MOVE EREQ-FILE     TO ERR-FILE(ERR-COUNT)
        MOVE EREQ-ROW      TO ERR-ROW(ERR-COUNT)
        MOVE EREQ-FIELD    TO ERR-FIELD(ERR-COUNT)
        MOVE EREQ-MESSAGE  TO ERR-MESSAGE(ERR-COUNT)
    ELSE
        ADD 1 TO ERR-OVERFLOW-CNT
    END-IF
    .

DO-PRINT-SUMMARY.
    MOVE ERR-ERROR-CNT    TO WS-ERR-TXT
    MOVE ERR-WARN-CNT     TO WS-WRN-TXT
    MOVE ERR-INFO-CNT     TO WS-INF-TXT
    MOVE ERR-OVERFLOW-CNT TO WS-OVF-TXT
    DISPLAY "Validation summary: "
            FUNCTION TRIM(WS-ERR-TXT) " error(s), "
            FUNCTION TRIM(WS-WRN-TXT) " warning(s), "
            FUNCTION TRIM(WS-INF-TXT) " info message(s)."
    IF ERR-OVERFLOW-CNT > 0
        DISPLAY "  [NOTE] Error buffer limit (" FL-MAX-ERRORS
                ") reached; " FUNCTION TRIM(WS-OVF-TXT)
                " additional issue(s) omitted from memory."
    END-IF

    MOVE 0 TO WS-SHOWN
    PERFORM VARYING WS-I FROM 1 BY 1 UNTIL WS-I > ERR-COUNT
        IF ERR-SEVERITY(WS-I) = "ERROR" OR ERR-SEVERITY(WS-I) = "WARNING"
            IF WS-SHOWN < 40
                ADD 1 TO WS-SHOWN
                MOVE ERR-ROW(WS-I) TO WS-ROW-TXT
                DISPLAY "  [" FUNCTION TRIM(ERR-SEVERITY(WS-I)) "] "
                        FUNCTION TRIM(ERR-CODE(WS-I)) " | "
                        FUNCTION TRIM(ERR-FILE(WS-I))
                        " row " FUNCTION TRIM(WS-ROW-TXT)
                        " (" FUNCTION TRIM(ERR-FIELD(WS-I)) "): "
                        FUNCTION TRIM(ERR-MESSAGE(WS-I))
            END-IF
        END-IF
    END-PERFORM

    IF (ERR-ERROR-CNT + ERR-WARN-CNT) > 40
        DISPLAY "  ... additional issues written to validation-report.csv"
    END-IF
    .
