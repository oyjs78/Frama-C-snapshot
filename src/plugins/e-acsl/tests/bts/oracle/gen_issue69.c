/* Generated by Frama-C */
#include "stdio.h"
#include "stdlib.h"
int main(void)
{
  int __retres;
  __e_acsl_memory_init((int *)0,(char ***)0,(size_t)8);
  /*@ assert ∀ unsigned char c; 4 ≤ c ≤ 300 ⇒ 0 ≤ c ≤ 255; */
  {
    int __gen_e_acsl_forall;
    int __gen_e_acsl_c;
    __gen_e_acsl_forall = 1;
    __gen_e_acsl_c = (unsigned char)4;
    while (1) {
      if (__gen_e_acsl_c <= 255) ; else break;
      {
        int __gen_e_acsl_and;
        if (0 <= __gen_e_acsl_c) __gen_e_acsl_and = __gen_e_acsl_c <= 255;
        else __gen_e_acsl_and = 0;
        if (__gen_e_acsl_and) ;
        else {
          __gen_e_acsl_forall = 0;
          goto e_acsl_end_loop1;
        }
      }
      __gen_e_acsl_c ++;
    }
    e_acsl_end_loop1: ;
    __e_acsl_assert(__gen_e_acsl_forall,(char *)"Assertion",(char *)"main",
                    (char *)"\\forall unsigned char c; 4 <= c <= 300 ==> 0 <= c <= 255",
                    6);
  }
  int n = 5;
  /*@ assert \let m = n > 0? 4: 341; ∀ char u; 1 < u < m ⇒ u > 0; */
  {
    int __gen_e_acsl_m;
    int __gen_e_acsl_if;
    int __gen_e_acsl_forall_2;
    int __gen_e_acsl_u;
    if (n > 0) __gen_e_acsl_if = 4; else __gen_e_acsl_if = 341;
    __gen_e_acsl_m = __gen_e_acsl_if;
    __gen_e_acsl_forall_2 = 1;
    __gen_e_acsl_u = (char)1 + 1;
    while (1) {
      {
        int __gen_e_acsl_and_2;
        if (-128 <= __gen_e_acsl_u) __gen_e_acsl_and_2 = __gen_e_acsl_u <= 127;
        else __gen_e_acsl_and_2 = 0;
        __e_acsl_assert(__gen_e_acsl_and_2,(char *)"RTE",(char *)"main",
                        (char *)"-128 <= u <= 127",11);
      }
      if (__gen_e_acsl_u < __gen_e_acsl_m) ; else break;
      if (__gen_e_acsl_u > 0) ;
      else {
        __gen_e_acsl_forall_2 = 0;
        goto e_acsl_end_loop2;
      }
      __gen_e_acsl_u ++;
    }
    e_acsl_end_loop2: ;
    __e_acsl_assert(__gen_e_acsl_forall_2,(char *)"Assertion",(char *)"main",
                    (char *)"\\let m = n > 0? 4: 341;\n\\forall char u; 1 < u < m ==> u > 0",
                    10);
  }
  __retres = 0;
  return __retres;
}


