>>SOURCE FORMAT FREE
*> =====================================================================
*> FIELDLEDGER - DUPLICATE-DETECTION.cob
*> O(N log N) sort-based duplicate detection and sorted lookup index
*> construction for sources, sites, surveys, observation IDs, and
*> composite (survey_id, species_code) keys.
*> =====================================================================
IDENTIFICATION DIVISION.
PROGRAM-ID. DUPLICATE-DETECTION.

DATA DIVISION.
WORKING-STORAGE SECTION.
COPY "LIMITS.cpy".
COPY "SOURCE-RECORD.cpy".
COPY "SITE-RECORD.cpy".
COPY "SURVEY-RECORD.cpy".
COPY "OBSERVATION-RECORD.cpy".
COPY "UTILS-IFACE.cpy".

01 WS-I                     PIC 9(9) COMP-5.
01 WS-N                     PIC 9(9) COMP-5.
01 WS-PREV-KEY              PIC X(80).
01 WS-ROW-TXT               PIC Z(8)9.

01 WS-SORT-SMALL-TBL.
   05 WS-SM-ITEM OCCURS 1 TO 50000 TIMES DEPENDING ON WS-N
                 ASCENDING KEY IS WS-SM-KEY.
      10 WS-SM-KEY          PIC X(64).
      10 WS-SM-POS          PIC 9(9) COMP-5.
      10 WS-SM-ROW          PIC 9(9) COMP-5.

01 WS-SORT-OBS-TBL.
   05 WS-OB-ITEM OCCURS 1 TO 250000 TIMES DEPENDING ON WS-N
                 ASCENDING KEY IS WS-OB-KEY.
      10 WS-OB-KEY          PIC X(80).
      10 WS-OB-POS          PIC 9(9) COMP-5.
      10 WS-OB-ROW          PIC 9(9) COMP-5.

LINKAGE SECTION.
01 L-DUP-OP                 PIC X(24).

PROCEDURE DIVISION USING L-DUP-OP.
MAIN-DUP.
    EVALUATE FUNCTION TRIM(L-DUP-OP)
        WHEN "INDEX-SOURCES"
            PERFORM DO-INDEX-SOURCES
        WHEN "INDEX-SITES"
            PERFORM DO-INDEX-SITES
        WHEN "INDEX-SURVEYS"
            PERFORM DO-INDEX-SURVEYS
        WHEN "CHECK-OBSERVATIONS"
            PERFORM DO-CHECK-OBS-IDS
            PERFORM DO-CHECK-OBS-KEYS
        WHEN OTHER
            CONTINUE
    END-EVALUATE
    GOBACK.

DO-INDEX-SOURCES.
    MOVE 0 TO SRC-DUP-COUNT
    MOVE SRC-COUNT TO WS-N
    IF WS-N = 0
        MOVE "Y" TO SRC-INDEX-BUILT
        EXIT PARAGRAPH
    END-IF

    PERFORM VARYING WS-I FROM 1 BY 1 UNTIL WS-I > WS-N
        MOVE SRC-ID(WS-I)      TO WS-SM-KEY(WS-I)
        MOVE WS-I              TO WS-SM-POS(WS-I)
        MOVE SRC-ROW-NUM(WS-I) TO WS-SM-ROW(WS-I)
    END-PERFORM

    IF WS-N > 1
        SORT WS-SM-ITEM ON ASCENDING KEY WS-SM-KEY WS-SM-ROW
    END-IF

    PERFORM VARYING WS-I FROM 1 BY 1 UNTIL WS-I > WS-N
        MOVE WS-SM-KEY(WS-I) TO SRCI-KEY(WS-I)
        MOVE WS-SM-POS(WS-I) TO SRCI-POS(WS-I)
        IF WS-I > 1 AND WS-SM-KEY(WS-I) = WS-SM-KEY(WS-I - 1)
            ADD 1 TO SRC-DUP-COUNT
            MOVE WS-SM-ROW(WS-I - 1) TO WS-ROW-TXT
            INITIALIZE ERR-REQ
            MOVE "ADD" TO EREQ-OP
            MOVE "ERROR" TO EREQ-SEVERITY
            MOVE "DUPLICATE_SOURCE_ID" TO EREQ-CODE
            MOVE "sources.csv" TO EREQ-FILE
            MOVE WS-SM-ROW(WS-I) TO EREQ-ROW
            MOVE "source_id" TO EREQ-FIELD
            STRING "Duplicate source_id '" FUNCTION TRIM(WS-SM-KEY(WS-I))
                   "' (previously seen on row " FUNCTION TRIM(WS-ROW-TXT) ")"
                   DELIMITED BY SIZE INTO EREQ-MESSAGE
            END-STRING
            CALL "ERROR-HANDLING" USING ERR-REQ
        END-IF
    END-PERFORM
    MOVE "Y" TO SRC-INDEX-BUILT
    .

