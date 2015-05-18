*-----------------------------------------------------------
* Title      :
* Written by :
* Date       :
* Description:
*-----------------------------------------------------------
    ORG    $1000
START:                  ; first instruction of program

    MOVEA.L #srt_addr,A2        *Load the starting address
    MOVEA.L #end_addr,A3        *Load the ending address
    
LOOP
    CMP.L   A2,A3               *Compare to our starting and ending
    BLE     DONE                *Check if done
    MOVE.W  (A2)+,D0            *Move the current data to D0
    MOVE.W  D0,D1
    AND.W   op_code_nop+2,D0    *And against the first bitmask
    CMP.W   op_code_nop,D0      *See if the values are equal
    BEQ     OP_NOP              *If it's a match then we'll go to the OP_NOP routine  
    BRA     OP_DATA             
DONE
    SIMHALT             ; halt simulator

OP_NOP
    LEA     op_print_nop,A1
    MOVEQ   #13,D0
    TRAP    #15
    BRA     LOOP
    
OP_DATA
    LEA     op_print_data,A1
    MOVEQ   #14,D0
    TRAP    #15
    
    MOVEQ   #15,D0
    MOVEQ   #16,D2
    TRAP    #15
    
    LEA     op_print_blank,A1
    MOVEQ   #13,D0
    TRAP    #15
    
    BRA     LOOP

* Put variables and constants here

srt_addr  EQU     $3000
end_addr  EQU     $3300

current   DS.W    1          

op_code_nop     DC.W    $4E71,$FFFF
op_code_data    DC.W    $0000,$0000

op_print_nop    DC.B    'NOP ',0
op_print_data   DC.B    'DATA ',0
op_print_blank   DC.B    '',0

CR EQU $0D
LF EQU $0A

    ORG     $3000
    ADDQ    #3,D0
    NOP
    NOP

    END    START        ; last line of source
    
    

*~Font name~Courier New~
*~Font size~12~
*~Tab type~1~
*~Tab size~4~
