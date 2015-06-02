******************************************************************************************************************************************
* Title      : 68K Disassembler
* Written by : Sam Hoover & Jordan Soltman
* Date       : May 30, 2015
* Description: When given a starting address and ending address this program will disassembler to the screen until it reaches the ending
*              address. For more details on operation see the Disassembler Documentation.
******************************************************************************************************************************************

    ORG    $1000

START

    MOVE.L  #string_enter_start,-(SP)           *Load the start address prompt to the stack
    BSR     sub_get_input_hex                   *Get the starting address to D0
    LEA     4(SP),SP                            *Reset the stack pointer

    MOVE.L  D0,current_addr                     *Store the start as the current address

    MOVE.L  #string_enter_stop,-(SP)            *Load the ending address to the stack
    BSR     sub_get_input_hex                   *Get the end address to D0
    LEA     4(SP),SP                            *Reset the stack pointer

    MOVE.L  D0,end_addr                         *Store the ending address

    MOVE.W  #clear_screen,D1                    *Setup D1 with the clear screen variable
    MOVEQ   #11,D0                              *Move trap 11 to clear screen
    TRAP    #15                                 *Clear the screen

    MOVE.B  #0,D3                               *We will use D3 as a counter for line output

LOOP
    MOVE.L  current_addr,current_addr_backup    *Create a backup of the address
    MOVE.L  current_addr,A0

    CMP.L   end_addr,A0                         *See if we are at the end address
    BGT     DONE                                *If so branch to done

    CMP.B   #31,D3                              *See if we have maxed out the output
    BGE     WAIT                                *If so we'll wait for the enter key

    ADDQ.B  #1,D3                               *Increment the counter by one

    CLR.W   output_string_displacement          *Reset the string displacement so we can write again
    CLR.B   invalid_op_flag                     *Clear the invalid flag for the new opcode

    MOVE.W  (A0)+,D0                            *Move the opcode (or data) to D0 for processing
    MOVE.L  A0,current_addr                     *Update the current address to reflect the change

    MOVE.W  #op_codes,A1                        *Move the starting address for the opcodes to A1

LOOP_OPCODES                                    *Begin to loop through the opcodes using A1

    MOVEA.W (A1)+,A2

    CMP.L   #0,A2                               *Check to see if we are at the end of the opcodes list
    BEQ     OUTPUT_DATA                         *We didn't find a matching term so we'll output data instead

    MOVE.W  (A2)+,D2                            *Get the value
    MOVE.W  (A2)+,D1                            *Get the mask

    AND.W   D0,D1                               *Mask the opcode value
    CMP.W   D1,D2                               *See if it's a match

    BNE     LOOP_OPCODES                        *Try the next opcode

LOOP_OPDEFS

    MOVE.W  (A2)+,A3                            *Get the next opcode definition address

    CMP.W   #op_code_term,A3                    *See if we are at the end of the opcode
    BEQ     LOOP_OPCODES                        *If so we'll continue trying other opcodes

    CLR.W   output_string_displacement          *Reset the string displacement so we can write again
    CLR.B   invalid_op_flag                     *Clear the invalid flag for the new opcode
    MOVE.L  A0,current_addr                     *Reset the address to the current address

    MOVEM.L D0-D3/A0-A2,-(SP)                   *Save D0
    BSR     sub_build_current_line_address      *Print out the current line address
    MOVEM.L (SP)+,D0-D3/A0-A2                   *Restore D0

    MOVEM.L A0-A3/D0-D3,-(SP)                   *Backup the registers
    MOVE.L  A3,-(SP)                            *Move the address of the opcode definition to the stack
    BSR     sub_process_opcode                  *Process the opcode
    LEA     4(SP),SP                            *Reset the stack pointer
    MOVEM.L (SP)+,A0-A3/D0-D3                   *Restore the registers

    CMP.B   #false,invalid_op_flag              *See if the invalid flag was set
    BEQ     OUTPUT                              *If it wasn't we'll go ahead and output

    MOVE.B  #false,invalid_op_flag              *Reset the stack pointer
    BRA     LOOP_OPDEFS                         *Try the next definition

OUTPUT_DATA
    MOVEM.L A0-A3/D0-D3,-(SP)                   *Backup the registers
    BSR     sub_build_data                      *Build ouput [ADDR]   DATA    $[DATA]
    MOVEM.L (SP)+,A0-A3/D0-D3                   *Restore the registers
    BRA     OUTPUT                              *Go output the string

WAIT

    LEA     string_press_enter,A1               *Load the press enter message
    MOVEQ   #14,D0                              *Setup for outputing a string
    TRAP    #15                                 *Output the string

    LEA  input,A1                               *Point A1 at the end of the program so that any input is dumped

    MOVEQ   #2,D0                               *Setup to input a string
    TRAP    #15                                 *Input a string (we don't need the result)

    MOVE.W  #clear_screen,D1                    *Setup D1 with the clear screen variable
    MOVEQ   #11,D0                              *Move trap 11 to clear screen
    TRAP    #15                                 *Clear the screen

    MOVEQ   #0,D3                               *Reset the line counter

    BRA     LOOP                                *Return to our master loop

DONE
    LEA     string_end,A1                       *Load the ending message
    MOVEQ   #14,D0                              *Setup for outputing a string
    TRAP    #15                                 *Output the string
    SIMHALT

OUTPUT
    LEA     output_string,A1                    *Get the output string and put it in A1
    MOVEQ   #13,D0                              *Setup for output with no CR/LF
    TRAP    #15                                 *Output
    BRA     LOOP                                *Return to the master loop



******************************************************************************************************************************************
******************************************************************************************************************************************
************************************************************** SUBROUTINES ***************************************************************
******************************************************************************************************************************************
******************************************************************************************************************************************



**************************************************************
*
* sub_process_opcode
*
* This method processes opcode definitions and outputs the final result to the output_string global. If the
* operation code was processed and an error was found, the invalid_op_flag will be set to true. If the invalid
* opflag is set true, the opcode should not be considered valid given the definition and any output may be
* incomplete and should be discarded.
*
* For a complete discussion on how this method processes operations see the Disassembler Documentation: SDL section.
*
* Stack parameters:
* 1 (L): Address of operation definition
*
    OFFSET 4
sub_process_opcode_addr DS.L    1
    ORG *

sub_process_opcode
    MOVEA.L sub_process_opcode_addr(SP),A0  *Load the opcode definition address

    CLR.L   D1                              *Clear D1 so it can take a long address
    MOVE.W  (A0)+,D1                        *Get opcode name address

    **** Print opcode name
    MOVEM.L D0/A0,-(SP)                     *Backup the registers to the stack
    MOVE.L  D1,-(SP)                        *Push string name onto the stack for printing
    BSR     sub_build_string                *Build the string
    LEA     4(SP),SP                        *Reset the stack
    MOVEM.L (SP)+,D0/A0                     *Restore the registers

    MOVE.W  (A0)+,D1                        *Get the size type or terminating opf or cond info

    **** Condition operand
    CMP.W   #opf_cond,D1                    *See if we have a condition
    BNE     sub_process_opcode_check_size   *If not continue on

    MOVE.W  (A0)+,D1                        *Get the condition bit location

    MOVEM.L D0/A0,-(SP)                     *Backup the registers
    MOVE.W  D1,-(SP)                        *Put the bit position in D1
    MOVE.W  #4,-(SP)                        *set our size to 4 for the condition code
    BSR     sub_handy_mask                  *Grab the condition to D1
    LEA     4(SP),SP                        *Reset the stack pointer
    MOVEM.L (SP)+,D0/A0                     *Restore the registers

    MOVE.W  (A0)+,D2                        *Get the boolean to determine if we should include true and false
    CMP.W   #false,D2                       *Check if it's false
    BEQ     sub_process_opcode_skip_tf      *If it is we'll skip tf

    MOVEA.L #conditions,A1                  *Otherwise load all the conditions

    BRA     sub_process_opcode_check_cond   *Jump to check the condition

sub_process_opcode_skip_tf

    MOVEA.L #conditions_stf,A1              *Load the conditions without true and false

sub_process_opcode_check_cond

    MOVE.W  (A1)+,D2                        *Store the condition code to D2
    CMP.W   #cond_term,D2                   *See if it's the
    BEQ     sub_process_opcode_rts_invalid  *It must be an invalid condition type because we've run out of options

    MOVE.W  (A1)+,D3                        *Get the address of the condition string

    CMP.W   D2,D1                           *see if the current condition is the right one
    BNE     sub_process_opcode_check_cond   *Go back through the loop

    MOVEM.L D0/A0,-(SP)                     *Backup the registers
    MOVE.L  D3,-(SP)                        *Put the string address on the stack
    BSR     sub_build_string                *Build the condition code
    LEA     4(SP),SP                        *Reset the stack pointer
    MOVEM.L (SP)+,D0/A0                     *Restore the registers

    MOVE.W  (A0)+,D1                        *Get the next token to hanle size or opf_term

sub_process_opcode_check_size

    CMP.W   #opf_term,D1                    *See if we have terminated
    BEQ     sub_process_opcode_rts          *We are done with this code so we'll return

    CMP.W   #opf_no_size,D1                 *See if it doens't have a size
    BEQ     sub_process_opcode_tab          *If it doesn't skip ahead

    CMP.W   #opf_size,D1                    *See if it is a size
    BNE     sub_process_opcode_opf_sizes    *Must support different sizes (not a single size)

    MOVE.W  (A0)+,D7                        *Store the size in D7
    BRA     sub_process_opcode_tab          *Skip to outputing a tab

sub_process_opcode_opf_sizes

    MOVE.W  (A0)+,D2                        *Get the size bit position
    MOVE.W  (A0)+,D3                        *Get the byte size format
    MOVE.W  (A0)+,D4                        *Get the word size format
    MOVE.W  (A0)+,D5                        *Get the long size format

    MOVEM.L D0/A0,-(SP)                     *Save the registers

    MOVE.W  D2,-(SP)                        *Put the size on the stack
    MOVE.W  D3,-(SP)                        *Put the byte size info on the stack
    MOVE.W  D4,-(SP)                        *Put the word size info on the stack
    MOVE.W  D5,-(SP)                        *Put the long size info on the stack

    BSR     sub_check_build_op              *Build the size operand
    LEA     8(SP),SP                        *Reset the stack pointer
    MOVEM.L (SP)+,D0/A0                     *Restore the registers

    MOVE.W  D1,D7                           *Save the size to D7

    CMP.B   #true,invalid_op_flag           *See if the size was invalid
    BEQ     sub_process_opcode_rts          *Branch to end if so

