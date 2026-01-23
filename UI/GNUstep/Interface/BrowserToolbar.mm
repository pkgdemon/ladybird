/*
 * Copyright (c) 2024-2025, the Ladybird developers.
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

#include <LibURL/URL.h>
#include <LibWebView/Application.h>
#include <LibWebView/URL.h>

#import <Application/ApplicationDelegate.h>
#import <Interface/BrowserTab.h>
#import <Interface/BrowserToolbar.h>
#import <Interface/GNUstepBrowserWindow.h>
#import <Interface/LadybirdWebView.h>
#import <Utilities/Conversions.h>

#if !__has_feature(objc_arc)
#    error "This project requires ARC"
#endif

static NSString* const TOOLBAR_IDENTIFIER = @"BrowserToolbar";
static NSString* const TOOLBAR_NAVIGATE_BACK_IDENTIFIER = @"ToolbarNavigateBackIdentifier";
static NSString* const TOOLBAR_NAVIGATE_FORWARD_IDENTIFIER = @"ToolbarNavigateForwardIdentifier";
static NSString* const TOOLBAR_RELOAD_IDENTIFIER = @"ToolbarReloadIdentifier";
static NSString* const TOOLBAR_LOCATION_IDENTIFIER = @"ToolbarLocationIdentifier";
static NSString* const TOOLBAR_NEW_TAB_IDENTIFIER = @"ToolbarNewTabIdentifier";
static NSString* const TOOLBAR_TAB_OVERVIEW_IDENTIFIER = @"ToolbarTabOverviewIdentifier";

@interface BrowserToolbar ()

@property (nonatomic, strong) NSToolbar* toolbarInstance;
@property (nonatomic, strong) NSToolbarItem* navigate_back_toolbar_item;
@property (nonatomic, strong) NSToolbarItem* navigate_forward_toolbar_item;
@property (nonatomic, strong) NSToolbarItem* reload_toolbar_item;
@property (nonatomic, strong) NSToolbarItem* location_toolbar_item;
@property (nonatomic, strong) NSToolbarItem* add_tab_toolbar_item;
@property (nonatomic, strong) NSToolbarItem* tab_overview_toolbar_item;

@end

@implementation BrowserToolbar

- (instancetype)initWithWindow:(GNUstepBrowserWindow*)window
{
    self = [super init];
    if (self) {
        self.browserWindow = window;

        // Create toolbar
        self.toolbarInstance = [[NSToolbar alloc] initWithIdentifier:TOOLBAR_IDENTIFIER];
        [self.toolbarInstance setDelegate:self];
        [self.toolbarInstance setDisplayMode:NSToolbarDisplayModeIconOnly];
        [self.toolbarInstance setAllowsUserCustomization:NO];
        [self.toolbarInstance setSizeMode:NSToolbarSizeModeRegular];
    }
    return self;
}

- (NSToolbar*)toolbar
{
    return self.toolbarInstance;
}

#pragma mark - Toolbar Updates

- (void)updateForTab:(BrowserTab*)tab
{
    if (!tab) {
        [self setLocationText:@""];
        return;
    }

    // Update location bar with current URL
    NSString* urlString = [tab currentURLString];
    [self setLocationText:urlString ?: @""];
}

- (void)setLocationText:(NSString*)text
{
    [self.locationField setStringValue:text ?: @""];
}

- (void)focusLocationField
{
    [self.browserWindow makeFirstResponder:self.locationField];
    [self.locationField selectText:nil];
}

#pragma mark - Navigation Actions

- (void)navigateBack:(id)sender
{
    BrowserTab* tab = [self.browserWindow activeTab];
    if (tab) {
        [tab navigateBack];
    }
}

- (void)navigateForward:(id)sender
{
    BrowserTab* tab = [self.browserWindow activeTab];
    if (tab) {
        [tab navigateForward];
    }
}

- (void)reload:(id)sender
{
    BrowserTab* tab = [self.browserWindow activeTab];
    if (tab) {
        [tab reload];
    }
}

- (void)createNewTab:(id)sender
{
    [self.browserWindow createNewTab];
}

- (void)locationFieldAction:(id)sender
{
    NSString* location = [self.locationField stringValue];
    if ([location length] == 0) {
        return;
    }

    auto url_string = Ladybird::ns_string_to_string(location);
    auto url = WebView::sanitize_url(url_string);

    if (url.has_value()) {
        BrowserTab* tab = [self.browserWindow activeTab];
        if (tab) {
            [tab loadURL:url.value()];
        }
    }

    // Remove focus from location field
    [self.browserWindow makeFirstResponder:nil];
}

#pragma mark - Toolbar Item Creation

- (NSToolbarItem*)createNavigateBackItem
{
    if (!_navigate_back_toolbar_item) {
        _navigate_back_toolbar_item = [[NSToolbarItem alloc] initWithItemIdentifier:TOOLBAR_NAVIGATE_BACK_IDENTIFIER];

        auto* button = [[NSButton alloc] initWithFrame:NSMakeRect(0, 0, 24, 24)];
        [button setTitle:@"<"];
        [button setBordered:YES];
        [button setTarget:self];
        [button setAction:@selector(navigateBack:)];
        [button setToolTip:@"Go back"];

        [_navigate_back_toolbar_item setView:button];
        [_navigate_back_toolbar_item setMinSize:NSMakeSize(24.0, 24.0)];
        [_navigate_back_toolbar_item setMaxSize:NSMakeSize(24.0, 24.0)];
    }
    return _navigate_back_toolbar_item;
}

- (NSToolbarItem*)createNavigateForwardItem
{
    if (!_navigate_forward_toolbar_item) {
        _navigate_forward_toolbar_item = [[NSToolbarItem alloc] initWithItemIdentifier:TOOLBAR_NAVIGATE_FORWARD_IDENTIFIER];

        auto* button = [[NSButton alloc] initWithFrame:NSMakeRect(0, 0, 24, 24)];
        [button setTitle:@">"];
        [button setBordered:YES];
        [button setTarget:self];
        [button setAction:@selector(navigateForward:)];
        [button setToolTip:@"Go forward"];

        [_navigate_forward_toolbar_item setView:button];
        [_navigate_forward_toolbar_item setMinSize:NSMakeSize(24.0, 24.0)];
        [_navigate_forward_toolbar_item setMaxSize:NSMakeSize(24.0, 24.0)];
    }
    return _navigate_forward_toolbar_item;
}

- (NSToolbarItem*)createReloadItem
{
    if (!_reload_toolbar_item) {
        _reload_toolbar_item = [[NSToolbarItem alloc] initWithItemIdentifier:TOOLBAR_RELOAD_IDENTIFIER];

        auto* button = [[NSButton alloc] initWithFrame:NSMakeRect(0, 0, 24, 24)];
        [button setTitle:@"R"];
        [button setBordered:YES];
        [button setTarget:self];
        [button setAction:@selector(reload:)];
        [button setToolTip:@"Reload page"];

        [_reload_toolbar_item setView:button];
        [_reload_toolbar_item setMinSize:NSMakeSize(24.0, 24.0)];
        [_reload_toolbar_item setMaxSize:NSMakeSize(24.0, 24.0)];
    }
    return _reload_toolbar_item;
}

- (NSToolbarItem*)createLocationItem
{
    if (!_location_toolbar_item) {
        _location_toolbar_item = [[NSToolbarItem alloc] initWithItemIdentifier:TOOLBAR_LOCATION_IDENTIFIER];

        self.locationField = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 400, 22)];
        [self.locationField setPlaceholderString:@"Enter web address"];
        [self.locationField setDelegate:self];
        [self.locationField setEditable:YES];
        [self.locationField setBezeled:YES];
        [self.locationField setBezelStyle:NSTextFieldSquareBezel];
        [self.locationField setTarget:self];
        [self.locationField setAction:@selector(locationFieldAction:)];

        [_location_toolbar_item setView:self.locationField];
        [_location_toolbar_item setMinSize:NSMakeSize(100.0, 22.0)];
        [_location_toolbar_item setMaxSize:NSMakeSize(600.0, 22.0)];
    }
    return _location_toolbar_item;
}

- (NSToolbarItem*)createNewTabItem
{
    if (!_add_tab_toolbar_item) {
        _add_tab_toolbar_item = [[NSToolbarItem alloc] initWithItemIdentifier:TOOLBAR_NEW_TAB_IDENTIFIER];

        auto* button = [[NSButton alloc] initWithFrame:NSMakeRect(0, 0, 24, 24)];
        [button setTitle:@"+"];
        [button setBordered:YES];
        [button setTarget:self];
        [button setAction:@selector(createNewTab:)];
        [button setToolTip:@"New tab"];

        [_add_tab_toolbar_item setView:button];
        [_add_tab_toolbar_item setMinSize:NSMakeSize(24.0, 24.0)];
        [_add_tab_toolbar_item setMaxSize:NSMakeSize(24.0, 24.0)];
    }
    return _add_tab_toolbar_item;
}

- (NSToolbarItem*)createTabOverviewItem
{
    if (!_tab_overview_toolbar_item) {
        _tab_overview_toolbar_item = [[NSToolbarItem alloc] initWithItemIdentifier:TOOLBAR_TAB_OVERVIEW_IDENTIFIER];

        auto* button = [[NSButton alloc] initWithFrame:NSMakeRect(0, 0, 24, 24)];
        [button setTitle:@"#"];
        [button setBordered:YES];
        [button setTarget:self];
        [button setAction:@selector(showTabOverview:)];
        [button setToolTip:@"Tab overview"];

        [_tab_overview_toolbar_item setView:button];
        [_tab_overview_toolbar_item setMinSize:NSMakeSize(24.0, 24.0)];
        [_tab_overview_toolbar_item setMaxSize:NSMakeSize(24.0, 24.0)];
    }
    return _tab_overview_toolbar_item;
}

- (void)showTabOverview:(id)sender
{
    // Create a popup menu with all tabs
    NSMenu* menu = [[NSMenu alloc] initWithTitle:@"Tabs"];

    NSArray* tabs = [self.browserWindow allTabs];
    for (NSUInteger i = 0; i < [tabs count]; i++) {
        BrowserTab* tab = tabs[i];
        NSString* title = [tab label] ?: @"New Tab";
        NSMenuItem* item = [[NSMenuItem alloc] initWithTitle:title
                                                      action:@selector(selectTabFromMenu:)
                                               keyEquivalent:@""];
        [item setTarget:self];
        [item setTag:(NSInteger)i];
        [item setRepresentedObject:tab];

        // Mark the active tab
        if (tab == [self.browserWindow activeTab]) {
            [item setState:NSOnState];
        }

        [menu addItem:item];
    }

    // Show the menu
    NSButton* button = (NSButton*)sender;
    NSPoint point = NSMakePoint(0, [button bounds].size.height);
    [menu popUpMenuPositioningItem:nil atLocation:point inView:button];
}

- (void)selectTabFromMenu:(NSMenuItem*)sender
{
    BrowserTab* tab = [sender representedObject];
    if (tab) {
        [self.browserWindow selectTab:tab];
    }
}

#pragma mark - NSToolbarDelegate

- (NSToolbarItem*)toolbar:(NSToolbar*)toolbar
        itemForItemIdentifier:(NSString*)identifier
    willBeInsertedIntoToolbar:(BOOL)flag
{
    if ([identifier isEqual:TOOLBAR_NAVIGATE_BACK_IDENTIFIER]) {
        return [self createNavigateBackItem];
    }
    if ([identifier isEqual:TOOLBAR_NAVIGATE_FORWARD_IDENTIFIER]) {
        return [self createNavigateForwardItem];
    }
    if ([identifier isEqual:TOOLBAR_RELOAD_IDENTIFIER]) {
        return [self createReloadItem];
    }
    if ([identifier isEqual:TOOLBAR_LOCATION_IDENTIFIER]) {
        return [self createLocationItem];
    }
    if ([identifier isEqual:TOOLBAR_NEW_TAB_IDENTIFIER]) {
        return [self createNewTabItem];
    }
    if ([identifier isEqual:TOOLBAR_TAB_OVERVIEW_IDENTIFIER]) {
        return [self createTabOverviewItem];
    }

    return nil;
}

- (NSArray*)toolbarAllowedItemIdentifiers:(NSToolbar*)toolbar
{
    return @[
        TOOLBAR_NAVIGATE_BACK_IDENTIFIER,
        TOOLBAR_NAVIGATE_FORWARD_IDENTIFIER,
        TOOLBAR_RELOAD_IDENTIFIER,
        TOOLBAR_LOCATION_IDENTIFIER,
        TOOLBAR_NEW_TAB_IDENTIFIER,
        TOOLBAR_TAB_OVERVIEW_IDENTIFIER,
    ];
}

- (NSArray*)toolbarDefaultItemIdentifiers:(NSToolbar*)toolbar
{
    return @[
        TOOLBAR_NAVIGATE_BACK_IDENTIFIER,
        TOOLBAR_NAVIGATE_FORWARD_IDENTIFIER,
        TOOLBAR_RELOAD_IDENTIFIER,
        TOOLBAR_LOCATION_IDENTIFIER,
        TOOLBAR_NEW_TAB_IDENTIFIER,
        TOOLBAR_TAB_OVERVIEW_IDENTIFIER,
    ];
}

#pragma mark - NSTextFieldDelegate

- (BOOL)control:(NSControl*)control textView:(NSTextView*)textView doCommandBySelector:(SEL)commandSelector
{
    if (commandSelector == @selector(insertNewline:)) {
        [self locationFieldAction:control];
        return YES;
    }
    return NO;
}

@end
