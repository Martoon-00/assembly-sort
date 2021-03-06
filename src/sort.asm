   ;;
   ;;
   ;; Macroses
   ;;
   ;;


   ;; Accepts name of label %2 refering to string and prints it to %1 file
   ;; descriptor. 
   ;; Assumes that variable <labelname>_len is defined and set to length.
   %macro print_to 2
   mov   eax, 4                 ; write
   mov   ebx, %1
   mov   edx, %2_len
   mov   ecx, %2
   int   0x80
   %endmacro 

   ;; Shortcut of 'print_msg_to' to print to stdout
   %macro print_msg 1
   print_to 1, %1
   %endmacro 

   ;; Shortcut of 'print_msg_to' to print to stderr
   %macro print_err 1
   print_to 2, %1
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
   ;; Burns %eax and %ebx like sys_brk() call.
   %macro ensure_mem_with 2
   mov   eax, 45                ;; sys_brk
   xor   ebx, ebx               ;; just get current heap end
   int   0x80 

   mov   ebx, eax
   sub   ebx, %1
   sub   ebx, edi
   jge   %%skip_alloc

   lea   ebx, [eax + %2]        ;; move heap end on PAGE_SIZE
   mov   eax, 45                ;; sys_brk
   int   0x80
%%skip_alloc:
   %endmacro

   ;; fill char jump table
   ;; specify %1 as base name for jump table and labels to jump to
   %macro init_char_table 1
   mov   ecx, 256
   mov   edi, %1_table
   mov   eax, %1_plain_char
   rep   stosd

   mov   dword [%1_table + 4 * 32], %1_space
   mov   dword [%1_table + 4 * 10], %1_ln
   mov   dword [%1_table + 4 * 13], %1_ln
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
   ;; jump tables
   mark_index_1_table resd 256
   mark_index_2_table resd 256
   mark_index_3_table resd 256
   interact_read_table resd 256

   section .data
   ;; predefined filename with input
   input_filename db "sort.in", 0
   alloc_msg input_filename_msg, "sort.in"
   ;; newline for printing
   alloc_msg newline, 10
   ;; for 'print_num'
   print_num_buffer_len dd 10


   ;; errors
   alloc_msg err_open_failed, "Failed to open input file", 10
   alloc_msg err_open_failed_nofile, "File doesn't exist: "

   alloc_msg err_read_file_is_dir, " shouldn't be directory", 10
   alloc_msg err_read_io, "read: io exception", 10
   alloc_msg err_read_int, "read: interrupted", 10
   alloc_msg err_read_unknown, "read: some error", 10

   alloc_msg err_no_spaces_in_line, "No space found in line "
   alloc_msg err_two_spaces_in_line, "More than one space detected on line "
   alloc_msg err_empty_key, "Empty key passed on line "
   alloc_msg err_empty_value, "Empty value passed on line "

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
   mov   ebx, 2                 ; to stderr
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
;;; Stack Depth: 8 * log(index_length)
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
   %define stack_allocated 32
   %define length [esp + 28]    ; passed length
   %define orig_dest [esp + 24] ; passed destination
   %define source [esp + 20]    ; passed source
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

   %define stack_allocated 20
   sub   esp, stack_allocated

   cld                          ;; clear direction flag

   init_char_table mark_index_1
   init_char_table mark_index_2
   init_char_table mark_index_3
   init_char_table interact_read

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

   print_err err_open_failed
   jmp program_exit   
open_file_not_exist:
   print_err err_open_failed_nofile
   print_err input_filename_msg
   print_err newline
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
   cmp   eax, -21                ; file is directory
   jz    .error_dir
   cmp   eax, -5                 ; I/O error
   jz    .error_io
   cmp   eax, -4                 ; caught interrupt
   jz    .error_int

   print_err err_read_unknown
   jmp   program_exit
.error_dir:
   print_err input_filename_msg
   print_err err_read_file_is_dir
   jmp   program_exit
.error_io:
   print_err err_read_io
   jmp   program_exit
.error_int:
   print_err err_read_int
   jmp   program_exit

read_file_post:
   ensure_mem 1
   mov   byte [edi], 10         ;; in case there were no newline at end

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

   %define strings_fin [esp + 0] ;; last symbol in 'strings'
   %define cur_line_num [esp + 4] ;; currently processing line of file
   %define index [esp + 12]     ;; index

   ;; init
   mov   strings_fin, edi
   dec   edi
   mov   esi, strings           ;; pointer to current element in 'string'
   start_new_mem                ;; %edi will point to being-built element in index
   mov   index, edi
   mov   dword  cur_line_num, 1

   ;; init first elem of index
   ensure_mem 16
   mov   [edi], esi
   add   edi, 8

   %macro print_err_with_line_num 1
   print_err %1
   mov   eax, cur_line_num
   call  print_num
   print_err newline
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

mark_index_1_space:
   print_err_with_line_num err_empty_key
   jmp   program_exit
mark_index_1_ln:
   inc   dword [edi - 8]        ; correct last set index value to point to
                                ; start of next line rather than this line
   inc   dword cur_line_num

   ;; whether end?
   cmp   esi, strings_fin
   jae   mark_index_post

   jmp mark_index

mark_index_1_plain_char:
mark_index_2_plain_char:
mark_index_2:
   inc   ecx
   lodsb
   jmp   [mark_index_2_table + 4 * eax]