DO-INDEX-SITES.
    MOVE 0 TO SITE-DUP-COUNT
    MOVE SITE-COUNT TO WS-N
    IF WS-N = 0
        MOVE "Y" TO SITE-INDEX-BUILT
        EXIT PARAGRAPH
    END-IF

    PERFORM VARYING WS-I FROM 1 BY 1 UNTIL WS-I > WS-N
        MOVE SITE-ID(WS-I)      TO WS-SM-KEY(WS-I)
        MOVE WS-I               TO WS-SM-POS(WS-I)
        MOVE SITE-ROW-NUM(WS-I) TO WS-SM-ROW(WS-I)
    END-PERFORM

    IF WS-N > 1
        SORT WS-SM-ITEM ON ASCENDING KEY WS-SM-KEY WS-SM-ROW
    END-IF

    PERFORM VARYING WS-I FROM 1 BY 1 UNTIL WS-I > WS-N
        MOVE WS-SM-KEY(WS-I) TO SITEI-KEY(WS-I)
        MOVE WS-SM-POS(WS-I) TO SITEI-POS(WS-I)
        IF WS-I > 1 AND WS-SM-KEY(WS-I) = WS-SM-KEY(WS-I - 1)
            ADD 1 TO SITE-DUP-COUNT
            MOVE WS-SM-ROW(WS-I - 1) TO WS-ROW-TXT
            INITIALIZE ERR-REQ
            MOVE "ADD" TO EREQ-OP
            MOVE "ERROR" TO EREQ-SEVERITY
            MOVE "DUPLICATE_SITE_ID" TO EREQ-CODE
            MOVE "sites.csv" TO EREQ-FILE
            MOVE WS-SM-ROW(WS-I) TO EREQ-ROW
            MOVE "site_id" TO EREQ-FIELD
            STRING "Duplicate site_id '" FUNCTION TRIM(WS-SM-KEY(WS-I))
                   "' (previously seen on row " FUNCTION TRIM(WS-ROW-TXT) ")"
                   DELIMITED BY SIZE INTO EREQ-MESSAGE
            END-STRING
            CALL "ERROR-HANDLING" USING ERR-REQ
        END-IF
    END-PERFORM
    MOVE "Y" TO SITE-INDEX-BUILT
    .

DO-INDEX-SURVEYS.
    MOVE 0 TO SURV-DUP-COUNT
    MOVE SURV-COUNT TO WS-N
    IF WS-N = 0
        MOVE "Y" TO SURV-INDEX-BUILT
        EXIT PARAGRAPH
    END-IF

    PERFORM VARYING WS-I FROM 1 BY 1 UNTIL WS-I > WS-N
        MOVE SURV-ID(WS-I)      TO WS-SM-KEY(WS-I)
        MOVE WS-I               TO WS-SM-POS(WS-I)
        MOVE SURV-ROW-NUM(WS-I) TO WS-SM-ROW(WS-I)
    END-PERFORM

    IF WS-N > 1
        SORT WS-SM-ITEM ON ASCENDING KEY WS-SM-KEY WS-SM-ROW
    END-IF

    PERFORM VARYING WS-I FROM 1 BY 1 UNTIL WS-I > WS-N
        MOVE WS-SM-KEY(WS-I) TO SURVI-KEY(WS-I)
        MOVE WS-SM-POS(WS-I) TO SURVI-POS(WS-I)
        IF WS-I > 1 AND WS-SM-KEY(WS-I) = WS-SM-KEY(WS-I - 1)
            ADD 1 TO SURV-DUP-COUNT
            MOVE WS-SM-ROW(WS-I - 1) TO WS-ROW-TXT
            INITIALIZE ERR-REQ
            MOVE "ADD" TO EREQ-OP
            MOVE "ERROR" TO EREQ-SEVERITY
            MOVE "DUPLICATE_SURVEY_ID" TO EREQ-CODE
            MOVE "surveys.csv" TO EREQ-FILE
            MOVE WS-SM-ROW(WS-I) TO EREQ-ROW
            MOVE "survey_id" TO EREQ-FIELD
            STRING "Duplicate survey_id '" FUNCTION TRIM(WS-SM-KEY(WS-I))
                   "' (previously seen on row " FUNCTION TRIM(WS-ROW-TXT) ")"
                   DELIMITED BY SIZE INTO EREQ-MESSAGE
            END-STRING
            CALL "ERROR-HANDLING" USING ERR-REQ
        END-IF
    END-PERFORM
    MOVE "Y" TO SURV-INDEX-BUILT
    .

