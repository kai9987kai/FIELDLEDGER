>>SOURCE FORMAT FREE
*> =====================================================================
*> FIELDLEDGER - CSV-READER.cob
*> RFC 4180-compatible CSV record parser.
*> Supports quoted fields, commas inside quoted values, escaped double
*> quotes (""), and empty trailing fields. Strictly rejects unclosed
*> quotes, stray quotes in unquoted fields, and trailing characters
*> after a closing quote.
*> =====================================================================
IDENTIFICATION DIVISION.
PROGRAM-ID. CSV-READER.

DATA DIVISION.
WORKING-STORAGE SECTION.
COPY "LIMITS.cpy".

01 WS-I                     PIC 9(6) COMP-5.
01 WS-LEN                   PIC 9(6) COMP-5.
01 WS-STATE                 PIC 9(1) COMP-5.
   88 ST-START              VALUE 0.
   88 ST-UNQUOTED           VALUE 1.
   88 ST-QUOTED             VALUE 2.
   88 ST-AFTER-QUOTE        VALUE 3.
01 WS-F-IDX                 PIC 9(4) COMP-5.
01 WS-C-POS                 PIC 9(4) COMP-5.
01 WS-CH                    PIC X(1).
01 WS-NEXT-CH               PIC X(1).

LINKAGE SECTION.
COPY "CSV-WORK.cpy".

PROCEDURE DIVISION USING CSV-REQ.
MAIN-PARSE.
    MOVE 00 TO CSV-STATUS
    MOVE SPACES TO CSV-ERR-MSG
    MOVE 0 TO CSV-FIELD-CNT

    PERFORM VARYING WS-F-IDX FROM 1 BY 1 UNTIL WS-F-IDX > FL-MAX-CSV-FIELDS
        MOVE SPACES TO CSV-F-VAL(WS-F-IDX)
        MOVE 0      TO CSV-F-LEN(WS-F-IDX)
    END-PERFORM

    IF CSV-LINE-LEN > 0
        MOVE CSV-LINE-LEN TO WS-LEN
    ELSE
        MOVE FUNCTION LENGTH(FUNCTION TRIM(CSV-LINE TRAILING)) TO WS-LEN
    END-IF

    IF WS-LEN = 0
        MOVE 0 TO CSV-FIELD-CNT
        GOBACK
    END-IF

    MOVE 1 TO WS-F-IDX
    MOVE 0 TO WS-C-POS
    SET ST-START TO TRUE
    MOVE 1 TO WS-I

    PERFORM UNTIL WS-I > WS-LEN
        MOVE CSV-LINE(WS-I:1) TO WS-CH

        EVALUATE TRUE
            WHEN ST-START
                IF WS-CH = '"'
                    SET ST-QUOTED TO TRUE
                    ADD 1 TO WS-I
                ELSE
                    IF WS-CH = ","
                        MOVE WS-C-POS TO CSV-F-LEN(WS-F-IDX)
                        ADD 1 TO WS-F-IDX
                        IF WS-F-IDX > FL-MAX-CSV-FIELDS
                            MOVE 04 TO CSV-STATUS
                            MOVE "CSV record exceeds maximum column limit (16)"
                                TO CSV-ERR-MSG
                            GOBACK
                        END-IF
                        MOVE 0 TO WS-C-POS
                        ADD 1 TO WS-I
                    ELSE
                        SET ST-UNQUOTED TO TRUE
                        PERFORM APPEND-CHAR
                        IF CSV-STATUS NOT = 00
                            GOBACK
                        END-IF
                        ADD 1 TO WS-I
                    END-IF
                END-IF

            WHEN ST-UNQUOTED
                IF WS-CH = ","
                    MOVE WS-C-POS TO CSV-F-LEN(WS-F-IDX)
                    ADD 1 TO WS-F-IDX
                    IF WS-F-IDX > FL-MAX-CSV-FIELDS
                        MOVE 04 TO CSV-STATUS
                        MOVE "CSV record exceeds maximum column limit (16)"
                            TO CSV-ERR-MSG
                        GOBACK
                    END-IF
                    MOVE 0 TO WS-C-POS
                    SET ST-START TO TRUE
                    ADD 1 TO WS-I
                ELSE
                    IF WS-CH = '"'
                        MOVE 02 TO CSV-STATUS
                        MOVE "Malformed CSV: unescaped quote inside unquoted field"
                            TO CSV-ERR-MSG
                        GOBACK
                    ELSE
                        PERFORM APPEND-CHAR
                        IF CSV-STATUS NOT = 00
                            GOBACK
                        END-IF
                        ADD 1 TO WS-I
                    END-IF
                END-IF

            WHEN ST-QUOTED
                IF WS-CH = '"'
                    IF WS-I < WS-LEN
                        MOVE CSV-LINE(WS-I + 1:1) TO WS-NEXT-CH
                        IF WS-NEXT-CH = '"'
                            *> RFC 4180 escaped double quote ("")
                            PERFORM APPEND-CHAR
                            IF CSV-STATUS NOT = 00
                                GOBACK
                            END-IF
                            ADD 2 TO WS-I
                        ELSE
                            SET ST-AFTER-QUOTE TO TRUE
                            ADD 1 TO WS-I
                        END-IF
                    ELSE
                        SET ST-AFTER-QUOTE TO TRUE
                        ADD 1 TO WS-I
                    END-IF
                ELSE
                    PERFORM APPEND-CHAR
                    IF CSV-STATUS NOT = 00
                        GOBACK
                    END-IF
                    ADD 1 TO WS-I
                END-IF

            WHEN ST-AFTER-QUOTE
                IF WS-CH = ","
                    MOVE WS-C-POS TO CSV-F-LEN(WS-F-IDX)
                    ADD 1 TO WS-F-IDX
                    IF WS-F-IDX > FL-MAX-CSV-FIELDS
                        MOVE 04 TO CSV-STATUS
                        MOVE "CSV record exceeds maximum column limit (16)"
                            TO CSV-ERR-MSG
                        GOBACK
                    END-IF
                    MOVE 0 TO WS-C-POS
                    SET ST-START TO TRUE
                    ADD 1 TO WS-I
                ELSE
                    MOVE 03 TO CSV-STATUS
                    MOVE "Malformed CSV: unexpected character after closing quote"
                        TO CSV-ERR-MSG
                    GOBACK
                END-IF
        END-EVALUATE
    END-PERFORM

    IF ST-QUOTED
        MOVE 01 TO CSV-STATUS
        MOVE "Malformed CSV: unclosed quoted field at end of line"
            TO CSV-ERR-MSG
        GOBACK
    END-IF

    MOVE WS-C-POS TO CSV-F-LEN(WS-F-IDX)
    MOVE WS-F-IDX TO CSV-FIELD-CNT
    GOBACK.

APPEND-CHAR.
    IF WS-C-POS >= FL-MAX-CSV-FIELD-LEN
        MOVE 05 TO CSV-STATUS
        MOVE "CSV field exceeds maximum length (512 characters)"
            TO CSV-ERR-MSG
        EXIT PARAGRAPH
    END-IF
    ADD 1 TO WS-C-POS
    MOVE WS-CH TO CSV-F-VAL(WS-F-IDX)(WS-C-POS:1)
    .
