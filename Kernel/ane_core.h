/* SPDX-License-Identifier: GPL-2.0-only */
#ifndef SWIFT_ANE_CORE_H
#define SWIFT_ANE_CORE_H

#include <linux/types.h>

u32 swift_ane_abi_version(void);
s32 swift_ane_is_m1_chip(u32 chip_id);

#endif
