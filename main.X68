*-----------------------------------------------------------
* Title      :
* Written by :
* Date       :
* Description:
*-----------------------------------------------------------
    ORG    $1000
    
    OFFSET  0
op_value   DS.W    1
op_mask    DS.W    1
    ORG *
    
START                                       ; first instruction of program
    CLR.W       output_string_displacement  ****MOVE ME!!!!
    MOVEA.L #srt_addr,A2                    *Load the starting address
    MOVEA.L #end_addr,A3                    *Load the ending address
    
LOOP
    CMP.L   A2,A3                           *Compare to our starting and ending
    BLE     DONE                            *Check if done
    MOVE.W  (A2)+,D0                        *Move the current data to D0
    MOVE.W  D0,D1
CHECK_NOP
    AND.W   op_code_nop+op_mask,D0          *And against the first bitmask
    CMP.W   op_code_nop+op_value,D0         *See if the values are equal
    BNE     CHECK_EOR
    BSR     sub_op_nop                          *If it's a match then we'll go to the OP_NOP routine
    BRA     LOOP
CHECK_EOR
    MOVE.W  D1,D0
    AND.W   op_code_eor+op_mask,D0          *And against the first bitmask
    CMP.W   op_code_eor+op_value,D0         *See if the values are equal
    BNE     CHECK_DATA                          *If it's a match then we'll go to the OP_NOP routine
    BSR     sub_op_eor
    BRA     LOOP
CHECK_DATA
    BSR     sub_op_data
    BRA     LOOP
DONE
    SIMHALT             ; halt simulator

sub_op_nop
    PEA     print_op_nop
    BSR     sub_build_string
    LEA     long_size(SP),SP    
    RTS

sub_op_data
    LEA     print_blank,A1
    MOVEQ   #14,D0
    TRAP    #15

    MOVEQ   #15,D0
    MOVEQ   #16,D2
    TRAP    #15

    LEA     print_blank,A1
    MOVEQ   #13,D0
    TRAP    #15

    RTS
    
sub_op_eor
    PEA     print_op_eor        *Push the EOR address string onto the stack
    BSR     sub_build_string    *Output the string
    LEA     long_size(SP),SP    *Restore the stack state
    
    MOVE.W  #6,-(SP)            *Start from 
    MOVE.W  #2,-(SP)
    BSR     sub_handy_mask
    LEA     8(SP),SP
    
    
    
    RTS
    
    
**************************************************************
*
* sub_build_string
*
* Print value at address
*
* Parameters:
* 1 (L): 0 terminated string address to add onto string
*
sub_build_string
    MOVEA.L     #output_string,A0
    MOVE.W      output_string_displacement,D0   *Load current displacement to D0
    ADD.W       D0,A0                           *Adjust the address for the current displacement
    MOVE.L      long_size(SP),A1                *Grab the address to print from
sub_build_string_loop
    CMP.B       #0,(A1)                         *See if we are at the end of the string
    BEQ         sub_build_string_rts            *If so we'll exit
    MOVE.B      (A1)+,(A0)+                     *Move the source char to the destination
    ADDQ.W      #byte_size,D0                   *increment the displacement
    BRA         sub_build_string_loop           *Go back and see if we are done copying
sub_build_string_rts
    MOVE.W      D0,output_string_displacement
    RTS
    
**************************************************************
*
* sub_build_hex_string
*
* Print value at address
*
* Parameters
* 1 (L): Value that should be converted to hex and added to string
* 2 (W): Boolean IN (true, false) that determines if it should be printed as an immediate
* 3 (W): Size IN (byte_size, word_size, long_size) that determines what size to print as

    OFFSET 4
size        DS.W    1
immediate   DS.W    1
value       DS.L    1
    ORG *

sub_build_hex_string
    MOVEA.L     #output_string,A0                   *Load the output string
    MOVEA.L     #hex_characters,A1                  *Load the hex characters
    MOVE.W      output_string_displacement,D0       *Load current displacement to D0
    ADD.W       D0,A0                               *Adjust the address for the current displacement
    MOVE.W      size(SP),D1                         *Get the size and save it in D1
    LSL.W       #1,D1                               *Multiply by 2 because we defined bytes not digits
    MOVE.W      D1,D4                               *Copy the size for later
    MOVE.W      immediate(SP),D2                    *Get immediate boolean and save in D2
    MOVE.L      value(SP),D3                        *Get the value and save in D3
    CMP.B       #false,D2                           *See if we are printing an immediate
    BEQ         sub_build_hex_string_hex            *Skip printing the hex sign if immediate is set false
    MOVE.B      #const_print_pound_sym,(A0)+        *Output the pound symbol
    ADDQ.W      #byte_size,D0                       *Add to our displacement incrementer
sub_build_hex_string_hex
    MOVE.B      #const_print_hex_sym,(A0)+          *Add in the $ symbol for hex
    ADDQ.W      #byte_size,D0                       *Add one to displacement counter
    ADDA.W      D1,A0                               *increment the pointer by the number size
