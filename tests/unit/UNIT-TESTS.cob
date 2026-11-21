>>SOURCE FORMAT FREE
*> =====================================================================
*> FIELDLEDGER - UNIT-TESTS.cob
*> Native COBOL unit test suite verifying CSV parsing, date validation,
*> fixed-point decimal parsing/formatting, JSON/HTML/CSV escaping,
*> UTF-8/encoding normalisation, effort-standardised rate calculation,
*> site-cluster bootstrap determinism, and LOSO sensitivity.
*> =====================================================================
IDENTIFICATION DIVISION.
PROGRAM-ID. UNIT-TESTS.

DATA DIVISION.
WORKING-STORAGE SECTION.
COPY "LIMITS.cpy".
COPY "RUN-CONFIG.cpy".
COPY "SURVEY-RECORD.cpy".
COPY "OBSERVATION-RECORD.cpy".
COPY "BACI-RESULT.cpy".
COPY "ANALYSIS-WORK.cpy".
COPY "CSV-WORK.cpy".
COPY "UTILS-IFACE.cpy".

01 WS-PASS                  PIC 9(6) COMP-5 VALUE 0.
01 WS-FAIL                  PIC 9(6) COMP-5 VALUE 0.
01 WS-PASS-TXT              PIC Z(5)9.
01 WS-FAIL-TXT              PIC Z(5)9.
01 WS-TEST-NAME             PIC X(80).
01 WS-CI-LOW-1              PIC S9(11)V9(6) COMP-3.
01 WS-CI-HIGH-1             PIC S9(11)V9(6) COMP-3.
01 WS-CI-LOW-2              PIC S9(11)V9(6) COMP-3.
01 WS-CI-HIGH-2             PIC S9(11)V9(6) COMP-3.

PROCEDURE DIVISION.
MAIN-UNIT-TESTS.
    DISPLAY "=== FIELDLEDGER COBOL Unit Test Suite ==="

    PERFORM TEST-CSV-PARSER
    PERFORM TEST-DATE-UTILS
    PERFORM TEST-NUMERIC-UTILS
    PERFORM TEST-ESCAPING
    PERFORM TEST-NORMALISER
    PERFORM TEST-EFFORT-RATES
    PERFORM TEST-BOOTSTRAP-DETERMINISM
    PERFORM TEST-LOSO-SENSITIVITY

    MOVE WS-PASS TO WS-PASS-TXT
    MOVE WS-FAIL TO WS-FAIL-TXT
    DISPLAY "-----------------------------------------"
    DISPLAY "COBOL Unit Tests: " FUNCTION TRIM(WS-PASS-TXT)
            " passed, " FUNCTION TRIM(WS-FAIL-TXT) " failed."
    IF WS-FAIL > 0
        MOVE 1 TO RETURN-CODE
    ELSE
        MOVE 0 TO RETURN-CODE
    END-IF
    STOP RUN.

PASS-ONE.
    ADD 1 TO WS-PASS
    DISPLAY "  [PASS] " FUNCTION TRIM(WS-TEST-NAME)
    .

FAIL-ONE.
    ADD 1 TO WS-FAIL
    DISPLAY "  [FAIL] " FUNCTION TRIM(WS-TEST-NAME)
    .

