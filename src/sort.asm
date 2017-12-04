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

   ;; Sets %edi to the end of heap, in fact initiates new dynamic storage.
   ;; Wastes %eax and %ebx like sys_brk() call.
   %macro start_new_mem 0
   mov   eax, 45                ;; sys_brk
   xor   ebx, ebx               ;; just get current heap end
   int   0x80
   
   mov   edi, eax
   %endmacro

   ;; Ensures that at least %1 bytes in front of %edi are allocated memory.
   ;; Allocates %2 bytes if more memory is needed.
   ;; Wastes %eax and %ebx like sys_brk() call.
   %macro ensure_mem_with 2
   mov   eax, 45                ;; sys_brk
   xor   ebx, ebx               ;; just get current heap end
   int   0x80 

   mov   ebx, eax
   sub   ebx, %1
   sub   ebx, edi
   ja    .skip_alloc            ;; e?

   lea   ebx, [eax + %2] ;; move heap end on PAGE_SIZE
   mov   eax, 45                ;; sys_brk
   int   0x80
.skip_alloc:
   %endmacro

   ;; Shorcut for ensure_mem_with
   %macro ensure_mem 1
   ensure_mem_with %1, PAGE_SIZE
   %endmacro
 
   ;; Maximal string length which could be passed.
   %define string_max_len 0x100
   ;; How much memory allocate per time.
   %define PAGE_SIZE 0x1000

   ;;
   ;;
   ;; Data
   ;;
   ;;

   %define string_max_len 256

   section .bss
   ;; temporal storage for 'print_num' functions
   print_num_buffer resb 11
   ;; buffer used to accept user queries
   interact_read_buffer resb string_max_len + 1


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

interact_read_table:             
      times 10 dd interact_read,
      dd    interact_read_cr, 
      times 2 dd interact_read,
      dd    interact_read_lf, 
      times 18 dd interact_read,
      dd    interact_read_space, 
      times 223 dd interact_read

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

   alloc_msg err_unexpected_space_in_query, "Unexpected space in query", 10
   alloc_msg err_key_not_found, "Key not found", 10

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
;;; Return Val: none
;;; 
;;; Registers Used: all
;;; Stack Depth: 9 * log(index_length)
;;; 
;;;;;;;;; 
merge_sort:
   push  esi
   push  ecx

   ;; clone 'index' to 'index_temp'
   start_new_mem
   push  edi

   shl   ecx, 4                 ; length is given in quadruples of dword addresses
                                ; converting to bytes
   ensure_mem_with ecx, ecx

   shr   ecx, 2                 ; quadruples of dwords to dwords
   rep   movsd        
   pop   esi
   pop   ecx
   pop   edi

;;; Arguments for recursive version:
;;;   %esi - temp storage for index
;;;   %edi - where to store sorted index
;;;   %ecx - length of sorted part
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
   shl   eax, 4
   add   esi, eax
   push  esi
   sub   esi, eax
   shr   ecx, 1
   mov   eax, ecx
   shl   eax, 4
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
   ;; $ecx initialized
   call  merge_sort_rec
   
   mov   ecx, length
   mov   edi, source
   mov   eax, ecx
   inc   ecx
   mov   esi, dest
   shr   eax, 1
   shr   ecx, 1
   shl   eax, 4
   lea   edi, [edi + eax]
   lea   esi, [esi + eax]
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
   ;; first compare lengths
   mov   ecx, [esi + 4]
   cmp   ecx, [edi + 4]
   jg    .greater
   jl    .lesser

   ;; then compare content
   mov   esi, [esi]
   mov   edi, [edi]
   ;; ecx initialized
   repe  cmpsb
   jg    .greater

.lesser:
   mov   esi, source
   mov   edi, dest
   mov   ecx, 4
   rep   movsd
   mov   dest, edi
   mov   source, esi
   jmp   merge_sort_combine

.greater:
   mov   esi, source_mid
   mov   edi, dest
   mov   ecx, 4
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

   %define stack_allocated 16
   sub   esp, stack_allocated

   cld                          ;; clear direction flag

   ;;
   ;; read all strings from a file
   ;;

   ;; open file

   mov   eax, 5                 ; open file
   mov   ebx, input_filename
   mov   ecx, 0x00              ; read-only mode
   int   0x80

   cmp   eax, 0
   jge   open_file_success

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

   %define strings [esp + 8]    ;; data read from file

   ;; init storage for data from file
   start_new_mem
   mov   strings, edi

read_file_strings:
   ;; allocate more space if needed
   ensure_mem PAGE_SIZE

   ;; perform read
   mov   eax, 3                 ; read
   mov   ebx, esi               ; from opened file
   mov   ecx, edi               ; to buffer
   mov   edx, PAGE_SIZE         ; up to PAGE_SIZE chars per read
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
   jz    read_file_error_dir
   cmp   eax, 5                 ; I/O error
   jz    read_file_error_io
   cmp   eax, 4                 ; caught interrupt
   jz    read_file_error_int

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
   ;; index is array of (key_addr, key_len, value_addr, value_len),
   ;; thus each element of this array uses 16 bytes.
   ;;
   ;; I also replace '\n' after each value with '\0' for easier build-in printing ;; TODO:
   ;;

   %define cur_line_num [esp + 4]
   %define index [esp + 12]     ;; index

   ;; init
   mov   esi, strings           ;; pointer to current element in 'string'
   start_new_mem 
   mov   index, edi
   mov   dword  cur_line_num, 1

   ;; init first elem of index
   ensure_mem 16
   mov   [edi], esi
   add   edi, 8

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
   mov   ecx, -1                ;; current length of current string
   xor   eax, eax               ;; keep %eax = %al

