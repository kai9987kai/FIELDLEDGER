>>SOURCE FORMAT FREE
*> =====================================================================
*> FIELDLEDGER - SPECIES-AGGREGATOR.cob
*> Enforces observation-method non-pooling discipline, applies --species
*> and --method filters, discovers distinct (species_code, method) strata
*> in O(N log N) time using COBOL table SORT, and builds observation
*> slice ranges for O(N) site-level aggregation.
*> =====================================================================
IDENTIFICATION DIVISION.
PROGRAM-ID. SPECIES-AGGREGATOR.

DATA DIVISION.
WORKING-STORAGE SECTION.
COPY "LIMITS.cpy".
COPY "RUN-CONFIG.cpy".
COPY "SURVEY-RECORD.cpy".
COPY "OBSERVATION-RECORD.cpy".
COPY "BACI-RESULT.cpy".
COPY "ANALYSIS-WORK.cpy".
COPY "UTILS-IFACE.cpy".

01 WS-I                     PIC 9(9) COMP-5.
01 WS-N                     PIC 9(9) COMP-5.
01 WS-SIDX                  PIC 9(9) COMP-5.
01 WS-M-IDX                 PIC 9(4) COMP-5.
01 WS-M-FOUND               PIC X(1).
01 WS-MATCH-SP              PIC X(1).
01 WS-MATCH-MT              PIC X(1).
01 WS-PREV-SP               PIC X(32).
01 WS-PREV-MT               PIC X(64).

01 WS-SORT-TBL.
   05 WS-ST-ITEM OCCURS 1 TO 250000 TIMES DEPENDING ON WS-N
                 ASCENDING KEY IS WS-ST-SP WS-ST-MT.
      10 WS-ST-SP           PIC X(32).
      10 WS-ST-MT           PIC X(64).
      10 WS-ST-OBS-IDX      PIC 9(9) COMP-5.

LINKAGE SECTION.
01 L-AGG-RC                 PIC S9(4) COMP-5.

