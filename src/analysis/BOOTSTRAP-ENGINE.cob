>>SOURCE FORMAT FREE
*> =====================================================================
*> FIELDLEDGER - BOOTSTRAP-ENGINE.cob
*> Deterministic site-cluster bootstrap using Park-Miller LCG
*>   state = (state * 16807) mod 2147483647
*> with 64-bit COMP-5 integer arithmetic and rejection sampling (zero
*> modulo bias). Uses exact integer micro-unit scaling (x 1,000,000) in
*> the hot resampling loop for zero-loss fixed-point speed, then converts
*> exact COMP-3 replicates and sorts in O(B log B) via COBOL table SORT.
*> =====================================================================
IDENTIFICATION DIVISION.
PROGRAM-ID. BOOTSTRAP-ENGINE.

DATA DIVISION.
WORKING-STORAGE SECTION.
COPY "LIMITS.cpy".
COPY "RUN-CONFIG.cpy".
COPY "BACI-RESULT.cpy".
COPY "ANALYSIS-WORK.cpy".

01 WS-K                     PIC 9(6) COMP-5.
01 WS-B                     PIC 9(7) COMP-5.
01 WS-ITER                  PIC 9(7) COMP-5.
01 WS-J                     PIC 9(6) COMP-5.
01 WS-N-IMP                 PIC 9(6) COMP-5.
01 WS-N-CTRL                PIC 9(6) COMP-5.
01 WS-PRNG-STATE            PIC S9(18) COMP-5.
01 WS-PROD                  PIC S9(18) COMP-5.
01 WS-QUOT                  PIC S9(18) COMP-5.
01 WS-REM                   PIC S9(18) COMP-5.
01 WS-TMP                   PIC S9(18) COMP-5.
01 WS-MOD-M                 PIC S9(18) COMP-5 VALUE 2147483647.
01 WS-MOD-M1                PIC S9(18) COMP-5 VALUE 2147483646.
01 WS-MULT-A                PIC S9(18) COMP-5 VALUE 16807.
01 WS-LIMIT-IMP             PIC S9(18) COMP-5.
01 WS-LIMIT-CTRL            PIC S9(18) COMP-5.
01 WS-DRAW-IDX              PIC 9(6) COMP-5.

01 WS-IMP-SCALED            PIC S9(18) COMP-5 OCCURS 2000 TIMES.
01 WS-CTRL-SCALED           PIC S9(18) COMP-5 OCCURS 2000 TIMES.
01 WS-IMP-SUM-I             PIC S9(18) COMP-5.
01 WS-CTRL-SUM-I            PIC S9(18) COMP-5.
01 WS-IMP-MEAN              PIC S9(11)V9(6) COMP-3.
01 WS-CTRL-MEAN             PIC S9(11)V9(6) COMP-3.
01 WS-IMP-DEC               PIC S9(15)V9(6) COMP-3.
01 WS-CTRL-DEC              PIC S9(15)V9(6) COMP-3.
01 WS-SCALE-DEN-IMP         PIC S9(18) COMP-5.
01 WS-SCALE-DEN-CTRL        PIC S9(18) COMP-5.

01 WS-POS-DEC               PIC S9(9)V9(6) COMP-3.
01 WS-IDX-LO                PIC 9(7) COMP-5.
01 WS-IDX-HI                PIC 9(7) COMP-5.
01 WS-FRAC                  PIC S9(3)V9(6) COMP-3.

01 WS-BOOT-TBL.
   05 WS-BOOT-ROW OCCURS 1 TO 100000 TIMES DEPENDING ON WS-B
                  ASCENDING KEY IS WS-BOOT-VAL.
      10 WS-BOOT-VAL        PIC S9(11)V9(6) COMP-3.

