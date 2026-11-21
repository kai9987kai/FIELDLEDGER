>>SOURCE FORMAT FREE
*> =====================================================================
*> FIELDLEDGER - UNCERTAINTY-ENGINE.cob
*> Enforces Principle 4 (Explicit uncertainty) and Section 10:
*> Reports nominal 95% site-cluster bootstrap percentile interval ONLY
*> when at least 5 complete independent sites exist in BOTH groups.
*> Withholds intervals with explicit warnings when sample size < 5.
*> Never manufactures p-values.
*> =====================================================================
IDENTIFICATION DIVISION.
PROGRAM-ID. UNCERTAINTY-ENGINE.

DATA DIVISION.
WORKING-STORAGE SECTION.
COPY "LIMITS.cpy".
COPY "RUN-CONFIG.cpy".
COPY "BACI-RESULT.cpy".
COPY "ANALYSIS-WORK.cpy".
COPY "UTILS-IFACE.cpy".

01 WS-K                     PIC 9(6) COMP-5.
01 WS-WARN-TMP              PIC X(256).

PROCEDURE DIVISION.
MAIN-UNCERTAINTY.
    MOVE SW-STRATUM-IDX TO WS-K
    MOVE CFG-SEED       TO BR-BOOT-SEED(WS-K)
    MOVE CFG-BOOTSTRAP  TO BR-BOOT-ITERS(WS-K)

    IF BR-CALCULABLE(WS-K) NOT = "Y"
        MOVE "NOT_CALCULABLE" TO BR-CI-STATUS(WS-K)
        MOVE 0 TO BR-BOOT-REPS(WS-K)
        MOVE 0 TO BR-CI-LOW(WS-K)
        MOVE 0 TO BR-CI-HIGH(WS-K)
        GOBACK
    END-IF

    IF SW-IMP-CNT >= FL-MIN-SITES-FOR-CI
        AND SW-CTRL-CNT >= FL-MIN-SITES-FOR-CI
        CALL "BOOTSTRAP-ENGINE"
        MOVE "REPORTED" TO BR-CI-STATUS(WS-K)
    ELSE
        MOVE "WITHHELD" TO BR-CI-STATUS(WS-K)
        MOVE 0 TO BR-BOOT-REPS(WS-K)
        MOVE 0 TO BR-CI-LOW(WS-K)
        MOVE 0 TO BR-CI-HIGH(WS-K)

        MOVE SPACES TO WS-WARN-TMP
        IF FUNCTION TRIM(BR-WARNINGS(WS-K)) = SPACES
            MOVE "SMALL_SAMPLE_CI_WITHHELD(<5_sites_per_group)"
                TO BR-WARNINGS(WS-K)
        ELSE
            STRING FUNCTION TRIM(BR-WARNINGS(WS-K))
                   ";SMALL_SAMPLE_CI_WITHHELD(<5_sites_per_group)"
                   DELIMITED BY SIZE INTO WS-WARN-TMP
            END-STRING
            MOVE WS-WARN-TMP TO BR-WARNINGS(WS-K)
        END-IF

        INITIALIZE ERR-REQ
        MOVE "ADD" TO EREQ-OP
        MOVE "WARNING" TO EREQ-SEVERITY
        MOVE "SMALL_SAMPLE_CI_WITHHELD" TO EREQ-CODE
        MOVE "baci-results.csv" TO EREQ-FILE
        MOVE WS-K TO EREQ-ROW
        MOVE BR-SPECIES(WS-K) TO EREQ-FIELD
        STRING "95% site-cluster bootstrap CI withheld for "
               FUNCTION TRIM(BR-SPECIES(WS-K)) " ("
               FUNCTION TRIM(BR-METHOD(WS-K))
               "): fewer than 5 complete independent sites in at least one group"
               DELIMITED BY SIZE INTO EREQ-MESSAGE
        END-STRING
        CALL "ERROR-HANDLING" USING ERR-REQ
    END-IF
    GOBACK.