sub_process_opcode_tab

    MOVEM.L D0/D7/A0,-(SP)                  *Save the registers
    BSR     sub_tab                         *Output out the tab
    MOVEM.L (SP)+,D0/D7/A0                  *Restore the registers

    MOVE.W  (A0)+,D1                        *Move next keyword to D1

    CMP.W   #opf_term,D1                    *See if this code is done
    BEQ     sub_process_opcode_rts          *If so we are done

    CMP.W   #opf_flip,D1                    *See if the flip bit is set
    BNE     sub_process_opcode_back_types   *If not we'll skip to types

    MOVE.W  (A0)+,D1                        *Get the determinate bit position
    BTST    D1,D0                           *Test to see if the flip bit is set
    BEQ     sub_process_opcode_types

sub_process_opcode_flip_loop
    CMP.W   #opf_flipped,(A0)+              *Get next bit and increment by one
    BEQ     sub_process_opcode_types        *We are back processing opcodes
    BRA     sub_process_opcode_flip_loop    *If we are at the opf_flipped bit we are done and ready to output

sub_process_opcode_back_types

    LEA     -2(A0),A0                       *Backup by one

sub_process_opcode_types

    MOVE.W  (A0)+,D1                        *Get the next keyword

    CMP.W   #opf_count,D1                   *See if we are passing in a count
    BNE     sub_process_opcode_types_reg    *If not equal we'll see if its a register

    ** code for count

    MOVE.W  (A0)+,D1                        *Get the count bit position

    MOVEM.L D0/D7/A0,-(SP)                  *Backup registers
    MOVE.W  D1,-(SP)
    BSR     sub_build_count
    LEA     2(SP),SP
    MOVEM.L (SP)+,D0/D7/A0                  *Restore the registers

    BRA     sub_process_opcode_types_next   *Go on to the next item

sub_process_opcode_types_reg

    CMP.W   #opf_reg,D1                         *See if its a register field
    BNE     sub_process_opcode_types_cnt_reg   *If not check if it's a count/register field

    ** code for reg

sub_process_opcode_types_reg_qwk            *Quick access to reg

    MOVE.W  (A0)+,D1                        *Get starting bit position
    MOVE.W  (A0)+,D2                        *Get register mode

    MOVEM.L D0/D7/A0,-(SP)                  *Backup the registers

    MOVE.W  D2,-(SP)                        *Push mode bit position onto the stack
    MOVE.W  D1,-(SP)                        *Push register bit position onto the stack
    BSR     sub_build_direct_string         *Build the address or data register
    LEA     4(SP),SP                        *Reset the stack pointer

    MOVEM.L (SP)+,D0/D7/A0                  *Restore the registers

    BRA     sub_process_opcode_types_next   *Go to the next statement

sub_process_opcode_types_cnt_reg

    CMP.W   #opf_count_reg,D1               *See if it the count reg
    BNE     sub_process_opcode_types_imm    *If not check immediate

    MOVE.W  (A0)+,D1                        *Get determinate to figure out if it's a count or register

    BTST    D1,D0                           *Check to see if it's a count (0) or register (1)
    BNE     sub_process_opcode_types_reg_qwk    *It's a register so we'll process it as such

    MOVE.W  (A0)+,D1                        *Get the count bit position

    MOVEM.L D0/D7/A0,-(SP)                  *Backup registers
    MOVE.W  D1,-(SP)
    BSR     sub_build_count
    LEA     2(SP),SP
    MOVEM.L (SP)+,D0/D7/A0                  *Restore the registers

    MOVE.W  (A0)+,D1                        *Dump a value of A0

    BRA     sub_process_opcode_types_next

sub_process_opcode_types_imm

    CMP.W   #opf_imm,D1                     *See if it the count reg
    BNE     sub_process_opcode_types_ea     *If not must be an ea mode

    MOVEM.L D0/D1/D7/A0,-(SP)               *Backup registers
    MOVE.W  #'#',-(SP)                      *Move pound sign to the stack
    BSR     sub_build_char                  *Output the pound sign
    LEA     2(SP),SP                        *Reset the stack
    MOVEM.L (SP)+,D0/D1/D7/A0               *Restore the registers

    MOVEM.L D0/D7/A0,-(SP)                  *Backup registers
    MOVE.W  D7,-(SP)                        *Push the size onto the stack
    BSR     sub_get_next_abs                *Get the value (will be returned in D1)
    LEA     2(SP),SP                        *Reset the stack
    MOVEM.L (SP)+,D0/D7/A0                  *Restore the registers

    MOVEM.L A0/D0/D7,-(SP)                  * save current address on the stack
    MOVE.L  D1,-(SP)                        * move value (word or long) to stack
    MOVE.W  #true,-(SP)                     * Always true becuase we always want to print the $ symbol
    MOVE.W  D7,-(SP)                        * move size to the stack
    BSR     sub_build_hex_string            * call sub_build_hex_string
    LEA     8(SP),SP                        * reset the stack
    MOVEM.L (SP)+,A0/D0/D7                  * reload A0 with current address

    BRA     sub_process_opcode_types_next

sub_process_opcode_types_ea

    CMP.W   #opf_ea,D1                      *Check if it's an EA
    BNE     sub_process_opcode_types_disp   *If not go to disp

    CLR.L   D1                              *Clear D1 to get address
    MOVE.W  (A0)+,D1                        *Get the address of acceptable EA modes
    MOVE.W  (A0)+,D2                        *Mode start bit position
    MOVE.W  (A0)+,D3                        *Reg start bit position

    MOVEM.L A0/D0/D7,-(SP)                  *Backup the registers

    MOVE.L  D1,-(SP)                        *Pass valid address modes address
    MOVE.W  D2,-(SP)                        *Pass mode starting bit position
    MOVE.W  D3,-(SP)                        *Register starting bit position
    MOVE.W  D7,-(SP)                        *Calling operand size
    BSR     sub_check_ea_string             *Output EA
    LEA     10(SP),SP                       *Reset the pointer

    MOVEM.L (SP)+,A0/D0/D7                  *Reset the pointer

    BRA     sub_process_opcode_types_next

sub_process_opcode_types_disp

    CMP.W   #opf_disp,D1                    *See if it's a displacement
    BNE     sub_process_opcode_types_sub    *If it's not we'll check if it's a subroutine

    MOVEM.L D0/A0,-(SP)                     *Backup the registers
    MOVE.W  #0,-(SP)                        *Displacement is assumed to start at bit 0
    MOVE.W  #8,-(SP)                        *Get 8 bits
    BSR     sub_handy_mask                  *Mask the values
    LEA     4(SP),SP                        *Reset the stack pointer
    MOVEM.L (SP)+,D0/A0                     *Restore the registers

    MOVEM.L D0/A0,-(SP)                     *Backup the registers
    MOVE.W  D1,-(SP)                        *Move the displacement to the stack
    BSR     sub_build_displacement          *Build the displacement string
    LEA     2(SP),SP                        *Reset the stack pointer
    MOVEM.L (SP)+,D0/A0                     *Restore the registers

    BRA     sub_process_opcode_types_next   *Check for the next room


sub_process_opcode_types_sub

    CMP.W   #opf_sub,D1                     *See if it's a subroutine
    BNE     sub_process_opcode_types_string *If not go to string

    MOVE.W  (A0)+,A1                        *Get the address of the subroutine

    MOVEM.L D1/D0/D7/A0,-(SP)               *Backup the registers
    JSR     (A1)                            *Call the custom subroutine
    MOVEM.L (SP)+,D1/D0/D7/A0               *Restore the registers

    BRA     sub_process_opcode_types_next   *Go to next

sub_process_opcode_types_string

    MOVE.W  (A0)+,A1                        *Get the address of the string

    MOVEM.L D1/D0/D7/A0,-(SP)               *Backup the registers
    MOVE.L  A1,-(SP)                        *Put the string address on the stack
    BSR     sub_build_string                *Build the string
    LEA     4(SP),SP                        *Reset the stack pointer
    MOVEM.L (SP)+,D1/D0/D7/A0               *Restore the registers

sub_process_opcode_types_next

    MOVE.W  (A0)+,D1                        *Get the next statement

    CMP.W   #opf_term,D1                    *See if this code is done
    BEQ     sub_process_opcode_rts          *If so we are done

    CMP.W   #opf_flipped,D1                 *See if it's the flipped
    BEQ     sub_process_opcode_rts          *If so we are done

    MOVEM.L A0/D0/D7,-(SP)                  *Backup the registers
    BSR     sub_build_string_comma_space    *Build a comma and then a space because there must be another field
    MOVEM.L (SP)+,A0/D0/D7                  *Restore the registers

    BRA     sub_process_opcode_back_types   *Go back and get start again

sub_process_opcode_rts_invalid

    MOVE.B  #true,invalid_op_flag           *Set the invalid op flag to true

sub_process_opcode_rts
    BSR     sub_build_finish                *Put the terminating character on the string
    RTS

**************************************************************
*
* sub_build_data
*
* Build data looks to the current address to print out first the address, then 'DATA', and then
* the data (of word size) at that address in hex form. This method will increment the current_address
* counter by word_size.
*
* This method accepts no arguments and has no returns.
*

sub_build_data

    CLR.W       output_string_displacement      *Reset the string displacement so we can write again

    BSR         sub_build_current_line_address  *Print out the current line

    MOVE.L      #string_data,-(SP)              *Load the position of 'DATA' to the stack
    BSR         sub_build_string                *Output DATA
    LEA         4(SP),SP                        *Reset the stack pointer

    BSR         sub_tab                         *Output it

    MOVE.L      current_addr_backup,A0          *Get the backup address and put it in A0
    CLR.L       D0                              *Clear D0
    MOVE.W      (A0),D0                         *Load the value at A0 (the word) to D0

    MOVE.L      D0,-(SP)                        *Move the value to the stack
    MOVE.W      #true,-(SP)                     *We want to print a hex symbol so #true
    MOVE.W      #word_size,-(SP)                *Ops are always of word size
    BSR         sub_build_hex_string            *Build the string
    LEA         8(SP),SP                        *Reset the pointer

    BSR         sub_build_finish                *Finish out the output with a terminating 0

    RTS

**************************************************************
*
* sub_build_count
*
* Given a bit position on the stack, and the opcode in D0, this method will go get the value of the
* count (assumed size of 3 bits) and output it's value. Since counts of 0 mean 8, it will output
* the correct value to the output string.
*
* Stack Parameters:
* 1 (W): The bit position of the count
*
* Register Parameters:
* D0 (L): The opcode to use for masking
*
    OFFSET  4
sub_build_count_pos DS.W    1
    ORG     *

