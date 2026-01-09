/*
 * Copyright (c) 2024-2025, the Ladybird developers.
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

#pragma once

#import <Platform.h>

#if LADYBIRD_HAS_NSTABVIEW

#import <Cocoa/Cocoa.h>

@class GNUstepBrowserWindow;
@class BrowserTab;

@interface BrowserToolbar : NSObject <NSToolbarDelegate, NSTextFieldDelegate>

- (instancetype)initWithWindow:(GNUstepBrowserWindow*)window;

// Toolbar synchronization
- (void)updateForTab:(BrowserTab*)tab;
- (void)setLocationText:(NSString*)text;
- (void)focusLocationField;

// Accessors
- (NSToolbar*)toolbar;

// Properties
@property (nonatomic, weak) GNUstepBrowserWindow* browserWindow;
@property (nonatomic, strong) NSTextField* locationField;

@end

#endif // LADYBIRD_HAS_NSTABVIEW
