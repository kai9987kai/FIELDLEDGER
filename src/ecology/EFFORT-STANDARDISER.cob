>>SOURCE FORMAT FREE
*> =====================================================================
*> FIELDLEDGER - EFFORT-STANDARDISER.cob
*> Computes effort-standardised observation rates:
*>   Rate = Count * 60 / Survey_Minutes (detections per observer-hour)
*> Uses COMP-3 fixed-point decimal arithmetic (S9(11)V9(6) ROUNDED).
*> Populates Version 1 observation/detection-process metadata hook.
*> =====================================================================
IDENTIFICATION DIVISION.
PROGRAM-ID. EFFORT-STANDARDISER.

DATA DIVISION.
WORKING-STORAGE SECTION.
COPY "LIMITS.cpy".
COPY "SURVEY-RECORD.cpy".
COPY "OBSERVATION-RECORD.cpy".
COPY "BACI-RESULT.cpy".

01 WS-I                     PIC 9(9) COMP-5.
01 WS-SIDX                  PIC 9(9) COMP-5.

PROCEDURE DIVISION.
MAIN-EFFORT.
    *> Document v1.0.0 observation-process model boundary (Section 11)
    MOVE "EFFORT_RATE_V1"        TO DMS-MODEL-ID
    MOVE "OBSERVATION_RATE_ONLY" TO DMS-STATE-ESTIMATED
    MOVE "FALSE"                 TO DMS-DETECTION-CORR
    MOVE "OCCUPANCY_EXT_V2"      TO DMS-OCCUPANCY-HOOK

    PERFORM VARYING WS-I FROM 1 BY 1 UNTIL WS-I > OBS-COUNT
        IF OBS-VALID(WS-I) = "Y"
            MOVE OBS-SURV-IDX(WS-I) TO WS-SIDX
            IF WS-SIDX > 0 AND SURV-MINUTES(WS-SIDX) > 0
                COMPUTE OBS-RATE(WS-I) ROUNDED =
                    (OBS-COUNT-VAL(WS-I) * 60) / SURV-MINUTES(WS-SIDX)
            ELSE
                MOVE 0 TO OBS-RATE(WS-I)
            END-IF
        END-IF
    END-PERFORM
    GOBACK.