sub_build_count

    MOVEM.L D0,-(SP)                        *Backup registers
    MOVE.W  #'#',-(SP)                      *Move pound sign to the stack
    BSR     sub_build_char                  *Output the pound sign
    LEA     2(SP),SP                        *Reset the stack
    MOVEM.L (SP)+,D0                        *Restore the registers

    MOVE.W  sub_build_count_pos(SP),D1      *Get the count bit position

    MOVEM.L D0,-(SP)                        *Backup the registers
    MOVE.W  D1,-(SP)                        *Put the bit position in D1
    MOVE.W  #3,-(SP)                        *set our size to 3
    BSR     sub_handy_mask                  *Get the value to D1
    LEA     4(SP),SP                        *Reset the stack pointer
    MOVEM.L (SP)+,D0                        *Restore the registers

    CMP.B   #0,D1                           *If it's equal to zero then it should actually be 8
    BNE     sub_build_count_output          *If it's not output normally
    MOVE.B  #8,D1                           *Set the value to 8

sub_build_count_output

    MOVE.L  D1,-(SP)                        *Put the value to the stack
    MOVE.W  #false,-(SP)                    *Don't print the hex char because we are going to be <= 8
    MOVE.W  #nibble_size,-(SP)              *Print it out as a nibble
    BSR     sub_build_hex_string            *Print out the value
    LEA     8(SP),SP                        *Reset the stack

    RTS

**************************************************************
*
* sub_get_input_hex
*
* This method will first output the string passed on the stack as a prompt, then will process the entered value
* as a hex. If there are invalid characters, it is empty, or it is larger than 8 characters (leading zeros not included)
* the method will prompt again until a valid address is entered. The return value (through D0) is garaunteed to be
* a valid number between $00000000 and $FFFFFFFF
*
* Stack Parameters:
* 1 (L): The address null terminated byte string to be output as a prompt
*
* Return Registers:
* D0 (L): The processed hex value
*
    OFFSET  4
sub_get_input_hex_prompt  DS.L  1
    ORG *

sub_get_input_hex

    MOVE.L  #14,D0                              *Setup for string output
    MOVEA.L sub_get_input_hex_prompt(SP),A1     *Load the prompt
    TRAP    #15                                 *Output the prompt

    MOVE.L  #2,D0                               *Setup for keyboard input
    LEA     input,A1                            *Load the ending address to store the input string
    TRAP    #15                                 *Get the input string and the size to D1.W

    CMP.W   #0,D1                               *See if no string was entered
    BEQ     sub_get_input_hex_invalid_hex       *If so it's invalid

    CLR.L   D3                                  *D3 will be for output

sub_get_input_hex_lead_zeros

    MOVE.B  (A1),D2                             *Get the first byte
    CMP.B   #$30,D2                             *See if it's 0
    BNE     sub_get_input_hex_check_size        *If not we'll go on to check the hex string size

    CMP.W   #0,D1                               *See if we have run out of characters
    BEQ     sub_get_input_hex_rts               *If so the hex must be 0x0

    SUBQ.W  #1,D1                               *If so, subtract one from the total size
    LEA     1(A1),A1                            *Move our address up by one

    BRA     sub_get_input_hex_lead_zeros        *Loop back to check the next 0

sub_get_input_hex_check_size

    CMP.W   #8,D1                               *See if our size is greater than 8
    BGT     sub_get_input_hex_invalid_size      *If we have more than 8 characters it's too big

sub_get_input_hex_parse

    CMP.W   #0,D1                               *See if we are out of characers
    BEQ     sub_get_input_hex_rts               *If so we'll return
    SUBQ    #1,D1                               *Otherwise subtract one from the size as a counter

    MOVE.B  (A1)+,D2                            *Get the next character

    CMP.B   #$61,D2                             *See if it's greater than $61 (lowercase letters)
    BLT     sub_get_input_hex_parse_uc          *If not check undercase letters
    SUB.B   #$57,D2                             *Subtract $57 so it'll be in the range A to infinity
    BRA     sub_get_input_hex_parse_output      *Continue to the output

sub_get_input_hex_parse_uc
    CMP.B   #$41,D2                             *See if it's greater than $41 (uppercase letters)
    BLT     sub_get_input_hex_parse_num         *If it's less than we'll check numbers 0-9
    SUB.B   #$37,D2                             *Subtract $47 so it'll be in the range a...A
    BRA     sub_get_input_hex_parse_output      *Contine to the output

sub_get_input_hex_parse_num
    CMP.B   #$30,D2                             *Compare against the numeric range
    BLT     sub_get_input_hex_invalid_hex       *If it's less, it must be an invalid character
    SUB.B   #$30,D2                             *Otherwise subract 30 to get in the range 0-a

sub_get_input_hex_parse_output

    CMP.B   #15,D2                              *See if it's greater than 15 (f)
    BGT     sub_get_input_hex_invalid_hex       *If so it's invalid
    LSL.L   #4,D3                               *Make room for the characer
    ADD.B   D2,D3                               *Put it onto the address
    BRA     sub_get_input_hex_parse             *Go back for the next character

sub_get_input_hex_invalid_size
    LEA     string_invalid_size,A1              *Load the invalid size string
    BRA     sub_get_input_hex_output_invalid    *Branch to output the string
sub_get_input_hex_invalid_hex
    LEA     string_invalid_hex,A1               *Load the invalid hex string
sub_get_input_hex_output_invalid
    MOVE.L  #13,D0                              *Setup for string output
    TRAP    #15                                 *Output the error message
    BRA     sub_get_input_hex                   *Go back to get another hex
sub_get_input_hex_rts
    MOVE.L  D3,D0                               *Return the address through D0
    RTS

**************************************************************
*
* sub_build_finish
*
* This method outputs a null byte to the end of the global output_string so that it can be processed for output
* by an output method. After calling this method any output to the output_string will be ignored.
*
* This method accepts no arguments and has no return value.
*
sub_build_finish
    MOVEA.L     #output_string,A0               *Load the output string
    MOVE.W      output_string_displacement,D0   *Load current displacement to D0
    ADD.W       D0,A0                           *Adjust the address for the current displacement
    MOVE.B      #null,(A0)
    RTS

**************************************************************
*
* sub_build_current_line_address
*
* This method uses the current_addr_backup and outputs that value to output_string as a word if it's less than
* $FFFF and as a long if it's greater than $FFFF.
*
* This method accepts no arguments and has no return value.
*
sub_build_current_line_address
    MOVE.L      current_addr_backup,D1          *Get the address
    MOVE.L      D1,-(SP)                        *Put the address on the stack
    MOVE.W      #false,-(SP)                    *We don't want to output a hex symbol for the address
    CMP.L       #$FFFF,D1                       *Compare against the max address of a word
    BGT         sub_build_current_line_long     *Use a long size
    MOVE.W      #word_size,-(SP)                *Otherwise we can represent with a word
    BRA         sub_build_current_line_build
sub_build_current_line_long
    MOVE.W      #long_size,-(SP)                *Make it a long
sub_build_current_line_build
    BSR         sub_build_hex_string            *Build the string
    LEA         8(SP),SP                        *Reset the stack pointer

    BSR         sub_tab                         *Tab forward

    RTS

**************************************************************
*
* sub_build_char
*
* This method takes a single ascii character as a byte on the stack and outputs it to the output_string.
* If a backspace character is output, the output_string_displacement will be decreased by one, essentially
* erasing a single character from the end of the string.
*
* Stack Parameters:
* 1 (W) : the ascii character that should be output to the output_string
*
    OFFSET 4
sub_build_char_ascii DS.W    1
    ORG *

sub_build_char
    MOVEA.L     #output_string,A0               *Load the output string
    MOVE.W      output_string_displacement,D0   *Load current displacement to D0
    ADD.W       D0,A0                           *Adjust the address for the current displacement
    MOVE.W      sub_build_char_ascii(SP),D1

    CMP.W       #BS,D1                          *See if it's a backspace
    BNE         sub_build_char_output           *If not output the char
    SUBQ        #byte_size,D0                   *Otherwise subtract one from our displacement
    BRA         sub_build_char_rts              *And RTS
sub_build_char_output
    MOVE.B      D1,(A0)+                        *Move the character on
    ADDQ.W      #byte_size,D0                   *Increase by one
sub_build_char_rts
    MOVE.W      D0,output_string_displacement   *Save the displacement back to the global variable
    RTS

**************************************************************
*
* sub_build_string
*
* This method will output the null terminated byte string at the given address to output_string.
* This method has no return value.
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
* This method takes a value to convert to hex, a boolean to indicate if a '$' symbol should be printed preceeding
* the value, and a size (byte_size, word_size, or long_size) to indicate the size to print. The value of the
* hex is output to output_string. This method does not return anything.
*
* Stack Parameters
* 1 (L): Value that should be converted to hex and added to string
* 2 (W): Boolean IN (true, false) that determines if it should print the $ symbol in front
* 3 (W): Size IN (byte_size, word_size, long_size) that determines what size to print as

    OFFSET 4
sub_build_hex_string_size        DS.W    1
sub_build_hex_string_hex_flag    DS.W    1
sub_build_hex_string_value       DS.L    1
    ORG *

sub_build_hex_string
    MOVEA.L     #output_string,A0                       *Load the output string
    MOVEA.L     #hex_characters,A1                      *Load the hex characters
    MOVE.W      output_string_displacement,D0           *Load current displacement to D0
    ADD.W       D0,A0                                   *Adjust the address for the current displacement
    MOVE.W      sub_build_hex_string_size(SP),D1        *Get the size and save it in D1
    LSL.W       #1,D1                                   *Multiply by 2 because we defined bytes not digits
    CMP.W       #nibble_size,D1                         *See if it's a nibble (represented by 0)
    BNE         sub_build_hex_string_con                *If it's not skip the next step
    MOVEQ       #1,D1                                   *Move a 1 on to represent a nibble
sub_build_hex_string_con
    MOVE.W      D1,D4                                   *Copy the size for later
    MOVE.W      sub_build_hex_string_hex_flag(SP),D2    *Get immediate boolean and save in D2
    MOVE.L      sub_build_hex_string_value(SP),D3       *Get the value and save in D3
    CMP.B       #false,D2                               *See if we are printing a $ symbol
    BEQ         sub_build_hex_string_move_ptr           *Skip printing the hex sign if immediate is set false
sub_build_hex_string_hex
    MOVE.B      #'$',(A0)+                              *Add in the $ symbol for hex
    ADDQ.W      #byte_size,D0                           *Add one to displacement counter
sub_build_hex_string_move_ptr
    ADDA.W      D1,A0                                   *increment the pointer by the number size
