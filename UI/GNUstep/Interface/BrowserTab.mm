/*
 * Copyright (c) 2024-2025, the Ladybird developers.
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

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
{
    LadybirdWebView* m_web_view;
}
@end

@implementation BrowserTab

static NSUInteger s_tab_counter = 0;

- (instancetype)init
{
    NSString* identifier = [NSString stringWithFormat:@"tab-%lu", (unsigned long)++s_tab_counter];

    self = [super initWithIdentifier:identifier];
    if (self) {
        self.title = @"New Tab";
        [self setLabel:@"New Tab"];

        // Create web view with self as observer
        m_web_view = [[LadybirdWebView alloc] init:self];

        // Set web view as the tab's content view
        [self setView:m_web_view];
    }
    return self;
}

- (LadybirdWebView*)web_view
{
    return m_web_view;
}

#pragma mark - Navigation

- (void)loadURL:(URL::URL const&)url
{
    [m_web_view loadURL:url];
}

- (void)navigateBack
{
    [m_web_view view].navigate_back_action().activate();
}

- (void)navigateForward
{
    [m_web_view view].navigate_forward_action().activate();
}

- (void)reload
{
    WebView::Application::the().reload_action().activate();
}

#pragma mark - View Management

- (void)handleVisibility:(BOOL)visible
{
    [m_web_view handleVisibility:visible];
}

- (void)handleResize
{
    [m_web_view handleResize];
}

- (void)clearHistory
{
    // TODO: Implement history clearing
}

- (NSString*)currentURLString
{
    auto& view = [m_web_view view];
    return Ladybird::string_to_ns_string(view.url().serialize());
}

#pragma mark - LadybirdWebViewObserver

- (String const&)onCreateNewTab:(Optional<URL::URL> const&)url
                    activateTab:(Web::HTML::ActivateTab)activate_tab
{
    // Create new tab in the same browser window
    BrowserTab* newTab = [self.browserWindow createNewTab];

    if (url.has_value()) {
        [newTab loadURL:url.value()];
    }

    if (activate_tab == Web::HTML::ActivateTab::Yes) {
        [self.browserWindow selectTab:newTab];
    }

    return [[newTab web_view] handle];
}

- (String const&)onCreateChildTab:(Optional<URL::URL> const&)url
                      activateTab:(Web::HTML::ActivateTab)activate_tab
                        pageIndex:(u64)page_index
{
    // For now, treat child tabs the same as new tabs
    (void)page_index;
    return [self onCreateNewTab:url activateTab:activate_tab];
}

- (void)onLoadStart:(URL::URL const&)url isRedirect:(BOOL)is_redirect
{
    (void)is_redirect;

    self.title = Ladybird::string_to_ns_string(url.serialize());
    [self setLabel:self.title];
    [self.browserWindow.tabView setNeedsDisplay:YES];

    if ([self.browserWindow activeTab] == self) {
        [self.browserWindow.browserToolbar updateForTab:self];
    }
}

- (void)onLoadFinish:(URL::URL const&)url
{
    (void)url;
}

- (void)onURLChange:(URL::URL const&)url
{
    (void)url;

    // Update toolbar if this is the active tab
    if ([self.browserWindow activeTab] == self) {
        [self.browserWindow.browserToolbar updateForTab:self];
    }
}

- (void)onTitleChange:(Utf16String const&)title
{
    self.title = Ladybird::utf16_string_to_ns_string(title);
    [self setLabel:self.title];
    [self.browserWindow.tabView setNeedsDisplay:YES];

    if ([self.browserWindow activeTab] == self) {
        [self.browserWindow setTitle:self.title];
    }
}

- (void)onFaviconChange:(Gfx::Bitmap const&)bitmap
{
    self.favicon = Ladybird::gfx_bitmap_to_ns_image(bitmap);
}

- (void)onAudioPlayStateChange:(Web::HTML::AudioPlayState)play_state
{
    (void)play_state;
}

- (void)onFindInPageResult:(size_t)current_match_index
           totalMatchCount:(Optional<size_t> const&)total_match_count
{
    (void)current_match_index;
    (void)total_match_count;
}

@end
