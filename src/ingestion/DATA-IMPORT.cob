>>SOURCE FORMAT FREE
*> =====================================================================
*> FIELDLEDGER - DATA-IMPORT.cob
*> Orchestrates study template initialisation (init), synthetic demo
*> dataset creation (demo), and full ordered dataset import/validation.
*> =====================================================================
IDENTIFICATION DIVISION.
PROGRAM-ID. DATA-IMPORT.

ENVIRONMENT DIVISION.
INPUT-OUTPUT SECTION.
FILE-CONTROL.
    SELECT F-OUT ASSIGN TO DYNAMIC WS-OUT-PATH
        ORGANIZATION IS LINE SEQUENTIAL
        FILE STATUS IS WS-FS.
    SELECT F-MAN ASSIGN TO DYNAMIC WS-MAN-PATH
        ORGANIZATION IS LINE SEQUENTIAL
        FILE STATUS IS WS-MAN-FS.

DATA DIVISION.
FILE SECTION.
FD F-OUT.
01 F-OUT-REC                PIC X(1024).
FD F-MAN.
01 F-MAN-REC                PIC X(512).

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

01 WS-OUT-PATH              PIC X(512).
01 WS-FS                    PIC XX.
01 WS-MAN-PATH              PIC X(512).
01 WS-MAN-FS                PIC XX.
01 WS-MAN-EOF               PIC X(1).
01 WS-DUP-OP                PIC X(24).
01 WS-WRITE-OK              PIC X(1).
01 WS-LINE                  PIC X(1024).
01 WS-TODAY                 PIC X(10).
01 WS-TARGET-FILE           PIC X(64).

LINKAGE SECTION.
01 L-IMP-OP                 PIC X(24).
01 L-IMP-RC                 PIC S9(4) COMP-5.

PROCEDURE DIVISION USING L-IMP-OP L-IMP-RC.
MAIN-IMPORT.
    MOVE 0 TO L-IMP-RC
    EVALUATE FUNCTION TRIM(L-IMP-OP)
        WHEN "INIT-STUDY"
            PERFORM DO-INIT-STUDY
        WHEN "DEMO-DATASET"
            PERFORM DO-DEMO-DATASET
        WHEN "IMPORT-ALL"
            PERFORM DO-IMPORT-ALL
        WHEN OTHER
            MOVE 1 TO L-IMP-RC
    END-EVALUATE
    GOBACK.

DO-IMPORT-ALL.
    *> Reset error store and BACI store
    INITIALIZE ERR-REQ
    MOVE "CLEAR" TO EREQ-OP
    CALL "ERROR-HANDLING" USING ERR-REQ

    MOVE 0 TO BACI-COUNT
    MOVE 0 TO SSUM-COUNT
    MOVE "N" TO SSUM-TRUNCATED
    MOVE "N" TO BACI-MULTI-METHOD-FLAG
    MOVE 0 TO BACI-TOTAL-TRANS-OBS
    MOVE "EFFORT_RATE_V1"        TO DMS-MODEL-ID
    MOVE "OBSERVATION_RATE_ONLY" TO DMS-STATE-ESTIMATED
    MOVE "FALSE"                 TO DMS-DETECTION-CORR
    MOVE "OCCUPANCY_EXT_V2"      TO DMS-OCCUPANCY-HOOK

    *> Execute ordered validation pipeline (referential order)
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
    MOVE "CHECK-OBSERVATIONS" TO WS-DUP-OP
    CALL "DUPLICATE-DETECTION" USING WS-DUP-OP

    *> Inspect manifest presence (without modifying source directory)
    PERFORM INSPECT-MANIFEST

    IF CFG-EXIT-CODE = FL-EXIT-LIMIT-ERR
        MOVE FL-EXIT-LIMIT-ERR TO L-IMP-RC
    ELSE
        IF ERR-ERROR-CNT > 0
            MOVE FL-EXIT-VAL-ERR TO L-IMP-RC
        ELSE
            MOVE FL-EXIT-OK TO L-IMP-RC
        END-IF
    END-IF
    .

