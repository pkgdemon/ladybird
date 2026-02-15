/*
 * Copyright (c) 2023-2025, Tim Flynn <trflynn89@ladybird.org>
 * Copyright (c) 2024, the Ladybird developers.
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

#include <LibWebView/Application.h>

#import <Application/ApplicationDelegate.h>
#import <Interface/InfoBar.h>
#import <Interface/LadybirdWebView.h>
#import <Interface/Menu.h>
#import <Interface/BrowserTab.h>
#import <Interface/BrowserToolbar.h>
#import <Interface/GNUstepBrowserWindow.h>
#import <Utilities/Conversions.h>

#if !__has_feature(objc_arc)
#    error "This project requires ARC"
#endif

@interface ApplicationDelegate ()

@property (nonatomic, strong) GNUstepBrowserWindow* browserWindow;
@property (nonatomic, assign) BOOL hasFinishedLaunching;

@property (nonatomic, strong) InfoBar* info_bar;

- (NSMenuItem*)createApplicationMenu;
- (NSMenuItem*)createFileMenu;
- (NSMenuItem*)createEditMenu;
- (NSMenuItem*)createViewMenu;
- (NSMenuItem*)createHistoryMenu;
- (NSMenuItem*)createInspectMenu;
- (NSMenuItem*)createDebugMenu;
- (NSMenuItem*)createWindowMenu;
- (NSMenuItem*)createHelpMenu;

@end

@implementation ApplicationDelegate

- (instancetype)init
{
    if (self = [super init]) {
        [NSApp setMainMenu:[[NSMenu alloc] init]];

        // Remove any automatic application menu items
        while ([[NSApp mainMenu] numberOfItems] > 0) {
            [[NSApp mainMenu] removeItemAtIndex:0];
        }

        [[NSApp mainMenu] addItem:[self createApplicationMenu]];
        [[NSApp mainMenu] addItem:[self createFileMenu]];
        [[NSApp mainMenu] addItem:[self createEditMenu]];
        [[NSApp mainMenu] addItem:[self createViewMenu]];
        [[NSApp mainMenu] addItem:[self createHistoryMenu]];
        [[NSApp mainMenu] addItem:[self createInspectMenu]];
        [[NSApp mainMenu] addItem:[self createDebugMenu]];
        [[NSApp mainMenu] addItem:[self createWindowMenu]];
        [[NSApp mainMenu] addItem:[self createHelpMenu]];

        self.browserWindow = nil;
        self.hasFinishedLaunching = NO;

        // Reduce the tooltip delay
        [[NSUserDefaults standardUserDefaults] setObject:@100 forKey:@"NSInitialToolTipDelay"];
    }

    return self;
}

#pragma mark - Public methods

- (BrowserTab*)activeTab
{
    if (self.browserWindow) {
        return [self.browserWindow activeTab];
    }
    return nil;
}

- (GNUstepBrowserWindow*)activeWindow
{
    return self.browserWindow;
}

- (void)onDevtoolsEnabled
{
    if (!self.info_bar) {
        self.info_bar = [[InfoBar alloc] init];
    }

    auto message = MUST(String::formatted("DevTools is enabled on port {}", WebView::Application::browser_options().devtools_port));

    [self.info_bar showWithMessage:Ladybird::string_to_ns_string(message)
                dismissButtonTitle:@"Disable"
              dismissButtonClicked:^{
                  MUST(WebView::Application::the().toggle_devtools_enabled());
              }
                         activeTab:self.browserWindow];
}

- (void)onDevtoolsDisabled
{
    if (self.info_bar) {
        [self.info_bar hide];
        self.info_bar = nil;
    }
}

#pragma mark - Private methods

- (void)openLocation:(id)sender
{
    if (self.browserWindow) {
        [[self.browserWindow browserToolbar] focusLocationField];
    }
}

- (void)closeCurrentTab:(id)sender
{
    if (self.browserWindow) {
        BrowserTab* tab = [self.browserWindow activeTab];
        if (tab) {
            [self.browserWindow closeTab:tab];
        }
    }
}

- (void)clearHistory:(id)sender
{
    // Clear history for all tabs
    if (self.browserWindow) {
        for (BrowserTab* tab in [self.browserWindow allTabs]) {
            [tab clearHistory];
        }
    }
}

- (NSMenuItem*)createApplicationMenu
{
    auto* process_name = [[NSProcessInfo processInfo] processName];
    auto* menu = [[NSMenuItem alloc] initWithTitle:process_name action:nil keyEquivalent:@""];

    auto* submenu = [[NSMenu alloc] initWithTitle:process_name];

    [submenu addItem:Ladybird::create_application_menu_item(WebView::Application::the().open_about_page_action())];
    [submenu addItem:[NSMenuItem separatorItem]];

    [submenu addItem:Ladybird::create_application_menu_item(WebView::Application::the().open_settings_page_action())];
    [submenu addItem:[NSMenuItem separatorItem]];

    [submenu addItem:[[NSMenuItem alloc] initWithTitle:[NSString stringWithFormat:@"Hide %@", process_name]
                                                action:@selector(hide:)
                                         keyEquivalent:@"h"]];
    [submenu addItem:[NSMenuItem separatorItem]];

    [submenu addItem:[[NSMenuItem alloc] initWithTitle:[NSString stringWithFormat:@"Quit %@", process_name]
                                                action:@selector(terminate:)
                                         keyEquivalent:@"q"]];

    [menu setSubmenu:submenu];
    return menu;
}

- (NSMenuItem*)createFileMenu
{
    auto* menu = [[NSMenuItem alloc] initWithTitle:@"File" action:nil keyEquivalent:@""];
    auto* submenu = [[NSMenu alloc] initWithTitle:@"File"];

    [submenu addItem:[[NSMenuItem alloc] initWithTitle:@"New Tab"
                                                action:@selector(createNewTab:)
                                         keyEquivalent:@"t"]];
    [submenu addItem:[[NSMenuItem alloc] initWithTitle:@"Close Tab"
                                                action:@selector(closeCurrentTab:)
                                         keyEquivalent:@"w"]];
    [submenu addItem:[NSMenuItem separatorItem]];

    [submenu addItem:[[NSMenuItem alloc] initWithTitle:@"Open Location"
                                                action:@selector(openLocation:)
                                         keyEquivalent:@"l"]];

    [menu setSubmenu:submenu];
    return menu;
}

- (NSMenuItem*)createEditMenu
{
    auto* menu = [[NSMenuItem alloc] initWithTitle:@"Edit" action:nil keyEquivalent:@""];
    auto* submenu = [[NSMenu alloc] initWithTitle:@"Edit"];

    [submenu addItem:[[NSMenuItem alloc] initWithTitle:@"Undo"
                                                action:@selector(undo:)
                                         keyEquivalent:@"z"]];
    [submenu addItem:[[NSMenuItem alloc] initWithTitle:@"Redo"
                                                action:@selector(redo:)
                                         keyEquivalent:@"y"]];
    [submenu addItem:[NSMenuItem separatorItem]];

    [submenu addItem:[[NSMenuItem alloc] initWithTitle:@"Cut"
                                                action:@selector(cut:)
                                         keyEquivalent:@"x"]];

    [submenu addItem:Ladybird::create_application_menu_item(WebView::Application::the().copy_selection_action())];
    [submenu addItem:Ladybird::create_application_menu_item(WebView::Application::the().paste_action())];
    [submenu addItem:[NSMenuItem separatorItem]];

    [submenu addItem:Ladybird::create_application_menu_item(WebView::Application::the().select_all_action())];
    [submenu addItem:[NSMenuItem separatorItem]];

    [submenu addItem:[[NSMenuItem alloc] initWithTitle:@"Find..."
                                                action:@selector(find:)
                                         keyEquivalent:@"f"]];
    [submenu addItem:[[NSMenuItem alloc] initWithTitle:@"Find Next"
                                                action:@selector(findNextMatch:)
                                         keyEquivalent:@"g"]];
    [submenu addItem:[[NSMenuItem alloc] initWithTitle:@"Find Previous"
                                                action:@selector(findPreviousMatch:)
                                         keyEquivalent:@"G"]];
    [submenu addItem:[[NSMenuItem alloc] initWithTitle:@"Use Selection for Find"
                                                action:@selector(useSelectionForFind:)
                                         keyEquivalent:@"e"]];

    [menu setSubmenu:submenu];
    return menu;
}

- (NSMenuItem*)createViewMenu
{
    auto* menu = [[NSMenuItem alloc] initWithTitle:@"View" action:nil keyEquivalent:@""];
    auto* submenu = [[NSMenu alloc] initWithTitle:@"View"];

    auto* zoom_menu = Ladybird::create_application_menu(WebView::Application::the().zoom_menu());
    auto* zoom_menu_item = [[NSMenuItem alloc] initWithTitle:[zoom_menu title]
                                                      action:nil
                                               keyEquivalent:@""];
    [zoom_menu_item setSubmenu:zoom_menu];

    auto* color_scheme_menu = Ladybird::create_application_menu(WebView::Application::the().color_scheme_menu());
    auto* color_scheme_menu_item = [[NSMenuItem alloc] initWithTitle:[color_scheme_menu title]
                                                              action:nil
                                                       keyEquivalent:@""];
    [color_scheme_menu_item setSubmenu:color_scheme_menu];

    auto* contrast_menu = Ladybird::create_application_menu(WebView::Application::the().contrast_menu());
    auto* contrast_menu_item = [[NSMenuItem alloc] initWithTitle:[contrast_menu title]
                                                          action:nil
                                                   keyEquivalent:@""];
    [contrast_menu_item setSubmenu:contrast_menu];

    auto* motion_menu = Ladybird::create_application_menu(WebView::Application::the().motion_menu());
    auto* motion_menu_item = [[NSMenuItem alloc] initWithTitle:[motion_menu title]
                                                        action:nil
                                                 keyEquivalent:@""];
    [motion_menu_item setSubmenu:motion_menu];

    [submenu addItem:zoom_menu_item];
    [submenu addItem:[NSMenuItem separatorItem]];
    [submenu addItem:color_scheme_menu_item];
    [submenu addItem:contrast_menu_item];
    [submenu addItem:motion_menu_item];
    [submenu addItem:[NSMenuItem separatorItem]];

    [menu setSubmenu:submenu];
    return menu;
}

- (NSMenuItem*)createHistoryMenu
{
    auto* menu = [[NSMenuItem alloc] initWithTitle:@"History" action:nil keyEquivalent:@""];

    auto* submenu = [[NSMenu alloc] initWithTitle:@"History"];
    [submenu setAutoenablesItems:NO];

    [submenu addItem:Ladybird::create_application_menu_item(WebView::Application::the().reload_action())];
    [submenu addItem:[NSMenuItem separatorItem]];

    [submenu addItem:[[NSMenuItem alloc] initWithTitle:@"Clear History"
                                                action:@selector(clearHistory:)
                                         keyEquivalent:@""]];

    [menu setSubmenu:submenu];
    return menu;
}

- (NSMenuItem*)createInspectMenu
{
    auto* submenu = Ladybird::create_application_menu(WebView::Application::the().inspect_menu());
    auto* menu = [[NSMenuItem alloc] initWithTitle:[submenu title] action:nil keyEquivalent:@""];
    [menu setSubmenu:submenu];

    return menu;
}

- (NSMenuItem*)createDebugMenu
{
    auto* submenu = Ladybird::create_application_menu(WebView::Application::the().debug_menu());
    auto* menu = [[NSMenuItem alloc] initWithTitle:[submenu title] action:nil keyEquivalent:@""];
    [menu setSubmenu:submenu];

    return menu;
}

- (NSMenuItem*)createWindowMenu
{
    auto* menu = [[NSMenuItem alloc] initWithTitle:@"Window" action:nil keyEquivalent:@""];
    auto* submenu = [[NSMenu alloc] initWithTitle:@"Window"];

    // Tab switching shortcuts (Cmd+1 through Cmd+9)
    for (int i = 1; i <= 9; i++) {
        NSString* title = [NSString stringWithFormat:@"Select Tab %d", i];
        NSString* keyEquiv = [NSString stringWithFormat:@"%d", i];
        NSMenuItem* item = [[NSMenuItem alloc] initWithTitle:title
                                                      action:@selector(selectTabByNumber:)
                                               keyEquivalent:keyEquiv];
        [item setTag:i];
        [submenu addItem:item];
    }

    [submenu addItem:[NSMenuItem separatorItem]];

    // Next/Previous tab shortcuts
    [submenu addItem:[[NSMenuItem alloc] initWithTitle:@"Select Next Tab"
                                                action:@selector(selectNextTab:)
                                         keyEquivalent:@"}"]];
    [submenu addItem:[[NSMenuItem alloc] initWithTitle:@"Select Previous Tab"
                                                action:@selector(selectPreviousTab:)
                                         keyEquivalent:@"{"]];

    [submenu addItem:[NSMenuItem separatorItem]];

    [NSApp setWindowsMenu:submenu];

    [menu setSubmenu:submenu];
    return menu;
}

- (NSMenuItem*)createHelpMenu
{
    auto* menu = [[NSMenuItem alloc] initWithTitle:@"Help" action:nil keyEquivalent:@""];
    auto* submenu = [[NSMenu alloc] initWithTitle:@"Help"];

    [menu setSubmenu:submenu];
    return menu;
}

#pragma mark - NSApplicationDelegate

- (void)applicationDidFinishLaunching:(NSNotification*)notification
{
    // Guard against being called multiple times
    if (self.hasFinishedLaunching) {
        return;
    }
    self.hasFinishedLaunching = YES;

    [NSApp activateIgnoringOtherApps:YES];

    auto const& browser_options = WebView::Application::browser_options();

    if (browser_options.devtools_port.has_value())
        [self onDevtoolsEnabled];

    // Create the main browser window with NSTabView
    self.browserWindow = [[GNUstepBrowserWindow alloc] init];
    [self.browserWindow makeKeyAndOrderFront:nil];

    if (browser_options.urls.is_empty()) {
        [self.browserWindow createNewTab];
    } else {
        BrowserTab* firstTab = nil;
        for (auto const& url : browser_options.urls) {
            BrowserTab* newTab = [self.browserWindow createNewTab];
            [newTab loadURL:url];

            if (firstTab == nil) {
                firstTab = newTab;
            }
        }
        // Select the first tab
        if (firstTab) {
            [self.browserWindow selectTab:firstTab];
        }
    }
}

- (void)applicationWillTerminate:(NSNotification*)notification
{
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication*)sender
{
    return YES;
}

- (void)applicationDidChangeScreenParameters:(NSNotification*)notification
{
    if (self.browserWindow) {
        for (BrowserTab* tab in [self.browserWindow allTabs]) {
            [[tab web_view] handleDisplayRefreshRateChange];
        }
    }
}

@end