mark_index_2_space:
   mov   [edi], esi
   mov   [edi - 4], ecx
   add   edi, 8
   jmp   mark_index_mid
mark_index_2_ln:
   print_err_with_line_num err_no_spaces_in_line
   jmp program_exit

mark_index_mid:
   mov   ecx, -1

mark_index_3_plain_char:
mark_index_3:
   inc   ecx
   lodsb
   jmp   [mark_index_3_table + 4 * eax]

mark_index_3_ln:
   test  ecx, ecx
   jnz   mark_index_3_ln_ok_len

   print_err_with_line_num err_empty_value
   jmp program_exit

mark_index_3_ln_ok_len:
   mov   [edi], esi
   mov   [edi - 4], ecx
   add   edi, 8
   mov   byte [esi - 1], 10     ;; dont like '\r'
   inc   dword cur_line_num

   ;; whether end?
   cmp   esi, strings_fin
   jae   mark_index_post

   ;; allocate more memory, if needed, in 'index'
   ensure_mem 16

   jmp   mark_index
mark_index_3_space:
   print_err_with_line_num err_two_spaces_in_line
   jmp program_exit

mark_index_post:

   %undef cur_line_num
   %undef strings_fin
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
   ;; squashing key duplicates in index
   ;;
   ;; having 2 pointers, one goes through index and another points
   ;; on last element of currently building array
   ;;

   %define index_fin [esp + 20]

   mov   ebx, index             ;; pointer to element of newly built array
   mov   edx, ebx               ;; pointer to element of current array
   mov   eax, index_length      ;; array end
   shl   eax, 4
   add   eax, ebx
   mov   index_fin, eax

squash_dups:
   add   ebx, 16

   ;; whether end?
   cmp   ebx, index_fin
   ja    squash_dups_post

   ;; compare length
   mov   ecx, [ebx + 4]
   cmp   ecx, [edx + 4]
   jnz   .nonequal

   ;; then compare content
   mov   esi, [ebx]
   mov   edi, [edx]
   ;; ecx initialized
   repe  cmpsb
   jne   .nonequal
   jmp   .equal

.nonequal:
   ;; if not equal, go further
   add   edx, 16

   mov   eax, [ebx + 0]
   mov   [edx + 0], eax
   mov   eax, [ebx + 4]
   mov   [edx + 4], eax
.equal:
   ;; and in any case copy content
   mov   eax, [ebx + 8]
   mov   [edx + 8], eax
   mov   eax, [ebx + 12]
   mov   [edx + 12], eax
   jmp   squash_dups


   ;; if squashed something,
   ;; set end of new array to zeros for pleasure debugging
squash_dups_post:

   cmp   edx, index_fin
   jae   squash_dups_no_stub_at_fin

   mov   edi, edx
   mov   ecx, 4
   xor   eax, eax
   rep   stosd

squash_dups_no_stub_at_fin:

   ;; reassign length
   sub   edx, index
   shr   edx, 4
   mov   index_length, edx

   ;;
   ;; serve queries
   ;;

   %define is_last_query [esp + 20]
   mov   dword  is_last_query, 0
 
interact:
   cmp   dword  is_last_query, 0
   jnz   interact_post
  
   ;; read query
   mov esi, interact_read_buffer
interact_read_plain_char:
interact_read:
   ;; TODO: try reading many bytes at once
   mov   eax, 3                 ; read
   mov   ebx, 0                 ; from stdin
   mov   ecx, esi               ; to buffer
   mov   edx, 1                 ; only 1 byte
   int   0x80

   cmp   eax, 0
   jz    interact_read_last_query
   jl    interact_read_error

   xor   eax, eax
   lodsb
   jmp   [interact_read_table + 4 * eax]

interact_read_error:
   cmp   eax, -5                 ; I/O error
   jz    .error_io
   cmp   eax, -4                 ; caught interrupt
   jz    .error_int

   print_err err_read_unknown
   jmp   program_exit
.error_io:
   print_err err_read_io
   jmp   program_exit
.error_int:
   print_err err_read_int
   jmp   program_exit

interact_read_space:
   print_err err_unexpected_space_in_query
   jmp   interact

interact_read_last_query:
   mov   dword  is_last_query, 1
   inc   esi                    ;; imagine '\n' was in the end
interact_read_ln:

   ;; count query length, loop if 0
   %define query_length [esp + 0]
   lea   eax, [interact_read_buffer]
   sub   esi, eax
   sub   esi, 1
   jz    interact

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
   jae   .greater

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
   print_err err_key_not_found
   jmp   interact

bin_search_found:
   ;; print value
   mov   eax, 4                 ; write
   mov   ecx, [ebx + 8]         ; value in index
   mov   edx, [ebx + 12]        ; length of value in index
   inc   edx                    ; including newline
   mov   ebx, 1                 ; to stdout
   int   0x80

   %undef query_length

   jmp   interact
interact_post:

   ;;
   ;; exit
   ;;

   ;; since we went so far, let's exit gracefully
   jmp   program_ok_exit

   ;; for those who exited hacky, no sweet end
program_exit:
   mov   ebx, 1                 ;; exit code
   jmp   program_exit_do

program_ok_exit:
   xor   ebx, ebx               ;; exit code

program_exit_do:

   %undef strings
   %undef index

   add   esp, stack_allocated
   %undef stack_allocated

   mov   eax, 1                 ; exit program
   int   0x80        

