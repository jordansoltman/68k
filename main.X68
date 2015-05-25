*-----------------------------------------------------------
* Title      :
* Written by :
* Date       :
* Description:
*-----------------------------------------------------------

    ORG    $1000

srt_addr  EQU     $3000
end_addr  EQU     $3040

START
    MOVE.L  #srt_addr,current_addr              *Load the starting address
LOOP
    MOVE.L  current_addr,current_addr_backup    *Creates a backup of the address
    MOVEA.L current_addr,A0                     *Load the current address to A0

    CMP.L   #end_addr,A0                        *See if we are at the end address
    BGE     DONE                                *If so branch to done

    CLR.W   output_string_displacement          *Reset the string displacement so we can write again
    CLR.B   invalid_op_flag                     *Clear the invalid flag for the new opcode

    MOVE.W  (A0)+,D0                            *Move the opcode (or data) to D0 for processing
    MOVE.L  A0,current_addr                     *Update the current address to reflect the change

    MOVEM.L D0/A0,-(SP)                         *Save D0
    BSR     sub_build_current_line_address      *Print out the current line
    MOVEM.L (SP)+,D0/A0                         *Restore D0

    MOVE.W  #op_codes,A1                        *Move the starting address for the opcodes to A1

LOOP_OPCODES                                    *Begin to loop through the opcodes using A1

    MOVEA.W (A1)+,A2

    CMP.L   #0,A2                               *Check to see if we are at the end of the opcodes list
    BEQ     OUTPUT_DATA                          *If so we'll print data

    MOVE.W  (A2)+,D2                            *Get the value
    MOVE.W  (A2)+,D1                            *Get the mask

    AND.W   D0,D1                               *Mask the opcode value
    CMP.W   D1,D2                               *See if it's a match

    BNE     LOOP_OPCODES

    MOVE.W  (A2)+,A2

    PEA     (A2)
    BSR     sub_process_opcode
    LEA     4(SP),SP

    CMP.B   #true,invalid_op_flag
    BEQ     OUTPUT_DATA
    BRA     OUTPUT

OUTPUT_DATA
    BSR     sub_build_data
    BRA     OUTPUT

DONE
    SIMHALT             ; halt simulator

OUTPUT
    LEA     output_string,A1
    MOVEQ   #13,D0
    TRAP    #15
    BRA     LOOP


**************************************************************
*
* sub_process_opcode
*
* * 1 (L): Address of operation definition
*
    OFFSET 4
sub_process_opcode_addr DS.L    1
    ORG *

sub_process_opcode
    MOVEA.L sub_process_opcode_addr(SP),A0  *Load the opcode definition address

    CLR.L   D1                              *Clear D1 so it can take a long address
    MOVE.W  (A0)+,D1                        *Get opcode name address

    **** Print opcode name
    MOVEM.L D0/A0,-(SP)
    MOVE.L  D1,-(SP)                        *Push string name onto the stack for printing
    BSR     sub_build_string                *Build the string
    LEA     4(SP),SP                        *Reset the stack
    MOVEM.L (SP)+,D0/A0

    MOVE.W  (A0)+,D1                        *Get the size type or terminating opf

    CMP.W   #opf_term,D1                    *See if we have terminated
    BEQ     sub_process_opcode_rts          *We are done with this code so we'll return

    CMP.W   #opf_no_size,D1                 *See if it doens't have a size
    BEQ     sub_process_opcode_tab          *If it doesn't skip ahead

    CMP.W   #opf_size,D1                    *See if it is a size
    BNE     sub_process_opcode_opf_sizes    *Must support different sizes (not a single size)

    MOVE.W  (A0)+,D7                        *Store the size in D7
    BRA     sub_process_opcode_tab

sub_process_opcode_opf_sizes

    MOVE.W  (A0)+,D2                        *Get the size bit position
    MOVE.W  (A0)+,D3                        *Get the byte size format
    MOVE.W  (A0)+,D4                        *Get the word size format
    MOVE.W  (A0)+,D5                        *Get the long size format

    MOVEM.L D0/A0,-(SP)                     *Save the registers

    MOVE.W  D2,-(SP)
    MOVE.W  D3,-(SP)
    MOVE.W  D4,-(SP)
    MOVE.W  D5,-(SP)

    BSR     sub_build_op                    *Build the size operand
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
    BEQ     sub_process_opcode_types
    BRA     sub_process_opcode_flip_loop    *If we are at the opf_flipped bit we are done and ready to output

sub_process_opcode_back_types

    LEA     -2(A0),A0                       *Backup by one

