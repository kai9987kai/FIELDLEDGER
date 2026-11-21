>>SOURCE FORMAT FREE
*> =====================================================================
*> FIELDLEDGER - RECORD-NORMALISER.cob
*> Transport-level line normalisation (CRLF handling) and strict
*> encoding validation (rejects UTF-16 BOM, NUL bytes, invalid UTF-8
*> sequences, and lines exceeding documented length limits).
*> Never mutates scientific field values.
*> =====================================================================
IDENTIFICATION DIVISION.
PROGRAM-ID. RECORD-NORMALISER.

DATA DIVISION.
WORKING-STORAGE SECTION.
COPY "LIMITS.cpy".

01 WS-I                     PIC 9(6) COMP-5.
01 WS-LEN                   PIC 9(6) COMP-5.
01 WS-B0                    PIC 9(4) COMP-5.
01 WS-B1                    PIC 9(4) COMP-5.
01 WS-B2                    PIC 9(4) COMP-5.
01 WS-B3                    PIC 9(4) COMP-5.
01 WS-NEED-CONT             PIC 9(2) COMP-5.
01 WS-TMP-BUF               PIC X(4096).
01 WS-HAD-BOM               PIC X(1).

LINKAGE SECTION.
COPY "UTILS-IFACE.cpy".

PROCEDURE DIVISION USING NORM-REQ.
MAIN-NORM.
    MOVE 00 TO RN-STATUS
    MOVE SPACES TO RN-ERR-MSG
    MOVE "N" TO WS-HAD-BOM

    *> Compute effective length (strip trailing spaces added by fixed buffer)
    MOVE FUNCTION LENGTH(FUNCTION TRIM(RN-BUF TRAILING)) TO WS-LEN

    *> Check if line hit buffer ceiling (likely truncated at read)
    IF WS-LEN >= 4095
        MOVE 05 TO RN-STATUS
        MOVE "Input record exceeds maximum supported line length (4094 bytes)"
            TO RN-ERR-MSG
        MOVE WS-LEN TO RN-LEN
        GOBACK
    END-IF

    *> Strip trailing CR (0x0D) from Windows CRLF files
    PERFORM UNTIL WS-LEN = 0
        COMPUTE WS-B0 = FUNCTION ORD(RN-BUF(WS-LEN:1)) - 1
        IF WS-B0 = 13
            MOVE SPACE TO RN-BUF(WS-LEN:1)
            SUBTRACT 1 FROM WS-LEN
        ELSE
            EXIT PERFORM
        END-IF
    END-PERFORM

    *> First-line BOM checks
    IF RN-IS-FIRST-LINE = "Y" AND WS-LEN >= 2
        COMPUTE WS-B0 = FUNCTION ORD(RN-BUF(1:1)) - 1
        COMPUTE WS-B1 = FUNCTION ORD(RN-BUF(2:1)) - 1
        IF (WS-B0 = 255 AND WS-B1 = 254) OR (WS-B0 = 254 AND WS-B1 = 255)
            MOVE 02 TO RN-STATUS
            MOVE "Unsupported UTF-16 encoding detected (BOM FF FE / FE FF); convert file to UTF-8"
                TO RN-ERR-MSG
            MOVE WS-LEN TO RN-LEN
            GOBACK
        END-IF
        IF WS-LEN >= 3
            COMPUTE WS-B2 = FUNCTION ORD(RN-BUF(3:1)) - 1
            IF WS-B0 = 239 AND WS-B1 = 187 AND WS-B2 = 191
                MOVE "Y" TO WS-HAD-BOM
                MOVE SPACES TO WS-TMP-BUF
                IF WS-LEN > 3
                    MOVE RN-BUF(4:WS-LEN - 3) TO WS-TMP-BUF
                END-IF
                MOVE WS-TMP-BUF TO RN-BUF
                SUBTRACT 3 FROM WS-LEN
            END-IF
        END-IF
    END-IF

    *> Validate NUL bytes and UTF-8 multibyte encoding across line
    MOVE 1 TO WS-I
    PERFORM UNTIL WS-I > WS-LEN
        COMPUTE WS-B0 = FUNCTION ORD(RN-BUF(WS-I:1)) - 1
        IF WS-B0 = 0
            MOVE 03 TO RN-STATUS
            MOVE "Unsupported binary/NUL byte (0x00) detected in text record"
                TO RN-ERR-MSG
            MOVE WS-LEN TO RN-LEN
            GOBACK
        END-IF

        IF WS-B0 < 128
            ADD 1 TO WS-I
        ELSE
            *> Multibyte UTF-8 sequence validation
            MOVE 0 TO WS-NEED-CONT
            EVALUATE TRUE
                WHEN WS-B0 >= 194 AND WS-B0 <= 223
                    MOVE 1 TO WS-NEED-CONT
                WHEN WS-B0 >= 224 AND WS-B0 <= 239
                    MOVE 2 TO WS-NEED-CONT
                WHEN WS-B0 >= 240 AND WS-B0 <= 244
                    MOVE 3 TO WS-NEED-CONT
                WHEN OTHER
                    MOVE 04 TO RN-STATUS
                    MOVE "Invalid UTF-8 lead byte detected (non-UTF-8 encoding such as Latin-1/CP1252)"
                        TO RN-ERR-MSG
                    MOVE WS-LEN TO RN-LEN
                    GOBACK
            END-EVALUATE

            IF WS-I + WS-NEED-CONT > WS-LEN
                MOVE 04 TO RN-STATUS
                MOVE "Truncated UTF-8 multibyte character sequence at end of record"
                    TO RN-ERR-MSG
                MOVE WS-LEN TO RN-LEN
                GOBACK
            END-IF

            COMPUTE WS-B1 = FUNCTION ORD(RN-BUF(WS-I + 1:1)) - 1
            IF WS-B1 < 128 OR WS-B1 > 191
                MOVE 04 TO RN-STATUS
                MOVE "Invalid UTF-8 continuation byte detected"
                    TO RN-ERR-MSG
                MOVE WS-LEN TO RN-LEN
                GOBACK
            END-IF

            IF WS-NEED-CONT >= 2
                COMPUTE WS-B2 = FUNCTION ORD(RN-BUF(WS-I + 2:1)) - 1
                IF WS-B2 < 128 OR WS-B2 > 191
                    MOVE 04 TO RN-STATUS
                    MOVE "Invalid UTF-8 3-byte continuation sequence"
                        TO RN-ERR-MSG
                    MOVE WS-LEN TO RN-LEN
                    GOBACK
                END-IF
                *> Reject overlong 3-byte sequences and UTF-16 surrogates
                IF (WS-B0 = 224 AND WS-B1 < 160)
                    OR (WS-B0 = 237 AND WS-B1 >= 160)
                    MOVE 04 TO RN-STATUS
                    MOVE "Invalid overlong or surrogate UTF-8 sequence"
                        TO RN-ERR-MSG
                    MOVE WS-LEN TO RN-LEN
                    GOBACK
                END-IF
            END-IF

            IF WS-NEED-CONT = 3
                COMPUTE WS-B3 = FUNCTION ORD(RN-BUF(WS-I + 3:1)) - 1
                IF WS-B3 < 128 OR WS-B3 > 191
                    MOVE 04 TO RN-STATUS
                    MOVE "Invalid UTF-8 4-byte continuation sequence"
                        TO RN-ERR-MSG
                    MOVE WS-LEN TO RN-LEN
                    GOBACK
                END-IF
                IF (WS-B0 = 240 AND WS-B1 < 144)
                    OR (WS-B0 = 244 AND WS-B1 > 143)
                    MOVE 04 TO RN-STATUS
                    MOVE "Invalid out-of-range UTF-8 4-byte sequence"
                        TO RN-ERR-MSG
                    MOVE WS-LEN TO RN-LEN
                    GOBACK
                END-IF
            END-IF

            COMPUTE WS-I = WS-I + 1 + WS-NEED-CONT
        END-IF
    END-PERFORM

    MOVE WS-LEN TO RN-LEN
    IF WS-HAD-BOM = "Y"
        MOVE 01 TO RN-STATUS
        MOVE "UTF-8 BOM (EF BB BF) detected and stripped on header line"
            TO RN-ERR-MSG
    END-IF
    GOBACK.
