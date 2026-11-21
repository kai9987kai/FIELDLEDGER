>>SOURCE FORMAT FREE
*> =====================================================================
*> FIELDLEDGER - SITE-SUMMARY.cob
*> Aggregates effort-standardised observations to site-level PRE/POST
*> averages and site changes for one (species_code, method) stratum.
*> Strictly enforces Principle 2 ("Missing is not zero"): absent rows
*> are counted as missingness and never converted into zero observations.
*> Excludes TRANSITION (same-day) observations with explicit counts.
*> =====================================================================
IDENTIFICATION DIVISION.
PROGRAM-ID. SITE-SUMMARY.

DATA DIVISION.
WORKING-STORAGE SECTION.
COPY "LIMITS.cpy".
COPY "SITE-RECORD.cpy".
COPY "SURVEY-RECORD.cpy".
COPY "OBSERVATION-RECORD.cpy".
COPY "BACI-RESULT.cpy".
COPY "ANALYSIS-WORK.cpy".

01 WS-K                     PIC 9(6) COMP-5.
01 WS-I                     PIC 9(9) COMP-5.
01 WS-S                     PIC 9(6) COMP-5.
01 WS-OIDX                  PIC 9(9) COMP-5.
01 WS-SIDX                  PIC 9(9) COMP-5.
01 WS-SITE-IDX              PIC 9(6) COMP-5.
01 WS-CUR-SP                PIC X(32).
01 WS-CUR-MT                PIC X(64).
01 WS-ELIG-SURV             PIC 9(9) COMP-5.
01 WS-EXP-OBS               PIC 9(9) COMP-5.
01 WS-MISS-OBS              PIC 9(9) COMP-5.
01 WS-PRE-MEAN              PIC S9(11)V9(6) COMP-3.
01 WS-POST-MEAN             PIC S9(11)V9(6) COMP-3.
01 WS-CHANGE                PIC S9(11)V9(6) COMP-3.
01 WS-COV                   PIC S9(5)V9(2) COMP-3.
01 WS-STATUS                PIC X(32).

01 WS-SITE-ACC OCCURS 2000 TIMES.
   05 SA-PRE-SURV           PIC 9(6) COMP-5.
   05 SA-POST-SURV          PIC 9(6) COMP-5.
   05 SA-TRANS-SURV         PIC 9(6) COMP-5.
   05 SA-PRE-OBS            PIC 9(6) COMP-5.
   05 SA-POST-OBS           PIC 9(6) COMP-5.
   05 SA-TRANS-OBS          PIC 9(6) COMP-5.
   05 SA-ZERO-OBS           PIC 9(6) COMP-5.
   05 SA-PRE-SUM            PIC S9(15)V9(6) COMP-3.
   05 SA-POST-SUM           PIC S9(15)V9(6) COMP-3.

