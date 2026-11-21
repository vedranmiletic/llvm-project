; RUN: llc -mtriple=amdgpu8.02 < %s | FileCheck --check-prefixes=CHECK,TONGA %s
; RUN: llc -mtriple=amdgpu8.03 < %s | FileCheck --check-prefixes=CHECK,FIJI %s

; With the SGPR init bug, the total number of SGPRs of a kernel is limited to
; 96, including its FLAT_SCRATCH, XNACK_MASK and VCC SGPRs. Without an OS, a
; kernel does not set up flat scratch, so it only reserves VCC and places its
; scratch resource descriptor at the top of its SGPR budget. An indirect callee
; is assumed to use flat scratch, though, so a kernel making an indirect call
; must also leave room for the FLAT_SCRATCH SGPRs. Otherwise, it fails with
; "scalar registers (98) exceeds limit (96)", which also makes this test fail.
;
; A kernel calling a function defined in the module only counts the
; FLAT_SCRATCH SGPRs if that function uses flat scratch, so it keeps the higher
; SGPRs. Fiji does not have the SGPR init bug and is not affected.

; CHECK-LABEL: {{^}}indirect_call:
; TONGA: .set .Lindirect_call.numbered_sgpr, max({{([0-9]|[1-8][0-9]|90)}}, amdgpu.max_num_sgpr)
; FIJI: .set .Lindirect_call.numbered_sgpr, max({{[0-9]+}}, amdgpu.max_num_sgpr)
define amdgpu_kernel void @indirect_call(ptr %fptr) {
  call void %fptr()
  ret void
}

define hidden void @callee() #0 {
  ret void
}

; CHECK-LABEL: {{^}}direct_call:
; TONGA: s_mov_b32 s88, SCRATCH_RSRC_DWORD0
; TONGA: .set .Ldirect_call.numbered_sgpr, max(92, .Lcallee.numbered_sgpr)
define amdgpu_kernel void @direct_call() {
  call void @callee()
  ret void
}

attributes #0 = { noinline nounwind }