sub_build_hex_string_loop
    CMP.W       #0,D1                                   *See if we are done
    BEQ         sub_build_hex_string_rts                *Exit the subroutine
    SUBQ.W      #1,D1                                   *Decrease our counter by one
    MOVE.W      D3,D5                                   *Move the byte from D3 to D5
    AND.W       #right_nibble_mask,D5                   *Mask the last nibble in D5
    MOVE.B      (0,A1,D5.W),-(A0)                       *Add remainder to output string
    ASR.L       #4,D3                                   *Shift our hex value right by two
    BRA         sub_build_hex_string_loop               *Loop
sub_build_hex_string_rts
    ADD.W       D4,D0                                   *Add our total displacement
    MOVE.W      D0,output_string_displacement           *Update the displacement
    RTS

**************************************************************
*
* sub_build_ea_string
*
* This method takes an addressing mode as defined by one of the ea_modes_, a register number, and
* a size (used in absolute modes). This method will output to the output_string the correct addressing mode
* string as defined by the parameters. This method has no return.
*
* Stack Parameters:
* 1 (W): Mode in defined ea_modes_[X]
* 2 (W): Register number 0-7
* 3 (W): (For Immediate) Size can be passed in as byte_size, word_size, or long_size NOTE: no_size if not immediate

    OFFSET 4
sub_build_ea_string_size        DS.W    1
sub_build_ea_string_register    DS.W    1
sub_build_ea_string_mode        DS.W    1
    ORG *

sub_build_ea_string
    MOVE.W      sub_build_ea_string_mode(SP),D1     *Load mode to D1
    MOVE.W      sub_build_ea_string_register(SP),D2 *Load register to D2
    MOVE.W      sub_build_ea_string_size(SP),D3     *Load size to D3
    CMP.W       #ea_abs,D1                          *See if the current mode is abs addressing
    BNE         sub_build_ea_string_reg             *If not it's a register

    *Deals with the immediate/absolute cases

    CMP.W       #ea_imm,D2                          *See if it's an immediate value
    BEQ         sub_build_ea_string_immediate       *If so go to print that
    CMP.W       #ea_word,D2                         *Otherwise we are printing an address, check if a word
    BNE         sub_build_ea_string_addr_long       *If not word it must be a long address
    MOVE.W      #word_size,D3                       *Setup for word_size printing
    BRA         sub_build_ea_string_abs_print       *Branch to print address
sub_build_ea_string_immediate
    MOVEM.L     D3,-(SP)                            *Backup D3
    MOVE.W      #'#',-(SP)                          *Push the immedate symbol onto the stack
    BSR         sub_build_char                      *Print it
    LEA         2(SP),SP                            *Reset the stack
    MOVEM.L     (SP)+,D3                            *Restore D3
    BRA         sub_build_ea_string_abs_print       *Move on to print
sub_build_ea_string_addr_long
    MOVE.W      #long_size,D3                       *Setup for long_size printing
sub_build_ea_string_abs_print
    MOVE.W      D3,-(SP)                            *Push the size onto the stack
    BSR         sub_get_next_abs                    *Get the next word/long to D1
    LEA         2(SP),SP                            *Reset the stack
    MOVE.L      D1,-(SP)                            * move value (word or long) to stack
    MOVE.W      #true,-(SP)                         * Always true becuase we always want to print the $ symbol
    MOVE.W      D3,-(SP)                            * move size to the stack
    BSR         sub_build_hex_string                * call sub_build_hex_string
    LEA         8(SP),SP                            * reset the stack
    RTS

    *Deals with the register cases

sub_build_ea_string_reg
    MOVEA.L     #output_string,A0                   *Load the output string
    MOVEA.L     #hex_characters,A1                  *Load the hex characters
    MOVE.W      output_string_displacement,D0       *Load current displacement to D0
    ADD.W       D0,A0                               *Adjust the address for the current displacement
    CMP.W       #ea_ari_pre,D1                      *Check if ARI with predecrement
    BNE         sub_build_ea_string_open_paren      *If not go to next step
    MOVE.B      #'-',(A0)+            *Output minus sign
    ADDQ.W      #1,D0                               *Increase the displacement by one
sub_build_ea_string_open_paren
    CMP.W       #ea_ari,D1                          *Check against modes that need open paren
    BLT         sub_build_ea_string_reg_type        *If DN or AN skip parens
    MOVE.B      #'(',(A0)+       *Otherwise add an opening paren
    ADDQ.W      #1,D0                               *Increment displacement
    BRA         sub_build_ea_string_reg_type_a      *Branch to A output (must be because only addresses have paren)
sub_build_ea_string_reg_type
    CMP.W       #ea_reg_dir,D1                      *Check if this is a register (DN)
    BNE         sub_build_ea_string_reg_type_a      *If not branch to print out an A instead
    MOVE.B      #'D',(A0)+                *Add 'D' to string
    ADDQ.W      #1,D0                               *Increase the displacement by one
    BRA         sub_build_ea_string_reg_num         *Branch to adding address number
sub_build_ea_string_reg_type_a
    MOVE.B      #'A',(A0)+                *Add 'A' to string
    ADDQ.W      #1,D0                               *Increase the displacement by one
sub_build_ea_string_reg_num
    MOVE.B      (0,A1,D2.W),(A0)+                   *Move our number into the string via the hex_string const
    ADDQ.W      #1,D0                               *Increase the displacement by one
    CMP.W       #ea_ari,D1                          *See if we need an close paren
    BLT         sub_build_ea_string_rts             *If we don't we are done
    MOVE.B      #')',(A0)+      *Add the closing paren
    ADDQ.W      #1,D0                               *Increase the displacement by one
    CMP.W       #ea_ari_post,D1                     *Check if we need a plus sign
    BNE         sub_build_ea_string_rts             *If not we are done
    MOVE.B      #'+',(A0)+             *Add plus sign to string
    ADDQ.W      #1,D0                               *Increase the displacement by one
sub_build_ea_string_rts
    MOVE.W      D0,output_string_displacement       *Update the displacement for the string
    RTS

**************************************************************
*
* sub_get_next_abs
*
* This method will get the next value from the current_addr and returns it via D1. The size
* (either word_size or long_size) should be passed on the stack.
*
* Stack Parameters:
* 1 (W): Size defined by either word_size or long_size
*
* Return Registers:
* D1 (W/L): The word or long value

    OFFSET 4
sub_get_next_abs_size    DS.W    1
    ORG *

sub_get_next_abs
    MOVE.W  sub_get_next_abs_size(SP),D1                * load size to D1
    MOVEA.L current_addr,A0                             * load current address to A0

    CMP.W   #long_size,D1                               * compare size to long
    BEQ     sub_get_next_abs_long                       * if it's a long advance
    MOVE.W  (A0)+,D1                                    * get next word
    BRA     sub_get_next_abs_adj                        * branch to return
sub_get_next_abs_long
    MOVE.L  (A0)+,D1                                    * get next long
sub_get_next_abs_adj
    MOVE.L  A0,current_addr                             * update the current address
    RTS

**************************************************************
*
* sub_build_direct_string
*
* This method is a convience method to output an address or data register to the output_string
* with a number found in the opcode. The first stack parameter should be the ea mode that will
* be used (NOTE: cannot be ea_abs) and the second parameter should be the starting bit position
* where the number can be found in the opcode. D0 should have the opcode string in it.
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
* sub_build_displacement
*
* This method takes a displacement offset, adds the value to the current address, and outputs it to
* the output_string. If the displacement value is #word_displace the next value word is taken
* and used to calculate the displacement address. This method returns nothing.
*
* Stack Parameters:
* 1 (W): Displacement offset
*
    OFFSET 4
sub_build_displacement_offset    DS.W   1
    ORG *

sub_build_displacement
    MOVE.L   current_addr,D7                        *Add our displacement to the address
    CLR.L   D1                                      *Clear out D1
    MOVE.W  sub_build_displacement_offset(SP),D0    *Get the displacement and put in D0
    CMP.W   #word_displace,D0                       *See if it's a word displacement
    BNE     sub_build_displacement_byte             *If it's not a word it's a byte

    MOVE.W  #word_size,-(SP)                        *Put word size onto the stack
    BSR     sub_get_next_abs                        *Get the next word or long to D1
    LEA     2(SP),SP                                *Reset the stack pointer
    EXT.L   D1                                      *Extend to a long
    BRA     sub_build_displacement_output
sub_build_displacement_byte
    MOVE.B  D0,D1                                   *Move byte to D0
    EXT.W   D1                                      *Extend to a word
    EXT.L   D1                                      *Then to a long
sub_build_displacement_output
    ADD.L   D7,D1
    MOVE.L  D1,-(SP)                                *Put the value on the stack
    MOVE.W  #false,-(SP)                            *Don't print the hex symbol
    MOVE.W  #word_size,-(SP)                        *Print the address as a word
    BSR     sub_build_hex_string
    LEA     8(SP),SP                                *Reset the stack
    RTS

**************************************************************
*
* sub_check_build_op
*
* This routine first grabs the 2 bits at the position specified in 'Bit position'. It then checks
* to see if each bit couple matches the provided definitions in 'Byte value', 'Word value', and
* 'Long value'. If it matches one of those it prints out the resulting character ('B', 'W', or 'L')
* and returns the size (byte_size, word_size, long_size) via D1. If it does not match any of the
* provided patterns, then it is considered to be invalid and the invalid_op_flag is set true and
* the method will return.
*
* Stack Parameters:
* 1 (W): Bit position for size
* 2 (W): Byte value
* 3 (W): Word value
* 4 (W): Long value
*
* The vaules should be specified as sets of two bits, e.g. %00 for byte %01 for word and %11 for long
*
* Register Parameters:
* 1 (L): D0 should contain the current op code that will be parsed
*
* Return
* 1 (W): Size of the operation as byte_size, word_size, or long_size

    OFFSET 4
sub_check_build_op_long_val    DS.W    1
sub_check_build_op_word_val    DS.W    1
sub_check_build_op_byte_val    DS.W    1
sub_check_build_op_position    DS.W    1
    ORG *

sub_check_build_op

    MOVE.W  sub_check_build_op_position(SP),D1          *Put the bit position in D1

    MOVE.W  D1,-(SP)                                    *Push bit position onto the stack
    MOVE.W  #2,-(SP)                                    *Size is determined by 2 bits so we'll put 2 on the stack
    BSR     sub_handy_mask                              *Get the 2 bits at that bit position to D1
    LEA     4(SP),SP                                    *Reset the stack pointer

    MOVEM.L D1,-(SP)                                    *Backup the value
    MOVE.W  #'.',-(SP)                                  *Push a period onto the stack
    BSR     sub_build_char                              *Put the period on the output string
    LEA     2(SP),SP                                    *Reset the stack pointer
    MOVEM.L (SP)+,D1                                    *Restore D1

    MOVE.W  sub_check_build_op_byte_val(SP),D5          *Get the byte value
    MOVE.W  sub_check_build_op_word_val(SP),D6          *Get the word value
    MOVE.W  sub_check_build_op_long_val(SP),D7          *Get the long value

    CMP.B   D5,D1                                       *See if the byte value matches the bit value
    BNE     sub_check_build_op_word                     *If not we'll see if it's a word
    MOVE.B  #'B',D3                                     *If it is we'll put 'B' in D3 for printing
    MOVE.W  #byte_size,D4                               *Set our size as byte size
    BRA     sub_check_build_op_print                    *Branch to print out
