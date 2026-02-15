/*
 * Copyright (c) 2025, Tim Flynn <trflynn89@ladybird.org>
 * Copyright (c) 2025, Joe Maloney <jpm820@proton.me>
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

#pragma once

#include <AK/String.h>
#include <AK/Vector.h>

#import <AppKit/AppKit.h>

@protocol AutocompleteObserver <NSObject>

- (void)onSelectedSuggestion:(String)suggestion;

@end

@interface Autocomplete : NSPanel <NSTableViewDataSource, NSTableViewDelegate>

- (instancetype)init:(id<AutocompleteObserver>)observer
     withToolbarItem:(NSToolbarItem*)toolbar_item;

- (void)showWithSuggestions:(Vector<String>)suggestions;
- (BOOL)close;

- (Optional<String>)selectedSuggestion;

- (BOOL)selectNextSuggestion;
- (BOOL)selectPreviousSuggestion;

@end
