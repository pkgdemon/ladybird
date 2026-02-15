/*
 * Copyright (c) 2025, Tim Flynn <trflynn89@ladybird.org>
 * Copyright (c) 2025, Joe Maloney <jpm820@proton.me>
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

#import <Interface/Event.h>
#import <Interface/LadybirdWebView.h>
#import <Interface/Menu.h>
#import <Utilities/Conversions.h>
#import <objc/runtime.h>

#if !__has_feature(objc_arc)
#    error "This project requires ARC"
#endif

@interface ActionExecutor : NSObject
{
    WeakPtr<WebView::Action> m_action;
}
@end

@implementation ActionExecutor

+ (instancetype)attachToNativeControl:(WebView::Action const&)action
                              control:(id)control
{
    auto* executor = [[ActionExecutor alloc] init];
    [control setAction:@selector(execute:)];
    [control setTarget:executor];

    static char executor_key = 0;
    objc_setAssociatedObject(control, &executor_key, executor, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    executor->m_action = action.make_weak_ptr();
    return executor;
}

- (void)execute:(id)sender
{
    auto action = m_action.strong_ref();
    if (!action)
        return;

    if (![[[NSApp keyWindow] firstResponder] isKindOfClass:[LadybirdWebView class]]) {
        switch (action->id()) {
        case WebView::ActionID::CopySelection:
            [NSApp sendAction:@selector(copy:) to:nil from:sender];
            return;
        case WebView::ActionID::Paste:
            [NSApp sendAction:@selector(paste:) to:nil from:sender];
            return;
        case WebView::ActionID::SelectAll:
            [NSApp sendAction:@selector(selectAll:) to:nil from:sender];
            return;
        default:
            break;
        }
    }

    if (action->is_checkable())
        action->set_checked(!action->checked());
    action->activate();
}

@end

namespace Ladybird {

class ActionObserver final : public WebView::Action::Observer {
public:
    static NonnullOwnPtr<ActionObserver> create(WebView::Action& action, id control)
    {
        return adopt_own(*new ActionObserver(action, control));
    }

    virtual void on_text_changed(WebView::Action& action) override
    {
        [m_control setTitle:string_to_ns_string(action.text())];
    }

    virtual void on_tooltip_changed(WebView::Action& action) override
    {
        [m_control setToolTip:string_to_ns_string(action.tooltip())];
    }

    virtual void on_enabled_state_changed(WebView::Action& action) override
    {
        [m_control setEnabled:action.enabled()];
    }

    virtual void on_visible_state_changed(WebView::Action& action) override
    {
        [m_control setHidden:!action.visible()];

        if ([m_control isKindOfClass:[NSButton class]])
            [m_control setBordered:action.visible()];
    }

    virtual void on_checked_state_changed(WebView::Action& action) override
    {
        [m_control setState:action.checked() ? NSOnState : NSOffState];
    }

private:
    ActionObserver(WebView::Action& action, id control)
        : m_control(control)
    {
        [ActionExecutor attachToNativeControl:action control:control];
    }

    __weak id m_control { nil };
};

static void initialize_native_control(WebView::Action& action, id control)
{
    switch (action.id()) {
    case WebView::ActionID::NavigateBack:
        set_control_title(control, @"\u25C0");  // ◀
        [control setKeyEquivalent:@"["];
        break;
    case WebView::ActionID::NavigateForward:
        set_control_title(control, @"\u25B6");  // ▶
        [control setKeyEquivalent:@"]"];
        break;
    case WebView::ActionID::Reload:
        set_control_title(control, @"\u21BB");  // ↻
        [control setKeyEquivalent:@"r"];
        break;

    case WebView::ActionID::CopySelection:
        set_control_title(control, @"\u2398");  // ⎘
        [control setKeyEquivalent:@"c"];
        break;
    case WebView::ActionID::Paste:
        set_control_title(control, @"\u2399");  // ⎙
        [control setKeyEquivalent:@"v"];
        break;
    case WebView::ActionID::SelectAll:
        set_control_title(control, @"\u2B1C");  // ⬜
        [control setKeyEquivalent:@"a"];
        break;

    case WebView::ActionID::SearchSelectedText:
        set_control_title(control, @"\u2315");  // ⌕
        break;

    case WebView::ActionID::OpenAboutPage:
        set_control_title(control, @"\u2139");  // ℹ
        break;
    case WebView::ActionID::OpenProcessesPage:
        set_control_title(control, @"\u2699");  // ⚙
        [control setKeyEquivalent:@"M"];
        break;
    case WebView::ActionID::OpenSettingsPage:
        set_control_title(control, @"\u2699");  // ⚙
        [control setKeyEquivalent:@","];
        break;
    case WebView::ActionID::ToggleDevTools:
        set_control_title(control, @"<>");
        [control setKeyEquivalent:@"I"];
        break;
    case WebView::ActionID::ViewSource:
        set_control_title(control, @"\u2630");  // ☰
        [control setKeyEquivalent:@"u"];
        break;

    case WebView::ActionID::TakeVisibleScreenshot:
    case WebView::ActionID::TakeFullScreenshot:
        set_control_title(control, @"\u2318");  // ⌘
        break;

    case WebView::ActionID::OpenInNewTab:
        set_control_title(control, @"\u2B1C");  // ⬜
        break;
    case WebView::ActionID::CopyURL:
        set_control_title(control, @"\u2398");  // ⎘
        break;

    case WebView::ActionID::OpenImage:
        set_control_title(control, @"\u2317");  // ⌗
        break;
    case WebView::ActionID::CopyImage:
        set_control_title(control, @"\u2398");  // ⎘
        break;

    case WebView::ActionID::OpenAudio:
        set_control_title(control, @"\u266B");  // ♫
        break;
    case WebView::ActionID::OpenVideo:
        set_control_title(control, @"\u25B6");  // ▶
        break;
    case WebView::ActionID::PlayMedia:
        set_control_title(control, @"\u25B6");  // ▶
        break;
    case WebView::ActionID::PauseMedia:
        set_control_title(control, @"\u23F8");  // ⏸
        break;
    case WebView::ActionID::MuteMedia:
        set_control_title(control, @"\u1F507");  // 🔇
        break;
    case WebView::ActionID::UnmuteMedia:
        set_control_title(control, @"\u1F50A");  // 🔊
        break;
    case WebView::ActionID::ShowControls:
        set_control_title(control, @"\u2713");  // ✓
        break;
    case WebView::ActionID::HideControls:
        set_control_title(control, @"\u2717");  // ✗
        break;
    case WebView::ActionID::ToggleMediaLoopState:
        set_control_title(control, @"\u21BB");  // ↻
        break;

    case WebView::ActionID::ZoomIn:
        set_control_title(control, @"+");
        [control setKeyEquivalent:@"+"];
        break;
    case WebView::ActionID::ZoomOut:
        set_control_title(control, @"-");
        [control setKeyEquivalent:@"-"];
        break;
    case WebView::ActionID::ResetZoom:
        set_control_title(control, @"1:1");
        [control setKeyEquivalent:@"0"];
        break;

    default:
        break;
    }

    action.add_observer(ActionObserver::create(action, control));
}

static void add_items_to_menu(NSMenu* menu, Span<WebView::Menu::MenuItem> menu_items)
{
    for (auto& menu_item : menu_items) {
        menu_item.visit(
            [&](NonnullRefPtr<WebView::Action>& action) {
                [menu addItem:create_application_menu_item(action)];
            },
            [&](NonnullRefPtr<WebView::Menu> const& submenu) {
                auto* application_submenu = [[NSMenu alloc] init];
                add_items_to_menu(application_submenu, submenu->items());

                auto* item = [[NSMenuItem alloc] initWithTitle:string_to_ns_string(submenu->title())
                                                        action:nil
                                                 keyEquivalent:@""];
                [item setSubmenu:application_submenu];

                [menu addItem:item];
            },
            [&](WebView::Separator) {
                [menu addItem:[NSMenuItem separatorItem]];
            });
    }
}

NSMenu* create_application_menu(WebView::Menu& menu)
{
    auto* application_menu = [[NSMenu alloc] initWithTitle:string_to_ns_string(menu.title())];
    add_items_to_menu(application_menu, menu.items());
    return application_menu;
}

NSMenu* create_context_menu(LadybirdWebView* view, WebView::Menu& menu)
{
    auto* application_menu = create_application_menu(menu);

    __weak LadybirdWebView* weak_view = view;
    __weak NSMenu* weak_application_menu = application_menu;

    menu.on_activation = [weak_view, weak_application_menu](Gfx::IntPoint position) {
        LadybirdWebView* view = weak_view;
        NSMenu* application_menu = weak_application_menu;

        if (view && application_menu) {
            auto* event = create_context_menu_mouse_event(view, position);
            [NSMenu popUpContextMenu:application_menu withEvent:event forView:view];
        }
    };

    return application_menu;
}

NSMenuItem* create_application_menu_item(WebView::Action& action)
{
    auto* item = [[NSMenuItem alloc] init];
    [item setTitle:string_to_ns_string(action.text())];
    initialize_native_control(action, item);
    return item;
}

NSButton* create_application_button(WebView::Action& action)
{
    auto* button = [[NSButton alloc] init];
    [button setTitle:string_to_ns_string(action.text())];
    initialize_native_control(action, button);
    return button;
}

void set_control_title(id control, NSString* title)
{
    if ([control isKindOfClass:[NSMenuItem class]]) {
        // For menu items, we prefix the action text with the icon
        NSString* current_title = [control title];
        if (current_title && [current_title length] > 0) {
            [control setTitle:[NSString stringWithFormat:@"%@ %@", title, current_title]];
        }
    } else if ([control isKindOfClass:[NSButton class]]) {
        [control setTitle:title];
        [control setToolTip:[control title]];
    }
}

}