sub_check_build_op_word
    CMP.B   D6,D1                                       *See if we match the word definition
    BNE     sub_check_build_op_long                     *If not we'll check long
    MOVE.B  #'W',D3                                     *If so we'll put a 'W' in D3 for printing later
    MOVE.W  #word_size,D4                               *Set our size to word size
    BRA     sub_check_build_op_print                    *Go print it
sub_check_build_op_long
    CMP.B   D7,D1                                       *See if it is a word size
    BNE     sub_check_build_op_flag_invalid             *If not, then it is an invalid size
    MOVE.B  #'L',D3                                     *If so we'll push an 'L' to D3 for printing
    MOVE.W  #long_size,D4                               *Put long_size in D4
sub_check_build_op_print
    MOVE.W  D3,-(SP)                                    *Push the character (stored in D3) onto the stack
    BSR     sub_build_char                              *Build the char to the output string
    LEA     2(SP),SP                                    *Reset the stack pointer
sub_check_build_op_rts
    MOVE.W  D4,D1                                       *Move the size into D1 for returning
    RTS
sub_check_build_op_flag_invalid
    MOVE.B  #true,invalid_op_flag                       *Set the invalid op flag to true since the size was invalid
    BRA     sub_check_build_op_rts                      *Branch to the return



**************************************************************
*
* sub_check_ea_string
*
* This method takes an address to the valid modes, a starting bit location for the mode, a starting bit location
* for the register, and the size of the calling operand on the stack. This method will first verify that the current
* addressing mode is included in the list of available modes. If it is, the value is taken and the EA mode is output
* to the output string. If there is an error due to an invalid mode, the invalid_op_flag will be set true and the
* method will return. The value of the output_string may be incorrect and should be discarded.
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

    CMP.W   #ea_add_dir,D2                      *See if we are in address direct mode
    BNE     sub_check_ea_string_get_vals        *If not continue on
    CMP.W   #byte_size,D5                       *See if it's a byte size
    BNE     sub_check_ea_string_get_vals        *If not continue on

    BRA     sub_check_ea_string_not_found       *Address direct cannot be used with bytes

sub_check_ea_string_get_vals

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
    CMP.B   #ea_all,D1                          *Check if it accepts all modes
    BEQ     sub_check_ea_string_print           *If it does we'll jump straight to printing
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
* sub_build_string_comma_space
*
* This method puts a comma and then a space onto the output_string. It does not take
* any parameters and has no return.
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
* sub_tab
*
* This method will first find the next tab stop from the current output_string_displcament and then fill the
* output strings with spaces until it gets to that position. This acts as a flexible tab stop. This method
* takes no parameters and has no return values.
*
sub_tab
    MOVEA.L     #tab_stops,A0
    MOVEA.L     #output_string,A1                   *Load the output string
    MOVE.W      output_string_displacement,D1
    ADD.W       D1,A1
sub_tab_loop
    MOVE.B      (A0)+,D0                            *D0 contains the next tab position
    CMP.B       D1,D0                               *See if the displacement is past the tab
    BLE         sub_tab_loop                        *If the tab is less than the current displacement find the next tab
sub_tab_spc_loop
    CMP.B       D1,D0                               *See if the displacement is past the tab
    BLE         sub_tab_rts                         *If the tab is less than or equal to the displacement we are done
    MOVE.B      #' ',(A1)+                          *Push a space onto the output string
    ADDQ        #1,D1                               *Increment the displacement
    BRA         sub_tab_spc_loop                    *Add another space
sub_tab_rts
    MOVE.W      D1,output_string_displacement
    RTS

**************************************************************
*
* sub_handy_mask
*
* Given a value, lower bound, and size, this method will return the masked
* values starting from the LSB to D0 and return them through D1. This can be used
* to quickly get the values from a hex string.
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




******************************************************************************************************************************************
******************************************************************************************************************************************
********************************************************** CONSTANT DEFINITIONS **********************************************************
******************************************************************************************************************************************
******************************************************************************************************************************************




clear_screen                EQU     $FF00

true                        EQU     1
false                       EQU     0

word_displace               EQU     $00
long_displace               EQU     $FF

nibble_size                 EQU     0   *This representation cannot be used mathematically
byte_size                   EQU     1
word_size                   EQU     2
long_size                   EQU     4
no_size                     EQU     $F

right_nibble_mask           EQU     $000F
null                        EQU     0

cond_term                   EQU     $FFFF
op_code_term                EQU     $FFFF
op_codes_term               EQU     $0000

BS                          EQU     $8

*** ea modes ***

* These are the constants that define available EA modes. Their use is outlined in the Disassembler Documentation in the
* SDL section.

ea_reg_dir                  EQU     %000
ea_add_dir                  EQU     %001
ea_ari                      EQU     %010
ea_ari_post                 EQU     %011
ea_ari_pre                  EQU     %100

ea_abs                      EQU     %111    *This MUST preceed each ea_word,ea_long,ea_imm
ea_word                     EQU     %000    *Used in conjunction with ea_abs
ea_long                     EQU     %001    *Used in conjunction with ea_abs
ea_imm                      EQU     %100    *Used in conjunction with ea_abs

ea_term                     EQU     %1111   *Terminates a list of ea modes
ea_all                      EQU     %1110   *Declares that all ea modes are accepted

*** opf definitions ***

* These opf_ definitions are used to define opcode functionality. Their use is defined in the Disassembler Documentation
* in the SDL section.

opf_ea                      EQU     0
opf_count                   EQU     1
opf_reg                     EQU     2
opf_reg_add                 EQU     3
opf_count_reg               EQU     4
opf_imm                     EQU     5
opf_disp                    EQU     6
opf_sub                     EQU     7
opf_string                  EQU     8
opf_cond                    EQU     9
*opf_vector                 EQU     10 * not supported yet *
opf_flip                    EQU     11
opf_flipped                 EQU     12
opf_sizes                   EQU     13
opf_size                    EQU     14
opf_no_size                 EQU     15
opf_term                    EQU     16




******************************************************************************************************************************************
******************************************************************************************************************************************
*********************************************************** STORAGE AND GLOBALS **********************************************************
******************************************************************************************************************************************
******************************************************************************************************************************************




*** globals ***

* These are the global variables for the program

output_string               DS.B    120 *Used to build the output
output_string_displacement  DS.W    1   *Used to track the current location in the output string
current_addr                DS.L    1
current_addr_backup         DS.L    1
end_addr                    DS.L    1
invalid_op_flag             DS.B    1
input                       DS.B    80  *Allocated dead space to store input values

*** strings ***

* These strings are used for output and other tasks

hex_characters              DC.B    '0123456789ABCDEF'  *Used to build hex strings. Do not change.
string_press_enter          DC.B    'Press enter to continue...',0
string_end                  DC.B    'Reached end address. Program halted.',0
string_invalid_size         DC.B    'Address too large!',0
string_invalid_hex          DC.B    'Not a valid hex value!',0
string_enter_start          DC.B    'Enter a starting hex address: ',0
string_enter_stop           DC.B    'Enter a stopping hex address: ',0
string_data                 DC.B    'DATA',0

* These strings should not be changed and are used to build opcode labels for conditions

cond_t                      DC.B    'T',0
cond_f                      DC.B    'F',0
cond_hi                     DC.B    'HI',0
cond_ls                     DC.B    'LS',0
cond_cc                     DC.B    'CC',0
cond_cs                     DC.B    'CS',0
cond_ne                     DC.B    'NE',0
cond_eq                     DC.B    'EQ',0
cond_vc                     DC.B    'VC',0
cond_vs                     DC.B    'VS',0
cond_pl                     DC.B    'PL',0
cond_mi                     DC.B    'MI',0
cond_ge                     DC.B    'GE',0
cond_lt                     DC.B    'LT',0
cond_gt                     DC.B    'GT',0
cond_le                     DC.B    'LE',0

*** settings ***

* Tab stops can be changed here to modify how things are output to the string.

tab_stops                   DC.B    12,24,36

*** condition definitions ***

* These condition definitions are used to output the cc labels

conditions                  DC.W    %0000,cond_t,%0001,cond_f
* stf (no true false) allows skipping of true and false
conditions_stf              DC.W    %0010,cond_hi,%0011,cond_ls,%0100,cond_cc,%0101,cond_cs,%0110,cond_ne,%0111,cond_eq,%1000,cond_vc
                            DC.W    %1001,cond_vs,%1010,cond_pl,%1011,cond_mi,%1100,cond_ge,%1101,cond_lt,%1110,cond_gt,%1111,cond_le,cond_term




******************************************************************************************************************************************
******************************************************************************************************************************************
************************************************************ OPCODE DEFINITIONS **********************************************************
******************************************************************************************************************************************
******************************************************************************************************************************************


*** opcode array ***

* All opcodes that should be checked should be in this array. The order is not important. Whenever a new opcode is defined, it should be
* placed here so that it is processed.

op_codes        DC.W    op_code_movem,op_code_adda,op_code_add,op_code_eor,op_code_divs,op_code_lea,op_code_nop,op_code_movea
                DC.W    op_code_move,op_code_neg,op_code_ori,op_code_cmpi,op_code_rts,op_code_bclr2
                DC.W    op_code_jsr,op_code_subq,op_code_or,op_code_sub,op_code_cmp,op_code_muls,op_code_bcc
                DC.W    op_code_aslm,op_code_lsrm,op_code_lslm,op_code_rolm,op_code_rorm,op_code_asr,op_code_asl,op_code_rol
                DC.W    op_code_asrm,op_code_ror,op_code_lsr,op_code_lsl,op_code_bra,op_code_bclr
op_codes_extra  DC.W    op_code_unlk,op_code_tst,op_code_tas,op_code_swap,op_code_subi,op_code_suba,op_code_rtr,op_code_pea
                DC.W    op_code_not,op_code_negx,op_code_nbcd,op_code_mulu,op_code_movesr,op_code_moveccr,op_code_jmp
                DC.W    op_code_illegal,op_code_eori,op_code_divu,op_code_cmpm,op_code_cmpa,op_code_clr,op_code_chk,op_code_bsr
                DC.W    op_code_scc,op_code_andi,op_code_andi_ccr,op_code_and,op_code_addq,op_code_addi,op_code_moveq,0