TEST-CSV-PARSER.
    *> 1. Standard RFC 4180 quoted fields with commas & escaped double quotes
    MOVE "CSV: quoted commas and escaped double quotes" TO WS-TEST-NAME
    INITIALIZE CSV-REQ
    MOVE 'study_1,"Wetland, ""North"" Marsh",BACI,"desc,1",' TO CSV-LINE
    MOVE 0 TO CSV-LINE-LEN
    CALL "CSV-READER" USING CSV-REQ
    IF CSV-OK AND CSV-FIELD-CNT = 5
        AND FUNCTION TRIM(CSV-F-VAL(1)) = "study_1"
        AND FUNCTION TRIM(CSV-F-VAL(2)) = 'Wetland, "North" Marsh'
        AND FUNCTION TRIM(CSV-F-VAL(3)) = "BACI"
        AND FUNCTION TRIM(CSV-F-VAL(4)) = "desc,1"
        AND CSV-F-LEN(5) = 0
        PERFORM PASS-ONE
    ELSE
        PERFORM FAIL-ONE
    END-IF

    *> 2. Reject unclosed quote
    MOVE "CSV: reject unclosed quoted field" TO WS-TEST-NAME
    INITIALIZE CSV-REQ
    MOVE 'a,"unclosed,c' TO CSV-LINE
    CALL "CSV-READER" USING CSV-REQ
    IF CSV-ERR-UNCLOSED
        PERFORM PASS-ONE
    ELSE
        PERFORM FAIL-ONE
    END-IF

    *> 3. Reject stray quote in unquoted field
    MOVE "CSV: reject stray quote inside unquoted field" TO WS-TEST-NAME
    INITIALIZE CSV-REQ
    MOVE 'a,bad"quote,c' TO CSV-LINE
    CALL "CSV-READER" USING CSV-REQ
    IF CSV-ERR-STRAY-QUOTE
        PERFORM PASS-ONE
    ELSE
        PERFORM FAIL-ONE
    END-IF

    *> 4. Reject trailing characters after closing quote
    MOVE "CSV: reject trailing characters after closing quote" TO WS-TEST-NAME
    INITIALIZE CSV-REQ
    MOVE 'a,"ok"junk,c' TO CSV-LINE
    CALL "CSV-READER" USING CSV-REQ
    IF CSV-ERR-TRAILING
        PERFORM PASS-ONE
    ELSE
        PERFORM FAIL-ONE
    END-IF
    .

TEST-DATE-UTILS.
    *> 5. Valid leap year 2024-02-29
    MOVE "DATE: accept leap day 2024-02-29" TO WS-TEST-NAME
    INITIALIZE DATE-REQ
    MOVE "VALIDATE"   TO DREQ-OP
    MOVE "2024-02-29" TO DREQ-DATE-A
    CALL "DATE-UTILS" USING DATE-REQ
    IF DREQ-VALID = "Y"
        PERFORM PASS-ONE
    ELSE
        PERFORM FAIL-ONE
    END-IF

    *> 6. Reject non-leap 2025-02-29 and century non-leap 1900-02-29
    MOVE "DATE: reject non-leap 2025-02-29 and 1900-02-29" TO WS-TEST-NAME
    INITIALIZE DATE-REQ
    MOVE "VALIDATE"   TO DREQ-OP
    MOVE "2025-02-29" TO DREQ-DATE-A
    CALL "DATE-UTILS" USING DATE-REQ
    IF DREQ-VALID = "N"
        INITIALIZE DATE-REQ
        MOVE "VALIDATE"   TO DREQ-OP
        MOVE "1900-02-29" TO DREQ-DATE-A
        CALL "DATE-UTILS" USING DATE-REQ
        IF DREQ-VALID = "N"
            PERFORM PASS-ONE
        ELSE
            PERFORM FAIL-ONE
        END-IF
    ELSE
        PERFORM FAIL-ONE
    END-IF

    *> 7. Accept 2000-02-29 (divisible by 400)
    MOVE "DATE: accept Gregorian 400-year leap day 2000-02-29" TO WS-TEST-NAME
    INITIALIZE DATE-REQ
    MOVE "VALIDATE"   TO DREQ-OP
    MOVE "2000-02-29" TO DREQ-DATE-A
    CALL "DATE-UTILS" USING DATE-REQ
    IF DREQ-VALID = "Y"
        PERFORM PASS-ONE
    ELSE
        PERFORM FAIL-ONE
    END-IF

    *> 8. Period comparison PRE / TRANSITION / POST
    MOVE "DATE: classify PRE, TRANSITION, POST against reference date"
        TO WS-TEST-NAME
    INITIALIZE DATE-REQ
    MOVE "COMPARE"    TO DREQ-OP
    MOVE "2024-12-31" TO DREQ-DATE-A
    MOVE "2025-01-01" TO DREQ-DATE-B
    CALL "DATE-UTILS" USING DATE-REQ
    IF DREQ-VALID = "Y" AND FUNCTION TRIM(DREQ-PERIOD) = "PRE"
        MOVE "2025-01-01" TO DREQ-DATE-A
        CALL "DATE-UTILS" USING DATE-REQ
        IF DREQ-VALID = "Y" AND FUNCTION TRIM(DREQ-PERIOD) = "TRANSITION"
            MOVE "2025-01-02" TO DREQ-DATE-A
            CALL "DATE-UTILS" USING DATE-REQ
            IF DREQ-VALID = "Y" AND FUNCTION TRIM(DREQ-PERIOD) = "POST"
                PERFORM PASS-ONE
            ELSE
                PERFORM FAIL-ONE
            END-IF
        ELSE
            PERFORM FAIL-ONE
        END-IF
    ELSE
        PERFORM FAIL-ONE
    END-IF
    .

