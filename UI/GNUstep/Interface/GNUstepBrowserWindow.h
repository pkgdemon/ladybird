/*
 * Copyright (c) 2024-2025, the Ladybird developers.
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

#pragma once

#import <AppKit/AppKit.h>
#import <Foundation/Foundation.h>

@class BrowserTab;
@class BrowserToolbar;
@class GNUstepBrowserWindow;

// Custom NSTabView with context menu support
@interface BrowserTabView : NSTabView

@property (nonatomic, weak) GNUstepBrowserWindow* browserWindow;

@end

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
@property (nonatomic, strong) BrowserTabView* tabView;
@property (nonatomic, strong) BrowserToolbar* browserToolbar;

@end