PROCEDURE DIVISION.
MAIN-BOOT.
    MOVE SW-STRATUM-IDX TO WS-K
    MOVE SW-IMP-CNT     TO WS-N-IMP
    MOVE SW-CTRL-CNT    TO WS-N-CTRL
    MOVE CFG-BOOTSTRAP  TO WS-B

    IF WS-B < FL-MIN-BOOTSTRAP OR WS-B > FL-MAX-BOOTSTRAP
        OR WS-N-IMP = 0 OR WS-N-CTRL = 0
        MOVE 0 TO BR-BOOT-REPS(WS-K)
        GOBACK
    END-IF

    *> Pre-scale exact 6-decimal COMP-3 site changes to exact integer micro-units
    PERFORM VARYING WS-J FROM 1 BY 1 UNTIL WS-J > WS-N-IMP
        COMPUTE WS-IMP-SCALED(WS-J) = SWI-CHANGE(WS-J) * 1000000
    END-PERFORM
    PERFORM VARYING WS-J FROM 1 BY 1 UNTIL WS-J > WS-N-CTRL
        COMPUTE WS-CTRL-SCALED(WS-J) = SWC-CHANGE(WS-J) * 1000000
    END-PERFORM

    COMPUTE WS-SCALE-DEN-IMP  = WS-N-IMP * 1000000
    COMPUTE WS-SCALE-DEN-CTRL = WS-N-CTRL * 1000000

    *> Initialize deterministic Park-Miller seed in [1, 2147483646]
    DIVIDE CFG-SEED BY WS-MOD-M GIVING WS-QUOT REMAINDER WS-PRNG-STATE
    IF WS-PRNG-STATE <= 0
        MOVE 1 TO WS-PRNG-STATE
    END-IF

    *> Rejection thresholds to eliminate modulo bias
    DIVIDE WS-MOD-M1 BY WS-N-IMP GIVING WS-QUOT REMAINDER WS-REM
    COMPUTE WS-LIMIT-IMP = WS-MOD-M1 - WS-REM
    DIVIDE WS-MOD-M1 BY WS-N-CTRL GIVING WS-QUOT REMAINDER WS-REM
    COMPUTE WS-LIMIT-CTRL = WS-MOD-M1 - WS-REM

    PERFORM VARYING WS-ITER FROM 1 BY 1 UNTIL WS-ITER > WS-B
        MOVE 0 TO WS-IMP-SUM-I
        PERFORM VARYING WS-J FROM 1 BY 1 UNTIL WS-J > WS-N-IMP
            PERFORM NEXT-RAND
            PERFORM UNTIL WS-PRNG-STATE <= WS-LIMIT-IMP
                PERFORM NEXT-RAND
            END-PERFORM
            COMPUTE WS-TMP = WS-PRNG-STATE - 1
            DIVIDE WS-TMP BY WS-N-IMP GIVING WS-QUOT REMAINDER WS-REM
            COMPUTE WS-DRAW-IDX = WS-REM + 1
            ADD WS-IMP-SCALED(WS-DRAW-IDX) TO WS-IMP-SUM-I
        END-PERFORM

        MOVE 0 TO WS-CTRL-SUM-I
        PERFORM VARYING WS-J FROM 1 BY 1 UNTIL WS-J > WS-N-CTRL
            PERFORM NEXT-RAND
            PERFORM UNTIL WS-PRNG-STATE <= WS-LIMIT-CTRL
                PERFORM NEXT-RAND
            END-PERFORM
            COMPUTE WS-TMP = WS-PRNG-STATE - 1
            DIVIDE WS-TMP BY WS-N-CTRL GIVING WS-QUOT REMAINDER WS-REM
            COMPUTE WS-DRAW-IDX = WS-REM + 1
            ADD WS-CTRL-SCALED(WS-DRAW-IDX) TO WS-CTRL-SUM-I
        END-PERFORM

        COMPUTE WS-IMP-MEAN  ROUNDED = WS-IMP-SUM-I / WS-SCALE-DEN-IMP
        COMPUTE WS-CTRL-MEAN ROUNDED = WS-CTRL-SUM-I / WS-SCALE-DEN-CTRL
        COMPUTE WS-BOOT-VAL(WS-ITER) = WS-IMP-MEAN - WS-CTRL-MEAN
    END-PERFORM

    *> Sort bootstrap replicates in O(B log B)
    SORT WS-BOOT-ROW ON ASCENDING KEY WS-BOOT-VAL

    *> 2.5th percentile via linear order-statistic interpolation
    COMPUTE WS-POS-DEC = 1 + (0.025 * (WS-B - 1))
    COMPUTE WS-IDX-LO  = FUNCTION INTEGER(WS-POS-DEC)
    IF WS-IDX-LO < 1
        MOVE 1 TO WS-IDX-LO
    END-IF
    COMPUTE WS-IDX-HI = WS-IDX-LO + 1
    IF WS-IDX-HI > WS-B
        MOVE WS-B TO WS-IDX-HI
    END-IF
    COMPUTE WS-FRAC = WS-POS-DEC - WS-IDX-LO
    COMPUTE BR-CI-LOW(WS-K) ROUNDED =
        WS-BOOT-VAL(WS-IDX-LO)
        + (WS-FRAC * (WS-BOOT-VAL(WS-IDX-HI) - WS-BOOT-VAL(WS-IDX-LO)))

    *> 97.5th percentile via linear order-statistic interpolation
    COMPUTE WS-POS-DEC = 1 + (0.975 * (WS-B - 1))
    COMPUTE WS-IDX-LO  = FUNCTION INTEGER(WS-POS-DEC)
    IF WS-IDX-LO < 1
        MOVE 1 TO WS-IDX-LO
    END-IF
    COMPUTE WS-IDX-HI = WS-IDX-LO + 1
    IF WS-IDX-HI > WS-B
        MOVE WS-B TO WS-IDX-HI
    END-IF
    COMPUTE WS-FRAC = WS-POS-DEC - WS-IDX-LO
    COMPUTE BR-CI-HIGH(WS-K) ROUNDED =
        WS-BOOT-VAL(WS-IDX-LO)
        + (WS-FRAC * (WS-BOOT-VAL(WS-IDX-HI) - WS-BOOT-VAL(WS-IDX-LO)))

    MOVE WS-B TO BR-BOOT-REPS(WS-K)
    GOBACK.

NEXT-RAND.
    COMPUTE WS-PROD = WS-PRNG-STATE * WS-MULT-A
    DIVIDE WS-PROD BY WS-MOD-M GIVING WS-QUOT REMAINDER WS-PRNG-STATE
    .
