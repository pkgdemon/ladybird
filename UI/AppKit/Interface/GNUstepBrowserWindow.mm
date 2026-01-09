/*
 * Copyright (c) 2024-2025, the Ladybird developers.
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

#import <Platform.h>

#if LADYBIRD_HAS_NSTABVIEW

#import <Interface/GNUstepBrowserWindow.h>
#import <Interface/BrowserTab.h>
#import <Interface/BrowserToolbar.h>

#if !__has_feature(objc_arc)
#    error "This project requires ARC"
#endif

@interface GNUstepBrowserWindow ()
@end

@implementation GNUstepBrowserWindow

- (instancetype)init
{
    NSLog(@"GNUstepBrowserWindow: init starting");
    fflush(stderr);

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
        NSLog(@"GNUstepBrowserWindow: creating toolbar");
        fflush(stderr);
        self.browserToolbar = [[BrowserToolbar alloc] initWithWindow:self];
        [self setToolbar:[self.browserToolbar toolbar]];

        // Create tab view
        NSLog(@"GNUstepBrowserWindow: creating tab view");
        fflush(stderr);
        NSRect contentRect = [[self contentView] bounds];
        self.tabView = [[NSTabView alloc] initWithFrame:contentRect];
        [self.tabView setTabViewType:NSTopTabsBezelBorder];
        [self.tabView setDelegate:self];
        [self.tabView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
        [self.tabView setAllowsTruncatedLabels:YES];
        [self.tabView setFont:[NSFont systemFontOfSize:11]];

        [[self contentView] addSubview:self.tabView];

        NSLog(@"GNUstepBrowserWindow: init complete");
        fflush(stderr);
    }

    return self;
}

#pragma mark - Tab Management

- (BrowserTab*)createNewTab
{
    NSLog(@"GNUstepBrowserWindow: createNewTab");
    fflush(stderr);

    BrowserTab* tab = [[BrowserTab alloc] init];
    tab.browserWindow = self;

    [self.tabView addTabViewItem:tab];
    [self.tabView selectTabViewItem:tab];

    // Update toolbar for new tab
    [self.browserToolbar updateForTab:tab];

    NSLog(@"GNUstepBrowserWindow: tab created, total tabs: %lu", (unsigned long)[self tabCount]);
    fflush(stderr);

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

    NSLog(@"GNUstepBrowserWindow: closeTab, tabs before: %lu", (unsigned long)[self tabCount]);
    fflush(stderr);

    [self.tabView removeTabViewItem:tab];

    NSLog(@"GNUstepBrowserWindow: tab closed, tabs remaining: %lu", (unsigned long)[self tabCount]);
    fflush(stderr);

    // If no tabs remain, close the window
    if ([self tabCount] == 0) {
        NSLog(@"GNUstepBrowserWindow: no tabs remaining, closing window");
        fflush(stderr);
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

#pragma mark - NSTabViewDelegate

- (BOOL)tabView:(NSTabView*)tabView shouldSelectTabViewItem:(NSTabViewItem*)tabViewItem
{
    return YES;
}

- (void)tabView:(NSTabView*)tabView willSelectTabViewItem:(NSTabViewItem*)tabViewItem
{
    NSLog(@"GNUstepBrowserWindow: willSelectTabViewItem: %@", [tabViewItem label]);
    fflush(stderr);

    // Pause rendering on outgoing tab
    BrowserTab* currentTab = (BrowserTab*)[tabView selectedTabViewItem];
    if (currentTab) {
        [currentTab handleVisibility:NO];
    }
}

- (void)tabView:(NSTabView*)tabView didSelectTabViewItem:(NSTabViewItem*)tabViewItem
{
    NSLog(@"GNUstepBrowserWindow: didSelectTabViewItem: %@", [tabViewItem label]);
    fflush(stderr);

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
    NSLog(@"GNUstepBrowserWindow: tabViewDidChangeNumberOfTabViewItems: %ld", (long)[tabView numberOfTabViewItems]);
    fflush(stderr);
}

#pragma mark - NSWindowDelegate

- (void)windowWillClose:(NSNotification*)notification
{
    NSLog(@"GNUstepBrowserWindow: windowWillClose");
    fflush(stderr);
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

#endif // LADYBIRD_HAS_NSTABVIEW
