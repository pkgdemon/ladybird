/*
 * Copyright (c) 2024, the Ladybird developers.
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

#pragma once

// Platform detection for GNUstep vs macOS AppKit compatibility

#if defined(GNUSTEP) || defined(__GNUSTEP_RUNTIME__)
#    define LADYBIRD_GNUSTEP 1
#    define LADYBIRD_APPLE 0
#else
#    define LADYBIRD_GNUSTEP 0
#    define LADYBIRD_APPLE 1
#endif

// Feature availability macros
#define LADYBIRD_HAS_METAL LADYBIRD_APPLE
#define LADYBIRD_HAS_POPOVER LADYBIRD_APPLE
#define LADYBIRD_HAS_STACKVIEW LADYBIRD_APPLE
#define LADYBIRD_HAS_IOSURFACE LADYBIRD_APPLE
#define LADYBIRD_HAS_UNIFORMTYPEIDENTIFIERS LADYBIRD_APPLE
#define LADYBIRD_HAS_CFRUNLOOP LADYBIRD_APPLE