sub_process_opcode_types

    MOVE.W  (A0)+,D1

    CMP.W   #opf_count,D1                   *See if we are passing in a count
    BNE     sub_process_opcode_types_reg    *If not equal we'll see if its a register

    ** code for count
    
    MOVE.W  (A0)+,D1                        *Get the immediate count value

    MOVEM.L D0/D1/D7/A0,-(SP)               *Backup registers
    MOVE.W  #'#',-(SP)                      *Move pound sign to the stack
    BSR     sub_build_char                  *Output the pound sign
    LEA     2(SP),SP                        *Reset the stack
    MOVEM.L (SP)+,D0/D1/D7/A0               *Restore the registers

    MOVEM.L D0/D7/A0,-(SP)                  *Backup the registers
    MOVE.W  D1,-(SP)                        *Put the bit position in D1
    MOVE.W  #3,-(SP)                        *set our size to 3
    BSR     sub_handy_mask                  *Grab those values
    LEA     4(SP),SP                        *Reset the stack pointer
    MOVEM.L (SP)+,D0/D7/A0                  *Restore the registers

    MOVEM.L D0/D7/A0,-(SP)                  *Backup registers
    MOVE.L  D1,-(SP)                        *Put the value to the stack
    MOVE.W  #false,-(SP)                    *Don't print the hex char because we are going to be <= 8
    MOVE.W  #nibble_size,-(SP)              *Print it out as a nibble
    BSR     sub_build_hex_string            *Print out the value
    LEA     8(SP),SP                        *Reset the stack
    MOVEM.L (SP)+,D0/D7/A0                  *Restore the registers

    BRA     sub_process_opcode_types_next   *Go on to the next item

sub_process_opcode_types_reg

    CMP.W   #opf_reg,D1
    BNE     sub_process_opcode_types_cnt_reg
    
    ** code for reg

sub_process_opcode_types_reg_qwk               *Quick access to reg

    MOVE.W  (A0)+,D1                        *Get starting bit position
    MOVE.W  (A0)+,D2                        *Get register mode (ea_reg_dir | ea_add_dir)

    MOVEM.L D0/D7/A0,-(SP)                     *Backup the registers

    MOVE.W  D2,-(SP)                        *Push mode bit position onto the stack
    MOVE.W  D1,-(SP)                        *Push register bit position onto the stack
    BSR     sub_build_direct_string         *Build the address or data register
    LEA     4(SP),SP                        *Reset the stack pointer

    MOVEM.L (SP)+,D0/D7/A0                     *Restore the registers

    BRA     sub_process_opcode_types_next   *Go to the next statement

sub_process_opcode_types_cnt_reg

    CMP.W   #opf_count_reg,D1               *See if it the count reg
    BNE     sub_process_opcode_types_imm    *If not check immediate

    MOVE.W  (A0)+,D1                        *Get determinate to figure out if it's a count or register

    BTST    D1,D0                           *Check to see if it's a count (0) or register (1)
    BNE     sub_process_opcode_types_reg_qwk    *It's a register so we'll process it as such

    MOVE.W  (A0)+,D1                        *Get the immediate count value

    MOVEM.L D0/D1/D7/A0,-(SP)               *Backup registers
    MOVE.W  #'#',-(SP)                      *Move pound sign to the stack
    BSR     sub_build_char                  *Output the pound sign
    LEA     2(SP),SP                        *Reset the stack
    MOVEM.L (SP)+,D0/D1/D7/A0               *Restore the registers

    MOVEM.L D0/D7/A0,-(SP)                  *Backup the registers
    MOVE.W  D1,-(SP)                        *Put the bit position in D1
    MOVE.W  #3,-(SP)                        *set our size to 3
    BSR     sub_handy_mask                  *Grab those values
    LEA     4(SP),SP                        *Reset the stack pointer
    MOVEM.L (SP)+,D0/D7/A0                  *Restore the registers

    MOVEM.L D0/D7/A0,-(SP)                  *Backup registers
    MOVE.L  D1,-(SP)                        *Put the value to the stack
    MOVE.W  #false,-(SP)                    *Don't print the hex char because we are going to be <= 8
    MOVE.W  #nibble_size,-(SP)              *Print it out as a nibble
    BSR     sub_build_hex_string            *Print out the value
    LEA     8(SP),SP                        *Reset the stack
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
    BSR     sub_get_next_abs                *Print out the value
    LEA     2(SP),SP                        *Reset the stack
    MOVEM.L (SP)+,D0/D7/A0                  *Restore the registers

    MOVEM.L A0/D0/D7,-(SP)                  * save current address on the stack
    MOVE.L  D3,-(SP)                        * move value (word or long) to stack
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
    BNE     sub_process_opcode_types_sub

    MOVEM.L D1/D0,-(SP)                        *Backup D1
    BSR     sub_tab                         *Build the size operand
    MOVEM.L (SP)+,D1/D0                        *Restore D1

    MOVE.W  #0,-(SP)
    MOVE.W  #8,-(SP)
    BSR     sub_handy_mask
    LEA     4(SP),SP

    MOVE.W  D1,-(SP)
    BSR     sub_build_displacement
    LEA     2(SP),SP
    
    BRA     sub_process_opcode_types_next
    
        
