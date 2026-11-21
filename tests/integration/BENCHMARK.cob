>>SOURCE FORMAT FREE
*> =====================================================================
*> FIELDLEDGER - BENCHMARK.cob
*> Native COBOL per-stage benchmark harness measuring real wall-clock
*> duration (millisecond resolution via CURRENT-DATE) across:
*>   1. CSV ingestion & validation (study, sources, sites, surveys, obs)
*>   2. O(N log N) duplicate detection & index building
*>   3. Effort standardisation & species aggregation
*>   4. BACI + site-cluster bootstrap (2,000 iters/species) + LOSO
*>   5. Report generation (CSV, JSON, Markdown, HTML, append-only ledger)
*> =====================================================================
IDENTIFICATION DIVISION.
PROGRAM-ID. BENCHMARK.

DATA DIVISION.
WORKING-STORAGE SECTION.
COPY "LIMITS.cpy".
COPY "RUN-CONFIG.cpy".
COPY "STUDY-RECORD.cpy".
COPY "SOURCE-RECORD.cpy".
COPY "SITE-RECORD.cpy".
COPY "SURVEY-RECORD.cpy".
COPY "OBSERVATION-RECORD.cpy".
COPY "ERROR-RECORD.cpy".
COPY "BACI-RESULT.cpy".
COPY "UTILS-IFACE.cpy".

01 WS-ARG-CNT               PIC 9(4) COMP-5.
01 WS-T0                    PIC 9(12) COMP-5.
01 WS-T1                    PIC 9(12) COMP-5.
01 WS-T2                    PIC 9(12) COMP-5.
01 WS-T3                    PIC 9(12) COMP-5.
01 WS-T4                    PIC 9(12) COMP-5.
01 WS-T5                    PIC 9(12) COMP-5.
01 WS-DT                    PIC X(21).
01 WS-HR                    PIC 9(2).
01 WS-MN                    PIC 9(2).
01 WS-SC                    PIC 9(2).
01 WS-CS                    PIC 9(2).
01 WS-MS-NOW                PIC 9(12) COMP-5.
01 WS-DIFF                  PIC 9(12) COMP-5.
01 WS-DUP-OP                PIC X(24).
01 WS-OP                    PIC X(24).
01 WS-RC                    PIC S9(4) COMP-5.
01 WS-FMT-1                 PIC Z(8)9.
01 WS-FMT-2                 PIC Z(8)9.
01 WS-FMT-3                 PIC Z(8)9.
01 WS-FMT-4                 PIC Z(8)9.