sub_build_hex_string_loop
    CMP.W       #0,D1                               *See if we are done
    BEQ         sub_build_hex_string_rts            *Exit the subroutine
    SUBQ.W      #1,D1                               *Decrease our counter by one
    DIVU.W      #16,D3                              *Divide by 16 to get LSB
    SWAP        D3                                  *Swap to put remainder in right word
    MOVE.B      (0,A1,D3.W),-(A0)                   *Add remainder to output string
    SWAP        D3                                  *Swap back to divide again
    BRA         sub_build_hex_string_loop           *Loop
sub_build_hex_string_rts
    ADD.W       D4,D0                               *Add our total displacement
    MOVE.W      D0,output_string_displacement       *Update the displacement
    RTS
    
**************************************************************
*
* sub_build_ea_string
*
* Adds an EA to the string
*
* Paremeters:
* 1 (W): Mode in defined ea_modes_[X]
* 2 (W): Register 0-7

    OFFSET 4
register    DS.W    1
mode        DS.W    1
    ORG *

sub_build_ea_string
    MOVEA.L     #output_string,A0                   *Load the output string
    MOVEA.L     #hex_characters,A1                  *Load the hex characters
    MOVE.W      output_string_displacement,D0       *Load current displacement to D0
    ADD.W       D0,A0                               *Adjust the address for the current displacement
    MOVE.W      mode(SP),D1                         *Load mode to D1
    MOVE.W      register(SP),D2                     *Load register to D2
    CMP.W       #ea_mode_ari_pre,D1                 *Check if ARI with predecrement
    BNE         sub_build_ea_string_open_paren      *If not go to next step
    MOVE.B      #const_print_minus,(A0)+            *Output minus sign
    ADDQ.W      #1,D0                               *Increase the displacement by one
sub_build_ea_string_open_paren
    CMP.W       #ea_mode_ari,D1                     *Check against modes that need open paren
    BLT         sub_build_ea_string_reg_type        *If DN or AN skip parens
    MOVE.B      #const_print_open_paren,(A0)+       *Otherwise add an opening paren
    ADDQ.W      #1,D0                               *Increment displacement
    BRA         sub_build_ea_string_reg_type_a      *Branch to A output (must be because only addresses have paren)
sub_build_ea_string_reg_type    
    CMP.W       #ea_mode_reg_direct,D1              *Check if this is a register (DN)
    BNE         sub_build_ea_string_reg_type_a      *If not branch to print out an A instead
    MOVE.B      #const_print_d,(A0)+                *Add 'D' to string
    ADDQ.W      #1,D0                               *Increase the displacement by one
    BRA         sub_build_ea_string_reg_num         *Branch to adding address number
sub_build_ea_string_reg_type_a
    MOVE.B      #const_print_a,(A0)+                *Add 'A' to string
    ADDQ.W      #1,D0                               *Increase the displacement by one
sub_build_ea_string_reg_num
    MOVE.B      (0,A1,D2.W),(A0)+                   *Move our number into the string via the hex_string const
    ADDQ.W      #1,D0                               *Increase the displacement by one
    CMP.W       #ea_mode_ari,D1                     *See if we need an close paren
    BLT         sub_build_ea_string_rts             *If we don't we are done
    MOVE.B      #const_print_close_paren,(A0)+      *Add the closing paren
    ADDQ.W      #1,D0                               *Increase the displacement by one
    CMP.W       #ea_mode_ari_post,D1                *Check if we need a plus sign
    BNE         sub_build_ea_string_rts             *If not we are done
    MOVE.B      #const_print_plus,(A0)+             *Add plus sign to string
    ADDQ.W      #1,D0                               *Increase the displacement by one
sub_build_ea_string_rts
    MOVE.W      D0,output_string_displacement       *Update the displacement for the string
    RTS
    
**************************************************************
*
* sub_build_instr_size
*
* Adds a period, the size and a space: ".S " where S is size
*
* Stack Parameters:
* 1 (W): Size

    OFFSET 4
size    DS.W    1
    ORG *

sub_build_instr_size
    MOVEA.L     #output_string,A0                   *Load the output string
    MOVEA.L     #hex_characters,A1                  *Load the hex characters
    MOVE.W      output_string_displacement,D0       *Load current displacement to D0
    ADD.W       D0,A0                               *Adjust the address for the current displacement
    MOVE.W      size(SP),D1                         *Load the size into D1
    MOVE.B      #'.',(A0)+                          *First add a period "OPCODE."
    ADDQ.W      #1,D0                               *Increase the displacement by one
    CMP.W       #byte_size,D1                       *See if it's a byte
    BNE         sub_build_instr_size_word           *If it's not a byte check a word
    MOVE.B      #'B',(A0)+                          *Add a 'B' to our string
    BRA         sub_build_instr_size_rts            *Branch to the return