*** opcode definitions ***

* Each opcode below defines an opcodes operation. The definition syntax is defined in the Disassembler Documentation in the SDL section.

op_ea_all           DC.B    ea_all
op_ea_dest_std      DC.B    ea_reg_dir,ea_ari,ea_ari_post,ea_ari_pre,ea_abs,ea_word,ea_abs,ea_long,ea_term
op_ea_no_dir_imm    DC.B    ea_ari,ea_ari_post,ea_ari_pre,ea_abs,ea_word,ea_abs,ea_long,ea_term 


op_string_lea   DC.B    'LEA',0
op_code_lea     DC.W    $41C0,$F1C0,op_def_lea,op_code_term
op_ea_lea_src   DC.B    ea_ari,ea_abs,ea_word,ea_abs,ea_long,ea_term
op_def_lea      DC.W    op_string_lea,opf_size,long_size,opf_ea,op_ea_lea_src,3,0,opf_reg,9,ea_add_dir,opf_term

op_string_eor   DC.B    'EOR',0
op_code_eor     DC.W    $B100,$F100,op_def_eor,op_code_term
op_def_eor      DC.W    op_string_eor,opf_sizes,6,%00,%01,%10,opf_reg,9,ea_reg_dir,opf_ea,op_ea_dest_std,3,0,opf_term

op_string_or    DC.B   'OR',0
op_code_or      DC.W    $8000,$F000,op_def_or,op_code_term
op_ea_or_src    DC.B    ea_reg_dir,ea_ari,ea_ari_post,ea_ari_pre,ea_abs,ea_word,ea_abs,ea_long,ea_abs,ea_imm,ea_term
op_ea_or_dest   DC.B    ea_ari,ea_ari_post,ea_ari_pre,ea_abs,ea_word,ea_abs,ea_long,ea_term
op_def_or       DC.W    op_string_or,opf_sizes,6,%00,%01,%10,opf_flip,8,opf_ea,op_ea_or_src,3,0,opf_reg,9,ea_reg_dir,opf_flipped,opf_reg,9,ea_reg_dir,opf_ea,op_ea_or_dest,3,0,opf_term

op_string_nop   DC.B    'NOP',0
op_code_nop     DC.W    $4E71,$FFFF,op_def_nop,op_code_term
op_def_nop      DC.W    op_string_nop,opf_term

op_string_adda  DC.B    'ADDA',0
op_code_adda    DC.W    $D0C0,$F0C0,op_def_adda,op_code_term
op_def_adda     DC.W    op_string_adda,opf_sizes,7,no_size,%01,%11,opf_ea,op_ea_all,3,0,opf_reg,9,ea_add_dir,opf_term

op_string_movea DC.B    'MOVEA',0
op_code_movea   DC.W    $2040,$E1C0,op_def_movea,op_code_term
op_def_movea    DC.W    op_string_movea,opf_sizes,12,no_size,%11,%10,opf_ea,op_ea_all,3,0,opf_reg,9,ea_add_dir,opf_term

op_string_move  DC.B    'MOVE',0
op_code_move    DC.W    $0000,$C000,op_def_move,op_code_term
op_def_move     DC.W    op_string_move,opf_sizes,12,%01,%11,%10,opf_ea,op_ea_all,3,0,opf_ea,op_ea_dest_std,6,9,opf_term

op_string_neg   DC.B    'NEG',0
op_code_neg     DC.W    $4400,$FF00,op_def_neg,op_code_term
op_def_neg      DC.W    op_string_neg,opf_sizes,6,%00,%01,%10,opf_ea,op_ea_dest_std,3,0,opf_term

op_string_ori   DC.B    'ORI',0
op_code_ori     DC.W    $0000,$FF00,op_def_ori,op_code_term
op_def_ori      DC.W    op_string_ori,opf_sizes,6,%00,%01,%10,opf_imm,opf_ea,op_ea_dest_std,3,0,opf_term

op_string_cmpi  DC.B    'CMPI',0
op_code_cmpi    DC.W    $0C00,$FF00,op_def_cmpi,op_code_term
op_def_cmpi     DC.W    op_string_cmpi,opf_sizes,6,%00,%01,%10,opf_imm,opf_ea,op_ea_dest_std,3,0,opf_term

op_string_rts   DC.B    'RTS',0
op_code_rts     DC.W    $4E75,$FFFF,op_def_rts,op_code_term
op_def_rts      DC.W    op_string_rts,opf_term

op_string_jsr   DC.B    'JSR',0
op_code_jsr     DC.W    $4E80,$FFC0,op_def_jsr,op_code_term
op_ea_jsr_dest  DC.B    ea_ari,ea_abs,ea_word,ea_abs,ea_long,ea_term
op_def_jsr      DC.W    op_string_jsr,opf_no_size,opf_ea,op_ea_jsr_dest,3,0,opf_term

op_string_subq  DC.B    'SUBQ',0
op_code_subq    DC.W    $5100,$F100,op_def_subq,op_code_term
op_ea_subq_dest DC.B    ea_reg_dir,ea_add_dir,ea_ari,ea_ari_post,ea_ari_pre,ea_abs,ea_word,ea_abs,ea_long,ea_term
op_def_subq     DC.W    op_string_subq,opf_sizes,6,%00,%01,%10,opf_count,9,opf_ea,op_ea_subq_dest,3,0,opf_term

op_string_divs  DC.B    'DIVS',0
op_code_divs    DC.W    $81C0,$F1C0,op_def_divs,op_code_term
op_ea_divs_src  DC.B    ea_reg_dir,ea_ari,ea_ari_post,ea_ari_pre,ea_abs,ea_word,ea_abs,ea_long,ea_abs,ea_imm,ea_term
op_def_divs     DC.W    op_string_divs,opf_size,word_size,opf_ea,op_ea_divs_src,3,0,opf_reg,9,ea_reg_dir,opf_term

op_string_sub   DC.B    'SUB',0
op_code_sub     DC.W    $9000,$F000,op_def_sub,op_code_term
op_def_sub      DC.W    op_string_sub,opf_sizes,6,%00,%01,%10,opf_flip,8,opf_ea,op_ea_all,3,0,opf_reg,9,ea_reg_dir,opf_flipped
op_def_sub_flip DC.W    opf_reg,9,ea_reg_dir,opf_ea,op_ea_no_dir_imm,3,0,opf_term

op_string_cmp   DC.B    'CMP',0
op_code_cmp     DC.W    $B000,$F100,op_def_cmp,op_code_term
op_def_cmp      DC.W    op_string_cmp,opf_sizes,6,%00,%01,%10,opf_ea,op_ea_all,3,0,opf_reg,9,ea_reg_dir,opf_term

op_string_muls  DC.B    'MULS',0
op_code_muls    DC.W    $C1C0,$F1C0,op_def_muls,op_code_term
op_ea_muls_src  DC.B    ea_reg_dir,ea_ari,ea_ari_post,ea_ari_pre,ea_abs,ea_word,ea_abs,ea_long,ea_abs,ea_imm,ea_term
op_def_muls     DC.W    op_string_muls,opf_size,word_size,opf_ea,op_ea_muls_src,3,0,opf_reg,9,ea_reg_dir,opf_term

op_string_add   DC.B    'ADD',0
op_code_add     DC.W    $D000,$F000,op_def_add,op_code_term
op_def_add      DC.W    op_string_add,opf_sizes,6,%00,%01,%10,opf_flip,8,opf_ea,op_ea_all,3,0,opf_reg,9,ea_reg_dir,opf_flipped
op_def_add_flip DC.W    opf_reg,9,ea_reg_dir,opf_ea,op_ea_no_dir_imm,3,0,opf_term

op_string_asr   DC.B    'ASR',0
op_code_asr     DC.W    $E000,$F118,op_def_asr,op_code_term
op_def_asr      DC.W    op_string_asr,opf_sizes,6,%00,%01,%10,opf_count_reg,5,9,ea_reg_dir,opf_reg,0,ea_reg_dir,opf_term
*** Opcodes for ASR operate differently for memory ***
op_code_asrm    DC.W    $E0C0,$FFC0,op_def_asrm,op_code_term
op_def_asrm     DC.W    op_string_asr,opf_size,word_size,opf_ea,op_ea_no_dir_imm,3,0,opf_term

op_string_asl   DC.B    'ASL',0
op_code_asl     DC.W    $E100,$F118,op_def_asl,op_code_term
op_def_asl      DC.W    op_string_asl,opf_sizes,6,%00,%01,%10,opf_count_reg,5,9,ea_reg_dir,opf_reg,0,ea_reg_dir,opf_term
*** Opcodes for ASL operate differently for memory ***
op_code_aslm    DC.W    $E1C0,$FFC0,op_def_aslm,op_code_term
op_def_aslm     DC.W    op_string_asl,opf_size,word_size,opf_ea,op_ea_no_dir_imm,3,0,opf_term

op_string_ror   DC.B    'ROR',0
op_code_ror     DC.W    $E018,$F118,op_def_ror,op_code_term
op_def_ror      DC.W    op_string_ror,opf_sizes,6,%00,%01,%10,opf_count_reg,5,9,ea_reg_dir,opf_reg,0,ea_reg_dir,opf_term
*** Opcodes for ROR operate differently for memory ***
op_code_rorm    DC.W    $E6C0,$FFC0,op_def_rorm,op_code_term
op_def_rorm     DC.W    op_string_ror,opf_size,word_size,opf_ea,op_ea_no_dir_imm,3,0,opf_term

op_string_rol   DC.B    'ROL',0
op_code_rol     DC.W    $E118,$F118,op_def_rol,op_code_term
op_def_rol      DC.W    op_string_rol,opf_sizes,6,%00,%01,%10,opf_count_reg,5,9,ea_reg_dir,opf_reg,0,ea_reg_dir,opf_term
*** Opcodes for ROL operate differently for memory ***
op_code_rolm    DC.W    $E7C0,$FFC0,op_def_rolm,op_code_term
op_def_rolm     DC.W    op_string_rol,opf_size,word_size,opf_ea,op_ea_no_dir_imm,3,0,opf_term

op_string_lsr   DC.B    'LSR',0
op_code_lsr     DC.W    $E008,$F118,op_def_lsr,op_code_term
op_def_lsr      DC.W    op_string_lsr,opf_sizes,6,%00,%01,%10,opf_count_reg,5,9,ea_reg_dir,opf_reg,0,ea_reg_dir,opf_term
*** Opcodes for LSR operate differently for memory ***
op_code_lsrm    DC.W    $E2C0,$FFC0,op_def_lsrm,op_code_term
op_def_lsrm     DC.W    op_string_lsr,opf_size,word_size,opf_ea,op_ea_no_dir_imm,3,0,opf_term

