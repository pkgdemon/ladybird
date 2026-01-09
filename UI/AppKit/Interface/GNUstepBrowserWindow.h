/*
 * Copyright (c) 2024-2025, the Ladybird developers.
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

#pragma once

#import <Platform.h>

#if LADYBIRD_HAS_NSTABVIEW

#import <Cocoa/Cocoa.h>

@class BrowserTab;
@class BrowserToolbar;

@interface GNUstepBrowserWindow : NSWindow <NSTabViewDelegate, NSWindowDelegate>

- (instancetype)init;

// Tab Management
- (BrowserTab*)createNewTab;
- (BrowserTab*)activeTab;
- (NSArray<BrowserTab*>*)allTabs;
- (void)closeTab:(BrowserTab*)tab;
- (void)selectTab:(BrowserTab*)tab;
- (NSUInteger)tabCount;

// Properties
@property (nonatomic, strong) NSTabView* tabView;
@property (nonatomic, strong) BrowserToolbar* browserToolbar;

@end

#endif // LADYBIRD_HAS_NSTABVIEW