PROCEDURE DIVISION USING L-AGG-RC.
MAIN-AGG.
    MOVE FL-EXIT-OK TO L-AGG-RC
    MOVE 0 TO BACI-COUNT
    MOVE 0 TO OSL-COUNT
    MOVE "N" TO BACI-MULTI-METHOD-FLAG
    MOVE OBS-TRANS-EXCL-COUNT TO BACI-TOTAL-TRANS-OBS

    *> Enforce observation-method selection / non-pooling rule (Section 9)
    IF FUNCTION TRIM(CFG-METHOD-FILTER) NOT = SPACES
        MOVE "N" TO WS-M-FOUND
        PERFORM VARYING WS-M-IDX FROM 1 BY 1 UNTIL WS-M-IDX > SURV-METHOD-COUNT
            IF FUNCTION TRIM(SM-NAME(WS-M-IDX)) =
               FUNCTION TRIM(CFG-METHOD-FILTER)
                MOVE "Y" TO WS-M-FOUND
                EXIT PERFORM
            END-IF
        END-PERFORM
        IF WS-M-FOUND = "N"
            STRING "Requested --method '" FUNCTION TRIM(CFG-METHOD-FILTER)
                   "' was not found in surveys.csv."
                   DELIMITED BY SIZE INTO CFG-ERROR-MSG
            END-STRING
            MOVE FL-EXIT-ANALYSIS-ERR TO L-AGG-RC
            GOBACK
        END-IF
        MOVE FUNCTION TRIM(CFG-METHOD-FILTER) TO CFG-ACTIVE-METHOD
    ELSE
        IF SURV-METHOD-COUNT = 0
            MOVE "NONE" TO CFG-ACTIVE-METHOD
        ELSE
            IF SURV-METHOD-COUNT = 1
                MOVE FUNCTION TRIM(SM-NAME(1)) TO CFG-ACTIVE-METHOD
            ELSE
                MOVE "STRATIFIED_BY_METHOD" TO CFG-ACTIVE-METHOD
                MOVE "Y" TO BACI-MULTI-METHOD-FLAG
                INITIALIZE ERR-REQ
                MOVE "ADD" TO EREQ-OP
                MOVE "WARNING" TO EREQ-SEVERITY
                MOVE "MULTI_METHOD_STRATIFIED" TO EREQ-CODE
                MOVE "surveys.csv" TO EREQ-FILE
                MOVE 0 TO EREQ-ROW
                MOVE "method" TO EREQ-FIELD
                MOVE "Multiple observation methods detected; methods were NOT pooled and are reported separately per (species, method) stratum"
                    TO EREQ-MESSAGE
                CALL "ERROR-HANDLING" USING ERR-REQ
            END-IF
        END-IF
    END-IF

    *> Collect filtered valid observations into sort buffer
    MOVE 0 TO WS-N
    PERFORM VARYING WS-I FROM 1 BY 1 UNTIL WS-I > OBS-COUNT
        IF OBS-VALID(WS-I) = "Y"
            MOVE OBS-SURV-IDX(WS-I) TO WS-SIDX
            MOVE "Y" TO WS-MATCH-SP
            MOVE "Y" TO WS-MATCH-MT
            IF FUNCTION TRIM(CFG-SPECIES-FILTER) NOT = SPACES
                IF FUNCTION TRIM(OBS-SPECIES(WS-I)) NOT =
                   FUNCTION TRIM(CFG-SPECIES-FILTER)
                    MOVE "N" TO WS-MATCH-SP
                END-IF
            END-IF
            IF FUNCTION TRIM(CFG-METHOD-FILTER) NOT = SPACES
                IF FUNCTION TRIM(SURV-METHOD(WS-SIDX)) NOT =
                   FUNCTION TRIM(CFG-METHOD-FILTER)
                    MOVE "N" TO WS-MATCH-MT
                END-IF
            END-IF
            IF WS-MATCH-SP = "Y" AND WS-MATCH-MT = "Y"
                ADD 1 TO WS-N
                MOVE OBS-SPECIES(WS-I)  TO WS-ST-SP(WS-N)
                MOVE SURV-METHOD(WS-SIDX) TO WS-ST-MT(WS-N)
                MOVE WS-I               TO WS-ST-OBS-IDX(WS-N)
            END-IF
        END-IF
    END-PERFORM

    IF WS-N = 0
        IF FUNCTION TRIM(CFG-SPECIES-FILTER) NOT = SPACES
            STRING "No observations matched --species '"
                   FUNCTION TRIM(CFG-SPECIES-FILTER) "'"
                   DELIMITED BY SIZE INTO CFG-ERROR-MSG
            END-STRING
        ELSE
            MOVE "No eligible observations found for BACI analysis."
                TO CFG-ERROR-MSG
        END-IF
        MOVE FL-EXIT-ANALYSIS-ERR TO L-AGG-RC
        GOBACK
    END-IF

    IF WS-N > 1
        SORT WS-ST-ITEM ON ASCENDING KEY WS-ST-SP WS-ST-MT
    END-IF

    *> Copy sorted order to OBS-SLICE-STORE and index distinct strata
    MOVE WS-N TO OSL-COUNT
    MOVE SPACES TO WS-PREV-SP
    MOVE SPACES TO WS-PREV-MT

    PERFORM VARYING WS-I FROM 1 BY 1 UNTIL WS-I > WS-N
        MOVE WS-ST-SP(WS-I)      TO OSL-SPECIES(WS-I)
        MOVE WS-ST-MT(WS-I)      TO OSL-METHOD(WS-I)
        MOVE WS-ST-OBS-IDX(WS-I) TO OSL-OBS-IDX(WS-I)

        IF WS-I = 1
            OR WS-ST-SP(WS-I) NOT = WS-PREV-SP
            OR WS-ST-MT(WS-I) NOT = WS-PREV-MT
            IF BACI-COUNT >= FL-MAX-SPECIES
                MOVE "Distinct (species, method) strata exceed documented v1.0.0 limit (2,000)"
                    TO CFG-ERROR-MSG
                MOVE FL-EXIT-LIMIT-ERR TO L-AGG-RC
                GOBACK
            END-IF
            IF BACI-COUNT > 0
                COMPUTE SSL-END(BACI-COUNT) = WS-I - 1
            END-IF
            ADD 1 TO BACI-COUNT
            INITIALIZE BACI-ITEM(BACI-COUNT)
            MOVE WS-ST-SP(WS-I)          TO BR-SPECIES(BACI-COUNT)
            MOVE WS-ST-MT(WS-I)          TO BR-METHOD(BACI-COUNT)
            MOVE "detections_per_hour"   TO BR-UNIT(BACI-COUNT)
            MOVE "N"                     TO BR-CALCULABLE(BACI-COUNT)
            MOVE CFG-SEED                TO BR-BOOT-SEED(BACI-COUNT)
            MOVE CFG-BOOTSTRAP           TO BR-BOOT-ITERS(BACI-COUNT)
            MOVE "NOT_CALCULABLE"        TO BR-CI-STATUS(BACI-COUNT)
            MOVE "INSUFFICIENT"          TO BR-LOSO-STATUS(BACI-COUNT)
            MOVE WS-I                    TO SSL-START(BACI-COUNT)
            MOVE WS-ST-SP(WS-I)          TO WS-PREV-SP
            MOVE WS-ST-MT(WS-I)          TO WS-PREV-MT
        END-IF
    END-PERFORM

    IF BACI-COUNT > 0
        MOVE WS-N TO SSL-END(BACI-COUNT)
    END-IF
    GOBACK.
