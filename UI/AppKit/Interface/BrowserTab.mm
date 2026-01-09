/*
 * Copyright (c) 2024-2025, the Ladybird developers.
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

#import <Platform.h>

#if LADYBIRD_HAS_NSTABVIEW

#include <AK/String.h>
#include <LibURL/URL.h>
#include <LibWebView/Application.h>
#include <LibWebView/Menu.h>
#include <LibWebView/ViewImplementation.h>

#import <Application/ApplicationDelegate.h>
#import <Interface/BrowserTab.h>
#import <Interface/BrowserToolbar.h>
#import <Interface/GNUstepBrowserWindow.h>
#import <Interface/LadybirdWebView.h>
#import <Utilities/Conversions.h>

#if !__has_feature(objc_arc)
#    error "This project requires ARC"
#endif

@interface BrowserTab () <LadybirdWebViewObserver>
@end

@implementation BrowserTab

static NSUInteger s_tab_counter = 0;

- (instancetype)init
{
    NSString* identifier = [NSString stringWithFormat:@"tab-%lu", (unsigned long)++s_tab_counter];

    self = [super initWithIdentifier:identifier];
    if (self) {
        NSLog(@"BrowserTab: init with identifier %@", identifier);
        fflush(stderr);

        self.title = @"New Tab";
        [self setLabel:@"New Tab"];

        // Create web view with self as observer
        self.webView = [[LadybirdWebView alloc] init:self];

        // Set web view as the tab's content view
        [self setView:self.webView];

        NSLog(@"BrowserTab: init complete");
        fflush(stderr);
    }
    return self;
}

#pragma mark - Navigation

- (void)loadURL:(URL::URL const&)url
{
    NSLog(@"BrowserTab: loadURL: %s", url.serialize().to_byte_string().characters());
    fflush(stderr);
    [self.webView loadURL:url];
}

- (void)navigateBack
{
    [self.webView view].navigate_back_action().activate();
}

- (void)navigateForward
{
    [self.webView view].navigate_forward_action().activate();
}

- (void)reload
{
    WebView::Application::the().reload_action().activate();
}

#pragma mark - View Management

- (void)handleVisibility:(BOOL)visible
{
    [self.webView handleVisibility:visible];
}

- (void)handleResize
{
    [self.webView handleResize];
}

- (NSString*)currentURLString
{
    auto& view = [self.webView view];
    return Ladybird::string_to_ns_string(view.url().serialize());
}

#pragma mark - LadybirdWebViewObserver

- (String const&)onCreateNewTab:(Optional<URL::URL> const&)url
                    activateTab:(Web::HTML::ActivateTab)activate_tab
{
    NSLog(@"BrowserTab: onCreateNewTab");
    fflush(stderr);

    // Create new tab in the same browser window
    BrowserTab* newTab = [self.browserWindow createNewTab];

    if (url.has_value()) {
        [newTab loadURL:url.value()];
    }

    if (activate_tab == Web::HTML::ActivateTab::Yes) {
        [self.browserWindow selectTab:newTab];
    }

    return [[newTab webView] handle];
}

- (String const&)onCreateChildTab:(Optional<URL::URL> const&)url
                      activateTab:(Web::HTML::ActivateTab)activate_tab
                        pageIndex:(u64)page_index
{
    NSLog(@"BrowserTab: onCreateChildTab pageIndex=%lu", (unsigned long)page_index);
    fflush(stderr);

    // For now, treat child tabs the same as new tabs
    // In the future, this could maintain parent-child relationship
    return [self onCreateNewTab:url activateTab:activate_tab];
}

- (void)onLoadStart:(URL::URL const&)url isRedirect:(BOOL)is_redirect
{
    NSLog(@"BrowserTab: onLoadStart: %s redirect=%d", url.serialize().to_byte_string().characters(), is_redirect);
    fflush(stderr);

    self.title = Ladybird::string_to_ns_string(url.serialize());
    [self setLabel:self.title];

    // Update toolbar if this is the active tab
    if ([self.browserWindow activeTab] == self) {
        [self.browserWindow.browserToolbar updateForTab:self];
    }
}

- (void)onLoadFinish:(URL::URL const&)url
{
    NSLog(@"BrowserTab: onLoadFinish: %s", url.serialize().to_byte_string().characters());
    fflush(stderr);
}

- (void)onURLChange:(URL::URL const&)url
{
    NSLog(@"BrowserTab: onURLChange: %s", url.serialize().to_byte_string().characters());
    fflush(stderr);

    // Update toolbar if this is the active tab
    if ([self.browserWindow activeTab] == self) {
        [self.browserWindow.browserToolbar updateForTab:self];
    }
}

- (void)onTitleChange:(Utf16String const&)title
{
    self.title = Ladybird::utf16_string_to_ns_string(title);
    [self setLabel:self.title];

    NSLog(@"BrowserTab: onTitleChange: %@", self.title);
    fflush(stderr);

    // Update window title if this is the active tab
    if ([self.browserWindow activeTab] == self) {
        [self.browserWindow setTitle:self.title];
    }
}

- (void)onFaviconChange:(Gfx::Bitmap const&)bitmap
{
    self.favicon = Ladybird::gfx_bitmap_to_ns_image(bitmap);
    // NSTabViewItem doesn't support icons directly, so we just store it
}

- (void)onAudioPlayStateChange:(Web::HTML::AudioPlayState)play_state
{
    // NSTabView doesn't support accessory views like macOS tab groups
    (void)play_state;
}

- (void)onFindInPageResult:(size_t)current_match_index
           totalMatchCount:(Optional<size_t> const&)total_match_count
{
    // TODO: Implement search panel for BrowserTab
    (void)current_match_index;
    (void)total_match_count;
}

@end

#endif // LADYBIRD_HAS_NSTABVIEW
