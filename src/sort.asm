   ;;
   ;;
   ;; Macroses
   ;;
   ;;


   ;; Accepts name of label refering to string and prints it.
   ;; Assumes that variable <labelname>_len is defined and set to length.
   %macro print_msg 1
   mov   eax, 4                 ; write
   mov   ebx, 1                 ; to stdout
   mov   edx, %1_len
   mov   ecx, %1
   int   0x80
   %endmacro 

   ;; Creates a label with specified name refering given string.
   ;; Also initiates <labelname>_len to strings length.
   %macro alloc_msg 2+
   %1 db %2
%1_len equ $ - %1
   %endmacro 

   %define string_max_len 0x100

   ;;
   ;;
   ;; Data
   ;;
   ;;


   section .bss
   ;; all read data, separated with '\0'
   strings resb 1000            ;TODO: unlimited
   ;; pairs (key_address, value_address) for strings read from file
   index resq 100
   ;; helper buffer for merge sort
   index_temp resq 100          ; TODO: get off!
   ;; temporal storage for 'print_num' functions
   print_num_buffer resb 11


   section .data
   ;; predefined filename with input
   input_filename db "sort.in", 0
   alloc_msg input_filename_msg, "sort.in"
   ;; newline for printing
   alloc_msg newline, 10
   ;; for 'print_num'
   print_num_buffer_len dd 10

   ;; transaction table for marking up read data
mark_index_1_table:             ; TODO: generate?
      dd    mark_index_1_zero,
      times 9 dd mark_index_2,
      dd    mark_index_1_cr, 
      times 2 dd mark_index_2,
      dd    mark_index_1_lf, 
      times 18 dd mark_index_2,
      dd    mark_index_1_space, 
      times 223 dd mark_index_2
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

   ;; errors
   alloc_msg err_open_failed, "Failed to open input file", 10
   alloc_msg err_open_failed_nofile, "File doesn't exist: "

   alloc_msg err_read_file_is_dir, " shouldn't be directory", 10
   alloc_msg err_read_io, "read: io exception", 10
   alloc_msg err_read_int, "read: interrupted", 10
   alloc_msg err_read_unknown, "read: some error", 10

   alloc_msg err_no_spaces_in_line, "No space found in line "
   alloc_msg err_two_spaces_in_line, "More than one space detected on line "
   alloc_msg err_line_ends_unexpectedly, "Unexpected end of line "


   ;;
   ;;
   ;; Code
   ;;
   ;;


   section .text
   global _start   

;;;;;;;;; print_num
;;; 
;;; Description: Prints number
;;; 
;;; Args: %eax - non-negative number to print
;;; 
;;; Registers Used: all (we don't care since it's used to report errors only)
;;; 
;;;;;;;;; 
print_num:
   lea   esi, [print_num_buffer - 1]
   add   esi, [print_num_buffer_len]
   mov   edi, esi
   mov   ecx, 10
   mov   byte   [esi + 1], 0

.loop:
   cdq                          ; set $edx to 0
   div    ecx
   add   edx, '0'
   mov   [edi], dl
   dec   edi
   
   test  eax, eax
   jnz   .loop
   
   mov   eax, 4                 ; write
   mov   ebx, 1                 ; to stdout
   lea   ecx, [edi + 1]
   mov   edx, esi
   sub   edx, edi
   int   0x80

   ret

;;;;;;;;; merge-sort
;;; 
;;; Description:
;;; 
;;; Args:
;;;   %esi - unsorted index
;;;   %ecx - length
;;; Return Val:
;;; 
;;; Registers Used:
;;; Stack Depth: 9 * log(index_length)
;;; 
;;;;;;;;; 
merge_sort:
   push  esi
   push  ecx
   ;; clone 'index' to 'index_temp'
   lea   edi, [index_temp]
   shl   ecx, 1                 ; since pairs are caried
   rep   movsd        
   pop   ecx
   pop   edi
   lea   esi, [index_temp]

merge_sort_rec:
   cmp   ecx, 1
   jg    merge_sort_big

   ret

merge_sort_big:
   push  ecx
   push  esi
   push  edi
   push  esi
   push  edi

   mov   eax, ecx
   shl   eax, 3
   add   esi, eax
   push  esi
   sub   esi, eax
   shr   ecx, 1
   mov   eax, ecx
   shl   eax, 3
   push  ecx
   add   esi, eax
   push  esi
   push  esi
   sub   esi, eax
   %define stack_allocated 36
   %define length [esp + 32]    ; passed length
   %define orig_source [esp + 28] ; passed source ;; TODO: unused?
   %define orig_dest [esp + 24] ; passed destination
   %define source [esp + 20]    ; like 'orig_source', but varies during merge
   %define dest [esp + 16]      ; like 'orig_dest', but varies during merge

   %define orig_source_fin [esp + 12] ; orig_source + length
   %define length_half [esp + 8] ; length / 2
   %define orig_source_mid [esp + 4] ; source + length_half
   %define source_mid [esp + 0] ; like 'orig_source_mid', but varies over time

   xchg  esi, edi
   call  merge_sort_rec
   
   mov   ecx, length
   mov   edi, source
   mov   eax, ecx
   inc   ecx
   mov   esi, dest
   shr   eax, 1
   shr   ecx, 1
   lea   edi, [edi + 8 * eax]
   lea   esi, [esi + 8 * eax]
   call  merge_sort_rec

   mov   esi, source            ; first half
   mov   ebx, esi
   mov   ecx, length_half
   add   ebx, ecx               ; second half
   mov   edx, dest              ; where combine to

