>>SOURCE FORMAT FREE
*> =====================================================================
*> FIELDLEDGER - NUMERIC-UTILS.cob
*> Strict decimal/integer parsing with precision enforcement, clean
*> fixed-point formatting, and RFC 4180 CSV / JSON / HTML escaping.
*> =====================================================================
IDENTIFICATION DIVISION.
PROGRAM-ID. NUMERIC-UTILS.

DATA DIVISION.
WORKING-STORAGE SECTION.
01 WS-TRIM                  PIC X(512).
01 WS-LEN                   PIC 9(6) COMP-5.
01 WS-I                     PIC 9(6) COMP-5.
01 WS-POS                   PIC 9(6) COMP-5.
01 WS-OUT-POS               PIC 9(6) COMP-5.
01 WS-CH                    PIC X(1).
01 WS-SIGN                  PIC S9(1) COMP-5.
01 WS-DOT-SEEN              PIC X(1).
01 WS-INT-DIGS              PIC 9(4) COMP-5.
01 WS-DEC-DIGS              PIC 9(4) COMP-5.
01 WS-INT-ACC               PIC 9(15) COMP-5.
01 WS-DEC-ACC               PIC 9(6) COMP-5.
01 WS-SCALE                 PIC 9(7) COMP-5.
01 WS-DIGIT                 PIC 9(1) COMP-5.
01 WS-FMT-DEC6              PIC -(11)9.9(6).
01 WS-FMT-DEC2              PIC -(11)9.9(2).
01 WS-FMT-INT               PIC -(12)9.
01 WS-DEC2-TMP              PIC S9(11)V9(2) COMP-3.
01 WS-NEEDS-QUOTE           PIC X(1).
01 WS-ORD-VAL               PIC 9(4) COMP-5.
01 WS-HEX-CHARS             PIC X(16) VALUE "0123456789ABCDEF".
01 WS-HI-NIB                PIC 9(2) COMP-5.
01 WS-LO-NIB                PIC 9(2) COMP-5.
01 WS-MAX-INT-LIM           PIC 9(2) COMP-5.
01 WS-MAX-DEC-LIM           PIC 9(2) COMP-5.

LINKAGE SECTION.
COPY "UTILS-IFACE.cpy".

PROCEDURE DIVISION USING NUM-REQ.
MAIN-DISPATCH.
    MOVE "N" TO NREQ-VALID
    MOVE SPACES TO NREQ-ERR-MSG

    EVALUATE FUNCTION TRIM(NREQ-OP)
        WHEN "PARSE-DEC"
            PERFORM DO-PARSE-DEC
        WHEN "PARSE-INT"
            PERFORM DO-PARSE-INT
        WHEN "FMT-DEC6"
            PERFORM DO-FMT-DEC6
        WHEN "FMT-DEC2"
            PERFORM DO-FMT-DEC2
        WHEN "FMT-INT"
            PERFORM DO-FMT-INT
        WHEN "ESC-CSV"
            PERFORM DO-ESC-CSV
        WHEN "ESC-JSON"
            PERFORM DO-ESC-JSON
        WHEN "ESC-HTML"
            PERFORM DO-ESC-HTML
        WHEN OTHER
            MOVE "Unknown NUMERIC-UTILS operation" TO NREQ-ERR-MSG
    END-EVALUATE
    GOBACK.