sub_build_instr_size_word
    CMP.W       #word_size,D1                       *See if it's a word
    BNE         sub_build_instr_size_long           *If not it's a long
    MOVE.B      #'W',(A0)+                          *Add a 'W' to our string
    BRA         sub_build_instr_size_rts            *Branch to the return
sub_build_instr_size_long
    MOVE.B      #'L',(A0)+                          *Move an 'L' to our string
sub_build_instr_size_rts
    MOVE.B      #' ',(A0)+                          *Add the final space
    ADDQ.W      #2,D0                               *Increase the displacement by two because we added a B, W or L and space
    MOVE.W      D0,output_string_displacement       *Save the updated displacement
    RTS
    
**************************************************************
*
* sub_build_string_comma_space
*
* Adds a single comma to the string
*
sub_build_string_comma_space
    MOVEA.L     #output_string,A0                   *Load the output string
    MOVEA.L     #hex_characters,A1                  *Load the hex characters
    MOVE.W      output_string_displacement,D0       *Load current displacement to D0
    ADD.W       D0,A0                               *Adjust the address for the current displacement
    MOVE.B      #',',(A0)+                          *add a ',' to the output string
    MOVE.B      #' ',(A0)+                          *add a ',' to the output string
    ADDQ.W      #2,D0                               *Increase the displacement by two
    MOVE.W      D0,output_string_displacement       *Save the updated displacement
    RTS

**************************************************************
*
* sub_handy_mask
*
* Given a value, lower bound, and size, this method will return the masked
* values starting from the LSB to D0
*
* Register Parameters
* D1 (L): Should contain the value to mask and split
*
* Stack Parameters
* 1 (W): Lower bit bound
* 2 (W): Size (number of bits to mask)
*
* Register Return
* D0 (L): Masked value
*
    OFFSET 4
sub_handy_mask_size     DS.W    1
sub_handy_mask_lower    DS.W    1
    ORG *
    
sub_handy_mask
    MOVE.W      sub_handy_mask_lower(SP),D5 *Load the lower bound size
    MOVE.W      sub_handy_mask_size(SP),D2  *Load the size
    CLR.L       D3                          *Clear D3 to be used as a mask
    MOVE.W      D2,D4                       *Copy the size to D4
    ADD.W       D5,D4                       *Add the lower bound and size to get the MSB of the mask
sub_handy_mask_loop
    CMP.W       D5,D4                       *Compare our counter to the lower bound
    BLE         sub_handy_mask_done         *If our counter is less than or equal we are done making the mask
    BSET        D4,D3                       *Set the bit to one in the mask at location D4
    SUBQ.W      #1,D4                       *Decrement D4 by one
    BRA         sub_handy_mask_loop         *Go back to loop again
sub_handy_mask_done
    MOVE.L      D1,D0                       *Move the value that should be masked to D0
    AND.L       D3,D0                       *Mask it with D3 (the mask we made above)
    LSR.L       D5,D0                       *Shift the result right so that it starts at the LSB
    RTS
   

*********** CONSTANTS ***********

srt_addr  EQU     $3000
end_addr  EQU     $3002
byte_size EQU     1
word_size EQU     2
long_size EQU     4

ea_mode_reg_direct          EQU %000
ea_mode_add_direct          EQU %001
ea_mode_ari                 EQU %010
ea_mode_ari_post            EQU %011
ea_mode_ari_pre             EQU %100
ea_mode_immediate           EQU %111
ea_mode_word                EQU %000
ea_mode_long                EQU %001

true      EQU     1
false     EQU     0

const_print_space       EQU   ' '
const_print_hex_sym     EQU   '$'
const_print_pound_sym   EQU   '#'
const_print_open_paren  EQU   '('
const_print_close_paren EQU   ')'
const_print_plus        EQU   '+'
const_print_minus       EQU   '-'
const_print_a           EQU   'A'
const_print_d           EQU   'D'   

output_string               DS.B    40
output_string_displacement  DS.W    1

hex_characters  DC.B    '0123456789ABCDEF'

* Put variables and constants here

print_blank         DC.B    '',0
print_space         DC.B    ' ',0


*Value first, mask second

op_code_nop     DC.W    $4E71,$FFFF
op_code_data    DC.W    $0000,$0000
op_code_eor     DC.W    $B100,$F100

print_op_nop    DC.B    'NOP ',0
print_op_data   DC.B    'DATA ',0
print_op_eor    DC.B    'EOR',0

print_size_long DC.B    'L ',0
print_size_word DC.B    'W ',0
print_size_byte DC.B    'B ',0

CR EQU $0D
LF EQU $0A


    * TEST PROGRAM *

    ORG     $3000
    EOR.L   D0,D1
    NOP

    END    START        ; last line of source




*~Font name~Courier New~
*~Font size~12~
*~Tab type~1~
*~Tab size~4~
