/*
* Copyright (C) 2013 The Android Open Source Project
* All rights reserved.
*
* Redistribution and use in source and binary forms, with or without
* modification, are permitted provided that the following conditions
* are met:
* * Redistributions of source code must retain the above copyright
* notice, this list of conditions and the following disclaimer.
* * Redistributions in binary form must reproduce the above copyright
* notice, this list of conditions and the following disclaimer in
* the documentation and/or other materials provided with the
* distribution.
*
* THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
* "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
* LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
* FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
* COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
* INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
* BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS
* OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED
* AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
* OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT
* OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
* SUCH DAMAGE.
*/

/* from libc/private/bionic_asm.h */
#include <asm/unistd.h> /* For system call numbers. */
#define MAX_ERRNO 4095  /* For recognizing system call error returns. */

#define __bionic_asm_custom_entry(f)
#define __bionic_asm_custom_end(f)
#define __bionic_asm_function_type @function

#include <machine/asm.h>

    .hidden __set_errno

ENTRY(b2g_prlimit64)
#if defined(__aarch64__)
    stp     x29, x30, [sp, #-16]!
    mov     x29,  sp
    str     x8,       [sp, #-16]!

    mov     x8, __NR_prlimit64
    svc     #0

    ldr     x8,       [sp], #16
    ldp     x29, x30, [sp], #16

    cmn     x0, #(MAX_ERRNO + 1)
    cneg    x0, x0, hi
    b.hi    __set_errno

    ret
#elif defined(__arm__)
    mov     ip, r7
    ldr     r7, =__NR_prlimit64
    swi     #0
    mov     r7, ip
    cmn     r0, #(MAX_ERRNO + 1)
    bxls    lr
    neg     r0, r0
    b       __set_errno
#elif defined(__amd64__)
    movq    %rcx, %r10
    movl    $__NR_prlimit64, %eax
    syscall
    cmpq    $-MAX_ERRNO, %rax
    jb      1f
    negl    %eax
    movl    %eax, %edi
    call    __set_errno
1:
    ret
#else /* x86 */
    pushl   %ebx
    pushl   %ecx
    pushl   %edx
    pushl   %esi
    .cfi_def_cfa_offset 16
    .cfi_rel_offset ebx, 0
    .cfi_rel_offset ecx, 4
    .cfi_rel_offset edx, 8
    .cfi_rel_offset esi, 12
    mov     20(%esp), %ebx
    mov     24(%esp), %ecx
    mov     28(%esp), %edx
    mov     32(%esp), %esi
    movl    $__NR_prlimit64, %eax
    int     $0x80
    cmpl    $-MAX_ERRNO, %eax
    jb      1f
    negl    %eax
    pushl   %eax
    call    __set_errno
    addl    $4, %esp
    orl     $-1, %eax
1:
    popl    %esi
    popl    %edx
    popl    %ecx
    popl    %ebx
    ret
#endif
END(b2g_prlimit64)
