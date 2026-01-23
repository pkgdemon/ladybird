/*
 * Copyright (c) 2025, Tim Flynn <trflynn89@ladybird.org>
 * Copyright (c) 2025, Joe Maloney <jpm820@proton.me>
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

#pragma once

#include <LibWebView/Menu.h>

#import <AppKit/AppKit.h>

@class LadybirdWebView;

namespace Ladybird {

NSMenu* create_application_menu(WebView::Menu&);
NSMenu* create_context_menu(LadybirdWebView*, WebView::Menu&);

NSMenuItem* create_application_menu_item(WebView::Action&);
NSButton* create_application_button(WebView::Action&);

void set_control_title(id control, NSString* title);

}