DO-PARSE-DEC.
    MOVE 0 TO NREQ-DEC-VAL
    MOVE FUNCTION TRIM(NREQ-TEXT-IN) TO WS-TRIM
    MOVE FUNCTION LENGTH(FUNCTION TRIM(WS-TRIM)) TO WS-LEN
    IF WS-LEN = 0
        MOVE "Numeric value is empty" TO NREQ-ERR-MSG
        EXIT PARAGRAPH
    END-IF

    IF NREQ-MAX-INT-DIGITS > 0
        MOVE NREQ-MAX-INT-DIGITS TO WS-MAX-INT-LIM
    ELSE
        MOVE 11 TO WS-MAX-INT-LIM
    END-IF
    IF NREQ-MAX-DEC-DIGITS > 0
        MOVE NREQ-MAX-DEC-DIGITS TO WS-MAX-DEC-LIM
    ELSE
        MOVE 6 TO WS-MAX-DEC-LIM
    END-IF

    MOVE 1 TO WS-SIGN
    MOVE 1 TO WS-POS
    MOVE WS-TRIM(1:1) TO WS-CH
    IF WS-CH = "-"
        IF NREQ-ALLOW-NEG NOT = "Y"
            MOVE "Negative numeric value is not permitted" TO NREQ-ERR-MSG
            EXIT PARAGRAPH
        END-IF
        MOVE -1 TO WS-SIGN
        ADD 1 TO WS-POS
    ELSE
        IF WS-CH = "+"
            ADD 1 TO WS-POS
        END-IF
    END-IF

    IF WS-POS > WS-LEN
        MOVE "Sign without digits is not a valid number" TO NREQ-ERR-MSG
        EXIT PARAGRAPH
    END-IF

    MOVE "N" TO WS-DOT-SEEN
    MOVE 0 TO WS-INT-DIGS
    MOVE 0 TO WS-DEC-DIGS
    MOVE 0 TO WS-INT-ACC
    MOVE 0 TO WS-DEC-ACC
    MOVE 100000 TO WS-SCALE

    PERFORM VARYING WS-I FROM WS-POS BY 1 UNTIL WS-I > WS-LEN
        MOVE WS-TRIM(WS-I:1) TO WS-CH
        IF WS-CH = "."
            IF WS-DOT-SEEN = "Y"
                MOVE "Multiple decimal points in numeric value" TO NREQ-ERR-MSG
                EXIT PARAGRAPH
            END-IF
            MOVE "Y" TO WS-DOT-SEEN
        ELSE
            IF WS-CH >= "0" AND WS-CH <= "9"
                COMPUTE WS-DIGIT = FUNCTION ORD(WS-CH) - FUNCTION ORD("0")
                IF WS-DOT-SEEN = "N"
                    IF WS-INT-ACC > 0 OR WS-DIGIT > 0
                        ADD 1 TO WS-INT-DIGS
                        IF WS-INT-DIGS > WS-MAX-INT-LIM
                            MOVE "Integer part exceeds documented numeric precision"
                                TO NREQ-ERR-MSG
                            EXIT PARAGRAPH
                        END-IF
                    END-IF
                    COMPUTE WS-INT-ACC = (WS-INT-ACC * 10) + WS-DIGIT
                ELSE
                    ADD 1 TO WS-DEC-DIGS
                    IF WS-DEC-DIGS > WS-MAX-DEC-LIM
                        MOVE "Decimal precision exceeds documented numeric limit"
                            TO NREQ-ERR-MSG
                        EXIT PARAGRAPH
                    END-IF
                    COMPUTE WS-DEC-ACC = WS-DEC-ACC + (WS-DIGIT * WS-SCALE)
                    COMPUTE WS-SCALE = WS-SCALE / 10
                END-IF
            ELSE
                MOVE "Invalid non-numeric character in decimal field"
                    TO NREQ-ERR-MSG
                EXIT PARAGRAPH
            END-IF
        END-IF
    END-PERFORM

    IF WS-INT-DIGS = 0 AND WS-DEC-DIGS = 0
        *> Allow literal "0" or "0.0"
        IF WS-TRIM(WS-POS:1) NOT = "0"
            MOVE "Numeric field contains no digits" TO NREQ-ERR-MSG
            EXIT PARAGRAPH
        END-IF
    END-IF

    COMPUTE NREQ-DEC-VAL = WS-SIGN * (WS-INT-ACC + (WS-DEC-ACC / 1000000))
    IF NREQ-DEC-VAL = 0 AND NREQ-ALLOW-ZERO = "N"
        MOVE "Numeric value must be strictly greater than zero" TO NREQ-ERR-MSG
        EXIT PARAGRAPH
    END-IF

    MOVE "Y" TO NREQ-VALID
    .

