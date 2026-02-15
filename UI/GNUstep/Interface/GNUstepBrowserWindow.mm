/*
 * Copyright (c) 2024-2025, the Ladybird developers.
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

#include <LibURL/Parser.h>
#include <LibURL/URL.h>

#import <Interface/GNUstepBrowserWindow.h>
#import <Interface/BrowserTab.h>
#import <Interface/BrowserToolbar.h>
#import <Utilities/Conversions.h>

#if !__has_feature(objc_arc)
#    error "This project requires ARC"
#endif

#pragma mark - BrowserTabView

@implementation BrowserTabView

- (NSMenu*)menuForEvent:(NSEvent*)event
{
    // Find which tab was clicked
    NSPoint point = [self convertPoint:[event locationInWindow] fromView:nil];

    // Check if click is in the tab bar area (top portion of the view)
    NSRect tabBarRect = [self bounds];
    tabBarRect.size.height = 25;  // Approximate tab bar height
    tabBarRect.origin.y = NSMaxY([self bounds]) - 25;

    if (!NSPointInRect(point, tabBarRect)) {
        return nil;  // Not in tab bar area
    }

    // Use tabViewItemAtPoint to find the clicked tab
    BrowserTab* clickedTab = (BrowserTab*)[self tabViewItemAtPoint:point];

    if (!clickedTab) {
        clickedTab = (BrowserTab*)[self selectedTabViewItem];
    }

    if (!clickedTab) {
        return nil;
    }

    // Create context menu
    NSMenu* menu = [[NSMenu alloc] initWithTitle:@"Tab"];

    NSMenuItem* closeItem = [[NSMenuItem alloc] initWithTitle:@"Close Tab"
                                                       action:@selector(closeTabFromMenu:)
                                                keyEquivalent:@""];
    [closeItem setTarget:self];
    [closeItem setRepresentedObject:clickedTab];
    [menu addItem:closeItem];

    NSMenuItem* closeOthersItem = [[NSMenuItem alloc] initWithTitle:@"Close Other Tabs"
                                                             action:@selector(closeOtherTabsFromMenu:)
                                                      keyEquivalent:@""];
    [closeOthersItem setTarget:self];
    [closeOthersItem setRepresentedObject:clickedTab];
    [menu addItem:closeOthersItem];

    [menu addItem:[NSMenuItem separatorItem]];

    NSMenuItem* duplicateItem = [[NSMenuItem alloc] initWithTitle:@"Duplicate Tab"
                                                           action:@selector(duplicateTabFromMenu:)
                                                    keyEquivalent:@""];
    [duplicateItem setTarget:self];
    [duplicateItem setRepresentedObject:clickedTab];
    [menu addItem:duplicateItem];

    return menu;
}

- (void)closeTabFromMenu:(NSMenuItem*)sender
{
    BrowserTab* tab = [sender representedObject];
    if (tab && self.browserWindow) {
        [self.browserWindow closeTab:tab];
    }
}

- (void)closeOtherTabsFromMenu:(NSMenuItem*)sender
{
    BrowserTab* keepTab = [sender representedObject];
    if (!keepTab || !self.browserWindow) {
        return;
    }

    // Get all tabs except the one to keep
    NSArray* allTabs = [[self tabViewItems] copy];
    for (BrowserTab* tab in allTabs) {
        if (tab != keepTab) {
            [self.browserWindow closeTab:tab];
        }
    }
}

- (void)duplicateTabFromMenu:(NSMenuItem*)sender
{
    BrowserTab* tab = [sender representedObject];
    if (!tab || !self.browserWindow) {
        return;
    }

    // Create new tab with same URL
    BrowserTab* newTab = [self.browserWindow createNewTab];
    NSString* urlString = [tab currentURLString];
    if (urlString && [urlString length] > 0) {
        // Parse and load the URL
        auto url_string = Ladybird::ns_string_to_string(urlString);
        auto url = URL::Parser::basic_parse(url_string);
        if (url.has_value()) {
            [newTab loadURL:url.value()];
        }
    }
}

@end

#pragma mark - GNUstepBrowserWindow

@interface GNUstepBrowserWindow ()
@end

@implementation GNUstepBrowserWindow

- (instancetype)init
{
    // Calculate centered window position
    NSRect screenRect = [[NSScreen mainScreen] frame];
    NSRect windowRect = NSMakeRect(
        (NSWidth(screenRect) - 1000) / 2,
        (NSHeight(screenRect) - 800) / 2,
        1000, 800);

    static constexpr auto style_mask = NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable;

    self = [super initWithContentRect:windowRect
                            styleMask:style_mask
                              backing:NSBackingStoreBuffered
                                defer:NO];

    if (self) {
        [self setTitle:@"Ladybird"];
        [self setDelegate:self];
        [self setFrameAutosaveName:@"GNUstepBrowserWindow"];

        // Create toolbar
        self.browserToolbar = [[BrowserToolbar alloc] initWithWindow:self];
        [self setToolbar:[self.browserToolbar toolbar]];

        // Create tab view
        NSRect contentRect = [[self contentView] bounds];
        self.tabView = [[BrowserTabView alloc] initWithFrame:contentRect];
        [self.tabView setBrowserWindow:self];
        [self.tabView setTabViewType:NSTopTabsBezelBorder];
        [self.tabView setDelegate:self];
        [self.tabView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
        [self.tabView setAllowsTruncatedLabels:YES];
        [self.tabView setFont:[NSFont systemFontOfSize:11]];

        [[self contentView] addSubview:self.tabView];
    }

    return self;
}

#pragma mark - Tab Management

- (BrowserTab*)createNewTab
{
    BrowserTab* tab = [[BrowserTab alloc] init];
    tab.browserWindow = self;

    [self.tabView addTabViewItem:tab];
    [self.tabView selectTabViewItem:tab];

    // Update toolbar for new tab
    [self.browserToolbar updateForTab:tab];

    return tab;
}

- (BrowserTab*)activeTab
{
    return (BrowserTab*)[self.tabView selectedTabViewItem];
}

- (NSArray<BrowserTab*>*)allTabs
{
    return (NSArray<BrowserTab*>*)[self.tabView tabViewItems];
}

- (void)closeTab:(BrowserTab*)tab
{
    if (!tab)
        return;

    [self.tabView removeTabViewItem:tab];

    // If no tabs remain, close the window
    if ([self tabCount] == 0) {
        [self close];
    }
}

- (void)selectTab:(BrowserTab*)tab
{
    if (tab) {
        [self.tabView selectTabViewItem:tab];
    }
}

- (NSUInteger)tabCount
{
    return (NSUInteger)[self.tabView numberOfTabViewItems];
}

#pragma mark - Menu Actions

- (void)createNewTab:(id)sender
{
    [self createNewTab];
}

- (void)closeCurrentTab:(id)sender
{
    BrowserTab* tab = [self activeTab];
    if (tab) {
        [self closeTab:tab];
    }
}

- (void)openLocation:(id)sender
{
    [self.browserToolbar focusLocationField];
}

- (void)selectTabByNumber:(id)sender
{
    NSInteger tabNumber = [sender tag];  // 1-based
    NSInteger tabIndex = tabNumber - 1;  // 0-based

    if (tabIndex >= 0 && tabIndex < [self.tabView numberOfTabViewItems]) {
        [self.tabView selectTabViewItemAtIndex:tabIndex];
    }
}

- (void)selectNextTab:(id)sender
{
    [self.tabView selectNextTabViewItem:sender];
}

- (void)selectPreviousTab:(id)sender
{
    [self.tabView selectPreviousTabViewItem:sender];
}

#pragma mark - NSTabViewDelegate

- (BOOL)tabView:(NSTabView*)tabView shouldSelectTabViewItem:(NSTabViewItem*)tabViewItem
{
    return YES;
}

- (void)tabView:(NSTabView*)tabView willSelectTabViewItem:(NSTabViewItem*)tabViewItem
{
    // Pause rendering on outgoing tab
    BrowserTab* currentTab = (BrowserTab*)[tabView selectedTabViewItem];
    if (currentTab) {
        [currentTab handleVisibility:NO];
    }
}

- (void)tabView:(NSTabView*)tabView didSelectTabViewItem:(NSTabViewItem*)tabViewItem
{
    BrowserTab* tab = (BrowserTab*)tabViewItem;

    // Resume rendering on incoming tab
    [tab handleVisibility:YES];

    // Update toolbar for the new active tab
    [self.browserToolbar updateForTab:tab];

    // Update window title
    NSString* title = [tab title];
    [self setTitle:title ? title : @"Ladybird"];
}

- (void)tabViewDidChangeNumberOfTabViewItems:(NSTabView*)tabView
{
}

#pragma mark - NSWindowDelegate

- (void)windowWillClose:(NSNotification*)notification
{
    [NSApp terminate:nil];
}

- (void)windowDidResize:(NSNotification*)notification
{
    // Notify active tab of resize
    BrowserTab* tab = [self activeTab];
    if (tab) {
        [tab handleResize];
    }
}

@end