sub_process_opcode_types_sub
    
    MOVE.W  (A0)+,A0
    JSR     (A0)

sub_process_opcode_types_next

    MOVE.W  (A0)+,D1                        *Get the next statement

    CMP.W   #opf_term,D1                    *See if this code is done
    BEQ     sub_process_opcode_rts          *If so we are done

    CMP.W   #opf_flipped,D1                 *See if it's the flipped
    BEQ     sub_process_opcode_rts          *If so we are done

    MOVEM.L A0/D0/D7,-(SP)
    BSR     sub_build_string_comma_space
    MOVEM.L (SP)+,A0/D0/D7

    BRA     sub_process_opcode_back_types   *Go back and get start again

sub_process_opcode_rts
    BSR     sub_build_finish                *Put the terminating character on the string
    RTS

**************************************************************
*
* sub_build_data
*
* Puts a null character at the end
*

sub_build_data

    CLR.W   output_string_displacement      *Reset the string displacement so we can write again

    BSR         sub_build_current_line_address  *Print out the current line

    MOVE.L      #data_string,-(SP)          *Load the position of 'DATA' to the stack
    BSR         sub_build_string            *Output DATA
    LEA         4(SP),SP                    *Reset the stack pointer

    BSR         sub_tab                     *Output it

    MOVE.L      current_addr_backup,A0      *Get the backup address and put it in A0
    CLR.L       D0                          *Clear D0
    MOVE.W      (A0),D0                     *Load the value at A0 (the word) to D0

    MOVE.L      D0,-(SP)                    *Move the value to the stack
    MOVE.W      #true,-(SP)                 *We want to print a hex symbol so #true
    MOVE.W      #word_size,-(SP)            *Ops are always of word size
    BSR         sub_build_hex_string        *Build the string
    LEA         8(SP),SP                    *Reset the pointer

    BSR         sub_build_finish

    RTS


**************************************************************
*
* sub_build_finish
*
* Puts a null character at the end
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
* Puts a null character at the end
*
sub_build_current_line_address
    MOVE.L      current_addr_backup,-(SP)
    MOVE.W      #false,-(SP)
    MOVE.W      #word_size,-(SP)
    BSR         sub_build_hex_string
    LEA         8(SP),SP

    BSR         sub_tab

    RTS

**************************************************************
*
* sub_build_char
*
* Adds a single character to the output string
*
    OFFSET 4
sub_build_char_ascii DS.W    1
    ORG *

sub_build_char
    MOVEA.L     #output_string,A0               *Load the output string
    MOVE.W      output_string_displacement,D0   *Load current displacement to D0
    ADD.W       D0,A0                           *Adjust the address for the current displacement
    MOVE.W      sub_build_char_ascii(SP),D1
    MOVE.B      D1,(A0)+
    ADDQ.W      #byte_size,D0
    MOVE.W      D0,output_string_displacement
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
* sub_get_next_abs
*
* Grabs the next
*
* Stack Parameters:
* 1 (W): Size defined by either word_size or long_size
*
* Return Registers:
* 1 (W/L): Returns the word or long in D1

    OFFSET 4
sub_get_next_abs_size    DS.W    1
    ORG *

sub_get_next_abs
    MOVE.W  sub_get_next_abs_size(SP),D1              * load size to D1
    MOVEA.L current_addr,A0                             * load current address to A0

    CMP.W   #long_size,D1                               * compare size to long
    BEQ     sub_get_next_abs_long                     * branch to special case if true
    MOVE.W  (A0)+,D1                                    * get next word
    BRA     sub_get_next_abs_adj
sub_get_next_abs_long
    MOVE.L  (A0)+,D1                                    * get next long