op_string_lsl   DC.B    'LSL',0
op_code_lsl     DC.W    $E108,$F118,op_def_lsl,op_code_term
op_def_lsl      DC.W    op_string_lsl,opf_sizes,6,%00,%01,%10,opf_count_reg,5,9,ea_reg_dir,opf_reg,0,ea_reg_dir,opf_term
*** Opcodes for LSL operate differently for memory ***
op_code_lslm    DC.W    $E3C0,$FFC0,op_def_lslm,op_code_term
op_def_lslm     DC.W    op_string_lsl,opf_size,word_size,opf_ea,op_ea_no_dir_imm,3,0,opf_term

op_string_bra   DC.B    'BRA',0
op_code_bra     DC.W    $6000,$FF00,op_def_bra,op_code_term
op_def_bra      DC.W    op_string_bra,opf_no_size,opf_disp,opf_term

op_string_bcc   DC.B    'B',0
op_code_bcc     DC.W    $6000,$F000,op_def_bcc,op_code_term
op_def_bcc      DC.W    op_string_bcc,opf_cond,8,false,opf_no_size,opf_disp,opf_term


op_string_bclr  DC.B    'BCLR',0

op_code_bclr    DC.W    $0180,$F1C0,op_def_bclrL,op_def_bclrB,op_code_term
op_ea_bclrL     DC.B    ea_reg_dir,ea_term                                                      *Long mode can only be data reg direct
op_def_bclrL    DC.W    op_string_bclr,opf_size,long_size,opf_reg,9,ea_reg_dir,opf_ea,op_ea_bclrL,3,0,opf_term
op_def_bclrB    DC.W    op_string_bclr,opf_size,byte_size,opf_reg,9,ea_reg_dir,opf_ea,op_ea_no_dir_imm,3,0,opf_term

* Seperate code for BCLR with immediate data
op_code_bclr2   DC.W    $0880,$FFC0,op_def_bclrL2,op_def_bclrB2,op_code_term
op_def_bclrL2   DC.W    op_string_bclr,opf_size,long_size,opf_sub,sub_op_bclr,opf_ea,op_ea_bclrL,3,0,opf_term
op_def_bclrB2   DC.W    op_string_bclr,opf_size,byte_size,opf_sub,sub_op_bclr,opf_ea,op_ea_no_dir_imm,3,0,opf_term

sub_op_bclr
    MOVE.W      #'#',-(SP)              *Push the pound sign to the stack
    BSR         sub_build_char          *Output the hex
    LEA         2(SP),SP                *Reset the stack

    MOVE.W      #word_size,-(SP)        *We need the word
    BSR         sub_get_next_abs        *Get the next absolute to D1
    LEA         2(SP),SP                *Reset the pointer

    MOVE.L      D1,D0                   *Put the value in D0 for handy mask
    MOVE.W      #0,-(SP)                *We want the byte at index 0
    MOVE.W      #8,-(SP)                *And we want the whole byte
    BSR         sub_handy_mask          *Get the value to D1
    LEA         4(SP),SP                *Reset the stack pointer

    MOVE.L      D1,-(SP)                *Put the number on the stack
    MOVE.W      #true,-(SP)             *We want it to print the boolean
    MOVE.W      #byte_size,-(SP)        *It will always be a byte
    BSR         sub_build_hex_string    *Build the string
    LEA         8(SP),SP                *Reset the stack pointer

    RTS


op_string_movem DC.B    'MOVEM',0
op_code_movem   DC.W    $4880,$FB80,op_def_movem,op_code_term
op_ea_movem_rtm DC.B    ea_ari,ea_ari_pre,ea_abs,ea_word,ea_abs,ea_long,ea_term
op_ea_movem_mtr DC.B    ea_ari,ea_ari_post,ea_abs,ea_word,ea_abs,ea_long,ea_term
op_def_movem    DC.W    op_string_movem,opf_sizes,6,no_size,%10,%11,opf_flip,10,opf_sub,sub_op_movem_rev,opf_ea,op_ea_movem_rtm,3,0
op_def_movemf   DC.W    opf_flipped,opf_ea,op_ea_movem_mtr,3,0,opf_sub,sub_op_movem_reg,opf_term

sub_op_movem_reg
    MOVE.B      #false,D7
    BRA         sub_op_movem
sub_op_movem_rev
    MOVE.B      #true,D7                *D7 deterimines if this should operate in reverse
sub_op_movem
    MOVE.B      #ea_reg_dir,D6          *Start data register mode
    MOVE.W      #word_size,-(SP)        *We want the word
    BSR         sub_get_next_abs        *Get the next word to D1
    LEA         2(SP),SP                *Reset the stack pointer
    CLR.B       D2                      *Clear D2 to use as a counter
sub_op_movem_loop
    CMP.B       #16,D2                  *See if we are done going through the registers
    BGE         sub_op_movem_rts        *If we are done return control
    CMP.B       #false,D7               *Check the direction
    BNE         sub_op_movem_loop_lsl   *Go left
    LSR.W       #1,D1                   *Push off the right
    BRA         sub_op_movem_loop_output  *Start loop
sub_op_movem_loop_lsl
    LSL.W       #1,D1                   *Shift left
sub_op_movem_loop_output
    BCC         sub_op_movem_chk        *See if the bit that was shifted off was set
    MOVE.L      D2,D3                   *Copy the counter
    DIVU        #8,D3                   *Mod it with 8 to get the reg number
    SWAP        D3                      *Swap it to put the mod in the right word
    MOVEM.L     D0/D1/D2/D3/D6/D7,-(SP) *Backup registers
    MOVE.W      D6,-(SP)                *Push the register mode onto the stack
    MOVE.W      D3,-(SP)                *Push the register number on
    MOVE.W      #no_size,-(SP)          *We don't care about the size for these modes
    BSR         sub_build_ea_string     *Build the register
    LEA         6(SP),SP                *Reset the pointer
    MOVEM.L     (SP)+,D0/D1/D2/D3/D6/D7 *Restore the registers
    MOVEM.L     D0/D1/D2/D3/D6/D7,-(SP) *Backup the registers
    MOVE.W      #'/',-(SP)              *Move the slash on
    BSR         sub_build_char          *Build it
    LEA         2(SP),SP                *Reset the pointer
    MOVEM.L     (SP)+,D0/D1/D2/D3/D6/D7 *Restore the registers
sub_op_movem_chk
    CMP.B       #7,D2                   *See if we need to switch to address mode
    BNE         sub_op_movem_inc        *If not we'll increment and continue
    MOVE.W      #ea_add_dir,D6          *Set the mode to address mode
sub_op_movem_inc
    ADDQ.B      #1,D2                   *Increment the counter
    BRA         sub_op_movem_loop       *Branch back to the loop
sub_op_movem_rts
    MOVE.W      #BS,-(SP)               *Request a backspace (we need to solve the fence post problem with the '/'s)
    BSR         sub_build_char          *Go back
    LEA         2(SP),SP                *Restore the pointers
    RTS

*** extra definitions ***

* the following definitions go beyond the required scope of the project

op_string_unlk      DC.B    'UNLK',0
op_code_unlk        DC.W    $4E58,$FFF8,op_def_unlk,op_code_term
op_def_unlk         DC.W    op_string_unlk,opf_no_size,opf_reg,0,ea_add_dir,opf_term

op_string_tst       DC.B    'TST',0
op_code_tst         DC.W    $4A00,$FF00,op_def_tst,op_code_term
op_ea_tst_dest      DC.B    ea_reg_dir,ea_ari,ea_ari_pre,ea_ari_post,ea_abs,ea_word,ea_abs,ea_long,ea_term
op_def_tst          DC.W    op_string_tst,opf_sizes,6,%00,%01,%10,opf_ea,op_ea_tst_dest,3,0,opf_term

op_string_tas       DC.B    'TAS',0
op_code_tas         DC.W    $4AC0,$FFC0,op_def_tas,op_code_term
op_ea_tas           DC.B    ea_reg_dir,ea_ari,ea_ari_pre,ea_ari_post,ea_abs,ea_word,ea_abs,ea_long,ea_term
op_def_tas          DC.W    op_string_tas,opf_size,byte_size,opf_ea,op_ea_tas,3,0,opf_term

op_string_swap      DC.B    'SWAP',0
op_code_swap        DC.W    $4840,$FFF8,op_def_swap,op_code_term
op_def_swap         DC.W    op_string_swap,opf_size,word_size,opf_reg,0,ea_reg_dir,opf_term

op_string_subi      DC.B    'SUBI',0
op_code_subi        DC.W    $0400,$FF00,op_def_subi,op_code_term
op_ea_subi          DC.B    ea_reg_dir,ea_ari,ea_ari_pre,ea_ari_post,ea_abs,ea_word,ea_abs,ea_long,ea_term
op_def_subi         DC.W    op_string_subi,opf_sizes,6,%00,%01,%10,opf_imm,opf_ea,op_ea_subi,3,0,opf_term

op_string_suba      DC.B    'SUBA',0
op_code_suba        DC.W    $90C0,$F0C0,op_def_suba,op_code_term
op_ea_suba_src      DC.B    ea_all
op_def_suba         DC.W    op_string_suba,opf_sizes,7,no_size,%01,%11,opf_ea,op_ea_suba_src,3,0,opf_reg,9,ea_add_dir,opf_term

op_string_rtr       DC.B    'RTR',0
op_code_rtr         DC.W    $4E77,$FFFF,op_def_rtr,op_code_term
op_def_rtr          DC.W    op_string_rtr,opf_no_size,opf_term

op_string_pea       DC.B    'PEA',0
op_code_pea         DC.W    $4840,$FFC0,op_def_pea,op_code_term
op_ea_pea           DC.B    ea_ari,ea_abs,ea_word,ea_abs,ea_long,ea_term
op_def_pea          DC.W    op_string_pea,opf_size,long_size,opf_ea,op_ea_pea,3,0,opf_term

op_string_not       DC.B    'NOT',0
op_code_not         DC.W    $4600,$FF00,op_def_not,op_code_term
op_ea_not           DC.B    ea_reg_dir,ea_ari,ea_ari_post,ea_ari_pre,ea_abs,ea_word,ea_abs,ea_long,ea_term
op_def_not          DC.W    op_string_not,opf_sizes,6,%00,%01,%10,opf_ea,op_ea_not,3,0,opf_term

