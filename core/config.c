// -------------------------------------------------------------
//  Cubzh Core
//  config.c
//  Created by Adrien Duermael on July 20, 2015.
// -------------------------------------------------------------

#include "config.h"

#include <stdio.h>
#include <stdlib.h>

#include "doubly_linked_list.h"

// returns closest upper power of two
unsigned long upper_power_of_two(unsigned long v) {
    v--;
    v |= v >> 1;
    v |= v >> 2;
    v |= v >> 4;
    v |= v >> 8;
    v |= v >> 16;
    v++;
    return v;
}