sub_get_next_abs_adj
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
* sub_build_displacement
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
* sub_build_op
*
* Adds an EA to the string
*
* Stack Parameters:
* 1 (L): Opcode string address
* 2 (W): Bit position for size
* 3 (W): Byte value
* 4 (W): Word value
* 5 (W): Long value
*
* Register Parameters:
* 1 (L): D0 should contain the current op code
*
* Return
* 1 (W): Size of the operation

    OFFSET 4
sub_build_op_long_val    DS.W    1
sub_build_op_word_val    DS.W    1
sub_build_op_byte_val    DS.W    1
sub_build_op_position    DS.W    1
    ORG *

sub_build_op

    CMP.B   #no_size,sub_build_op_position(SP)
    BEQ     sub_build_op_print

    MOVE.W  sub_build_op_position(SP),D1

    MOVE.W  D1,-(SP)
    MOVE.W  #2,-(SP)
    BSR     sub_handy_mask
    LEA     4(SP),SP

    MOVEM.L D1,-(SP)
    MOVE.W  #'.',-(SP)
    BSR     sub_build_char
    LEA     2(SP),SP
    MOVEM.L (SP)+,D1

    MOVE.W  sub_build_op_byte_val(SP),D5
    MOVE.W  sub_build_op_word_val(SP),D6
    MOVE.W  sub_build_op_long_val(SP),D7

    CMP.B   D5,D1
    BNE     sub_build_op_word
    MOVE.B  #'B',D3
    MOVE.W  #byte_size,D4
    BRA     sub_build_op_print
sub_build_op_word
    CMP.B   D6,D1
    BNE     sub_build_op_long
    MOVE.B  #'W',D3
    MOVE.W  #word_size,D4
    BRA     sub_build_op_print
sub_build_op_long
    CMP.B   D7,D1
    BNE     sub_build_op_flag_invalid
    MOVE.B  #'L',D3
    MOVE.W  #long_size,D4
sub_build_op_print
    MOVE.W  D3,-(SP)
    BSR     sub_build_char
    LEA     2(SP),SP
sub_build_op_rts
    MOVE.W  D4,D1
    RTS
sub_build_op_flag_invalid
    MOVE.B  #true,invalid_op_flag
    BRA     sub_build_op_rts



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
* sub_tab
*
* Adds a single comma to the string
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

true                EQU 1
false               EQU 0

word_displace       EQU $00
long_displace       EQU $FF

nibble_size         EQU 0   *This representation cannot be used mathematically
byte_size           EQU 1
word_size           EQU 2
long_size           EQU 4
no_size             EQU $F

right_nibble_mask   EQU $000F
null                EQU 0

* EA MODES

ea_reg_dir          EQU %000
ea_add_dir          EQU %001
ea_ari              EQU %010
ea_ari_post         EQU %011
ea_ari_pre          EQU %100

ea_abs              EQU %111    *This MUST preceed each ea_word,ea_long,ea_imm
ea_word             EQU %000    *Used in conjunction with abs
ea_long             EQU %001    *Used in conjunction with abs
ea_imm              EQU %100    *Used in conjunction with abs

ea_term             EQU %1111   *Terminates a list of ea modes
ea_all              EQU %1110   *Declares that all ea modes are accepted

*** opf definitions ***
* label [op name string address],{[size],[flip bit],[type],[type],opf_flipped,[type],[type],}[opf_term]
*
*   add opf_imm
*
* [size] =
* opf_size [byte_size | word_size | long_size]
* OR
* opf_sizes [size bit pos],[byte size rep | no_size], [word size rep | no_size], [long size rep | no_size]
*
* [flip bit] =
* opf_flip  [bit position of indicator]
*
* [type] =

*** opf_ea ***
* 1) acceptable ea modes address
* 2) mode start bit position
* 3) reg start bit position
opf_ea          EQU     0

*** opf_count ***
* 1) start bit position
opf_count       EQU     1

*** opf_reg ***
* 1) start bit position
* 2) type (either ea_reg_dir or ea_add_dir)
opf_reg         EQU     2

*** opf_count_reg ***
* 1) determinent bit position (where it is determined if it's a count or register)
* 2) start bit position
* 3) type (either ea_reg_dir or ea_add_dir)
opf_count_reg   EQU     3

opf_imm         EQU     4

opf_disp        EQU     5

*** opf_sub ***
* Passes control to a subroutine
* 1) address of subroutine
opf_sub         EQU      6

*** opf_flip ***
* Determines if A and B can be flipped
* 1) bit position
opf_flip        EQU     7

opf_flipped     EQU     8