op_string_negx      DC.B    'NEGX',0
op_code_negx        DC.W    $4000,$FF00,op_def_negx,op_code_term
op_ea_negx          DC.B    ea_reg_dir,ea_ari,ea_ari_pre,ea_ari_post,ea_abs,ea_word,ea_abs,ea_long,ea_term
op_def_negx         DC.W    op_string_negx,opf_sizes,6,%00,%01,%10,opf_ea,op_ea_negx,3,0,opf_term

op_string_nbcd      DC.B    'NBCD',0
op_code_nbcd        DC.W    $4800,$FFC0,op_def_nbcd,op_code_term
op_ea_nbcd          DC.B    ea_reg_dir,ea_ari,ea_ari_pre,ea_ari_post,ea_abs,ea_word,ea_abs,ea_long,ea_term
op_def_nbcd         DC.W    op_string_nbcd,opf_size,byte_size,opf_ea,op_ea_nbcd,3,0,opf_term

op_string_mulu      DC.B    'MULU',0
op_code_mulu        DC.W    $C0C0,$F1C0,op_def_mulu,op_code_term
op_ea_mulu          DC.B    ea_reg_dir,ea_ari,ea_ari_pre,ea_ari_post,ea_abs,ea_word,ea_abs,ea_long,ea_abs,ea_imm,ea_term
op_def_mulu         DC.W    op_string_mulu,opf_size,word_size,opf_ea,op_ea_mulu,3,0,opf_reg,9,ea_reg_dir,opf_term

op_string_movesr    DC.B    'MOVE',0
op_string_sr        DC.B    'SR',0
op_code_movesr      DC.W    $40C0,$FFC0,op_def_movesr,op_code_term
op_ea_movesr        DC.B    ea_reg_dir,ea_ari,ea_ari_pre,ea_ari_post,ea_abs,ea_word,ea_abs,ea_long,ea_term
op_def_movesr       DC.W    op_string_movesr,opf_size,word_size,opf_string,op_string_sr,opf_ea,op_ea_movesr,3,0,opf_term

op_string_moveccr   DC.B    'MOVE',0
op_string_ccr       DC.B    'CCR',0
op_code_moveccr     DC.W    $44C0,$FFC0,op_def_moveccr,op_code_term
op_ea_moveccr       DC.B    ea_reg_dir,ea_ari,ea_ari_pre,ea_ari_post,ea_abs,ea_word,ea_abs,ea_long,ea_abs,ea_imm,ea_term
op_def_moveccr      DC.W    op_string_moveccr,opf_size,word_size,opf_ea,op_ea_moveccr,3,0,opf_string,op_string_ccr,opf_term

op_string_jmp       DC.B    'JMP',0
op_code_jmp         DC.W    $4EC0,$FFC0,op_def_jmp,op_code_term
op_ea_jmp           DC.B    ea_ari,ea_abs,ea_word,ea_abs,ea_long,ea_term
op_def_jmp          DC.W    op_string_jmp,opf_no_size,opf_ea,op_ea_jmp,3,0,opf_term

op_string_illegal   DC.B    'ILLEGAL',0
op_code_illegal     DC.W    $4AFC,$FFFF,op_def_illegal,op_code_term
op_def_illegal      DC.W    op_string_illegal,opf_term

op_string_eori      DC.B    'EORI',0
op_code_eori        DC.W    $0A00,$FF00,op_def_eori,op_code_term
op_ea_eori          DC.B    ea_reg_dir,ea_ari,ea_ari_pre,ea_ari_post,ea_abs,ea_word,ea_abs,ea_long,ea_term
op_def_eori         DC.W    op_string_eori,opf_sizes,6,%00,%01,%10,opf_imm,opf_ea,op_ea_eori,3,0,opf_term

op_string_divu      DC.B    'DIVU',0
op_code_divu        DC.W    $80C0,$F1C0,op_def_divu,op_code_term
op_ea_divu          DC.B    ea_reg_dir,ea_ari,ea_ari_pre,ea_ari_post,ea_abs,ea_word,ea_abs,ea_long,ea_abs,ea_imm,ea_term
op_def_divu         DC.W    op_string_divu,opf_size,word_size,opf_ea,op_ea_divu,3,0,opf_reg,9,ea_reg_dir,opf_term

op_string_cmpm      DC.B    'CMPM',0
op_code_cmpm        DC.W    $B108,$F138,op_def_cmpm,op_code_term
op_def_cmpm         DC.W    op_string_cmpm,opf_sizes,6,%00,%01,%10,opf_reg,0,ea_ari_post,opf_reg,9,ea_ari_post,opf_term

op_string_cmpa      DC.B    'CMPA',0
op_code_cmpa        DC.W    $B0C0,$F0C0,op_def_cmpa,op_code_term
op_ea_cmpa          DC.B    ea_all
op_def_cmpa         DC.W    op_string_cmpa,opf_sizes,7,no_size,%01,%11,opf_ea,op_ea_cmpa,3,0,opf_reg,9,ea_add_dir,opf_term

op_string_clr       DC.B    'CLR',0
op_code_clr         DC.W    $4200,$FF00,op_def_clr,op_code_term
op_ea_clr           DC.B    ea_reg_dir,ea_ari,ea_ari_pre,ea_ari_post,ea_abs,ea_word,ea_abs,ea_long,ea_term
op_def_clr          DC.W    op_string_clr,opf_sizes,6,%00,%01,%10,opf_ea,op_ea_clr,3,0,opf_term

op_string_chk       DC.B    'CHK',0
op_code_chk         DC.W    $4100,$F140,op_def_chk,op_code_term
op_ea_chk           DC.B    ea_reg_dir,ea_ari,ea_ari_pre,ea_ari_post,ea_abs,ea_word,ea_abs,ea_long,ea_abs,ea_imm,ea_term
op_def_chk          DC.W    op_string_chk,opf_size,word_size,opf_ea,op_ea_chk,3,0,opf_reg,9,ea_reg_dir,opf_term

op_string_bsr       DC.B    'BSR',0
op_code_bsr         DC.W    $6100,$FF00,op_def_bsr,op_code_term
op_def_bsr          DC.W    op_string_bsr,opf_no_size,opf_disp,opf_term

op_string_scc       DC.B    'S',0
op_code_scc         DC.W    $50C0,$F0C0,op_def_scc,op_code_term
op_ea_scc           DC.B    ea_reg_dir,ea_ari,ea_ari_pre,ea_ari_post,ea_abs,ea_word,ea_abs,ea_long,ea_term
op_def_scc          DC.W    op_string_scc,opf_cond,8,true,opf_no_size,opf_ea,op_ea_scc,3,0,opf_term

op_string_andi      DC.B    'ANDI',0
op_code_andi        DC.W    $0200,$FF00,op_def_andi,op_code_term
op_ea_andi          DC.B    ea_reg_dir,ea_ari,ea_ari_pre,ea_ari_post,ea_abs,ea_word,ea_abs,ea_long,ea_term
op_def_andi         DC.W    op_string_andi,opf_sizes,6,%00,%01,%10,opf_imm,opf_ea,op_ea_andi,3,0,opf_term

op_string_andi_ccr  DC.B    'CCR',0
op_code_andi_ccr    DC.W    $023C,$FFFF,op_def_andi_ccr,op_code_term
op_def_andi_ccr     DC.W    op_string_andi,opf_size,byte_size,opf_imm,opf_string,op_string_andi_ccr,opf_term

op_string_and       DC.B    'AND',0
op_code_and         DC.W    $C000,$F000,op_def_and,op_code_term
op_ea_and_src       DC.B    ea_reg_dir,ea_ari,ea_ari_pre,ea_ari_post,ea_abs,ea_word,ea_abs,ea_long,ea_abs,ea_imm,ea_term
op_ea_and_dest      DC.B    ea_ari,ea_ari_pre,ea_ari_post,ea_abs,ea_word,ea_abs,ea_long,ea_term
op_def_and          DC.W    op_string_and,opf_sizes,6,%00,%01,%10,opf_flip,8,opf_ea,op_ea_and_src,3,0,opf_reg,9,ea_reg_dir,opf_flipped
op_def_and_flipped  DC.W    opf_reg,9,ea_reg_dir,opf_ea,op_ea_and_dest,3,0,opf_term

op_string_addq      DC.B    'ADDQ',0
op_code_addq        DC.W    $5000,$F100,op_def_addq,op_code_term
op_ea_addq          DC.B    ea_add_dir,ea_reg_dir,ea_ari,ea_ari_pre,ea_ari_post,ea_abs,ea_word,ea_abs,ea_long,ea_term
op_def_addq         DC.W    op_string_addq,opf_sizes,6,%00,%01,%10,opf_count,9,opf_ea,op_ea_addq,3,0,opf_term

op_string_addi      DC.B    'ADDI',0
op_code_addi        DC.W    $0600,$FF00,op_def_addi,op_code_term
op_ea_addi          DC.B    ea_reg_dir,ea_ari,ea_ari_pre,ea_ari_post,ea_abs,ea_word,ea_abs,ea_long,ea_term
op_def_addi         DC.W    op_string_addi,opf_sizes,6,%00,%01,%10,opf_imm,opf_ea,op_ea_addi,3,0,opf_term

op_string_moveq     DC.B    'MOVEQ',0
op_code_moveq       DC.W    $7000,$F100,op_def_moveq,op_code_term
op_def_moveq        DC.W    op_string_moveq,opf_size,long_size,opf_sub,sub_op_moveq,opf_reg,9,ea_reg_dir,opf_term

sub_op_moveq
    MOVE.W          #0,-(SP)                *We want the byte at bit 0
    MOVE.W          #8,-(SP)                *We want a byte
    BSR             sub_handy_mask          *Mask the value to d1
    LEA             4(SP),SP                *Reset the stack pointer

    MOVEM.L         D1,-(SP)                *Backup the registers
    MOVE.W          #'#',-(SP)              *Put a pound sign on for immediate
    BSR             sub_build_char          *Build it
    LEA             2(SP),SP                *Reset the stack
    MOVEM.L         (SP)+,D1                *Restore the registers

    MOVE.L          D1,-(SP)                *Put the value on the stack
    MOVE.W          #true,-(SP)             *We want a hex sign
    MOVE.W          #byte_size,-(SP)        *We want to print a byte
    BSR             sub_build_hex_string    *Build it
    LEA             8(SP),SP                *Reset the stack pointer

    RTS

******************************************************************************************************************************************
******************************************************************************************************************************************
************************************************************* END OF PROGRAM *************************************************************
******************************************************************************************************************************************
******************************************************************************************************************************************

    END    START








*~Font name~Courier New~
*~Font size~12~
*~Tab type~1~
*~Tab size~4~