PROCEDURE DIVISION.
MAIN-BENCH.
    INITIALIZE CFG-REQ
    MOVE "INIT" TO CREQ-OP
    CALL "CONFIGURATION" USING CFG-REQ

    ACCEPT WS-ARG-CNT FROM ARGUMENT-NUMBER
    IF WS-ARG-CNT < 2
        DISPLAY "Usage: benchmark <study_path> <out_path> [bootstrap_iters]"
        MOVE 1 TO RETURN-CODE
        STOP RUN
    END-IF

    DISPLAY 1 UPON ARGUMENT-NUMBER
    ACCEPT CFG-STUDY-PATH FROM ARGUMENT-VALUE
    DISPLAY 2 UPON ARGUMENT-NUMBER
    ACCEPT CFG-OUT-PATH FROM ARGUMENT-VALUE
    MOVE 20261120 TO CFG-SEED
    MOVE 2000     TO CFG-BOOTSTRAP
    IF WS-ARG-CNT >= 3
        MOVE SPACES TO WS-OP
        DISPLAY 3 UPON ARGUMENT-NUMBER
        ACCEPT WS-OP FROM ARGUMENT-VALUE
        MOVE FUNCTION NUMVAL(WS-OP) TO CFG-BOOTSTRAP
    END-IF
    MOVE "BACI" TO CFG-ANALYSIS-TYPE

    INITIALIZE ERR-REQ
    MOVE "CLEAR" TO EREQ-OP
    CALL "ERROR-HANDLING" USING ERR-REQ

    *> Stage 1: Ingestion & Validation (study, sources, sites, surveys, obs)
    PERFORM GET-MS MOVE WS-MS-NOW TO WS-T0
    CALL "VALIDATE-STUDY"
    CALL "VALIDATE-SOURCES"
    MOVE "INDEX-SOURCES" TO WS-DUP-OP
    CALL "DUPLICATE-DETECTION" USING WS-DUP-OP
    CALL "VALIDATE-SITES"
    MOVE "INDEX-SITES" TO WS-DUP-OP
    CALL "DUPLICATE-DETECTION" USING WS-DUP-OP
    CALL "VALIDATE-SURVEYS"
    MOVE "INDEX-SURVEYS" TO WS-DUP-OP
    CALL "DUPLICATE-DETECTION" USING WS-DUP-OP
    CALL "VALIDATE-OBSERVATIONS"
    PERFORM GET-MS MOVE WS-MS-NOW TO WS-T1

    *> Stage 2: O(N log N) Observation Duplicate Detection (ID + composite key)
    MOVE "CHECK-OBSERVATIONS" TO WS-DUP-OP
    CALL "DUPLICATE-DETECTION" USING WS-DUP-OP
    PERFORM GET-MS MOVE WS-MS-NOW TO WS-T2

    *> Stage 3: Effort Standardisation & Species/Method Aggregation
    CALL "EFFORT-STANDARDISER"
    MOVE 0 TO WS-RC
    CALL "SPECIES-AGGREGATOR" USING WS-RC
    PERFORM GET-MS MOVE WS-MS-NOW TO WS-T3

    *> Stage 4: Full BACI + Site-Cluster Bootstrap + LOSO Sensitivity
    MOVE 0 TO WS-RC
    CALL "BACI-ENGINE" USING WS-RC
    PERFORM GET-MS MOVE WS-MS-NOW TO WS-T4

    *> Stage 5: Report Generation (CSV + JSON + MD + HTML + Ledger)
    MOVE "WRITE-VALIDATION" TO WS-OP CALL "CSV-REPORTER" USING WS-OP WS-RC
    MOVE "WRITE-BACI"       TO WS-OP CALL "CSV-REPORTER" USING WS-OP WS-RC
    CALL "JSON-REPORTER" USING WS-RC
    CALL "MARKDOWN-REPORTER" USING WS-RC
    CALL "HTML-REPORTER" USING WS-RC
    MOVE "APPEND-RUN"       TO WS-OP CALL "EVIDENCE-LEDGER" USING WS-OP WS-RC
    PERFORM GET-MS MOVE WS-MS-NOW TO WS-T5

    MOVE SITE-COUNT TO WS-FMT-1
    MOVE SURV-COUNT TO WS-FMT-2
    MOVE OBS-COUNT  TO WS-FMT-3
    MOVE BACI-COUNT TO WS-FMT-4
    DISPLAY "=== FIELDLEDGER Stage Benchmark Results ==="
    DISPLAY "Dataset : sites=" FUNCTION TRIM(WS-FMT-1)
            " surveys=" FUNCTION TRIM(WS-FMT-2)
            " observations=" FUNCTION TRIM(WS-FMT-3)
            " strata=" FUNCTION TRIM(WS-FMT-4)
    MOVE CFG-BOOTSTRAP TO WS-FMT-1
    MOVE ERR-ERROR-CNT TO WS-FMT-2
    DISPLAY "Config  : bootstrap=" FUNCTION TRIM(WS-FMT-1)
            " errors=" FUNCTION TRIM(WS-FMT-2)

    COMPUTE WS-DIFF = WS-T1 - WS-T0
    MOVE WS-DIFF TO WS-FMT-1
    DISPLAY "  Stage 1 (CSV Ingestion + Validation + FK) : "
            FUNCTION TRIM(WS-FMT-1) " ms"

    COMPUTE WS-DIFF = WS-T2 - WS-T1
    MOVE WS-DIFF TO WS-FMT-1
    DISPLAY "  Stage 2 (Observation Duplicate Detection) : "
            FUNCTION TRIM(WS-FMT-1) " ms"

    COMPUTE WS-DIFF = WS-T3 - WS-T2
    MOVE WS-DIFF TO WS-FMT-1
    DISPLAY "  Stage 3 (Effort Std + Species Aggreg.)    : "
            FUNCTION TRIM(WS-FMT-1) " ms"

    COMPUTE WS-DIFF = WS-T4 - WS-T3
    MOVE WS-DIFF TO WS-FMT-1
    DISPLAY "  Stage 4 (BACI + Bootstrap + LOSO)         : "
            FUNCTION TRIM(WS-FMT-1) " ms"

    COMPUTE WS-DIFF = WS-T5 - WS-T4
    MOVE WS-DIFF TO WS-FMT-1
    DISPLAY "  Stage 5 (CSV/JSON/MD/HTML/Ledger Reports) : "
            FUNCTION TRIM(WS-FMT-1) " ms"

    COMPUTE WS-DIFF = WS-T5 - WS-T0
    MOVE WS-DIFF TO WS-FMT-1
    DISPLAY "  TOTAL END-TO-END                          : "
            FUNCTION TRIM(WS-FMT-1) " ms"

    MOVE 0 TO RETURN-CODE
    STOP RUN.

GET-MS.
    MOVE FUNCTION CURRENT-DATE TO WS-DT
    MOVE WS-DT(9:2)  TO WS-HR
    MOVE WS-DT(11:2) TO WS-MN
    MOVE WS-DT(13:2) TO WS-SC
    MOVE WS-DT(15:2) TO WS-CS
    COMPUTE WS-MS-NOW =
        ((WS-HR * 3600) + (WS-MN * 60) + WS-SC) * 1000 + (WS-CS * 10)
    .
