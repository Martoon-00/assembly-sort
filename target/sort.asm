   section .text
   global _start   
_start:         
   ;; initialization


   ;; read all strings from a file

   mov   eax, 5                 ; open file
   mov   ebx, input_filename
   mov   ecx, 0                 ; read-only mode
   int   0x80

   jge open_file_success
   ;;TODO:
   jmp program_exit   

open_file_success:
   mov   esi, eax

   mov   edi, strings

read_file_strings:
   mov   eax, 3                 ; read
   mov   ebx, esi               ; from opened file
   mov   ecx, edi
   mov   edx, 10
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

   mov   eax, 6                 ; close file
   mov   ebx, esi
   int   0x80


   ;; process data


   ;; exit
program_exit:
   mov   eax,1                  ; sys_exit()
   int   0x80        

section	.bss
   strings resb 1000            ;TODO: unlimited

section .data
   input_filename db "sort.in"