DO-PARSE-INT.
    MOVE 0 TO NREQ-INT-VAL
    MOVE FUNCTION TRIM(NREQ-TEXT-IN) TO WS-TRIM
    MOVE FUNCTION LENGTH(FUNCTION TRIM(WS-TRIM)) TO WS-LEN
    IF WS-LEN = 0
        MOVE "Integer value is empty" TO NREQ-ERR-MSG
        EXIT PARAGRAPH
    END-IF

    IF NREQ-MAX-INT-DIGITS > 0
        MOVE NREQ-MAX-INT-DIGITS TO WS-MAX-INT-LIM
    ELSE
        MOVE 9 TO WS-MAX-INT-LIM
    END-IF

    MOVE 1 TO WS-SIGN
    MOVE 1 TO WS-POS
    MOVE WS-TRIM(1:1) TO WS-CH
    IF WS-CH = "-"
        IF NREQ-ALLOW-NEG NOT = "Y"
            MOVE "Negative integer value is not permitted" TO NREQ-ERR-MSG
            EXIT PARAGRAPH
        END-IF
        MOVE -1 TO WS-SIGN
        ADD 1 TO WS-POS
    ELSE
        IF WS-CH = "+"
            ADD 1 TO WS-POS
        END-IF
    END-IF

    IF WS-POS > WS-LEN
        MOVE "Sign without digits is not a valid integer" TO NREQ-ERR-MSG
        EXIT PARAGRAPH
    END-IF

    MOVE 0 TO WS-INT-DIGS
    MOVE 0 TO WS-INT-ACC

    PERFORM VARYING WS-I FROM WS-POS BY 1 UNTIL WS-I > WS-LEN
        MOVE WS-TRIM(WS-I:1) TO WS-CH
        IF WS-CH >= "0" AND WS-CH <= "9"
            COMPUTE WS-DIGIT = FUNCTION ORD(WS-CH) - FUNCTION ORD("0")
            IF WS-INT-ACC > 0 OR WS-DIGIT > 0
                ADD 1 TO WS-INT-DIGS
                IF WS-INT-DIGS > WS-MAX-INT-LIM
                    MOVE "Integer exceeds documented numeric precision"
                        TO NREQ-ERR-MSG
                    EXIT PARAGRAPH
                END-IF
            END-IF
            COMPUTE WS-INT-ACC = (WS-INT-ACC * 10) + WS-DIGIT
        ELSE
            MOVE "Invalid non-digit character in integer field" TO NREQ-ERR-MSG
            EXIT PARAGRAPH
        END-IF
    END-PERFORM

    COMPUTE NREQ-INT-VAL = WS-SIGN * WS-INT-ACC
    IF NREQ-INT-VAL = 0 AND NREQ-ALLOW-ZERO = "N"
        MOVE "Integer value must be strictly greater than zero" TO NREQ-ERR-MSG
        EXIT PARAGRAPH
    END-IF

    MOVE "Y" TO NREQ-VALID
    .

DO-FMT-DEC6.
    MOVE SPACES TO NREQ-TEXT-OUT
    MOVE NREQ-DEC-VAL TO WS-FMT-DEC6
    MOVE FUNCTION TRIM(WS-FMT-DEC6) TO NREQ-TEXT-OUT
    MOVE FUNCTION LENGTH(FUNCTION TRIM(NREQ-TEXT-OUT)) TO NREQ-OUT-LEN
    MOVE "Y" TO NREQ-VALID
    .

DO-FMT-DEC2.
    MOVE SPACES TO NREQ-TEXT-OUT
    COMPUTE WS-DEC2-TMP ROUNDED = NREQ-DEC-VAL
    MOVE WS-DEC2-TMP TO WS-FMT-DEC2
    MOVE FUNCTION TRIM(WS-FMT-DEC2) TO NREQ-TEXT-OUT
    MOVE FUNCTION LENGTH(FUNCTION TRIM(NREQ-TEXT-OUT)) TO NREQ-OUT-LEN
    MOVE "Y" TO NREQ-VALID
    .

DO-FMT-INT.
    MOVE SPACES TO NREQ-TEXT-OUT
    MOVE NREQ-INT-VAL TO WS-FMT-INT
    MOVE FUNCTION TRIM(WS-FMT-INT) TO NREQ-TEXT-OUT
    MOVE FUNCTION LENGTH(FUNCTION TRIM(NREQ-TEXT-OUT)) TO NREQ-OUT-LEN
    MOVE "Y" TO NREQ-VALID
    .

