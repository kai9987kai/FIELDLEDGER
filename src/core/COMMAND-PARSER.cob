>>SOURCE FORMAT FREE
*> =====================================================================
*> FIELDLEDGER - COMMAND-PARSER.cob
*> Robust CLI argument parser supporting all commands, optional flags,
*> paths with spaces, range checks, and clear error reporting.
*> =====================================================================
IDENTIFICATION DIVISION.
PROGRAM-ID. COMMAND-PARSER.

DATA DIVISION.
WORKING-STORAGE SECTION.
COPY "LIMITS.cpy".
COPY "RUN-CONFIG.cpy".
COPY "UTILS-IFACE.cpy".

01 WS-ARGC                  PIC 9(4) COMP-5.
01 WS-IDX                   PIC 9(4) COMP-5.
01 WS-ARG                   PIC X(512).
01 WS-ARG-UP                PIC X(512).
01 WS-VAL                   PIC X(512).

PROCEDURE DIVISION.
MAIN-PARSE.
    MOVE FL-EXIT-OK TO CFG-EXIT-CODE
    MOVE SPACES TO CFG-ERROR-MSG

    ACCEPT WS-ARGC FROM ARGUMENT-NUMBER
    IF WS-ARGC = 0
        MOVE "HELP" TO CFG-COMMAND
        GOBACK
    END-IF

    MOVE 1 TO WS-IDX
    PERFORM FETCH-ARG
    MOVE FUNCTION UPPER-CASE(FUNCTION TRIM(WS-ARG)) TO WS-ARG-UP

    EVALUATE WS-ARG-UP
        WHEN "HELP"
        WHEN "--HELP"
        WHEN "-H"
            MOVE "HELP" TO CFG-COMMAND
            GOBACK

        WHEN "--VERSION"
        WHEN "-V"
        WHEN "VERSION"
            MOVE "VERSION" TO CFG-COMMAND
            GOBACK

        WHEN "INIT"
            MOVE "INIT" TO CFG-COMMAND
            ADD 1 TO WS-IDX

        WHEN "DEMO"
            MOVE "DEMO" TO CFG-COMMAND
            ADD 1 TO WS-IDX

        WHEN "VALIDATE"
            MOVE "VALIDATE" TO CFG-COMMAND
            ADD 1 TO WS-IDX

        WHEN "REPORT"
            MOVE "REPORT" TO CFG-COMMAND
            ADD 1 TO WS-IDX

        WHEN "MANIFEST"
            MOVE "MANIFEST" TO CFG-COMMAND
            ADD 1 TO WS-IDX

        WHEN "VERIFY"
            MOVE "VERIFY" TO CFG-COMMAND
            ADD 1 TO WS-IDX

        WHEN "ANALYZE"
            MOVE "ANALYZE" TO CFG-COMMAND
            ADD 1 TO WS-IDX
            IF WS-IDX > WS-ARGC
                MOVE "Command 'analyze' requires a subcommand (e.g. 'analyze baci')"
                    TO CFG-ERROR-MSG
                MOVE FL-EXIT-CLI-ERR TO CFG-EXIT-CODE
                GOBACK
            END-IF
            PERFORM FETCH-ARG
            MOVE FUNCTION UPPER-CASE(FUNCTION TRIM(WS-ARG)) TO WS-ARG-UP
            IF WS-ARG-UP = "BACI"
                MOVE "BACI" TO CFG-SUBCOMMAND
                ADD 1 TO WS-IDX
            ELSE
                STRING "Unknown analyze subcommand: '"
                       FUNCTION TRIM(WS-ARG) "'. Supported: baci"
                       DELIMITED BY SIZE INTO CFG-ERROR-MSG
                END-STRING
                MOVE FL-EXIT-CLI-ERR TO CFG-EXIT-CODE
                GOBACK
            END-IF

        WHEN OTHER
            STRING "Unknown command: '" FUNCTION TRIM(WS-ARG)
                   "'. Run 'fieldledger help' for usage."
                   DELIMITED BY SIZE INTO CFG-ERROR-MSG
            END-STRING
            MOVE FL-EXIT-CLI-ERR TO CFG-EXIT-CODE
            GOBACK
    END-EVALUATE

    *> Parse remaining flags
    PERFORM UNTIL WS-IDX > WS-ARGC OR CFG-EXIT-CODE NOT = FL-EXIT-OK
        PERFORM FETCH-ARG
        EVALUATE FUNCTION TRIM(WS-ARG)
            WHEN "--study"
                PERFORM FETCH-NEXT-VALUE
                IF CFG-EXIT-CODE = FL-EXIT-OK
                    MOVE WS-VAL TO CFG-STUDY-PATH
                END-IF

            WHEN "--out"
                PERFORM FETCH-NEXT-VALUE
                IF CFG-EXIT-CODE = FL-EXIT-OK
                    MOVE WS-VAL TO CFG-OUT-PATH
                END-IF

            WHEN "--species"
                PERFORM FETCH-NEXT-VALUE
                IF CFG-EXIT-CODE = FL-EXIT-OK
                    MOVE WS-VAL TO CFG-SPECIES-FILTER
                END-IF

            WHEN "--method"
                PERFORM FETCH-NEXT-VALUE
                IF CFG-EXIT-CODE = FL-EXIT-OK
                    MOVE WS-VAL TO CFG-METHOD-FILTER
                END-IF

            WHEN "--seed"
                PERFORM FETCH-NEXT-VALUE
                IF CFG-EXIT-CODE = FL-EXIT-OK
                    INITIALIZE NUM-REQ
                    MOVE "PARSE-INT" TO NREQ-OP
                    MOVE WS-VAL      TO NREQ-TEXT-IN
                    MOVE 11          TO NREQ-MAX-INT-DIGITS
                    MOVE "N"         TO NREQ-ALLOW-ZERO
                    MOVE "N"         TO NREQ-ALLOW-NEG
                    CALL "NUMERIC-UTILS" USING NUM-REQ
                    IF NREQ-VALID = "Y"
                        MOVE NREQ-INT-VAL TO CFG-SEED
                        MOVE "Y" TO CFG-SEED-PROVIDED
                    ELSE
                        STRING "Invalid --seed value '" FUNCTION TRIM(WS-VAL)
                               "': must be a positive integer."
                               DELIMITED BY SIZE INTO CFG-ERROR-MSG
                        END-STRING
                        MOVE FL-EXIT-CLI-ERR TO CFG-EXIT-CODE
                    END-IF
                END-IF

            WHEN "--bootstrap"
                PERFORM FETCH-NEXT-VALUE
                IF CFG-EXIT-CODE = FL-EXIT-OK
                    INITIALIZE NUM-REQ
                    MOVE "PARSE-INT" TO NREQ-OP
                    MOVE WS-VAL      TO NREQ-TEXT-IN
                    MOVE 7           TO NREQ-MAX-INT-DIGITS
                    MOVE "N"         TO NREQ-ALLOW-ZERO
                    MOVE "N"         TO NREQ-ALLOW-NEG
                    CALL "NUMERIC-UTILS" USING NUM-REQ
                    IF NREQ-VALID = "Y"
                        AND NREQ-INT-VAL >= FL-MIN-BOOTSTRAP
                        AND NREQ-INT-VAL <= FL-MAX-BOOTSTRAP
                        MOVE NREQ-INT-VAL TO CFG-BOOTSTRAP
                        MOVE "Y" TO CFG-BOOTSTRAP-PROVIDED
                    ELSE
                        STRING "Invalid --bootstrap value '" FUNCTION TRIM(WS-VAL)
                               "': must be an integer between 100 and 100000."
                               DELIMITED BY SIZE INTO CFG-ERROR-MSG
                        END-STRING
                        MOVE FL-EXIT-CLI-ERR TO CFG-EXIT-CODE
                    END-IF
                END-IF

            WHEN "--no-color"
                MOVE "Y" TO CFG-NO-COLOR
                ADD 1 TO WS-IDX

            WHEN "--help"
            WHEN "-h"
                MOVE "HELP" TO CFG-COMMAND
                GOBACK

            WHEN OTHER
                STRING "Unknown or unexpected option: '"
                       FUNCTION TRIM(WS-ARG)
                       "'. Run 'fieldledger help' for usage."
                       DELIMITED BY SIZE INTO CFG-ERROR-MSG
                END-STRING
                MOVE FL-EXIT-CLI-ERR TO CFG-EXIT-CODE
        END-EVALUATE
    END-PERFORM

    IF CFG-EXIT-CODE NOT = FL-EXIT-OK
        GOBACK
    END-IF

    *> Validate command-specific required options
    EVALUATE FUNCTION TRIM(CFG-COMMAND)
        WHEN "INIT"
        WHEN "MANIFEST"
        WHEN "VERIFY"
            IF FUNCTION TRIM(CFG-STUDY-PATH) = SPACES
                STRING "Command '" FUNCTION TRIM(CFG-COMMAND)
                       "' requires --study <PATH>."
                       DELIMITED BY SIZE INTO CFG-ERROR-MSG
                END-STRING
                MOVE FL-EXIT-CLI-ERR TO CFG-EXIT-CODE
            END-IF

        WHEN "DEMO"
            IF FUNCTION TRIM(CFG-OUT-PATH) = SPACES
                MOVE "Command 'demo' requires --out <PATH>." TO CFG-ERROR-MSG
                MOVE FL-EXIT-CLI-ERR TO CFG-EXIT-CODE
            END-IF

        WHEN "VALIDATE"
        WHEN "ANALYZE"
        WHEN "REPORT"
            IF FUNCTION TRIM(CFG-STUDY-PATH) = SPACES
                STRING "Command '" FUNCTION TRIM(CFG-COMMAND)
                       "' requires --study <PATH>."
                       DELIMITED BY SIZE INTO CFG-ERROR-MSG
                END-STRING
                MOVE FL-EXIT-CLI-ERR TO CFG-EXIT-CODE
            ELSE
                IF FUNCTION TRIM(CFG-OUT-PATH) = SPACES
                    STRING "Command '" FUNCTION TRIM(CFG-COMMAND)
                           "' requires --out <PATH>."
                           DELIMITED BY SIZE INTO CFG-ERROR-MSG
                    END-STRING
                    MOVE FL-EXIT-CLI-ERR TO CFG-EXIT-CODE
                END-IF
            END-IF
    END-EVALUATE
    GOBACK.