INSPECT-MANIFEST.
    MOVE "NOT_PRESENT" TO CFG-MANIFEST-STATUS
    MOVE SPACES        TO CFG-MANIFEST-PATH
    MOVE SPACES        TO CFG-MANIFEST-DATE

    INITIALIZE CFG-REQ
    MOVE "JOIN-PATH"       TO CREQ-OP
    MOVE CFG-STUDY-PATH    TO CREQ-PATH-A
    MOVE "manifest.sha256" TO CREQ-PATH-B
    CALL "CONFIGURATION" USING CFG-REQ
    MOVE CREQ-PATH-OUT TO WS-MAN-PATH

    OPEN INPUT F-MAN
    IF WS-MAN-FS = "00"
        MOVE "PRESENT"   TO CFG-MANIFEST-STATUS
        MOVE WS-MAN-PATH TO CFG-MANIFEST-PATH
        MOVE "N" TO WS-MAN-EOF
        PERFORM UNTIL WS-MAN-EOF = "Y"
            MOVE SPACES TO F-MAN-REC
            READ F-MAN
                AT END
                    MOVE "Y" TO WS-MAN-EOF
                NOT AT END
                    IF F-MAN-REC(1:17) = "# generated_utc: "
                        MOVE FUNCTION TRIM(F-MAN-REC(18:32))
                            TO CFG-MANIFEST-DATE
                        MOVE "Y" TO WS-MAN-EOF
                    END-IF
            END-READ
        END-PERFORM
        CLOSE F-MAN
    END-IF
    .

DO-INIT-STUDY.
    MOVE "Y" TO WS-WRITE-OK
    MOVE CFG-RUN-TIMESTAMP(1:10) TO WS-TODAY

    INITIALIZE CFG-REQ
    MOVE "ENSURE-DIR"   TO CREQ-OP
    MOVE CFG-STUDY-PATH TO CREQ-PATH-A
    CALL "CONFIGURATION" USING CFG-REQ

    *> study.csv
    MOVE "study.csv" TO WS-TARGET-FILE
    PERFORM OPEN-STUDY-FILE
    IF WS-WRITE-OK = "Y"
        MOVE "study_id,study_title,study_design,primary_outcome,primary_outcome_unit,study_description"
            TO WS-LINE
        PERFORM WRITE-OUT-LINE
        MOVE "study_001,Untitled Ecological Study,BACI,species_observations,detections_per_hour,Replace with study description"
            TO WS-LINE
        PERFORM WRITE-OUT-LINE
        CLOSE F-OUT
    END-IF

    *> sources.csv
    IF WS-WRITE-OK = "Y"
        MOVE "sources.csv" TO WS-TARGET-FILE
        PERFORM OPEN-STUDY-FILE
    END-IF
    IF WS-WRITE-OK = "Y"
        MOVE "source_id,source_type,source_title,organisation,citation,source_url,licence,accessed_date"
            TO WS-LINE
        PERFORM WRITE-OUT-LINE
        STRING "SRC001,survey_dataset,Template Monitoring Dataset,Research Organisation,"
               '"Replace with citation",,CC-BY-4.0,' WS-TODAY
               DELIMITED BY SIZE INTO WS-LINE
        END-STRING
        PERFORM WRITE-OUT-LINE
        CLOSE F-OUT
    END-IF

    *> sites.csv
    IF WS-WRITE-OK = "Y"
        MOVE "sites.csv" TO WS-TARGET-FILE
        PERFORM OPEN-STUDY-FILE
    END-IF
    IF WS-WRITE-OK = "Y"
        MOVE "site_id,site_role,reference_date,area_ha,habitat_type,region_code"
            TO WS-LINE
        PERFORM WRITE-OUT-LINE
        CLOSE F-OUT
    END-IF

    *> surveys.csv
    IF WS-WRITE-OK = "Y"
        MOVE "surveys.csv" TO WS-TARGET-FILE
        PERFORM OPEN-STUDY-FILE
    END-IF
    IF WS-WRITE-OK = "Y"
        MOVE "survey_id,site_id,survey_date,survey_minutes,method,observer_id,source_id"
            TO WS-LINE
        PERFORM WRITE-OUT-LINE
        CLOSE F-OUT
    END-IF

    *> observations.csv
    IF WS-WRITE-OK = "Y"
        MOVE "observations.csv" TO WS-TARGET-FILE
        PERFORM OPEN-STUDY-FILE
    END-IF
    IF WS-WRITE-OK = "Y"
        MOVE "observation_id,survey_id,species_code,count,observation_status"
            TO WS-LINE
        PERFORM WRITE-OUT-LINE
        CLOSE F-OUT
    END-IF

    IF WS-WRITE-OK = "N"
        MOVE FL-EXIT-IO-ERR TO L-IMP-RC
    ELSE
        MOVE FL-EXIT-OK TO L-IMP-RC
    END-IF
    .

