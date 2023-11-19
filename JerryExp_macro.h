#ifndef JERRYEXP_MACRO_H
#define JERRYEXP_MACRO_H


#define DISABLE_process_large_req_one_st_copy
#define DISABLE_process_resp_one_st_copy
#define START_TIMER uint64_t timmer_profile_start = erpc::rdtsc();
#define SHOW_TIMER printf("Time is %f\n", erpc::to_usec(erpc::rdtsc() - timmer_profile_start, 2));

#endif