FETCH-ARG.
    MOVE SPACES TO WS-ARG
    DISPLAY WS-IDX UPON ARGUMENT-NUMBER
    ACCEPT WS-ARG FROM ARGUMENT-VALUE
    .

FETCH-NEXT-VALUE.
    ADD 1 TO WS-IDX
    IF WS-IDX > WS-ARGC
        STRING "Option '" FUNCTION TRIM(WS-ARG) "' requires a value."
               DELIMITED BY SIZE INTO CFG-ERROR-MSG
        END-STRING
        MOVE FL-EXIT-CLI-ERR TO CFG-EXIT-CODE
        EXIT PARAGRAPH
    END-IF
    MOVE SPACES TO WS-VAL
    DISPLAY WS-IDX UPON ARGUMENT-NUMBER
    ACCEPT WS-VAL FROM ARGUMENT-VALUE
    IF FUNCTION TRIM(WS-VAL) = SPACES
        STRING "Option '" FUNCTION TRIM(WS-ARG) "' cannot be empty."
               DELIMITED BY SIZE INTO CFG-ERROR-MSG
        END-STRING
        MOVE FL-EXIT-CLI-ERR TO CFG-EXIT-CODE
        EXIT PARAGRAPH
    END-IF
    ADD 1 TO WS-IDX
    .