DO-DEMO-DATASET.
    MOVE "Y" TO WS-WRITE-OK

    INITIALIZE CFG-REQ
    MOVE "ENSURE-DIR"   TO CREQ-OP
    MOVE CFG-STUDY-PATH TO CREQ-PATH-A
    CALL "CONFIGURATION" USING CFG-REQ

    *> study.csv
    MOVE "study.csv" TO WS-TARGET-FILE
    PERFORM OPEN-STUDY-FILE
    IF WS-WRITE-OK = "Y"
        MOVE "study_id,study_title,study_design,primary_outcome,primary_outcome_unit,study_description"
            TO WS-LINE
        PERFORM WRITE-OUT-LINE
        MOVE "study_001,Wetland Restoration Study (Synthetic Demo),BACI,species_observations,detections_per_hour,Explicitly synthetic ecological restoration reference fixture with known BACI effect of +6 detections/hour"
            TO WS-LINE
        PERFORM WRITE-OUT-LINE
        CLOSE F-OUT
    END-IF

    *> sources.csv
    IF WS-WRITE-OK = "Y"
        MOVE "sources.csv" TO WS-TARGET-FILE
        PERFORM OPEN-STUDY-FILE
    END-IF
    IF WS-WRITE-OK = "Y"
        MOVE "source_id,source_type,source_title,organisation,citation,source_url,licence,accessed_date"
            TO WS-LINE
        PERFORM WRITE-OUT-LINE
        MOVE 'SRC001,synthetic_test_dataset,FIELDLEDGER Synthetic Wetland Reference Fixture,FIELDLEDGER Project,"FIELDLEDGER v1.0.0 Synthetic Test Fixture (not empirical field data)",https://example.invalid/fieldledger/synthetic-wetland-demo,MIT,2026-11-20'
            TO WS-LINE
        PERFORM WRITE-OUT-LINE
        CLOSE F-OUT
    END-IF

    *> sites.csv
    IF WS-WRITE-OK = "Y"
        MOVE "sites.csv" TO WS-TARGET-FILE
        PERFORM OPEN-STUDY-FILE
    END-IF
    IF WS-WRITE-OK = "Y"
        MOVE "site_id,site_role,reference_date,area_ha,habitat_type,region_code"
            TO WS-LINE
        PERFORM WRITE-OUT-LINE
        MOVE "IMP01,IMPACT,2025-01-01,45.50,freshwater_marsh,REG-NORTH" TO WS-LINE
        PERFORM WRITE-OUT-LINE
        MOVE "IMP02,IMPACT,2025-01-01,52.00,freshwater_marsh,REG-NORTH" TO WS-LINE
        PERFORM WRITE-OUT-LINE
        MOVE "CTRL01,CONTROL,2025-01-01,48.25,freshwater_marsh,REG-NORTH" TO WS-LINE
        PERFORM WRITE-OUT-LINE
        MOVE "CTRL02,CONTROL,2025-01-01,46.75,freshwater_marsh,REG-NORTH" TO WS-LINE
        PERFORM WRITE-OUT-LINE
        CLOSE F-OUT
    END-IF

    *> surveys.csv
    IF WS-WRITE-OK = "Y"
        MOVE "surveys.csv" TO WS-TARGET-FILE
        PERFORM OPEN-STUDY-FILE
    END-IF
    IF WS-WRITE-OK = "Y"
        MOVE "survey_id,site_id,survey_date,survey_minutes,method,observer_id,source_id"
            TO WS-LINE
        PERFORM WRITE-OUT-LINE
        MOVE "SRV001,IMP01,2024-06-15,60,point_count,OBS-A,SRC001" TO WS-LINE
        PERFORM WRITE-OUT-LINE
        MOVE "SRV002,IMP01,2025-06-15,60,point_count,OBS-A,SRC001" TO WS-LINE
        PERFORM WRITE-OUT-LINE
        MOVE "SRV003,IMP02,2024-06-16,60,point_count,OBS-B,SRC001" TO WS-LINE
        PERFORM WRITE-OUT-LINE
        MOVE "SRV004,IMP02,2025-06-16,60,point_count,OBS-B,SRC001" TO WS-LINE
        PERFORM WRITE-OUT-LINE
        MOVE "SRV005,CTRL01,2024-06-17,60,point_count,OBS-A,SRC001" TO WS-LINE
        PERFORM WRITE-OUT-LINE
        MOVE "SRV006,CTRL01,2025-06-17,60,point_count,OBS-A,SRC001" TO WS-LINE
        PERFORM WRITE-OUT-LINE
        MOVE "SRV007,CTRL02,2024-06-18,60,point_count,OBS-B,SRC001" TO WS-LINE
        PERFORM WRITE-OUT-LINE
        MOVE "SRV008,CTRL02,2025-06-18,60,point_count,OBS-B,SRC001" TO WS-LINE
        PERFORM WRITE-OUT-LINE
        CLOSE F-OUT
    END-IF

    *> observations.csv
    IF WS-WRITE-OK = "Y"
        MOVE "observations.csv" TO WS-TARGET-FILE
        PERFORM OPEN-STUDY-FILE
    END-IF
    IF WS-WRITE-OK = "Y"
        MOVE "observation_id,survey_id,species_code,count,observation_status"
            TO WS-LINE
        PERFORM WRITE-OUT-LINE
        MOVE "OBS001,SRV001,SP001,10,DETECTED" TO WS-LINE
        PERFORM WRITE-OUT-LINE
        MOVE "OBS002,SRV002,SP001,18,DETECTED" TO WS-LINE
        PERFORM WRITE-OUT-LINE
        MOVE "OBS003,SRV003,SP001,12,DETECTED" TO WS-LINE
        PERFORM WRITE-OUT-LINE
        MOVE "OBS004,SRV004,SP001,20,DETECTED" TO WS-LINE
        PERFORM WRITE-OUT-LINE
        MOVE "OBS005,SRV005,SP001,11,DETECTED" TO WS-LINE
        PERFORM WRITE-OUT-LINE
        MOVE "OBS006,SRV006,SP001,13,DETECTED" TO WS-LINE
        PERFORM WRITE-OUT-LINE
        MOVE "OBS007,SRV007,SP001,9,DETECTED"  TO WS-LINE
        PERFORM WRITE-OUT-LINE
        MOVE "OBS008,SRV008,SP001,11,DETECTED" TO WS-LINE
        PERFORM WRITE-OUT-LINE
        CLOSE F-OUT
    END-IF

    IF WS-WRITE-OK = "N"
        MOVE FL-EXIT-IO-ERR TO L-IMP-RC
    ELSE
        MOVE FL-EXIT-OK TO L-IMP-RC
    END-IF
    .