PROCEDURE DIVISION.
MAIN-SITE-SUM.
    MOVE SW-STRATUM-IDX TO WS-K
    MOVE BR-SPECIES(WS-K) TO WS-CUR-SP
    MOVE BR-METHOD(WS-K)  TO WS-CUR-MT

    MOVE 0 TO SW-IMP-CNT
    MOVE 0 TO SW-CTRL-CNT

    *> Zero per-site accumulators for current stratum
    PERFORM VARYING WS-S FROM 1 BY 1 UNTIL WS-S > SITE-COUNT
        MOVE 0 TO SA-PRE-SURV(WS-S)
        MOVE 0 TO SA-POST-SURV(WS-S)
        MOVE 0 TO SA-TRANS-SURV(WS-S)
        MOVE 0 TO SA-PRE-OBS(WS-S)
        MOVE 0 TO SA-POST-OBS(WS-S)
        MOVE 0 TO SA-TRANS-OBS(WS-S)
        MOVE 0 TO SA-ZERO-OBS(WS-S)
        MOVE 0 TO SA-PRE-SUM(WS-S)
        MOVE 0 TO SA-POST-SUM(WS-S)
    END-PERFORM

    *> Count surveys at each site using this stratum's method
    PERFORM VARYING WS-I FROM 1 BY 1 UNTIL WS-I > SURV-COUNT
        IF SURV-VALID(WS-I) = "Y" AND SURV-METHOD(WS-I) = WS-CUR-MT
            MOVE SURV-SITE-IDX(WS-I) TO WS-SITE-IDX
            IF WS-SITE-IDX > 0 AND WS-SITE-IDX <= SITE-COUNT
                EVALUATE SURV-PERIOD(WS-I)
                    WHEN "PRE"
                        ADD 1 TO SA-PRE-SURV(WS-SITE-IDX)
                    WHEN "POST"
                        ADD 1 TO SA-POST-SURV(WS-SITE-IDX)
                    WHEN "TRANSITION"
                        ADD 1 TO SA-TRANS-SURV(WS-SITE-IDX)
                END-EVALUATE
            END-IF
        END-IF
    END-PERFORM

    *> Accumulate ONLY explicit observations in this stratum's sorted slice
    PERFORM VARYING WS-I FROM SSL-START(WS-K) BY 1 UNTIL WS-I > SSL-END(WS-K)
        MOVE OSL-OBS-IDX(WS-I)  TO WS-OIDX
        MOVE OBS-SURV-IDX(WS-OIDX) TO WS-SIDX
        MOVE SURV-SITE-IDX(WS-SIDX) TO WS-SITE-IDX
        IF WS-SITE-IDX > 0 AND WS-SITE-IDX <= SITE-COUNT
            EVALUATE SURV-PERIOD(WS-SIDX)
                WHEN "PRE"
                    ADD 1 TO SA-PRE-OBS(WS-SITE-IDX)
                    ADD OBS-RATE(WS-OIDX) TO SA-PRE-SUM(WS-SITE-IDX)
                    IF OBS-STATUS(WS-OIDX) = "NOT_DETECTED"
                        ADD 1 TO SA-ZERO-OBS(WS-SITE-IDX)
                    END-IF
                WHEN "POST"
                    ADD 1 TO SA-POST-OBS(WS-SITE-IDX)
                    ADD OBS-RATE(WS-OIDX) TO SA-POST-SUM(WS-SITE-IDX)
                    IF OBS-STATUS(WS-OIDX) = "NOT_DETECTED"
                        ADD 1 TO SA-ZERO-OBS(WS-SITE-IDX)
                    END-IF
                WHEN "TRANSITION"
                    ADD 1 TO SA-TRANS-OBS(WS-SITE-IDX)
            END-EVALUATE
        END-IF
    END-PERFORM

    *> Compute site-level means, changes, coverage, missingness, and exclusions
    PERFORM VARYING WS-S FROM 1 BY 1 UNTIL WS-S > SITE-COUNT
        IF SITE-VALID(WS-S) = "Y"
            COMPUTE WS-ELIG-SURV = SA-PRE-SURV(WS-S) + SA-POST-SURV(WS-S)
            COMPUTE WS-EXP-OBS   = SA-PRE-OBS(WS-S)  + SA-POST-OBS(WS-S)
            IF WS-ELIG-SURV >= WS-EXP-OBS
                COMPUTE WS-MISS-OBS = WS-ELIG-SURV - WS-EXP-OBS
            ELSE
                MOVE 0 TO WS-MISS-OBS
            END-IF

            IF WS-ELIG-SURV > 0
                COMPUTE WS-COV ROUNDED = (WS-EXP-OBS * 100) / WS-ELIG-SURV
            ELSE
                MOVE 0 TO WS-COV
            END-IF

            MOVE 0 TO WS-PRE-MEAN
            MOVE 0 TO WS-POST-MEAN
            MOVE 0 TO WS-CHANGE
            IF SA-PRE-OBS(WS-S) > 0
                COMPUTE WS-PRE-MEAN ROUNDED =
                    SA-PRE-SUM(WS-S) / SA-PRE-OBS(WS-S)
            END-IF
            IF SA-POST-OBS(WS-S) > 0
                COMPUTE WS-POST-MEAN ROUNDED =
                    SA-POST-SUM(WS-S) / SA-POST-OBS(WS-S)
            END-IF

            *> Stratum-level totals
            ADD WS-ELIG-SURV       TO BR-SURVEYS-ELIGIBLE(WS-K)
            ADD WS-EXP-OBS         TO BR-OBS-USED(WS-K)
            ADD SA-ZERO-OBS(WS-S)  TO BR-OBS-EXPLICIT-ZERO(WS-K)
            ADD WS-MISS-OBS        TO BR-OBS-MISSING(WS-K)
            ADD SA-TRANS-OBS(WS-S) TO BR-OBS-TRANS-EXCL(WS-K)

            IF SA-PRE-OBS(WS-S) > 0 AND SA-POST-OBS(WS-S) > 0
                MOVE "COMPLETE" TO WS-STATUS
                COMPUTE WS-CHANGE = WS-POST-MEAN - WS-PRE-MEAN
                ADD WS-EXP-OBS TO BR-SURVEYS-USED(WS-K)
                IF SITE-ROLE(WS-S) = "IMPACT"
                    ADD 1 TO SW-IMP-CNT
                    MOVE SITE-ID(WS-S) TO SWI-SITE-ID(SW-IMP-CNT)
                    MOVE WS-PRE-MEAN   TO SWI-PRE-MEAN(SW-IMP-CNT)
                    MOVE WS-POST-MEAN  TO SWI-POST-MEAN(SW-IMP-CNT)
                    MOVE WS-CHANGE     TO SWI-CHANGE(SW-IMP-CNT)
                ELSE
                    ADD 1 TO SW-CTRL-CNT
                    MOVE SITE-ID(WS-S) TO SWC-SITE-ID(SW-CTRL-CNT)
                    MOVE WS-PRE-MEAN   TO SWC-PRE-MEAN(SW-CTRL-CNT)
                    MOVE WS-POST-MEAN  TO SWC-POST-MEAN(SW-CTRL-CNT)
                    MOVE WS-CHANGE     TO SWC-CHANGE(SW-CTRL-CNT)
                END-IF
            ELSE
                IF SA-PRE-OBS(WS-S) = 0 AND SA-POST-OBS(WS-S) = 0
                    IF SA-TRANS-OBS(WS-S) > 0
                        MOVE "EXCLUDED_TRANSITION_ONLY" TO WS-STATUS
                    ELSE
                        MOVE "NO_OBSERVATIONS" TO WS-STATUS
                    END-IF
                ELSE
                    IF SA-PRE-OBS(WS-S) = 0
                        MOVE "NO_PRE_OBSERVATIONS" TO WS-STATUS
                    ELSE
                        MOVE "NO_POST_OBSERVATIONS" TO WS-STATUS
                    END-IF
                END-IF
                IF SITE-ROLE(WS-S) = "IMPACT"
                    ADD 1 TO BR-EXCL-IMP-SITES(WS-K)
                ELSE
                    ADD 1 TO BR-EXCL-CTRL-SITES(WS-K)
                END-IF
            END-IF

            *> Record site summary row for CSV/MD/HTML audit trail
            IF SSUM-COUNT < FL-MAX-SITE-SUMS
                ADD 1 TO SSUM-COUNT
                MOVE WS-CUR-SP          TO SS-SPECIES(SSUM-COUNT)
                MOVE WS-CUR-MT          TO SS-METHOD(SSUM-COUNT)
                MOVE SITE-ID(WS-S)      TO SS-SITE-ID(SSUM-COUNT)
                MOVE SITE-ROLE(WS-S)    TO SS-SITE-ROLE(SSUM-COUNT)
                MOVE SA-PRE-SURV(WS-S)  TO SS-PRE-SURVEYS(SSUM-COUNT)
                MOVE SA-POST-SURV(WS-S) TO SS-POST-SURVEYS(SSUM-COUNT)
                MOVE SA-TRANS-SURV(WS-S) TO SS-TRANS-SURVEYS(SSUM-COUNT)
                MOVE SA-PRE-OBS(WS-S)   TO SS-PRE-OBS(SSUM-COUNT)
                MOVE SA-POST-OBS(WS-S)  TO SS-POST-OBS(SSUM-COUNT)
                MOVE SA-TRANS-OBS(WS-S) TO SS-TRANS-OBS(SSUM-COUNT)
                MOVE SA-ZERO-OBS(WS-S)  TO SS-ZERO-OBS(SSUM-COUNT)
                MOVE WS-MISS-OBS        TO SS-MISSING-OBS(SSUM-COUNT)
                MOVE WS-PRE-MEAN        TO SS-PRE-MEAN(SSUM-COUNT)
                MOVE WS-POST-MEAN       TO SS-POST-MEAN(SSUM-COUNT)
                MOVE WS-CHANGE          TO SS-SITE-CHANGE(SSUM-COUNT)
                MOVE WS-COV             TO SS-COVERAGE-PCT(SSUM-COUNT)
                MOVE WS-STATUS          TO SS-STATUS(SSUM-COUNT)
            ELSE
                MOVE "Y" TO SSUM-TRUNCATED
            END-IF
        END-IF
    END-PERFORM

    MOVE SW-IMP-CNT  TO BR-IMP-SITES(WS-K)
    MOVE SW-CTRL-CNT TO BR-CTRL-SITES(WS-K)
    IF BR-SURVEYS-ELIGIBLE(WS-K) > 0
        COMPUTE BR-COVERAGE-PCT(WS-K) ROUNDED =
            (BR-OBS-USED(WS-K) * 100) / BR-SURVEYS-ELIGIBLE(WS-K)
    ELSE
        MOVE 0 TO BR-COVERAGE-PCT(WS-K)
    END-IF
    GOBACK.