*** opf_sizes ***
* 1) determinent bit position (starting location where size can be determined)
* 2) byte representation or no_size
* 3) word representation or no_size
* 4) long representation or no_size
opf_sizes       EQU     9

*** opf_size_only ***
* 1) size (in byte_size, word_size, long_size)
opf_size        EQU     10

opf_no_size     EQU     11

opf_term        EQU      12

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

output_string               DS.B    50
output_string_displacement  DS.W    1
current_addr                DS.L    1
current_addr_backup         DS.L    1
invalid_op_flag             DS.B    1

hex_characters  DC.B    '0123456789ABCDEF'

* Put variables and constants here

print_blank         DC.B    0


op_codes        DC.W    op_code_adda,op_code_add,op_code_eor,op_code_divs,op_code_lea,op_code_nop,op_code_movea1,op_code_movea2
op_codes1       DC.W    op_code_move1,op_code_move2,op_code_move3,op_code_neg,op_code_ori,op_code_cmpi,op_code_rts
op_codes2       DC.W    op_code_jsr,op_code_subq,op_code_or,op_code_sub,op_code_cmp,op_code_muls
op_codes3       DC.W    op_code_asrm,op_code_aslm,op_code_lslm,op_code_lsrm,op_code_asr,op_code_asl,op_code_rolm,op_code_rorm,op_code_rol,op_code_ror,op_code_lsr,op_code_lsl **this order is strict
op_codes4       DC.W    op_code_bra,op_code_bcs,op_code_bvc,op_code_bge,op_code_blt,op_code_movem,0

************** OP CODE DEFINITIONS ***************

data_string     DC.B    'DATA',0

op_string_lea   DC.B    'LEA',0
op_code_lea     DC.W    $41C0,$F1C0,op_def_lea
op_ea_lea_src   DC.B    ea_ari,ea_abs,ea_word,ea_abs,ea_long
op_def_lea      DC.W    op_string_lea,opf_size,long_size,opf_ea,op_ea_lea_src,3,0,opf_reg,9,ea_add_dir,opf_term

op_string_eor   DC.B    'EOR',0
op_code_eor     DC.W    $B100,$F100,op_def_eor
op_ea_eor_dest  DC.B    ea_reg_dir,ea_ari,ea_ari_post,ea_ari_pre,ea_abs,ea_word,ea_abs,ea_long,ea_term
op_def_eor      DC.W    op_string_eor,opf_sizes,6,%00,%01,%10,opf_reg,9,ea_reg_dir,opf_ea,op_ea_eor_dest,3,0,opf_term

op_string_or    DC.B   'OR',0
op_code_or      DC.W    $8000,$F000,op_def_or
op_ea_or_src    DC.B    ea_reg_dir,ea_ari,ea_ari_post,ea_ari_pre,ea_abs,ea_word,ea_abs,ea_long,ea_abs,ea_imm,ea_term
op_ea_or_dest   DC.B    ea_ari,ea_ari_post,ea_ari_pre,ea_abs,ea_word,ea_abs,ea_long,ea_term
op_def_or       DC.W    op_string_or,opf_sizes,6,%00,%01,%10,opf_flip,8,opf_ea,op_ea_or_src,3,0,opf_reg,9,ea_reg_dir,opf_flipped,opf_reg,9,ea_reg_dir,opf_ea,op_ea_or_dest,3,0,opf_term

op_string_nop   DC.B    'NOP',0
op_code_nop     DC.W    $4E71,$FFFF,op_def_nop
op_def_nop      DC.W    op_string_nop,opf_term

op_string_adda  DC.B    'ADDA',0
op_code_adda    DC.W    $D0C0,$F0C0,op_def_adda
op_ea_adda_src  DC.B    ea_all
op_def_adda     DC.W    op_string_adda,opf_sizes,7,no_size,%01,%11,opf_ea,op_ea_adda_src,3,0,opf_reg,9,ea_add_dir,opf_term

op_string_movea DC.B    'MOVEA',0
op_code_movea1  DC.W    $3040,$F1C0,op_def_movea    *Two different ways to define MOVEA
op_code_movea2  DC.W    $2040,$F1C0,op_def_movea
op_ea_movea_src DC.B    ea_all
op_def_movea    DC.W    op_string_movea,opf_sizes,12,no_size,%11,%10,opf_ea,op_ea_movea_src,3,0,opf_reg,9,ea_add_dir,opf_term

