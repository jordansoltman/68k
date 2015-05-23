*-----------------------------------------------------------
* Title      :
* Written by :
* Date       :
* Description:
*-----------------------------------------------------------

*method that takes the mode offset and register offset, and valid formats and determines valid, and if so print
    
    ORG    $1000
    
srt_addr  EQU     $3000
end_addr  EQU     $3010
    
    OFFSET  0
op_value   DS.W    1
op_mask    DS.W    1
    ORG *

START                                       ; first instruction of program
    
    MOVE.L  #srt_addr,current_addr          *Load the starting address

LOOP
    MOVEA.L current_addr,A0                 *Load the current address
    CMP.L   #end_addr,A0                    *Compare to our starting and ending
    BGE     DONE                            *Check if done
    CLR.W   output_string_displacement      *Clear the current word
    CLR.B   invalid_op_flag                 *Clear the invalid flag
    MOVE.W  (A0)+,D0                        *Move the current data to D0
    MOVE.L  A0,current_addr                 *Update the current address
    MOVE.W  D0,D1    
CHECK_NOP
    AND.W   op_code_nop+op_mask,D1          *And against the first bitmask
    CMP.W   op_code_nop+op_value,D1         *See if the values are equal
    BNE     CHECK_EOR
    BSR     sub_op_nop                      *If it's a match then we'll go to the OP_NOP routine
    BRA     OUTPUT
CHECK_EOR
    MOVE.W  D0,D1
    AND.W   op_code_eor+op_mask,D1          *And against the first bitmask
    CMP.W   op_code_eor+op_value,D1         *See if the values are equal
    BNE     CHECK_DATA                      *If it's a match then we'll go to the OP_NOP routine
    BSR     sub_op_eor
    BRA     OUTPUT
CHECK_DATA
    BSR     sub_op_data
    BRA     LOOP
DONE
    SIMHALT             ; halt simulator

OUTPUT
    LEA     output_string,A1
    MOVEQ   #13,D0
    TRAP    #15
    BRA     LOOP

sub_op_nop
    PEA     print_op_nop
    BSR     sub_build_string
    LEA     4(SP),SP
    RTS
    
sub_op_eor
    MOVEM.L D0,-(SP)                        *Backup D0
    PEA     print_op_eor                    *Load print eor string
    BSR     sub_build_string                *Print it out to our output string
    LEA     4(SP),SP                        *Move our stack pointer back
    MOVEM.L (SP)+,D0                        *Restore D0
    
    MOVEM.L D0,-(SP)
    MOVE.W  #long_size,-(SP)
    BSR     sub_build_instr_size
    LEA     2(SP),SP
    MOVEM.L (SP)+,D0
    
    MOVEM.L D0,-(SP)                        *Backup D0
    MOVE.W  #ea_reg_dir,-(SP)
    MOVE.W  #9,-(SP)
    BSR     sub_build_direct_string
    LEA     4(SP),SP
    MOVEM.L (SP)+,D0                        *Restore D0
    
    MOVEM.L D0,-(SP) 
    BSR     sub_build_string_comma_space
    MOVEM.L (SP)+,D0
    
    MOVEM.L D0,-(SP)                        *Backup D0
    PEA     op_ea_dest_eor
    MOVE.W  #3,-(SP)
    MOVE.W  #0,-(SP)
    MOVE.W  #long_size,-(SP)    ***UPDATE***
    BSR     sub_check_ea_string
    LEA     10(SP),SP
    MOVEM.L (SP)+,D0                        *Restore D0
    
    BSR     sub_build_finish
    
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


**************************************************************
*
* sub_build_finish
*
* Puts a null character at the end
*
sub_build_finish
    MOVEA.L     #output_string,A0
    MOVE.W      output_string_displacement,D0   *Load current displacement to D0
    ADD.W       D0,A0                           *Adjust the address for the current displacement
    MOVE.B      #null,(A0)
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
    MOVE.W      D3,D5                               *Move the byte from D3 to D5
    AND.W       #right_nibble_mask,D5               *Mask the last nibble in D5
    MOVE.B      (0,A1,D5.W),-(A0)                   *Add remainder to output string
    LSR.L       #4,D3                               *Shift our hex value right by two
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
* 3 (W): (For Immediate) Size can be passed in as byte_size, word_size, or long_size

    OFFSET 4
sub_build_ea_string_size        DS.W    1
sub_build_ea_string_register    DS.W    1
sub_build_ea_string_mode        DS.W    1
    ORG *

