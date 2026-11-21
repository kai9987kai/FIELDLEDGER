>>SOURCE FORMAT FREE
*> =====================================================================
*> FIELDLEDGER - DATE-UTILS.cob
*> Strict ISO 8601 (YYYY-MM-DD) calendar-date validation, Gregorian
*> leap-year checking, ordinal day conversion, and PRE/POST/TRANSITION
*> period classification.
*> =====================================================================
IDENTIFICATION DIVISION.
PROGRAM-ID. DATE-UTILS.

DATA DIVISION.
WORKING-STORAGE SECTION.
01 WS-STR                   PIC X(32).
01 WS-LEN                   PIC 9(4) COMP-5.
01 WS-YR                    PIC 9(4) COMP-5.
01 WS-MO                    PIC 9(2) COMP-5.
01 WS-DY                    PIC 9(2) COMP-5.
01 WS-MAX-DY                PIC 9(2) COMP-5.
01 WS-IS-LEAP               PIC X(1).
01 WS-ORD                   PIC 9(9) COMP-5.
01 WS-OK                    PIC X(1).
01 WS-MSG                   PIC X(128).
01 WS-ADJ-Y                 PIC S9(9) COMP-5.
01 WS-ADJ-M                 PIC S9(9) COMP-5.
01 WS-ERA-A                 PIC S9(9) COMP-5.
01 WS-ERA-B                 PIC S9(9) COMP-5.
01 WS-ERA-C                 PIC S9(9) COMP-5.
01 WS-ERA-D                 PIC S9(9) COMP-5.
01 WS-ORD-A                 PIC 9(9) COMP-5.
01 WS-ORD-B                 PIC 9(9) COMP-5.

LINKAGE SECTION.
COPY "UTILS-IFACE.cpy".

PROCEDURE DIVISION USING DATE-REQ.
MAIN-DISPATCH.
    MOVE "N" TO DREQ-VALID
    MOVE 0 TO DREQ-ORD-A
    MOVE 0 TO DREQ-ORD-B
    MOVE SPACES TO DREQ-PERIOD
    MOVE SPACES TO DREQ-ERR-MSG

    EVALUATE FUNCTION TRIM(DREQ-OP)
        WHEN "VALIDATE"
            MOVE DREQ-DATE-A TO WS-STR
            PERFORM VALIDATE-ONE
            MOVE WS-OK  TO DREQ-VALID
            MOVE WS-ORD TO DREQ-ORD-A
            MOVE WS-MSG TO DREQ-ERR-MSG

        WHEN "COMPARE"
            MOVE DREQ-DATE-A TO WS-STR
            PERFORM VALIDATE-ONE
            IF WS-OK = "N"
                MOVE "N" TO DREQ-VALID
                MOVE WS-MSG TO DREQ-ERR-MSG
                GOBACK
            END-IF
            MOVE WS-ORD TO WS-ORD-A

            MOVE DREQ-DATE-B TO WS-STR
            PERFORM VALIDATE-ONE
            IF WS-OK = "N"
                MOVE "N" TO DREQ-VALID
                MOVE WS-MSG TO DREQ-ERR-MSG
                GOBACK
            END-IF
            MOVE WS-ORD TO WS-ORD-B

            MOVE "Y" TO DREQ-VALID
            MOVE WS-ORD-A TO DREQ-ORD-A
            MOVE WS-ORD-B TO DREQ-ORD-B
            IF WS-ORD-A < WS-ORD-B
                MOVE "PRE" TO DREQ-PERIOD
            ELSE
                IF WS-ORD-A > WS-ORD-B
                    MOVE "POST" TO DREQ-PERIOD
                ELSE
                    MOVE "TRANSITION" TO DREQ-PERIOD
                END-IF
            END-IF

        WHEN OTHER
            MOVE "Unknown DATE-UTILS operation" TO DREQ-ERR-MSG
    END-EVALUATE
    GOBACK.