op_string_move  DC.B    'MOVE',0
op_code_move1   DC.W    $1000,$F000,op_def_move     *Three different ways to define MOVE
op_code_move2   DC.W    $2000,$F000,op_def_move
op_code_move3   DC.W    $3000,$F000,op_def_move
op_ea_move_src  DC.B    ea_all
op_ea_move_dest DC.B    ea_reg_dir,ea_ari,ea_ari_post,ea_ari_pre,ea_abs,ea_word,ea_abs,ea_long,ea_abs,ea_imm,ea_term
op_def_move     DC.W    op_string_move,opf_sizes,12,%01,%11,%10,opf_ea,op_ea_move_src,3,0,opf_ea,op_ea_move_dest,6,9,opf_term

op_string_neg   DC.B    'NEG',0
op_code_neg     DC.W    $4400,$FF00,op_def_neg
op_ea_neg_dest  DC.B    ea_reg_dir,ea_ari,ea_ari_post,ea_ari_pre,ea_abs,ea_word,ea_abs,ea_long,ea_abs,ea_imm,ea_term
op_def_neg      DC.W    op_string_neg,opf_sizes,6,%00,%01,%10,opf_ea,op_ea_neg_dest,3,0,opf_term

op_string_ori   DC.B    'ORI',0
op_code_ori     DC.W    $0000,$FF00,op_def_ori
op_ea_ori_dest  DC.B    ea_reg_dir,ea_ari,ea_ari_post,ea_ari_pre,ea_abs,ea_word,ea_abs,ea_long,ea_term
op_def_ori      DC.W    op_string_ori,opf_sizes,6,%00,%01,%10,opf_imm,opf_ea,op_ea_ori_dest,3,0,opf_term

op_string_cmpi  DC.B    'CMPI',0
op_code_cmpi    DC.W    $0C00,$FF00,op_def_cmpi
op_ea_cmpi_dest DC.B    ea_reg_dir,ea_ari,ea_ari_post,ea_ari_pre,ea_abs,ea_word,ea_abs,ea_long,ea_term
op_def_cmpi     DC.W    op_string_cmpi,opf_sizes,6,%00,%01,%10,opf_imm,opf_ea,op_ea_cmpi_dest,3,0,opf_term

op_string_rts   DC.B    'RTS',0
op_code_rts     DC.W    $4E75,$FFFF,op_def_rts
op_def_rts      DC.W    op_string_rts,opf_term

op_string_jsr   DC.B    'JSR',0
op_code_jsr     DC.W    $4E80,$FFC0,op_def_jsr
op_ea_jsr_dest  DC.B    ea_ari,ea_abs,ea_word,ea_abs,ea_long,ea_term
op_def_jsr      DC.W    op_string_jsr,opf_no_size,opf_ea,op_ea_jsr_dest,3,0,opf_term

op_string_subq  DC.B    'SUBQ',0
op_code_subq    DC.W    $5000,$F000,op_def_subq
op_ea_subq_dest DC.B    ea_reg_dir,ea_add_dir,ea_ari,ea_ari_post,ea_ari_pre,ea_abs,ea_word,ea_abs,ea_long,ea_term
op_def_subq     DC.W    op_string_subq,opf_sizes,6,%00,%01,%10,opf_count,9,opf_ea,op_ea_subq_dest,3,0,opf_term

op_string_divs  DC.B    'DIVS',0
op_code_divs    DC.W    $81C0,$F1C0,op_def_divs
op_ea_divs_src  DC.B    ea_reg_dir,ea_ari,ea_ari_post,ea_ari_pre,ea_abs,ea_word,ea_abs,ea_long,ea_abs,ea_imm,ea_term
op_def_divs     DC.W    op_string_divs,opf_size,word_size,opf_ea,op_ea_divs_src,3,0,opf_reg,9,ea_reg_dir,opf_term

op_string_sub   DC.B    'SUB',0
op_code_sub     DC.W    $9000,$F000,op_def_sub
op_ea_sub_src   DC.B    ea_all
op_ea_sub_dest  DC.B    ea_ari,ea_ari_post,ea_ari_pre,ea_abs,ea_word,ea_abs,ea_long,ea_term
op_def_sub      DC.W    op_string_sub,opf_sizes,6,%00,%01,%10,opf_flip,8,opf_ea,op_ea_sub_dest,3,0,opf_reg,9,ea_reg_dir,opf_flipped
op_def_sub_flip DC.W    opf_reg,9,ea_reg_dir,opf_ea,op_ea_sub_dest,3,0,opf_term