TEST-NUMERIC-UTILS.
    *> 9. Fixed-point decimal parse and exact COMP-3 value
    MOVE "NUM: parse positive fixed-point decimal 45.125" TO WS-TEST-NAME
    INITIALIZE NUM-REQ
    MOVE "PARSE-DEC" TO NREQ-OP
    MOVE "45.125"    TO NREQ-TEXT-IN
    MOVE 9   TO NREQ-MAX-INT-DIGITS
    MOVE 4   TO NREQ-MAX-DEC-DIGITS
    MOVE "N" TO NREQ-ALLOW-ZERO
    MOVE "N" TO NREQ-ALLOW-NEG
    CALL "NUMERIC-UTILS" USING NUM-REQ
    IF NREQ-VALID = "Y" AND NREQ-DEC-VAL = 45.125
        PERFORM PASS-ONE
    ELSE
        PERFORM FAIL-ONE
    END-IF

    *> 10. Reject zero when ALLOW-ZERO = N, reject negative when ALLOW-NEG = N
    MOVE "NUM: reject 0 and -5 for strictly positive field" TO WS-TEST-NAME
    INITIALIZE NUM-REQ
    MOVE "PARSE-DEC" TO NREQ-OP
    MOVE "0"         TO NREQ-TEXT-IN
    MOVE "N" TO NREQ-ALLOW-ZERO
    MOVE "N" TO NREQ-ALLOW-NEG
    CALL "NUMERIC-UTILS" USING NUM-REQ
    IF NREQ-VALID = "N"
        MOVE "-5.25" TO NREQ-TEXT-IN
        CALL "NUMERIC-UTILS" USING NUM-REQ
        IF NREQ-VALID = "N"
            PERFORM PASS-ONE
        ELSE
            PERFORM FAIL-ONE
        END-IF
    ELSE
        PERFORM FAIL-ONE
    END-IF

    *> 11. Reject precision overflow (>4 decimals when limit=4)
    MOVE "NUM: reject decimal exceeding documented precision limit" TO WS-TEST-NAME
    INITIALIZE NUM-REQ
    MOVE "PARSE-DEC" TO NREQ-OP
    MOVE "12.12345"  TO NREQ-TEXT-IN
    MOVE 7   TO NREQ-MAX-INT-DIGITS
    MOVE 4   TO NREQ-MAX-DEC-DIGITS
    MOVE "N" TO NREQ-ALLOW-ZERO
    MOVE "N" TO NREQ-ALLOW-NEG
    CALL "NUMERIC-UTILS" USING NUM-REQ
    IF NREQ-VALID = "N"
        PERFORM PASS-ONE
    ELSE
        PERFORM FAIL-ONE
    END-IF

    *> 12. Clean fixed-point formatting
    MOVE "NUM: format negative COMP-3 value cleanly (-6.250000)" TO WS-TEST-NAME
    INITIALIZE NUM-REQ
    MOVE "FMT-DEC6" TO NREQ-OP
    MOVE -6.25      TO NREQ-DEC-VAL
    CALL "NUMERIC-UTILS" USING NUM-REQ
    IF FUNCTION TRIM(NREQ-TEXT-OUT) = "-6.250000"
        PERFORM PASS-ONE
    ELSE
        PERFORM FAIL-ONE
    END-IF
    .

