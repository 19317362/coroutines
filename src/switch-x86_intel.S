// Copyright (c) 2009, 2011, Pierre-Andre Saulais <pasaulais@free.fr>
// All rights reserved.
// 
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
// * Redistributions of source code must retain the above copyright
//   notice, this list of conditions and the following disclaimer.
// * Redistributions in binary form must reproduce the above copyright
//   notice, this list of conditions and the following disclaimer in the
//   documentation and/or other materials provided with the distribution.
// * Neither the name of the <organization> nor the
//   names of its contributors may be used to endorse or promote products
//   derived from this software without specific prior written permission.
// 
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
// ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
// WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
// DISCLAIMED. IN NO EVENT SHALL <COPYRIGHT HOLDER> BE LIABLE FOR ANY
// DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
// (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
// LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
// ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
// SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

.intel_syntax noprefix
.section .text

// void *coroutine_switch(coroutine_t co, void *arg)
// ecx: co eax: current/arg edx: ctx
coroutine_switch:   .globl coroutine_switch
// save the current context (stack, return address and registers)
    mov edx, dword ptr [esp+12]     // load ctx
    mov eax, dword ptr [edx]        // current = ctx->current
    pop dword ptr [eax+4]           // current->ret_addr = caller
    mov ecx, dword ptr [esp]        // load co
    mov dword ptr [edx], ecx        // ctx->current = co
    mov dword ptr [ecx+12], eax     // co->caller = current
    push ebp                        // save stack frame
    mov dword ptr [eax+8], esp      // current->stack = current stack
    mov eax, dword ptr [esp+8]      // load arg
    test dword ptr [ecx], 1         // if(!(co->ctx_state & STARTED))
    jz coroutine_entry              //   call coroutine_entry

// void *coroutine_return(coroutine_t co, void *arg)
// ecx: co, eax: arg
coroutine_return:
    mov esp, dword ptr [ecx+8]      // restore the coroutine's stack
    pop ebp                         // restore the frame pointer
    push [ecx+4]                    // return to co's caller
    ret

// void coroutine_entry(coroutine_t co, void *arg) no_return
// run the dest coroutine (for the first time)
coroutine_entry:
// ecx: co, eax: arg
    or dword ptr [ecx], 1           // co->state |= STARTED
    mov esp, dword ptr [%ecx+8]     // switch to coroutine's stack
    push ecx                        // save co
    mov edx, dword ptr [ecx]        // ctx = co->ctx_state & ~STATE_MASK
    and edx, -8                     // ...
    push eax                        // co->entry(ctx->user, arg)
    push dword ptr [edx+12]         // ...
    call dword ptr [ecx+16]         // ...

// the coroutine exited, switch back to its last caller
// ecx: caller, eax: co, edx: ctx
    add esp, 8                      // clean the stack after the call
    pop eax                         // restore co
    mov edx, dword ptr  [eax]       // ctx = co->ctx_state & ~STATE_MASK
    and edx, -8                     // ...
    or dword ptr [eax], 2           // co->state |= FINISHED
    mov ecx, dword ptr [eax+12]     // current = co->caller
    mov dword ptr [edx], ecx        // ...
    mov dword ptr [eax+12], 0       // co->caller = NULL
    mov eax, 0                      // coroutine_return(current, 0, ctx)
    jmp coroutine_return