DO-ESC-CSV.
    MOVE SPACES TO NREQ-TEXT-OUT
    MOVE FUNCTION LENGTH(FUNCTION TRIM(NREQ-TEXT-IN TRAILING)) TO WS-LEN
    MOVE "N" TO WS-NEEDS-QUOTE

    PERFORM VARYING WS-I FROM 1 BY 1 UNTIL WS-I > WS-LEN
        MOVE NREQ-TEXT-IN(WS-I:1) TO WS-CH
        IF WS-CH = "," OR WS-CH = '"' OR WS-CH = X"0A" OR WS-CH = X"0D"
            MOVE "Y" TO WS-NEEDS-QUOTE
            EXIT PERFORM
        END-IF
    END-PERFORM

    IF WS-NEEDS-QUOTE = "N"
        IF WS-LEN > 0
            MOVE NREQ-TEXT-IN(1:WS-LEN) TO NREQ-TEXT-OUT
        END-IF
        MOVE WS-LEN TO NREQ-OUT-LEN
    ELSE
        MOVE 1 TO WS-OUT-POS
        MOVE '"' TO NREQ-TEXT-OUT(WS-OUT-POS:1)
        ADD 1 TO WS-OUT-POS
        PERFORM VARYING WS-I FROM 1 BY 1 UNTIL WS-I > WS-LEN
            MOVE NREQ-TEXT-IN(WS-I:1) TO WS-CH
            IF WS-CH = '"'
                IF WS-OUT-POS + 1 <= 1022
                    MOVE '""' TO NREQ-TEXT-OUT(WS-OUT-POS:2)
                    ADD 2 TO WS-OUT-POS
                END-IF
            ELSE
                IF WS-OUT-POS <= 1022
                    MOVE WS-CH TO NREQ-TEXT-OUT(WS-OUT-POS:1)
                    ADD 1 TO WS-OUT-POS
                END-IF
            END-IF
        END-PERFORM
        MOVE '"' TO NREQ-TEXT-OUT(WS-OUT-POS:1)
        MOVE WS-OUT-POS TO NREQ-OUT-LEN
    END-IF
    MOVE "Y" TO NREQ-VALID
    .