merge_sort_combine:
   mov   esi, source
   mov   edi, source_mid

   cmp   esi, orig_source_mid
   jge   .copy_second_half

   cmp   edi, orig_source_fin
   jge   .copy_first_half

   ;; compare current elements
   ;; TODO: assuming that all keys are different!!!
   mov   ecx, string_max_len
   mov   esi, [esi]
   mov   edi, [edi]
   repe  cmpsb
   jg    .greater

   mov   esi, source
   mov   edi, dest
   mov   ecx, 2
   rep   movsd
   mov   dest, edi
   mov   source, esi
   jmp   merge_sort_combine

.greater:
   mov   esi, source_mid
   mov   edi, dest
   mov   ecx, 2
   rep   movsd
   mov   dest, edi
   mov   source_mid, esi
   jmp   merge_sort_combine

.copy_first_half:
   mov   esi, source
   mov   edi, dest
   mov   ecx, orig_source_mid
   sub   ecx, esi
   shr   ecx, 2
   rep   movsd
   jmp merge_sort_combine_post

.copy_second_half:
   mov   esi, source_mid
   mov   edi, dest
   mov   ecx, orig_source_fin
   sub   ecx, esi
   shr   ecx, 2
   rep   movsd

merge_sort_combine_post:

   add   esp, stack_allocated
   %undef stack_allocated
   %undef length
   %undef orig_source
   %undef orig_dest
   %undef source
   %undef dest
   %undef orig_source_fin
   %undef length_half
   %undef orig_source_mid
   %undef source_mid

   ret

;;;;;;;;; entry point
_start:         
   ;; preparations

   sub esp, 4

   ;;
   ;; read all strings from a file
   ;;

   ;; open file

   mov   eax, 5                 ; open file
   mov   ebx, input_filename
   mov   ecx, 0x00              ; read-only mode
   int   0x80

   cmp   eax, 0
   jge open_file_success

   ;; opening failed
   cmp   eax, -2
   jz    open_file_not_exist

   print_msg err_open_failed
   jmp program_exit   
open_file_not_exist:
   print_msg err_open_failed_nofile
   print_msg input_filename_msg
   print_msg newline
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
   cmp   eax, 21                ; file is directory
   jnz   read_file_error_dir
   cmp   eax, 5                 ; I/O error
   jnz   read_file_error_io
   cmp   eax, 4                 ; caugh interrupt
   jnz   read_file_error_int

   print_msg err_read_unknown
   jmp   program_exit
read_file_error_dir:
   print_msg input_filename_msg
   print_msg err_read_file_is_dir
   jmp   program_exit
read_file_error_io:
   print_msg err_read_io
   jmp   program_exit
read_file_error_int:
   print_msg err_read_int
   jmp   program_exit

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

   %define cur_line_num [esp - 4]

   mov   esi, strings
   mov   edi, index
   mov   dword  cur_line_num, 1

   mov   [edi], esi
   add   edi, 4

   %macro print_msg_with_line_num 1
   print_msg %1
   mov   eax, cur_line_num
   call  print_num
   print_msg newline
   %endmacro

   ;; when processing data read, we can be in one of two states:
   ;; reading key and reading value.
   ;; also reading first char of line is counted as special case
   ;; in order to skip empty lines.
   ;; thus 3 stages are present:
mark_index:
mark_index_1:
   lodsb                        ; same as "mov al, [esi]; inc esi"
   jmp   [mark_index_1_table + 4 * eax]

mark_index_1_space:             ;; TODO: is it ok to have "" as key? as value?
   mov   [edi], esi  
   add   edi, 4
   jmp   mark_index_3
mark_index_1_cr:
mark_index_1_lf:
   inc   dword [edi - 4]        ; correct last set index value to point to
                                ; start of next line rather than this line
   inc   dword cur_line_num
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
   print_msg_with_line_num err_no_spaces_in_line
   jmp program_exit
mark_index_2_zero:
   print_msg_with_line_num err_line_ends_unexpectedly
   jmp program_exit

mark_index_3:
   lodsb
   jmp   [mark_index_3_table + 4 * eax]

mark_index_3_cr:
mark_index_3_lf:
   mov   [edi], esi
   add   edi, 4
   mov   byte   [esi - 1], 0    ;; terminate value-string with '\0'
   inc   dword cur_line_num
   jmp   mark_index
mark_index_3_space:
   print_msg_with_line_num err_two_spaces_in_line
   jmp program_exit
mark_index_3_zero:
   jmp mark_index_post

mark_index_post:

   %undef cur_line_num
   %define index_length [esp - 4]

   ;; count index length (number of pairs)
   sub   edi, index
   shr   edi, 3
   mov   index_length, edi

   ;;
   ;; merge sort
   ;;

   mov   ecx, edi
   mov   esi, index
   call  merge_sort

   ;;
   ;; exit
   ;;

program_exit:
   mov   eax, 1                 ; exit program
   xor   ebx, ebx               ; exit code 0
   int   0x80        