sub_build_ea_string
    MOVE.W      sub_build_ea_string_mode(SP),D1                         *Load mode to D1
    MOVE.W      sub_build_ea_string_register(SP),D2                     *Load register to D2
    MOVE.W      sub_build_ea_string_size(SP),D3
    CMP.W       #ea_abs,D1
    BNE         sub_build_ea_string_reg
    
    CMP.W       #ea_imm,D2
    BEQ         sub_build_ea_string_immediate
    CMP.W       #ea_word,D2
    BNE         sub_build_ea_string_addr_long
    MOVE.W      #word_size,-(SP)
    BRA         sub_build_ea_string_addr
sub_build_ea_string_addr_long
    MOVE.W      #long_size,-(SP)
sub_build_ea_string_addr 
    MOVE.W      #false,-(SP)
    BRA         sub_build_ea_string_abs_print
sub_build_ea_string_immediate
    MOVE.W      D3,-(SP)
    MOVE.W      #true,-(SP)
sub_build_ea_string_abs_print
    BSR         sub_build_next_abs
    LEA         4(SP),SP
    RTS
sub_build_ea_string_reg
    MOVEA.L     #output_string,A0                   *Load the output string
    MOVEA.L     #hex_characters,A1                  *Load the hex characters
    MOVE.W      output_string_displacement,D0       *Load current displacement to D0
    ADD.W       D0,A0                               *Adjust the address for the current displacement
    CMP.W       #ea_ari_pre,D1                      *Check if ARI with predecrement
    BNE         sub_build_ea_string_open_paren      *If not go to next step
    MOVE.B      #const_print_minus,(A0)+            *Output minus sign
    ADDQ.W      #1,D0                               *Increase the displacement by one
sub_build_ea_string_open_paren
    CMP.W       #ea_ari,D1                          *Check against modes that need open paren
    BLT         sub_build_ea_string_reg_type        *If DN or AN skip parens
    MOVE.B      #const_print_open_paren,(A0)+       *Otherwise add an opening paren
    ADDQ.W      #1,D0                               *Increment displacement
    BRA         sub_build_ea_string_reg_type_a      *Branch to A output (must be because only addresses have paren)
sub_build_ea_string_reg_type
    CMP.W       #ea_reg_dir,D1                      *Check if this is a register (DN)
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
    CMP.W       #ea_ari,D1                          *See if we need an close paren
    BLT         sub_build_ea_string_rts             *If we don't we are done
    MOVE.B      #const_print_close_paren,(A0)+      *Add the closing paren
    ADDQ.W      #1,D0                               *Increase the displacement by one
    CMP.W       #ea_ari_post,D1                     *Check if we need a plus sign
    BNE         sub_build_ea_string_rts             *If not we are done
    MOVE.B      #const_print_plus,(A0)+             *Add plus sign to string
    ADDQ.W      #1,D0                               *Increase the displacement by one
sub_build_ea_string_rts
    MOVE.W      D0,output_string_displacement       *Update the displacement for the string
    RTS
    
**************************************************************
*
* sub_build_next_abs
*
* Grabs the next address from the 
*
* Stack Parameters:
* 1 (W): Size defined by either byte_size, word_size or long_size
* 2 (W): Is immediate? pass #true or #false
*

    OFFSET 4
sub_build_next_abs_imm     DS.W    1
sub_build_next_abs_size    DS.W    1
    ORG *