OPEN-STUDY-FILE.
    INITIALIZE CFG-REQ
    MOVE "JOIN-PATH"    TO CREQ-OP
    MOVE CFG-STUDY-PATH TO CREQ-PATH-A
    MOVE WS-TARGET-FILE TO CREQ-PATH-B
    CALL "CONFIGURATION" USING CFG-REQ
    MOVE CREQ-PATH-OUT TO WS-OUT-PATH
    OPEN OUTPUT F-OUT
    IF WS-FS NOT = "00"
        MOVE "N" TO WS-WRITE-OK
        STRING "Failed to create file '" FUNCTION TRIM(WS-OUT-PATH)
               "' (file status " WS-FS ")"
               DELIMITED BY SIZE INTO CFG-ERROR-MSG
        END-STRING
    END-IF
    .

WRITE-OUT-LINE.
    IF WS-WRITE-OK = "N"
        EXIT PARAGRAPH
    END-IF
    MOVE WS-LINE TO F-OUT-REC
    WRITE F-OUT-REC
    IF WS-FS NOT = "00"
        MOVE "N" TO WS-WRITE-OK
        STRING "Write failure on '" FUNCTION TRIM(WS-OUT-PATH)
               "' (file status " WS-FS ")"
               DELIMITED BY SIZE INTO CFG-ERROR-MSG
        END-STRING
    END-IF
    MOVE SPACES TO WS-LINE
    .