DO-ESC-JSON.
    MOVE SPACES TO NREQ-TEXT-OUT
    MOVE FUNCTION LENGTH(FUNCTION TRIM(NREQ-TEXT-IN TRAILING)) TO WS-LEN
    MOVE 1 TO WS-OUT-POS

    PERFORM VARYING WS-I FROM 1 BY 1 UNTIL WS-I > WS-LEN
        MOVE NREQ-TEXT-IN(WS-I:1) TO WS-CH
        COMPUTE WS-ORD-VAL = FUNCTION ORD(WS-CH) - 1
        EVALUATE TRUE
            WHEN WS-CH = '"'
                IF WS-OUT-POS + 1 <= 1024
                    MOVE '\"' TO NREQ-TEXT-OUT(WS-OUT-POS:2)
                    ADD 2 TO WS-OUT-POS
                END-IF
            WHEN WS-CH = "\"
                IF WS-OUT-POS + 1 <= 1024
                    MOVE "\\" TO NREQ-TEXT-OUT(WS-OUT-POS:2)
                    ADD 2 TO WS-OUT-POS
                END-IF
            WHEN WS-ORD-VAL = 8
                IF WS-OUT-POS + 1 <= 1024
                    MOVE "\b" TO NREQ-TEXT-OUT(WS-OUT-POS:2)
                    ADD 2 TO WS-OUT-POS
                END-IF
            WHEN WS-ORD-VAL = 12
                IF WS-OUT-POS + 1 <= 1024
                    MOVE "\f" TO NREQ-TEXT-OUT(WS-OUT-POS:2)
                    ADD 2 TO WS-OUT-POS
                END-IF
            WHEN WS-ORD-VAL = 10
                IF WS-OUT-POS + 1 <= 1024
                    MOVE "\n" TO NREQ-TEXT-OUT(WS-OUT-POS:2)
                    ADD 2 TO WS-OUT-POS
                END-IF
            WHEN WS-ORD-VAL = 13
                IF WS-OUT-POS + 1 <= 1024
                    MOVE "\r" TO NREQ-TEXT-OUT(WS-OUT-POS:2)
                    ADD 2 TO WS-OUT-POS
                END-IF
            WHEN WS-ORD-VAL = 9
                IF WS-OUT-POS + 1 <= 1024
                    MOVE "\t" TO NREQ-TEXT-OUT(WS-OUT-POS:2)
                    ADD 2 TO WS-OUT-POS
                END-IF
            WHEN WS-ORD-VAL < 32
                IF WS-OUT-POS + 5 <= 1024
                    COMPUTE WS-HI-NIB = FUNCTION INTEGER(WS-ORD-VAL / 16) + 1
                    COMPUTE WS-LO-NIB = FUNCTION MOD(WS-ORD-VAL, 16) + 1
                    MOVE "\u00" TO NREQ-TEXT-OUT(WS-OUT-POS:4)
                    MOVE WS-HEX-CHARS(WS-HI-NIB:1)
                        TO NREQ-TEXT-OUT(WS-OUT-POS + 4:1)
                    MOVE WS-HEX-CHARS(WS-LO-NIB:1)
                        TO NREQ-TEXT-OUT(WS-OUT-POS + 5:1)
                    ADD 6 TO WS-OUT-POS
                END-IF
            WHEN OTHER
                IF WS-OUT-POS <= 1024
                    MOVE WS-CH TO NREQ-TEXT-OUT(WS-OUT-POS:1)
                    ADD 1 TO WS-OUT-POS
                END-IF
        END-EVALUATE
    END-PERFORM

    COMPUTE NREQ-OUT-LEN = WS-OUT-POS - 1
    MOVE "Y" TO NREQ-VALID
    .

DO-ESC-HTML.
    MOVE SPACES TO NREQ-TEXT-OUT
    MOVE FUNCTION LENGTH(FUNCTION TRIM(NREQ-TEXT-IN TRAILING)) TO WS-LEN
    MOVE 1 TO WS-OUT-POS

    PERFORM VARYING WS-I FROM 1 BY 1 UNTIL WS-I > WS-LEN
        MOVE NREQ-TEXT-IN(WS-I:1) TO WS-CH
        EVALUATE WS-CH
            WHEN "&"
                IF WS-OUT-POS + 4 <= 1024
                    MOVE "&amp;" TO NREQ-TEXT-OUT(WS-OUT-POS:5)
                    ADD 5 TO WS-OUT-POS
                END-IF
            WHEN "<"
                IF WS-OUT-POS + 3 <= 1024
                    MOVE "&lt;" TO NREQ-TEXT-OUT(WS-OUT-POS:4)
                    ADD 4 TO WS-OUT-POS
                END-IF
            WHEN ">"
                IF WS-OUT-POS + 3 <= 1024
                    MOVE "&gt;" TO NREQ-TEXT-OUT(WS-OUT-POS:4)
                    ADD 4 TO WS-OUT-POS
                END-IF
            WHEN '"'
                IF WS-OUT-POS + 5 <= 1024
                    MOVE "&quot;" TO NREQ-TEXT-OUT(WS-OUT-POS:6)
                    ADD 6 TO WS-OUT-POS
                END-IF
            WHEN "'"
                IF WS-OUT-POS + 4 <= 1024
                    MOVE "&#39;" TO NREQ-TEXT-OUT(WS-OUT-POS:5)
                    ADD 5 TO WS-OUT-POS
                END-IF
            WHEN OTHER
                IF WS-OUT-POS <= 1024
                    MOVE WS-CH TO NREQ-TEXT-OUT(WS-OUT-POS:1)
                    ADD 1 TO WS-OUT-POS
                END-IF
        END-EVALUATE
    END-PERFORM

    COMPUTE NREQ-OUT-LEN = WS-OUT-POS - 1
    MOVE "Y" TO NREQ-VALID
    .