sub_build_next_abs
    MOVE.W  sub_build_next_abs_size(SP),D1              * load size to D1
    MOVE.W  sub_build_next_abs_imm(SP),D2               * load immediate flag (#true or #false)
    MOVEA.L current_addr,A0                             * load current address to A0
    
    CMP.W   #long_size,D1                               * compare size to long
    BEQ     sub_build_next_abs_long                     * branch to special case if true
    MOVE.W  (A0)+,D3                                    * get next word
    BRA     sub_build_next_abs_print
sub_build_next_abs_long
    MOVE.L  (A0)+,D3                                    * get next long
sub_build_next_abs_print
    MOVEM.L A0,-(SP)                                    * save current address on the stack
    MOVE.L  D3,-(SP)                                    * move value (word or long) to stack
    MOVE.W  D2,-(SP)                                    * move immediate flag (#true or #false) to the stack
    MOVE.W  D1,-(SP)                                    * move size to the stack
    BSR     sub_build_hex_string                        * call sub_build_hex_string
    LEA     8(SP),SP                                    * reset the stack
    MOVEM.L (SP)+,A0                                    * reload A0 with current address
    MOVE.L  A0,current_addr                             * set current address to value of A0
    RTS

**************************************************************
*
* sub_build_direct_string
*
* Directly builds an EA string for register or address direct with a given number
*
* Stack Parameters:
* 1 (W): Mode in defined ea_reg_dir or ea_add_dir
* 2 (W): Starting bit location within D0
*
* Register Parameters:
* 1 (L): D0 should contain the current op code
*

    OFFSET 4
sub_build_direct_string_start    DS.W   1
sub_build_direct_string_ea       DS.W   1
    ORG *

sub_build_direct_string
    MOVE.W  sub_build_direct_string_start(SP),D1    *Get the starting position
    
    MOVE.W  D1,-(SP)                                *Give handy mask the starting position
    MOVE.W  #3,-(SP)                                *And give handy mask the size
    BSR     sub_handy_mask                          *Branch to handy mask
    LEA     4(SP),SP                                *Reset the stack pointer
    
    MOVE.W  sub_build_direct_string_ea(SP),-(SP)    *Give the mode
    MOVE.W  D1,-(SP)                                *Give the register number
    MOVE.W  #null,-(SP)                             *Push an empty value for size
    BSR     sub_build_ea_string                     *Build the string
    LEA     6(SP),SP                                *Reset the stack pointer
    
    RTS
    
**************************************************************
*
* sub_check_ea_string
*
* Adds an EA to the string
*
* Stack Parameters:
* 1 (L): Address of valid modes
* 2 (W): Mode starting bit location within D0
* 3 (W): Register starting bit location within D0
* 4 (W): Calling operand size IN (byte_size, word_size, long_size)
*
* Register Parameters:
* 1 (L): D0 should contain the current op code
*
    OFFSET 4
sub_check_ea_string_size    DS.W    1
sub_check_ea_string_reg     DS.W    1
sub_check_ea_string_mode    DS.W    1
sub_check_ea_string_add     DS.L    1
    ORG *

sub_check_ea_string
    
    MOVE.W  sub_check_ea_string_mode(SP),D2     *Move the bit position of the mode to D2
    MOVE.W  sub_check_ea_string_reg(SP),D3      *Move the bit position of the reg to D3
    MOVE.W  sub_check_ea_string_size(SP),D5     *Move the size onto D5
    
    MOVEM.L D3/D5,-(SP)                         *Backup D3 (reg bit pos) and A2
    MOVE.W  D2,-(SP)                            *Push mode bit position onto stack
    MOVE.W  #3,-(SP)                            *Push the mode size (always 3) onto the stack
    BSR     sub_handy_mask                      *Call handy mask to get the value to D1
    LEA     4(SP),SP                            *Restore the stack
    MOVEM.L (SP)+,D3/D5                         *Restore D3 and A2
    
    MOVE.W  D1,D2                               *Move the mode value to D2
    
    MOVEM.L D2/D5,-(SP)                         *Backup the mode value (D2)
    MOVE.W  D3,-(SP)                            *Push the reg bit position onto stack
    MOVE.W  #3,-(SP)                            *Push the reg size (always 3) onto the stack
    BSR     sub_handy_mask                      *Call handy mask to get the value to D1
    LEA     4(SP),SP                            *Restore the stack
    MOVEM.L (SP)+,D2/D5                         *Restore D2 and A2
    
    MOVE.W  D1,D3                               *Move the reg value back to D3
    
    MOVEA.L sub_check_ea_string_add(SP),A2      *Move the starting address mode value to A2
    
sub_check_ea_string_loop
    MOVE.B  (A2)+,D1                            *Grab the next ea_mode and store in D1
    CMP.B   #ea_term,D1                         *See if we are at the end of the available modes
    BEQ     sub_check_ea_string_not_found       *Branch to not found if true
    CMP.B   #ea_abs,D1                          *Test if it's absolute
    BEQ     sub_check_ea_string_abs             *Branch to absolute special case if so
    CMP.B   D1,D2                               *Test to see if our mode matches
    BEQ     sub_check_ea_string_print           *Branch to print if it does
    BRA     sub_check_ea_string_loop            *Otherwise loop back through
sub_check_ea_string_abs
    MOVE.B  (A2)+,D4                            *Get the absolute addressing mode (as register value)
    CMP.B   #ea_abs,D2                          *Check to see if our mode is the absolute mode
    BNE     sub_check_ea_string_loop            *If it's not we'll go back to the loop
    CMP.B   D4,D3                               *See if it matches the register value
    BEQ     sub_check_ea_string_print           *If so we'll print it out
    BRA     sub_check_ea_string_loop            *Otherwise we'll loop back again
sub_check_ea_string_print    
    MOVE.W  D2,-(SP)                            *Load the mode to the stack
    MOVE.W  D3,-(SP)                            *Load the register to the stack
    MOVE.W  D5,-(SP)                            *Load the size onto the stack
    BSR     sub_build_ea_string                 *Build that string
    LEA     6(SP),SP                            *Reset the stack
    BRA     sub_check_ea_string_rts             *Return
sub_check_ea_string_not_found
    MOVE.B  #true,invalid_op_flag               *Set the data invalid flag true
sub_check_ea_string_rts
    RTS

    

**************************************************************
*
* sub_build_instr_size
*
* Adds a period, the size and a space: ".S " where S is size
*
* Stack Parameters:
* 1 (W): Size should be either #byte_size, #word_size, or #long_size

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
* D0 (L): Should contain the value to mask and split
*
* Stack Parameters
* 1 (W): Lower bit bound
* 2 (W): Size (number of bits to mask)
*
* Register Return
* D1 (L): Masked value
*
    OFFSET 4
sub_handy_mask_size     DS.W    1
sub_handy_mask_lower    DS.W    1
    ORG *

sub_handy_mask
    MOVE.W      sub_handy_mask_lower(SP),D5 *Load the lower bound size
    MOVE.W      sub_handy_mask_size(SP),D2  *Load the size
    SUBQ.W      #1,D2                       *Decrease size by one to make bounds correct
    CLR.L       D3                          *Clear D3 to be used as a mask
    MOVE.W      D2,D4                       *Copy the size to D4
    ADD.W       D5,D4                       *Add the lower bound and size to get the MSB of the mask
sub_handy_mask_loop
    CMP.W       D5,D4                       *Compare our counter to the lower bound
    BLT         sub_handy_mask_done         *If our counter is less than or equal we are done making the mask
    BSET        D4,D3                       *Set the bit to one in the mask at location D4
    SUBQ.W      #1,D4                       *Decrement D4 by one
    BRA         sub_handy_mask_loop         *Go back to loop again
sub_handy_mask_done
    MOVE.L      D0,D1                       *Move the value that should be masked to D1
    AND.L       D3,D1                       *Mask it with D3 (the mask we made above)
    LSR.L       D5,D1                       *Shift the result right so that it starts at the LSB
    RTS


*********** CONSTANTS ***********

byte_size EQU     1
word_size EQU     2
long_size EQU     4

right_nibble_mask   EQU $000F
null                EQU 0

ea_reg_dir             EQU %000
ea_add_dir             EQU %001
ea_ari                 EQU %010
ea_ari_post            EQU %011
ea_ari_pre             EQU %100

ea_abs                 EQU %111    *This MUST preceed each ea_word,ea_long,ea_imm
ea_word                EQU %000    *Used in conjunction with abs
ea_long                EQU %001    *Used in conjunction with abs
ea_imm                 EQU %100    *Used in conjunction with abs

ea_term                EQU %1111   *Terminates a list of ea modes

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

******* STORAGE **********

output_string               DS.B    40
output_string_displacement  DS.W    1
current_addr                DS.L    1
invalid_op_flag             DS.B    1

hex_characters  DC.B    '0123456789ABCDEF'

* Put variables and constants here

print_blank         DC.B    0


*Value first, mask second

********** OP CODE EFFECTIVE ADDRESS MODES ************

op_ea_dest_eor   DC.B    ea_reg_dir,ea_ari,ea_ari_post,ea_ari_pre,ea_abs,ea_word,ea_abs,ea_long,ea_term

************** OP CODE MASKS AND VALUES ***************

op_code_nop     DC.W    $4E71,$FFFF
op_code_data    DC.W    $0000,$0000
op_code_eor     DC.W    $B100,$F100

print_op_nop    DC.B    'NOP ',0
print_op_data   DC.B    'DATA ',0
print_op_eor    DC.B    'EOR',0

print_size_long DC.B    'L',$9,0
print_size_word DC.B    'W ',0
print_size_byte DC.B    'B ',0

CR EQU $0D
LF EQU $0A


    * TEST PROGRAM * *BB88 eor bad*

    ORG     $3000
*tst DC.W    $BB88
    EOR.L   D3,$12345678
    EOR.W   D0,$ABCD
    EOR.L   D1,(A0)+
    
    END    START        ; last line of source






*~Font name~Courier New~
*~Font size~12~
*~Tab type~1~
*~Tab size~4~