VALIDATE-ONE.
    MOVE "N" TO WS-OK
    MOVE 0 TO WS-ORD
    MOVE SPACES TO WS-MSG

    MOVE FUNCTION TRIM(WS-STR) TO WS-STR
    MOVE FUNCTION LENGTH(FUNCTION TRIM(WS-STR)) TO WS-LEN
    IF WS-LEN NOT = 10
        MOVE "Date must match ISO 8601 format YYYY-MM-DD (exact length 10)"
            TO WS-MSG
        EXIT PARAGRAPH
    END-IF

    IF WS-STR(5:1) NOT = "-" OR WS-STR(8:1) NOT = "-"
        MOVE "Date separators must be hyphens in YYYY-MM-DD format"
            TO WS-MSG
        EXIT PARAGRAPH
    END-IF

    IF WS-STR(1:4) NOT NUMERIC
        OR WS-STR(6:2) NOT NUMERIC
        OR WS-STR(9:2) NOT NUMERIC
        MOVE "Date components YYYY, MM, and DD must be ASCII digits"
            TO WS-MSG
        EXIT PARAGRAPH
    END-IF

    MOVE FUNCTION NUMVAL(WS-STR(1:4)) TO WS-YR
    MOVE FUNCTION NUMVAL(WS-STR(6:2)) TO WS-MO
    MOVE FUNCTION NUMVAL(WS-STR(9:2)) TO WS-DY

    IF WS-YR < 1 OR WS-YR > 9999
        MOVE "Calendar year out of valid range (0001-9999)" TO WS-MSG
        EXIT PARAGRAPH
    END-IF

    IF WS-MO < 1 OR WS-MO > 12
        MOVE "Calendar month out of valid range (01-12)" TO WS-MSG
        EXIT PARAGRAPH
    END-IF

    MOVE "N" TO WS-IS-LEAP
    IF (FUNCTION MOD(WS-YR, 4) = 0 AND FUNCTION MOD(WS-YR, 100) NOT = 0)
        OR (FUNCTION MOD(WS-YR, 400) = 0)
        MOVE "Y" TO WS-IS-LEAP
    END-IF

    EVALUATE WS-MO
        WHEN 1 WHEN 3 WHEN 5 WHEN 7 WHEN 8 WHEN 10 WHEN 12
            MOVE 31 TO WS-MAX-DY
        WHEN 4 WHEN 6 WHEN 9 WHEN 11
            MOVE 30 TO WS-MAX-DY
        WHEN 2
            IF WS-IS-LEAP = "Y"
                MOVE 29 TO WS-MAX-DY
            ELSE
                MOVE 28 TO WS-MAX-DY
            END-IF
    END-EVALUATE

    IF WS-DY < 1 OR WS-DY > WS-MAX-DY
        MOVE "Calendar day is not valid for the specified year and month"
            TO WS-MSG
        EXIT PARAGRAPH
    END-IF

    *> Proleptic Gregorian ordinal day number (strictly monotonic for all dates)
    IF WS-MO <= 2
        COMPUTE WS-ADJ-Y = WS-YR - 1
        COMPUTE WS-ADJ-M = WS-MO + 9
    ELSE
        MOVE WS-YR TO WS-ADJ-Y
        COMPUTE WS-ADJ-M = WS-MO - 3
    END-IF

    COMPUTE WS-ERA-A = FUNCTION INTEGER(WS-ADJ-Y / 4)
    COMPUTE WS-ERA-B = FUNCTION INTEGER(WS-ADJ-Y / 100)
    COMPUTE WS-ERA-C = FUNCTION INTEGER(WS-ADJ-Y / 400)
    COMPUTE WS-ERA-D = FUNCTION INTEGER((153 * WS-ADJ-M + 2) / 5)
    COMPUTE WS-ORD = (365 * WS-ADJ-Y) + WS-ERA-A - WS-ERA-B + WS-ERA-C
                     + WS-ERA-D + WS-DY + 1000

    MOVE "Y" TO WS-OK
    .
