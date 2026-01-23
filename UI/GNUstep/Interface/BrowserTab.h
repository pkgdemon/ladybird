/*
 * Copyright (c) 2024-2025, the Ladybird developers.
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

#pragma once

#import <AppKit/AppKit.h>
#import <Foundation/Foundation.h>

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

// History
- (void)clearHistory;

// Properties
@property (nonatomic, readonly) LadybirdWebView* web_view;
@property (nonatomic, strong) NSString* title;
@property (nonatomic, strong) NSImage* favicon;
@property (nonatomic, weak) GNUstepBrowserWindow* browserWindow;

// URL accessor
- (NSString*)currentURLString;

@end