TEST-ESCAPING.
    *> 13. JSON escaping quotes, backslashes, and tab control char
    MOVE "ESC: JSON escape quotes, backslashes, and tab" TO WS-TEST-NAME
    INITIALIZE NUM-REQ
    MOVE "ESC-JSON" TO NREQ-OP
    STRING 'a"b\c' X"09" "d" DELIMITED BY SIZE INTO NREQ-TEXT-IN
    CALL "NUMERIC-UTILS" USING NUM-REQ
    IF FUNCTION TRIM(NREQ-TEXT-OUT) = 'a\"b\\c\td'
        PERFORM PASS-ONE
    ELSE
        PERFORM FAIL-ONE
    END-IF

    *> 14. HTML escaping &, <, >, ", '
    MOVE "ESC: HTML escape &, <, >, double and single quotes" TO WS-TEST-NAME
    INITIALIZE NUM-REQ
    MOVE "ESC-HTML" TO NREQ-OP
    MOVE '<a href="x">&''</a>' TO NREQ-TEXT-IN
    CALL "NUMERIC-UTILS" USING NUM-REQ
    IF FUNCTION TRIM(NREQ-TEXT-OUT) =
       "&lt;a href=&quot;x&quot;&gt;&amp;&#39;&lt;/a&gt;"
        PERFORM PASS-ONE
    ELSE
        PERFORM FAIL-ONE
    END-IF
    .

TEST-NORMALISER.
    *> 15. Strip UTF-8 BOM cleanly and flag RN-WARN-BOM
    MOVE "NORM: detect and strip UTF-8 BOM on header line" TO WS-TEST-NAME
    INITIALIZE NORM-REQ
    STRING X"EFBBBF" "study_id" X"0D" DELIMITED BY SIZE INTO RN-BUF
    MOVE "Y" TO RN-IS-FIRST-LINE
    CALL "RECORD-NORMALISER" USING NORM-REQ
    IF RN-WARN-BOM AND RN-LEN = 8 AND RN-BUF(1:8) = "study_id"
        PERFORM PASS-ONE
    ELSE
        PERFORM FAIL-ONE
    END-IF

    *> 16. Reject UTF-16 BOM and invalid UTF-8 lead byte
    MOVE "NORM: reject UTF-16 BOM and invalid Latin-1 byte (0xE9 alone)"
        TO WS-TEST-NAME
    INITIALIZE NORM-REQ
    STRING X"FFFE" "abc" DELIMITED BY SIZE INTO RN-BUF
    MOVE "Y" TO RN-IS-FIRST-LINE
    CALL "RECORD-NORMALISER" USING NORM-REQ
    IF RN-ERR-UTF16
        INITIALIZE NORM-REQ
        STRING "caf" X"E9" DELIMITED BY SIZE INTO RN-BUF
        MOVE "N" TO RN-IS-FIRST-LINE
        CALL "RECORD-NORMALISER" USING NORM-REQ
        IF RN-ERR-UTF8
            PERFORM PASS-ONE
        ELSE
            PERFORM FAIL-ONE
        END-IF
    ELSE
        PERFORM FAIL-ONE
    END-IF
    .

TEST-EFFORT-RATES.
    *> 17. Effort standardisation for 30 min, 45 min, 60 min, 120 min, and zero count
    MOVE "EFFORT: Rate = Count * 60 / Survey_Minutes across durations"
        TO WS-TEST-NAME
    MOVE 3 TO SURV-COUNT
    MOVE 30  TO SURV-MINUTES(1)
    MOVE 45  TO SURV-MINUTES(2)
    MOVE 120 TO SURV-MINUTES(3)

    MOVE 4 TO OBS-COUNT
    MOVE "Y" TO OBS-VALID(1) MOVE 1 TO OBS-SURV-IDX(1) MOVE 7  TO OBS-COUNT-VAL(1)
    MOVE "Y" TO OBS-VALID(2) MOVE 2 TO OBS-SURV-IDX(2) MOVE 9  TO OBS-COUNT-VAL(2)
    MOVE "Y" TO OBS-VALID(3) MOVE 3 TO OBS-SURV-IDX(3) MOVE 15 TO OBS-COUNT-VAL(3)
    MOVE "Y" TO OBS-VALID(4) MOVE 1 TO OBS-SURV-IDX(4) MOVE 0  TO OBS-COUNT-VAL(4)

    CALL "EFFORT-STANDARDISER"
    IF OBS-RATE(1) = 14.000000
        AND OBS-RATE(2) = 12.000000
        AND OBS-RATE(3) = 7.500000
        AND OBS-RATE(4) = 0.000000
        PERFORM PASS-ONE
    ELSE
        PERFORM FAIL-ONE
    END-IF
    .