op_string_cmp   DC.B    'CMP',0
op_code_cmp     DC.W    $B000,$F100,op_def_cmp
op_ea_cmp_src   DC.B    ea_all
op_def_cmp      DC.W    op_string_cmp,opf_sizes,6,%00,%01,%10,opf_ea,op_ea_cmp_src,3,0,opf_reg,9,ea_reg_dir,opf_term

op_string_muls  DC.B    'MULS',0
op_code_muls    DC.W    $C000,$F000,op_def_muls
op_ea_muls_src  DC.B    ea_reg_dir,ea_ari,ea_ari_post,ea_ari_pre,ea_abs,ea_word,ea_abs,ea_long,ea_abs,ea_imm,ea_term
op_def_muls     DC.W    op_string_muls,opf_size,word_size,opf_ea,op_ea_muls_src,3,0,opf_reg,9,ea_reg_dir,opf_term

op_string_add   DC.B    'ADD',0
op_code_add     DC.W    $D000,$F000,op_def_add
op_ea_add_src   DC.B    ea_all
op_ea_add_dest  DC.B    ea_ari,ea_ari_post,ea_ari_pre,ea_abs,ea_word,ea_abs,ea_long,ea_term
op_def_add      DC.W    op_string_add,opf_sizes,6,%00,%01,%10,opf_flip,8,opf_ea,op_ea_add_src,3,0,opf_reg,9,ea_reg_dir,opf_flipped
op_def_add_flip DC.W    opf_reg,9,ea_reg_dir,opf_ea,op_ea_add_dest,3,0,opf_term

op_string_asr   DC.B    'ASR',0
op_code_asr     DC.W    $E000,$F118,op_def_asr
op_def_asr      DC.W    op_string_asr,opf_sizes,6,%00,%01,%10,opf_count_reg,5,9,ea_reg_dir,opf_reg,0,ea_reg_dir,opf_term
*** Opcodes for ASR operate differently for memory ***
op_ea_asrm      DC.B    ea_ari,ea_ari_post,ea_ari_pre,ea_abs,ea_word,ea_abs,ea_long,ea_term
op_code_asrm    DC.W    $E0C0,$FFC0,op_def_asrm
op_def_asrm     DC.W    op_string_asr,opf_size,word_size,opf_ea,op_ea_asrm,3,0,opf_term

op_string_asl   DC.B    'ASL',0
op_code_asl     DC.W    $E100,$F118,op_def_asl
op_def_asl      DC.W    op_string_asl,opf_sizes,6,%00,%01,%10,opf_count_reg,5,9,ea_reg_dir,opf_reg,0,ea_reg_dir,opf_term
*** Opcodes for ASL operate differently for memory ***
op_ea_aslm      DC.B    ea_ari,ea_ari_post,ea_ari_pre,ea_abs,ea_word,ea_abs,ea_long,ea_term
op_code_aslm    DC.W    $E1C0,$FFC0,op_def_aslm
op_def_aslm     DC.W    op_string_asl,opf_size,word_size,opf_ea,op_ea_aslm,3,0,opf_term

op_string_ror   DC.B    'ROR',0
op_code_ror     DC.W    $E018,$F118,op_def_ror
op_def_ror      DC.W    op_string_ror,opf_sizes,6,%00,%01,%10,opf_count_reg,5,9,ea_reg_dir,opf_reg,0,ea_reg_dir,opf_term
*** Opcodes for ROR operate differently for memory ***
op_ea_rorm      DC.B    ea_ari,ea_ari_post,ea_ari_pre,ea_abs,ea_word,ea_abs,ea_long,ea_term
op_code_rorm    DC.W    $E6C0,$FFC0,op_def_rorm
op_def_rorm     DC.W    op_string_ror,opf_size,word_size,opf_ea,op_ea_rorm,3,0,opf_term

op_string_rol   DC.B    'ROL',0
op_code_rol     DC.W    $E118,$F118,op_def_rol
op_def_rol      DC.W    op_string_rol,opf_sizes,6,%00,%01,%10,opf_count_reg,5,9,ea_reg_dir,opf_reg,0,ea_reg_dir,opf_term
*** Opcodes for ROL operate differently for memory ***
op_ea_rolm      DC.B    ea_ari,ea_ari_post,ea_ari_pre,ea_abs,ea_word,ea_abs,ea_long,ea_term
op_code_rolm    DC.W    $E7C0,$FFC0,op_def_rolm
op_def_rolm     DC.W    op_string_rol,opf_size,word_size,opf_ea,op_ea_rolm,3,0,opf_term

