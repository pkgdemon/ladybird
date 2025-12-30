/*
 * Copyright (c) 2025, Tim Flynn <trflynn89@ladybird.org>
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

#pragma once

#include <AK/String.h>
#include <AK/Vector.h>

#import <Cocoa/Cocoa.h>
#import <Platform.h>

@protocol AutocompleteObserver <NSObject>

- (void)onSelectedSuggestion:(String)suggestion;

@end

#if LADYBIRD_HAS_POPOVER
@interface Autocomplete : NSPopover
#else
@interface Autocomplete : NSPanel
#endif

- (instancetype)init:(id<AutocompleteObserver>)observer
     withToolbarItem:(NSToolbarItem*)toolbar_item;

- (void)showWithSuggestions:(Vector<String>)suggestions;
- (BOOL)close;

- (Optional<String>)selectedSuggestion;

- (BOOL)selectNextSuggestion;
- (BOOL)selectPreviousSuggestion;

@end
