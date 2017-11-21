   section .bss
   ;; all read data, separated with '\0'
   strings resb 1000            ;TODO: unlimited
   ;; pairs (key_address, value_address) for strings read from file
   index resq 100


   section .data
   ;; predefined filename with input
   input_filename db "sort.in", 0
   ;; transaction table for marking up read data
mark_index_1_table:             ; TODO: generate?
      dd    mark_index_1_zero,
      times 9 dd mark_index_1,
      dd    mark_index_1_cr, 
      times 2 dd mark_index_1,
      dd    mark_index_1_lf, 
      times 18 dd mark_index_1,
      dd    mark_index_1_space, 
      times 223 dd mark_index_1
mark_index_2_table:             
      dd    mark_index_2_zero,
      times 9 dd mark_index_2,
      dd    mark_index_2_cr, 
      times 2 dd mark_index_2,
      dd    mark_index_2_lf, 
      times 18 dd mark_index_2,
      dd    mark_index_2_space, 
      times 223 dd mark_index_2
mark_index_3_table:             
      dd    mark_index_3_zero,
      times 9 dd mark_index_3,
      dd    mark_index_3_cr, 
      times 2 dd mark_index_3,
      dd    mark_index_3_lf, 
      times 18 dd mark_index_3,
      dd    mark_index_3_space, 
      times 223 dd mark_index_3
   
   section .text
   global _start   
_start:         
   ;; initialization
      

   ;;
   ;; read all strings from a file
   ;;

   ;; open file

   mov   eax, 5                 ; open file
   mov   ebx, input_filename
   mov   ecx, 0                 ; read-only mode
   int   0x80

   cmp   eax, 0
   jge open_file_success
   ;;TODO:
   jmp program_exit   

open_file_success:
   mov   esi, eax               

   ;; read from file to 'strings'

   mov   edi, strings           

read_file_strings:
   mov   eax, 3                 ; read
   mov   ebx, esi               ; from opened file
   mov   ecx, edi               ; to buffer
   mov   edx, 0x1000            ; up to 4Kb chars per read
   int   0x80

   cmp   eax, 0
   jg    read_file_success
   jl    read_file_error
   jmp   read_file_post

read_file_success:
   add   edi, eax
   jmp   read_file_strings

read_file_error:
   ;; TODO: cases, print error
   jmp program_exit

read_file_post:

   ;; close file

   mov   eax, 6                 ; close file
   mov   ebx, esi
   int   0x80

   ;;
   ;; mark up the index
   ;;
   ;; process 'strings' and initialize index
   ;; also replace '\n' after each value with '\0' for easier build-in printing
   ;;

   mov   esi, strings
   mov   edi, index

   mov   [edi], esi
   add   edi, 4

   ;; when processing data read, we can be in one of two states:
   ;; reading key and reading value.
   ;; also reading first char of line is counted as special case
   ;; in order to skip empty lines.
   ;; thus 3 stages are present:
mark_index:
mark_index_1:
   lodsb                        ; same as "mov al, [esi]; inc esi"
   jmp   [mark_index_1_table + 4 * eax]

mark_index_1_space:             ;; TODO: is it ok to have "" as key?
   mov   [edi], esi  
   add   edi, 4
   jmp   mark_index_3
mark_index_1_cr:
mark_index_1_lf:
   inc   dword [edi - 4]        ; correct last set index value to point to
                                ; start of next line rather than this line
   jmp mark_index
mark_index_1_zero:
   jmp mark_index_post

mark_index_2:
   lodsb
   jmp   [mark_index_2_table + 4 * eax]

mark_index_2_space:
   mov   [edi], esi
   add   edi, 4
   jmp   mark_index_3
mark_index_2_cr:
mark_index_2_lf:
   ;; TODO:
   jmp program_exit
mark_index_2_zero:
   ;; TODO:
   jmp program_exit

mark_index_3:
   lodsb
   jmp   [mark_index_3_table + 4 * eax]

mark_index_3_cr:
mark_index_3_lf:
   mov   [edi], esi
   add   edi, 4
   mov   byte   [esi - 1], 0    ;; terminate value-string with '\0'
   jmp   mark_index
mark_index_3_space:
   ;; TODO:
   jmp program_exit
mark_index_3_zero:
   jmp mark_index_post

mark_index_post:

   ;; count index length (number of pairs)
   add   edi, 4
   sub   edi, index
   shr   edi, 3

   ;;
   ;; merge sort
   ;;

   ;;
   ;; exit
   ;;

program_exit:
   mov   eax, 1                 ; exit program
   xor   ebx, ebx               ; exit code 0
   int   0x80        


