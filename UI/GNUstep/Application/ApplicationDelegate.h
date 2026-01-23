/*
 * Copyright (c) 2023-2025, Tim Flynn <trflynn89@ladybird.org>
 * Copyright (c) 2024, the Ladybird developers.
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

#pragma once

#include <AK/Optional.h>
#include <AK/StringView.h>
#include <LibURL/URL.h>
#include <LibWeb/HTML/ActivateTab.h>

#import <AppKit/AppKit.h>
#import <Foundation/Foundation.h>

@class BrowserTab;
@class GNUstepBrowserWindow;

@interface ApplicationDelegate : NSObject <NSApplicationDelegate>

- (nullable instancetype)init;

- (nullable BrowserTab*)activeTab;
- (nullable GNUstepBrowserWindow*)activeWindow;

- (void)onDevtoolsEnabled;
- (void)onDevtoolsDisabled;

@end
