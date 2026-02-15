/*
 * Copyright (c) 2024, Tim Flynn <trflynn89@serenityos.org>
 * Copyright (c) 2025, Joe Maloney <jpm820@proton.me>
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

#pragma once

#include <AK/Optional.h>

#import <AppKit/AppKit.h>

@interface SearchPanel : NSView <NSTextFieldDelegate>

- (void)find:(id)selector;
- (void)findNextMatch:(id)selector;
- (void)findPreviousMatch:(id)selector;
- (void)useSelectionForFind:(id)selector;
- (void)onFindInPageResult:(size_t)current_match_index
           totalMatchCount:(Optional<size_t> const&)total_match_count;

@end
