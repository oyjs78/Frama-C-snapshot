/* Generated by Frama-C */
#include "ctype.h"
#include "stdio.h"
#include "stdlib.h"
extern int __e_acsl_sound_verdict;

int main(int argc, char const **argv)
{
  int __retres;
  int tmp;
  __e_acsl_memory_init(& argc,(char ***)(& argv),(size_t)8);
  tmp = __gen_e_acsl_isupper(argc);
  char c = (char)tmp;
  __e_acsl_store_block((void *)(& c),(size_t)1);
  __e_acsl_full_init((void *)(& c));
  char *d = & c;
  __e_acsl_store_block((void *)(& d),(size_t)8);
  __e_acsl_full_init((void *)(& d));
  /*@ assert \valid(d); */
  {
    int __gen_e_acsl_initialized;
    int __gen_e_acsl_and;
    __gen_e_acsl_initialized = __e_acsl_initialized((void *)(& d),
                                                    sizeof(char *));
    if (__gen_e_acsl_initialized) {
      int __gen_e_acsl_valid;
      __gen_e_acsl_valid = __e_acsl_valid((void *)d,sizeof(char),(void *)d,
                                          (void *)(& d));
      __gen_e_acsl_and = __gen_e_acsl_valid;
    }
    else __gen_e_acsl_and = 0;
    __e_acsl_assert(__gen_e_acsl_and,(char *)"Assertion",(char *)"main",
                    (char *)"\\valid(d)",39);
  }
  __retres = 0;
  __e_acsl_delete_block((void *)(& d));
  __e_acsl_delete_block((void *)(& c));
  __e_acsl_memory_clean();
  return __retres;
}


