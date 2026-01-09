/*
 * Copyright (c) 2024-2025, the Ladybird developers.
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

#pragma once

#import <Platform.h>

#if LADYBIRD_HAS_NSTABVIEW

#import <Cocoa/Cocoa.h>

#include <LibURL/URL.h>

@class GNUstepBrowserWindow;
@class LadybirdWebView;

@interface BrowserTab : NSTabViewItem

- (instancetype)init;

// Navigation
- (void)loadURL:(URL::URL const&)url;
- (void)navigateBack;
- (void)navigateForward;
- (void)reload;

// View management
- (void)handleVisibility:(BOOL)visible;
- (void)handleResize;

// Properties
@property (nonatomic, strong) LadybirdWebView* webView;
@property (nonatomic, strong) NSString* title;
@property (nonatomic, strong) NSImage* favicon;
@property (nonatomic, weak) GNUstepBrowserWindow* browserWindow;

// URL accessor
- (NSString*)currentURLString;

@end

#endif // LADYBIRD_HAS_NSTABVIEW
