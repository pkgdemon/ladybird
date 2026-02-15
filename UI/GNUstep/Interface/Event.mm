/*
 * Copyright (c) 2023-2024, Tim Flynn <trflynn89@serenityos.org>
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

#include <AK/TypeCasts.h>
#include <AK/Utf8View.h>
#include <LibURL/URL.h>
#include <LibWeb/HTML/SelectedFile.h>
#include <LibWeb/UIEvents/KeyCode.h>

#import <Interface/Event.h>
#import <Utilities/Conversions.h>

#if !__has_feature(objc_arc)
#    error "This project requires ARC"
#endif

// Carbon key codes (kVK_* constants)
// These are hardware-independent virtual key codes from Carbon/HIToolbox/Events.h
enum {
    kVK_ANSI_A = 0x00,
    kVK_ANSI_S = 0x01,
    kVK_ANSI_D = 0x02,
    kVK_ANSI_F = 0x03,
    kVK_ANSI_H = 0x04,
    kVK_ANSI_G = 0x05,
    kVK_ANSI_Z = 0x06,
    kVK_ANSI_X = 0x07,
    kVK_ANSI_C = 0x08,
    kVK_ANSI_V = 0x09,
    kVK_ANSI_B = 0x0B,
    kVK_ANSI_Q = 0x0C,
    kVK_ANSI_W = 0x0D,
    kVK_ANSI_E = 0x0E,
    kVK_ANSI_R = 0x0F,
    kVK_ANSI_Y = 0x10,
    kVK_ANSI_T = 0x11,
    kVK_ANSI_1 = 0x12,
    kVK_ANSI_2 = 0x13,
    kVK_ANSI_3 = 0x14,
    kVK_ANSI_4 = 0x15,
    kVK_ANSI_6 = 0x16,
    kVK_ANSI_5 = 0x17,
    kVK_ANSI_Equal = 0x18,
    kVK_ANSI_9 = 0x19,
    kVK_ANSI_7 = 0x1A,
    kVK_ANSI_Minus = 0x1B,
    kVK_ANSI_8 = 0x1C,
    kVK_ANSI_0 = 0x1D,
    kVK_ANSI_RightBracket = 0x1E,
    kVK_ANSI_O = 0x1F,
    kVK_ANSI_U = 0x20,
    kVK_ANSI_LeftBracket = 0x21,
    kVK_ANSI_I = 0x22,
    kVK_ANSI_P = 0x23,
    kVK_ANSI_L = 0x25,
    kVK_ANSI_J = 0x26,
    kVK_ANSI_Quote = 0x27,
    kVK_ANSI_K = 0x28,
    kVK_ANSI_Semicolon = 0x29,
    kVK_ANSI_Backslash = 0x2A,
    kVK_ANSI_Comma = 0x2B,
    kVK_ANSI_Slash = 0x2C,
    kVK_ANSI_N = 0x2D,
    kVK_ANSI_M = 0x2E,
    kVK_ANSI_Period = 0x2F,
    kVK_ANSI_Grave = 0x32,
    kVK_ANSI_KeypadDecimal = 0x41,
    kVK_ANSI_KeypadMultiply = 0x43,
    kVK_ANSI_KeypadPlus = 0x45,
    kVK_ANSI_KeypadClear = 0x47,
    kVK_ANSI_KeypadDivide = 0x4B,
    kVK_ANSI_KeypadEnter = 0x4C,
    kVK_ANSI_KeypadMinus = 0x4E,
    kVK_ANSI_KeypadEquals = 0x51,
    kVK_ANSI_Keypad0 = 0x52,
    kVK_ANSI_Keypad1 = 0x53,
    kVK_ANSI_Keypad2 = 0x54,
    kVK_ANSI_Keypad3 = 0x55,
    kVK_ANSI_Keypad4 = 0x56,
    kVK_ANSI_Keypad5 = 0x57,
    kVK_ANSI_Keypad6 = 0x58,
    kVK_ANSI_Keypad7 = 0x59,
    kVK_ANSI_Keypad8 = 0x5B,
    kVK_ANSI_Keypad9 = 0x5C,
    kVK_Return = 0x24,
    kVK_Tab = 0x30,
    kVK_Space = 0x31,
    kVK_Delete = 0x33,
    kVK_Escape = 0x35,
    kVK_Command = 0x37,
    kVK_Shift = 0x38,
    kVK_CapsLock = 0x39,
    kVK_Option = 0x3A,
    kVK_Control = 0x3B,
    kVK_RightCommand = 0x36,
    kVK_RightShift = 0x3C,
    kVK_RightOption = 0x3D,
    kVK_RightControl = 0x3E,
    kVK_F17 = 0x40,
    kVK_VolumeUp = 0x48,
    kVK_VolumeDown = 0x49,
    kVK_Mute = 0x4A,
    kVK_F18 = 0x4F,
    kVK_F19 = 0x50,
    kVK_F5 = 0x60,
    kVK_F6 = 0x61,
    kVK_F7 = 0x62,
    kVK_F3 = 0x63,
    kVK_F8 = 0x64,
    kVK_F9 = 0x65,
    kVK_F11 = 0x67,
    kVK_F13 = 0x69,
    kVK_F16 = 0x6A,
    kVK_F14 = 0x6B,
    kVK_F10 = 0x6D,
    kVK_F12 = 0x6F,
    kVK_F15 = 0x71,
    kVK_Help = 0x72,
    kVK_Home = 0x73,
    kVK_PageUp = 0x74,
    kVK_ForwardDelete = 0x75,
    kVK_F4 = 0x76,
    kVK_End = 0x77,
    kVK_F2 = 0x78,
    kVK_PageDown = 0x79,
    kVK_F1 = 0x7A,
    kVK_LeftArrow = 0x7B,
    kVK_RightArrow = 0x7C,
    kVK_DownArrow = 0x7D,
    kVK_UpArrow = 0x7E
};

namespace Ladybird {

static Web::UIEvents::KeyModifier ns_modifiers_to_key_modifiers(NSEventModifierFlags modifier_flags, Optional<Web::UIEvents::MouseButton&> button = {})
{
    unsigned modifiers = Web::UIEvents::KeyModifier::Mod_None;

    if ((modifier_flags & NSEventModifierFlagShift) != 0) {
        modifiers |= Web::UIEvents::KeyModifier::Mod_Shift;
    }
    if ((modifier_flags & NSEventModifierFlagControl) != 0) {
        if (button == Web::UIEvents::MouseButton::Primary) {
            *button = Web::UIEvents::MouseButton::Secondary;
        } else {
            modifiers |= Web::UIEvents::KeyModifier::Mod_Ctrl;
        }
    }
    if ((modifier_flags & NSEventModifierFlagOption) != 0) {
        modifiers |= Web::UIEvents::KeyModifier::Mod_Alt;
    }
    if ((modifier_flags & NSEventModifierFlagCommand) != 0) {
        modifiers |= Web::UIEvents::KeyModifier::Mod_Super;
    }

    return static_cast<Web::UIEvents::KeyModifier>(modifiers);
}

Web::MouseEvent ns_event_to_mouse_event(Web::MouseEvent::Type type, NSEvent* event, NSView* view, Web::UIEvents::MouseButton button)
{
    auto position = [view convertPoint:event.locationInWindow fromView:nil];
    auto device_position = ns_point_to_gfx_point(position).to_type<Web::DevicePixels>();

    auto screen_position = [NSEvent mouseLocation];
    auto device_screen_position = ns_point_to_gfx_point(screen_position).to_type<Web::DevicePixels>();

    auto modifiers = ns_modifiers_to_key_modifiers(event.modifierFlags, button);

    int wheel_delta_x = 0;
    int wheel_delta_y = 0;

    if (type == Web::MouseEvent::Type::MouseDown) {
        if (event.clickCount % 2 == 0) {
            type = Web::MouseEvent::Type::DoubleClick;
        }
    } else if (type == Web::MouseEvent::Type::MouseWheel) {
        static constexpr CGFloat imprecise_scroll_multiplier = 24;
        CGFloat delta_x = -[event deltaX] * imprecise_scroll_multiplier;
        CGFloat delta_y = -[event deltaY] * imprecise_scroll_multiplier;

        wheel_delta_x = static_cast<int>(delta_x);
        wheel_delta_y = static_cast<int>(delta_y);
    }

    return { type, device_position, device_screen_position, button, button, modifiers, wheel_delta_x, wheel_delta_y, nullptr };
}

struct DragData : public Web::BrowserInputData {
    explicit DragData(Vector<URL::URL> urls)
        : urls(move(urls))
    {
    }

    Vector<URL::URL> urls;
};

Web::DragEvent ns_event_to_drag_event(Web::DragEvent::Type type, id<NSDraggingInfo> event, NSView* view)
{
    auto position = [view convertPoint:event.draggingLocation fromView:nil];
    auto device_position = ns_point_to_gfx_point(position).to_type<Web::DevicePixels>();

    auto screen_position = [NSEvent mouseLocation];
    auto device_screen_position = ns_point_to_gfx_point(screen_position).to_type<Web::DevicePixels>();

    auto button = Web::UIEvents::MouseButton::Primary;
    auto modifiers = ns_modifiers_to_key_modifiers([NSEvent modifierFlags], button);

    Vector<Web::HTML::SelectedFile> files;
    OwnPtr<DragData> browser_data;

    auto for_each_file = [&](auto callback) {
        NSArray* file_list = [[event draggingPasteboard] propertyListForType:NSFilenamesPboardType];

        for (NSString* file_path_str in file_list) {
            auto file_path = Ladybird::ns_string_to_byte_string(file_path_str);
            callback(file_path);
        }
    };

    if (type == Web::DragEvent::Type::DragStart) {
        for_each_file([&](ByteString const& file_path) {
            if (auto file = Web::HTML::SelectedFile::from_file_path(file_path); file.is_error())
                warnln("Unable to open file {}: {}", file_path, file.error());
            else
                files.append(file.release_value());
        });
    } else if (type == Web::DragEvent::Type::Drop) {
        Vector<URL::URL> urls;

        for_each_file([&](ByteString const& file_path) {
            if (auto url = URL::create_with_url_or_path(file_path); url.has_value())
                urls.append(url.release_value());
        });

        browser_data = make<DragData>(move(urls));
    }

    return { type, device_position, device_screen_position, button, button, modifiers, move(files), move(browser_data) };
}

Vector<URL::URL> drag_event_url_list(Web::DragEvent const& event)
{
    auto& browser_data = as<DragData>(*event.browser_data);
    return move(browser_data.urls);
}

NSEvent* create_context_menu_mouse_event(NSView* view, Gfx::IntPoint position)
{
    return create_context_menu_mouse_event(view, gfx_point_to_ns_point(position));
}

NSEvent* create_context_menu_mouse_event(NSView* view, NSPoint position)
{
    return [NSEvent mouseEventWithType:NSEventTypeRightMouseUp
                              location:[view convertPoint:position fromView:nil]
                         modifierFlags:0
                             timestamp:0
                          windowNumber:[[view window] windowNumber]
                               context:nil
                           eventNumber:1
                            clickCount:1
                              pressure:1.0];
}

static Web::UIEvents::KeyCode ns_key_code_to_key_code(unsigned short key_code, Web::UIEvents::KeyModifier& modifiers)
{
    auto augment_modifiers_and_return = [&](auto key, auto modifier) {
        modifiers = static_cast<Web::UIEvents::KeyModifier>(static_cast<unsigned>(modifiers) | modifier);
        return key;
    };

    // clang-format off
    switch (key_code) {
    case kVK_ANSI_0: return Web::UIEvents::KeyCode::Key_0;
    case kVK_ANSI_1: return Web::UIEvents::KeyCode::Key_1;
    case kVK_ANSI_2: return Web::UIEvents::KeyCode::Key_2;
    case kVK_ANSI_3: return Web::UIEvents::KeyCode::Key_3;
    case kVK_ANSI_4: return Web::UIEvents::KeyCode::Key_4;
    case kVK_ANSI_5: return Web::UIEvents::KeyCode::Key_5;
    case kVK_ANSI_6: return Web::UIEvents::KeyCode::Key_6;
    case kVK_ANSI_7: return Web::UIEvents::KeyCode::Key_7;
    case kVK_ANSI_8: return Web::UIEvents::KeyCode::Key_8;
    case kVK_ANSI_9: return Web::UIEvents::KeyCode::Key_9;
    case kVK_ANSI_A: return Web::UIEvents::KeyCode::Key_A;
    case kVK_ANSI_B: return Web::UIEvents::KeyCode::Key_B;
    case kVK_ANSI_C: return Web::UIEvents::KeyCode::Key_C;
    case kVK_ANSI_D: return Web::UIEvents::KeyCode::Key_D;
    case kVK_ANSI_E: return Web::UIEvents::KeyCode::Key_E;
    case kVK_ANSI_F: return Web::UIEvents::KeyCode::Key_F;
    case kVK_ANSI_G: return Web::UIEvents::KeyCode::Key_G;
    case kVK_ANSI_H: return Web::UIEvents::KeyCode::Key_H;
    case kVK_ANSI_I: return Web::UIEvents::KeyCode::Key_I;
    case kVK_ANSI_J: return Web::UIEvents::KeyCode::Key_J;
    case kVK_ANSI_K: return Web::UIEvents::KeyCode::Key_K;
    case kVK_ANSI_L: return Web::UIEvents::KeyCode::Key_L;
    case kVK_ANSI_M: return Web::UIEvents::KeyCode::Key_M;
    case kVK_ANSI_N: return Web::UIEvents::KeyCode::Key_N;
    case kVK_ANSI_O: return Web::UIEvents::KeyCode::Key_O;
    case kVK_ANSI_P: return Web::UIEvents::KeyCode::Key_P;
    case kVK_ANSI_Q: return Web::UIEvents::KeyCode::Key_Q;
    case kVK_ANSI_R: return Web::UIEvents::KeyCode::Key_R;
    case kVK_ANSI_S: return Web::UIEvents::KeyCode::Key_S;
    case kVK_ANSI_T: return Web::UIEvents::KeyCode::Key_T;
    case kVK_ANSI_U: return Web::UIEvents::KeyCode::Key_U;
    case kVK_ANSI_V: return Web::UIEvents::KeyCode::Key_V;
    case kVK_ANSI_W: return Web::UIEvents::KeyCode::Key_W;
    case kVK_ANSI_X: return Web::UIEvents::KeyCode::Key_X;
    case kVK_ANSI_Y: return Web::UIEvents::KeyCode::Key_Y;
    case kVK_ANSI_Z: return Web::UIEvents::KeyCode::Key_Z;
    case kVK_ANSI_Backslash: return Web::UIEvents::KeyCode::Key_Backslash;
    case kVK_ANSI_Comma: return Web::UIEvents::KeyCode::Key_Comma;
    case kVK_ANSI_Equal: return Web::UIEvents::KeyCode::Key_Equal;
    case kVK_ANSI_Grave: return Web::UIEvents::KeyCode::Key_Backtick;
    case kVK_ANSI_Keypad0: return augment_modifiers_and_return(Web::UIEvents::KeyCode::Key_0, Web::UIEvents::KeyModifier::Mod_Keypad);
    case kVK_ANSI_Keypad1: return augment_modifiers_and_return(Web::UIEvents::KeyCode::Key_1, Web::UIEvents::KeyModifier::Mod_Keypad);
    case kVK_ANSI_Keypad2: return augment_modifiers_and_return(Web::UIEvents::KeyCode::Key_2, Web::UIEvents::KeyModifier::Mod_Keypad);
    case kVK_ANSI_Keypad3: return augment_modifiers_and_return(Web::UIEvents::KeyCode::Key_3, Web::UIEvents::KeyModifier::Mod_Keypad);
    case kVK_ANSI_Keypad4: return augment_modifiers_and_return(Web::UIEvents::KeyCode::Key_4, Web::UIEvents::KeyModifier::Mod_Keypad);
    case kVK_ANSI_Keypad5: return augment_modifiers_and_return(Web::UIEvents::KeyCode::Key_5, Web::UIEvents::KeyModifier::Mod_Keypad);
    case kVK_ANSI_Keypad6: return augment_modifiers_and_return(Web::UIEvents::KeyCode::Key_6, Web::UIEvents::KeyModifier::Mod_Keypad);
    case kVK_ANSI_Keypad7: return augment_modifiers_and_return(Web::UIEvents::KeyCode::Key_7, Web::UIEvents::KeyModifier::Mod_Keypad);
    case kVK_ANSI_Keypad8: return augment_modifiers_and_return(Web::UIEvents::KeyCode::Key_8, Web::UIEvents::KeyModifier::Mod_Keypad);
    case kVK_ANSI_Keypad9: return augment_modifiers_and_return(Web::UIEvents::KeyCode::Key_9, Web::UIEvents::KeyModifier::Mod_Keypad);
    case kVK_ANSI_KeypadClear: return augment_modifiers_and_return(Web::UIEvents::KeyCode::Key_Delete, Web::UIEvents::KeyModifier::Mod_Keypad);
    case kVK_ANSI_KeypadDecimal: return augment_modifiers_and_return(Web::UIEvents::KeyCode::Key_Period, Web::UIEvents::KeyModifier::Mod_Keypad);
    case kVK_ANSI_KeypadDivide: return augment_modifiers_and_return(Web::UIEvents::KeyCode::Key_Slash, Web::UIEvents::KeyModifier::Mod_Keypad);
    case kVK_ANSI_KeypadEnter: return augment_modifiers_and_return(Web::UIEvents::KeyCode::Key_Return, Web::UIEvents::KeyModifier::Mod_Keypad);
    case kVK_ANSI_KeypadEquals: return augment_modifiers_and_return(Web::UIEvents::KeyCode::Key_Equal, Web::UIEvents::KeyModifier::Mod_Keypad);
    case kVK_ANSI_KeypadMinus: return augment_modifiers_and_return(Web::UIEvents::KeyCode::Key_Minus, Web::UIEvents::KeyModifier::Mod_Keypad);
    case kVK_ANSI_KeypadMultiply: return augment_modifiers_and_return(Web::UIEvents::KeyCode::Key_Asterisk, Web::UIEvents::KeyModifier::Mod_Keypad);
    case kVK_ANSI_KeypadPlus: return augment_modifiers_and_return(Web::UIEvents::KeyCode::Key_Plus, Web::UIEvents::KeyModifier::Mod_Keypad);
    case kVK_ANSI_LeftBracket: return Web::UIEvents::KeyCode::Key_LeftBracket;
    case kVK_ANSI_Minus: return Web::UIEvents::KeyCode::Key_Minus;
    case kVK_ANSI_Period: return Web::UIEvents::KeyCode::Key_Period;
    case kVK_ANSI_Quote: return Web::UIEvents::KeyCode::Key_Apostrophe;
    case kVK_ANSI_RightBracket: return Web::UIEvents::KeyCode::Key_RightBracket;
    case kVK_ANSI_Semicolon: return Web::UIEvents::KeyCode::Key_Semicolon;
    case kVK_ANSI_Slash: return Web::UIEvents::KeyCode::Key_Slash;
    case kVK_CapsLock: return Web::UIEvents::KeyCode::Key_CapsLock;
    case kVK_Command: return Web::UIEvents::KeyCode::Key_LeftSuper;
    case kVK_Control: return Web::UIEvents::KeyCode::Key_LeftControl;
    case kVK_Delete: return Web::UIEvents::KeyCode::Key_Backspace;
    case kVK_DownArrow: return Web::UIEvents::KeyCode::Key_Down;
    case kVK_End: return Web::UIEvents::KeyCode::Key_End;
    case kVK_Escape: return Web::UIEvents::KeyCode::Key_Escape;
    case kVK_F1: return Web::UIEvents::KeyCode::Key_F1;
    case kVK_F2: return Web::UIEvents::KeyCode::Key_F2;
    case kVK_F3: return Web::UIEvents::KeyCode::Key_F3;
    case kVK_F4: return Web::UIEvents::KeyCode::Key_F4;
    case kVK_F5: return Web::UIEvents::KeyCode::Key_F5;
    case kVK_F6: return Web::UIEvents::KeyCode::Key_F6;
    case kVK_F7: return Web::UIEvents::KeyCode::Key_F7;
    case kVK_F8: return Web::UIEvents::KeyCode::Key_F8;
    case kVK_F9: return Web::UIEvents::KeyCode::Key_F9;
    case kVK_F10: return Web::UIEvents::KeyCode::Key_F10;
    case kVK_F11: return Web::UIEvents::KeyCode::Key_F11;
    case kVK_F12: return Web::UIEvents::KeyCode::Key_F12;
    case kVK_ForwardDelete: return Web::UIEvents::KeyCode::Key_Delete;
    case kVK_Home: return Web::UIEvents::KeyCode::Key_Home;
    case kVK_LeftArrow: return Web::UIEvents::KeyCode::Key_Left;
    case kVK_Option: return Web::UIEvents::KeyCode::Key_LeftAlt;
    case kVK_PageDown: return Web::UIEvents::KeyCode::Key_PageDown;
    case kVK_PageUp: return Web::UIEvents::KeyCode::Key_PageUp;
    case kVK_Return: return Web::UIEvents::KeyCode::Key_Return;
    case kVK_RightArrow: return Web::UIEvents::KeyCode::Key_Right;
    case kVK_RightCommand: return Web::UIEvents::KeyCode::Key_RightSuper;
    case kVK_RightControl: return Web::UIEvents::KeyCode::Key_RightControl;
    case kVK_RightOption: return Web::UIEvents::KeyCode::Key_RightAlt;
    case kVK_RightShift: return Web::UIEvents::KeyCode::Key_RightShift;
    case kVK_Shift: return Web::UIEvents::KeyCode::Key_LeftShift;
    case kVK_Space: return Web::UIEvents::KeyCode::Key_Space;
    case kVK_Tab: return Web::UIEvents::KeyCode::Key_Tab;
    case kVK_UpArrow: return Web::UIEvents::KeyCode::Key_Up;
    default: break;
    }
    // clang-format on

    return Web::UIEvents::KeyCode::Key_Invalid;
}

class KeyData : public Web::BrowserInputData {
public:
    explicit KeyData(NSEvent* event)
        : m_event(event)
    {
    }

    virtual ~KeyData() override = default;

    NSEvent* take_event()
    {
        VERIFY(m_event != nullptr);
        NSEvent* event = m_event;
        m_event = nil;
        return event;
    }

private:
    NSEvent* m_event { nil };
};

Web::KeyEvent ns_event_to_key_event(Web::KeyEvent::Type type, NSEvent* event)
{
    auto modifiers = ns_modifiers_to_key_modifiers(event.modifierFlags);
    auto key_code = ns_key_code_to_key_code(event.keyCode, modifiers);
    auto repeat = false;

    u32 code_point = 0;

    if (event.type == NSEventTypeKeyDown || event.type == NSEventTypeKeyUp) {
        auto const* utf8 = [event.characters UTF8String];
        Utf8View utf8_view { StringView { utf8, strlen(utf8) } };

        code_point = utf8_view.is_empty() ? 0u : *utf8_view.begin();

        repeat = event.isARepeat;
    }

    // NSEvent assigns PUA code points to functional keys, e.g. arrow keys. Do not propagate them.
    if (code_point >= 0xE000 && code_point <= 0xF8FF)
        code_point = 0;

    return { type, key_code, modifiers, code_point, repeat, make<KeyData>(event) };
}

NSEvent* key_event_to_ns_event(Web::KeyEvent const& event)
{
    auto& browser_data = as<KeyData>(*event.browser_data);
    return browser_data.take_event();
}

}