DO-CHECK-OBS-IDS.
    MOVE 0 TO OBS-DUP-ID-COUNT
    MOVE OBS-COUNT TO WS-N
    IF WS-N <= 1
        EXIT PARAGRAPH
    END-IF

    PERFORM VARYING WS-I FROM 1 BY 1 UNTIL WS-I > WS-N
        MOVE SPACES            TO WS-OB-KEY(WS-I)
        MOVE OBS-ID(WS-I)      TO WS-OB-KEY(WS-I)
        MOVE WS-I              TO WS-OB-POS(WS-I)
        MOVE OBS-ROW-NUM(WS-I) TO WS-OB-ROW(WS-I)
    END-PERFORM

    SORT WS-OB-ITEM ON ASCENDING KEY WS-OB-KEY WS-OB-ROW

    PERFORM VARYING WS-I FROM 2 BY 1 UNTIL WS-I > WS-N
        IF WS-OB-KEY(WS-I) = WS-OB-KEY(WS-I - 1)
            ADD 1 TO OBS-DUP-ID-COUNT
            MOVE WS-OB-ROW(WS-I - 1) TO WS-ROW-TXT
            INITIALIZE ERR-REQ
            MOVE "ADD" TO EREQ-OP
            MOVE "ERROR" TO EREQ-SEVERITY
            MOVE "DUPLICATE_OBSERVATION_ID" TO EREQ-CODE
            MOVE "observations.csv" TO EREQ-FILE
            MOVE WS-OB-ROW(WS-I) TO EREQ-ROW
            MOVE "observation_id" TO EREQ-FIELD
            STRING "Duplicate observation_id '" FUNCTION TRIM(WS-OB-KEY(WS-I))
                   "' (previously seen on row " FUNCTION TRIM(WS-ROW-TXT) ")"
                   DELIMITED BY SIZE INTO EREQ-MESSAGE
            END-STRING
            CALL "ERROR-HANDLING" USING ERR-REQ
        END-IF
    END-PERFORM
    .

DO-CHECK-OBS-KEYS.
    MOVE 0 TO OBS-DUP-KEY-COUNT
    MOVE OBS-COUNT TO WS-N
    IF WS-N <= 1
        EXIT PARAGRAPH
    END-IF

    PERFORM VARYING WS-I FROM 1 BY 1 UNTIL WS-I > WS-N
        MOVE SPACES            TO WS-OB-KEY(WS-I)
        MOVE OBS-SURV-ID(WS-I) TO WS-OB-KEY(WS-I)(1:48)
        MOVE OBS-SPECIES(WS-I) TO WS-OB-KEY(WS-I)(49:32)
        MOVE WS-I              TO WS-OB-POS(WS-I)
        MOVE OBS-ROW-NUM(WS-I) TO WS-OB-ROW(WS-I)
    END-PERFORM

    SORT WS-OB-ITEM ON ASCENDING KEY WS-OB-KEY WS-OB-ROW

    PERFORM VARYING WS-I FROM 2 BY 1 UNTIL WS-I > WS-N
        IF WS-OB-KEY(WS-I) = WS-OB-KEY(WS-I - 1)
            ADD 1 TO OBS-DUP-KEY-COUNT
            MOVE WS-OB-ROW(WS-I - 1) TO WS-ROW-TXT
            INITIALIZE ERR-REQ
            MOVE "ADD" TO EREQ-OP
            MOVE "ERROR" TO EREQ-SEVERITY
            MOVE "DUPLICATE_SURVEY_SPECIES" TO EREQ-CODE
            MOVE "observations.csv" TO EREQ-FILE
            MOVE WS-OB-ROW(WS-I) TO EREQ-ROW
            MOVE "survey_id+species_code" TO EREQ-FIELD
            STRING "Duplicate (survey_id, species_code) pair '"
                   FUNCTION TRIM(WS-OB-KEY(WS-I)(1:48)) "' / '"
                   FUNCTION TRIM(WS-OB-KEY(WS-I)(49:32))
                   "' (previously seen on row " FUNCTION TRIM(WS-ROW-TXT) ")"
                   DELIMITED BY SIZE INTO EREQ-MESSAGE
            END-STRING
            CALL "ERROR-HANDLING" USING ERR-REQ
        END-IF
    END-PERFORM
    .