TEST-BOOTSTRAP-DETERMINISM.
    *> 18. Identical seed produces bit-for-bit identical 95% CI on 6+6 sites
    MOVE "BOOT: deterministic 95% site-cluster bootstrap CI for identical seed"
        TO WS-TEST-NAME
    MOVE 1 TO SW-STRATUM-IDX
    MOVE 6 TO SW-IMP-CNT
    MOVE 6 TO SW-CTRL-CNT
    MOVE 6  TO SWI-CHANGE(1) MOVE 8  TO SWI-CHANGE(2) MOVE 10 TO SWI-CHANGE(3)
    MOVE 6  TO SWI-CHANGE(4) MOVE 11 TO SWI-CHANGE(5) MOVE 7  TO SWI-CHANGE(6)
    MOVE 1  TO SWC-CHANGE(1) MOVE 2  TO SWC-CHANGE(2) MOVE 3  TO SWC-CHANGE(3)
    MOVE 1  TO SWC-CHANGE(4) MOVE 2  TO SWC-CHANGE(5) MOVE 3  TO SWC-CHANGE(6)
    MOVE 20261120 TO CFG-SEED
    MOVE 2000     TO CFG-BOOTSTRAP
    MOVE "Y"      TO BR-CALCULABLE(1)

    CALL "BOOTSTRAP-ENGINE"
    MOVE BR-CI-LOW(1)  TO WS-CI-LOW-1
    MOVE BR-CI-HIGH(1) TO WS-CI-HIGH-1

    MOVE 0 TO BR-CI-LOW(1) BR-CI-HIGH(1)
    CALL "BOOTSTRAP-ENGINE"
    MOVE BR-CI-LOW(1)  TO WS-CI-LOW-2
    MOVE BR-CI-HIGH(1) TO WS-CI-HIGH-2

    IF WS-CI-LOW-1 = WS-CI-LOW-2
        AND WS-CI-HIGH-1 = WS-CI-HIGH-2
        AND WS-CI-LOW-1 < 6.000000
        AND WS-CI-HIGH-1 > 6.000000
        AND BR-BOOT-REPS(1) = 2000
        PERFORM PASS-ONE
    ELSE
        PERFORM FAIL-ONE
    END-IF
    .

TEST-LOSO-SENSITIVITY.
    *> 19. Leave-one-site-out detects influential outlier site
    MOVE "SENS: leave-one-site-out identifies single influential impact site"
        TO WS-TEST-NAME
    MOVE 1 TO SW-STRATUM-IDX
    MOVE 3 TO SW-IMP-CNT
    MOVE 2 TO SW-CTRL-CNT
    MOVE "I1" TO SWI-SITE-ID(1) MOVE 4  TO SWI-CHANGE(1)
    MOVE "I2" TO SWI-SITE-ID(2) MOVE 4  TO SWI-CHANGE(2)
    MOVE "I3" TO SWI-SITE-ID(3) MOVE 22 TO SWI-CHANGE(3)
    MOVE "C1" TO SWC-SITE-ID(1) MOVE 2  TO SWC-CHANGE(1)
    MOVE "C2" TO SWC-SITE-ID(2) MOVE 2  TO SWC-CHANGE(2)
    MOVE "Y"  TO BR-CALCULABLE(1)
    MOVE 10   TO BR-IMP-CHANGE(1)
    MOVE 2    TO BR-CTRL-CHANGE(1)
    MOVE 8    TO BR-BACI-EST(1)

    CALL "SENSITIVITY-ENGINE"
    IF FUNCTION TRIM(BR-LOSO-STATUS(1)) = "COMPUTED"
        AND FUNCTION TRIM(BR-LOSO-SITE(1)) = "I3"
        AND BR-LOSO-MIN(1) = 2.000000
        AND BR-LOSO-MAX(1) = 11.000000
        PERFORM PASS-ONE
    ELSE
        PERFORM FAIL-ONE
    END-IF
    .
