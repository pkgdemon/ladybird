/*
 * Copyright (c) 2023-2025, Tim Flynn <trflynn89@ladybird.org>
 * Copyright (c) 2024, the Ladybird developers.
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

#include <AK/Enumerate.h>
#include <LibMain/Main.h>
#include <LibWebView/Application.h>
#include <LibWebView/BrowserProcess.h>
#include <LibWebView/URL.h>

#import <Application/Application.h>
#import <Application/ApplicationDelegate.h>

#if !__has_feature(objc_arc)
#    error "This project requires ARC"
#endif

ErrorOr<int> ladybird_main(Main::Arguments arguments)
{
    AK::set_rich_debug_enabled(true);

    auto app = TRY(Ladybird::Application::create(arguments));
    WebView::BrowserProcess browser_process;

    if (auto const& browser_options = WebView::Application::browser_options(); !browser_options.headless_mode.has_value()) {
        if (browser_options.force_new_process == WebView::ForceNewProcess::No) {
            auto disposition = TRY(browser_process.connect(browser_options.raw_urls, browser_options.new_window));

            if (disposition == WebView::BrowserProcess::ProcessDisposition::ExitProcess) {
                outln("Opening in existing process");
                return 0;
            }
        }

        auto* delegate = [[ApplicationDelegate alloc] init];
        [NSApp setDelegate:delegate];

        [delegate applicationDidFinishLaunching:nil];
    }

    return WebView::Application::the().execute();
}