mark_index_1:
   inc   ecx
   lodsb                        ; same as "mov al, [esi]; inc esi"
   jmp   [mark_index_1_table + 4 * eax]

mark_index_1_space:             ;; TODO: is it ok to have "" as key? as value?
   mov   [edi], esi
   mov   [edi - 4], ecx
   add   edi, 8
   jmp   mark_index_mid
mark_index_1_cr:
mark_index_1_lf:
   inc   dword [edi - 8]        ; correct last set index value to point to
                                ; start of next line rather than this line
   inc   dword cur_line_num
   jmp mark_index
mark_index_1_zero:
   jmp mark_index_post

mark_index_2:
   inc   ecx
   lodsb
   jmp   [mark_index_2_table + 4 * eax]

mark_index_2_space:
   mov   [edi], esi
   mov   [edi - 4], ecx
   add   edi, 8
   jmp   mark_index_mid
mark_index_2_cr:
mark_index_2_lf:
   print_msg_with_line_num err_no_spaces_in_line
   jmp program_exit
mark_index_2_zero:
   print_msg_with_line_num err_line_ends_unexpectedly
   jmp program_exit

mark_index_mid:
   mov   ecx, -1

mark_index_3:
   inc   ecx
   lodsb
   jmp   [mark_index_3_table + 4 * eax]

mark_index_3_cr:
mark_index_3_lf:
   mov   [edi], esi
   mov   [edi - 4], ecx
   add   edi, 8
   mov   byte   [esi - 1], 0    ;; terminate value-string with '\0'
   inc   dword cur_line_num

   ;; allocate more memory if needed
   ensure_mem 16

   jmp   mark_index
mark_index_3_space:
   print_msg_with_line_num err_two_spaces_in_line
   jmp program_exit
mark_index_3_zero:
   mov   [edi - 4], ecx
   jmp mark_index_post

mark_index_post:

   %undef cur_line_num
   %define index_length [esp + 4]

   ;; count index length (number of key-value entries)
   sub   edi, index
   shr   edi, 4
   mov   index_length, edi

   ;;
   ;; merge sort
   ;;

   mov   ecx, edi
   mov   esi, index
   call  merge_sort

   ;;
   ;; serve queries
   ;;

interact:

   ;; read query

   mov esi, interact_read_buffer
interact_read:
   ;; TODO: try reading many bytes at once
   ;; TODO: do smth with empty lines
   mov   eax, 3                 ; read
   mov   ebx, 0                 ; from stdin
   mov   ecx, esi               ; to buffer
   mov   edx, 1                 ; only 1 byte
   int   0x80

   test  eax, eax
   jz    program_exit

   xor   eax, eax
   lodsb
   jmp   [interact_read_table + 4 * eax]

interact_read_space:
   print_msg err_unexpected_space_in_query
   jmp   interact

interact_read_cr:
interact_read_lf:

   %define query_length [esp + 0]
   lea   eax, [interact_read_buffer]
   sub   esi, eax
   dec   esi
   mov   query_length, esi

   ;; binary search
   ;;
   ;; Pseudo code:
   ;;     l = -1
   ;;     r = a.length
   ;;     while (l + 1 != r)
   ;;         m = (l + r) / 2
   ;;         if (x < a[m]) r = m
   ;;         else l = m
   ;;
   ;;     if (l != -1 && a[l] == x) found
   ;;     else not_found
   ;;
   ;; with only difference that I store &a[l] and r - l instead of bounds

   ;; init
   ;; reminder: %ebx always changes on multiple of 16,
   ;; because it is reference to (key, key_len, value, value_len) in index
   mov   ebx, index
   lea   ebx, [ebx - 16]      ;; &a[l]
   mov   edx, index_length
   inc   edx                    ;; r - l

bin_search_loop:
   ;; whether end?
   cmp   edx, 1
   jle   bin_search_loop_post

   ;; count middle
   mov   eax, edx
   shr   eax, 1

   ;; compare strings
   mov   ecx, eax               ;; index offset
   shl   ecx, 4

   ;; first compare lengths
   mov   esi, query_length
   cmp   esi, [ebx + ecx + 4]
   jg    .greater
   jl    .lesser

   ;; if equal, compare chars
   mov   esi, interact_read_buffer
   mov   edi, [ebx + ecx]
   mov   ecx, query_length
   repe  cmpsb
   jge   .greater               ;; TODO: jae? and further

.lesser:
   ;; query is greater than middle key
   mov   edx, eax
   jmp   bin_search_loop

.greater:
   ;; query is lesser
   mov   ecx, eax
   shl   ecx, 4
   lea   ebx, [ebx + ecx]
   sub   edx, eax
   jmp   bin_search_loop

bin_search_loop_post:

   ;; final comparisons
   ;; l == -1 ?
   cmp   ebx, index
   jl    bin_search_not_found

   ;; compare lengths
   mov   esi, query_length
   cmp   esi, [ebx + 4]
   jne   bin_search_not_found

   ;; compare content
   mov   esi, [ebx]
   mov   edi, interact_read_buffer
   mov   ecx, query_length
   repe  cmpsb
   je    bin_search_found

bin_search_not_found:
   ;; print error
   print_msg err_key_not_found
   jmp   interact

bin_search_found:
   ;; print value
   mov   eax, 4                 ; write
   mov   ecx, [ebx + 8]         ; value in index
   mov   edx, [ebx + 12]        ; length of value in index
   mov   ebx, 1                 ; to stdout
   int   0x80

   print_msg newline

   jmp interact
   %undef query_length

   ;;
   ;; exit
   ;;

program_exit:
   %undef strings
   %undef index

   add   esp, stack_allocated
   %undef stack_allocated

   mov   eax, 1                 ; exit program
   xor   ebx, ebx               ; exit code 0
   int   0x80        