op_string_lsr   DC.B    'LSR',0
op_code_lsr     DC.W    $E008,$F118,op_def_lsr
op_def_lsr      DC.W    op_string_lsr,opf_sizes,6,%00,%01,%10,opf_count_reg,5,9,ea_reg_dir,opf_reg,0,ea_reg_dir,opf_term
*** Opcodes for LSR operate differently for memory ***
op_ea_lsrm      DC.B    ea_ari,ea_ari_post,ea_ari_pre,ea_abs,ea_word,ea_abs,ea_long,ea_term
op_code_lsrm    DC.W    $E2C0,$FFC0,op_def_lsrm
op_def_lsrm     DC.W    op_string_lsr,opf_size,word_size,opf_ea,op_ea_lsrm,3,0,opf_term

op_string_lsl   DC.B    'LSL',0
op_code_lsl     DC.W    $E108,$F118,op_def_lsl
op_def_lsl      DC.W    op_string_lsl,opf_sizes,6,%00,%01,%10,opf_count_reg,5,9,ea_reg_dir,opf_reg,0,ea_reg_dir,opf_term
*** Opcodes for LSL operate differently for memory ***
op_ea_lslm      DC.B    ea_ari,ea_ari_post,ea_ari_pre,ea_abs,ea_word,ea_abs,ea_long,ea_term
op_code_lslm    DC.W    $E3C0,$FFC0,op_def_lslm
op_def_lslm     DC.W    op_string_lsl,opf_size,word_size,opf_ea,op_ea_lslm,3,0,opf_term

op_string_bra   DC.B    'BRA',0
op_code_bra     DC.W    $6000,$FF00,op_def_bra
op_def_bra      DC.W    op_string_bra,opf_no_size,opf_disp,opf_term

op_string_bcs   DC.B    'BCS',0
op_code_bcs     DC.W    $6500,$FF00,op_def_bcs
op_def_bcs      DC.W    op_string_bcs,opf_no_size,opf_disp,opf_term

op_string_bvc   DC.B    'BVC',0
op_code_bvc     DC.W    $6800,$FF00,op_def_bvc
op_def_bvc      DC.W    op_string_bvc,opf_no_size,opf_disp,opf_term

op_string_bge   DC.B    'BGE',0
op_code_bge     DC.W    $6C00,$FF00,op_def_bge
op_def_bge      DC.W    op_string_bge,opf_no_size,opf_disp,opf_term

op_string_blt   DC.B    'BLT',0
op_code_blt     DC.W    $6D00,$FF00,op_def_blt
op_def_blt      DC.W    op_string_blt,opf_no_size,opf_disp,opf_term

op_string_movem DC.B    'MOVEM',0
op_code_movem   DC.W    $4880,$FB80,op_def_movem
op_def_movem    DC.W    op_string_movem,opf_sizes,6,no_size,%10,%11,opf_sub,sub_op_movem,opf_term


sub_op_movem
    
    RTS

CR EQU $0D
LF EQU $0A
TAB EQU $9

tab_stops       DC.B    8,17,24

*make program jump back to other opcodes if invalid flag set?


    * TEST PROGRAM * *BB88 eor bad*

    ORG     $3000
    *MOVEM.W D0,-(SP)
    BRA     $2FFE
    BLT     $3005
    BGE     $3008
    BVC     $3922
    BCS     $2323
    ASR.W   (A0)+
    ASL.W   (A0)+
    ASR.L   #3,D3
    ASL.L   #3,D3
    ASR.L   D1,D3
    ASL.L   D1,D3
tst ROR.W   (A0)+
    ROL.W   (A0)+
    ROR.L   #3,D3
    ROL.L   #3,D3
    ROR.L   D1,D3
    ROL.L   D1,D3

    LSR.W   (A0)+
    LSL.W   (A0)+
    LSR.L   #3,D3
    LSL.L   #3,D3
    LSR.L   D1,D3
    LSL.L   D1,D3

    ADD.L   $12345678,D3
    SUBQ.W  #4,A0
    ORI.W   #$1234,D4
    SUB.W   $1233,D3
    MULS    $1233,D1
    DIVS    #$12,D1
    CMP.W   A0,D1
    RTS
    JSR     (A0)
    JSR     $1234
    EOR.B   D1,(A0)+
    CMPI.L  #$12345678,D2

    NEG.W    D3
    NEG.L    -(A1)
    MOVE.B  D1,(A0)


    END    START        ; last line of source













*~Font name~Courier New~
*~Font size~12~
*~Tab type~1~
*~Tab size~4~
