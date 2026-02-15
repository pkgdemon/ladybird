/*
 * Copyright (c) 2023-2025, Tim Flynn <trflynn89@ladybird.org>
 * Copyright (c) 2024, the Ladybird developers.
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

#include <AK/Assertions.h>
#include <AK/HashMap.h>
#include <AK/IDAllocator.h>
#include <AK/Singleton.h>
#include <AK/TemporaryChange.h>
#include <Application/EventLoopImplementationGNUstep.h>
#include <LibCore/Event.h>
#include <LibCore/Notifier.h>
#include <LibCore/ThreadEventQueue.h>
#include <LibThreading/RWLock.h>

#import <AppKit/AppKit.h>
#import <Foundation/Foundation.h>

#include <signal.h>
#include <sys/select.h>
#include <sys/time.h>
#include <sys/types.h>

#if !__has_feature(objc_arc)
#    error "This project requires ARC"
#endif

namespace Ladybird {

struct ThreadData;
static thread_local OwnPtr<ThreadData> s_this_thread_data;
static HashMap<pthread_t, ThreadData*> s_thread_data;
static thread_local pthread_t s_thread_id;
static Threading::RWLock s_thread_data_lock;

struct ThreadData {
    static ThreadData& the()
    {
        if (s_thread_id == 0)
            s_thread_id = pthread_self();
        if (!s_this_thread_data) {
            s_this_thread_data = make<ThreadData>();
            Threading::RWLockLocker<Threading::LockMode::Write> locker(s_thread_data_lock);
            s_thread_data.set(s_thread_id, s_this_thread_data);
        }
        return *s_this_thread_data;
    }

    static ThreadData* for_thread(pthread_t thread_id)
    {
        Threading::RWLockLocker<Threading::LockMode::Read> locker(s_thread_data_lock);
        return s_thread_data.get(thread_id).value_or(nullptr);
    }

    ~ThreadData()
    {
        Threading::RWLockLocker<Threading::LockMode::Write> locker(s_thread_data_lock);
        s_thread_data.remove(s_thread_id);
    }

    IDAllocator timer_id_allocator;
    HashMap<int, NSTimer*> timers;
    struct NotifierState {
        int fd { -1 };
        NSTimer* timer { nil };
    };
    HashMap<Core::Notifier*, NotifierState> notifiers;
};

class SignalHandlers : public RefCounted<SignalHandlers> {
    AK_MAKE_NONCOPYABLE(SignalHandlers);
    AK_MAKE_NONMOVABLE(SignalHandlers);

public:
    SignalHandlers(int signal_number);
    ~SignalHandlers();

    void dispatch();
    int add(Function<void(int)>&& handler);
    bool remove(int handler_id);

    bool is_empty() const
    {
        if (m_calling_handlers) {
            for (auto const& handler : m_handlers_pending) {
                if (handler.value)
                    return false;
            }
        }
        return m_handlers.is_empty();
    }

    bool have(int handler_id) const
    {
        if (m_calling_handlers) {
            auto it = m_handlers_pending.find(handler_id);
            if (it != m_handlers_pending.end()) {
                if (!it->value)
                    return false;
            }
        }
        return m_handlers.contains(handler_id);
    }

    int m_signal_number;
    void (*m_original_handler)(int);
    HashMap<int, Function<void(int)>> m_handlers;
    HashMap<int, Function<void(int)>> m_handlers_pending;
    bool m_calling_handlers { false };
};

static HashMap<int, SignalHandlers*> s_signal_handlers_map;

static void gnustep_signal_handler(int signum)
{
    auto* handlers = s_signal_handlers_map.get(signum).value_or(nullptr);
    if (handlers) {
        // Post an event to handle signal in the main run loop
        auto* event = [NSEvent otherEventWithType:NSEventTypeApplicationDefined
                                         location:NSMakePoint(0, 0)
                                    modifierFlags:0
                                        timestamp:0
                                     windowNumber:0
                                          context:nil
                                          subtype:signum
                                            data1:0
                                            data2:0];
        [NSApp postEvent:event atStart:YES];
    }
}

SignalHandlers::SignalHandlers(int signal_number)
    : m_signal_number(signal_number)
    , m_original_handler(signal(signal_number, gnustep_signal_handler))
{
    s_signal_handlers_map.set(signal_number, this);
}

SignalHandlers::~SignalHandlers()
{
    s_signal_handlers_map.remove(m_signal_number);
    (void)::signal(m_signal_number, m_original_handler);
}

struct SignalHandlersInfo {
    HashMap<int, NonnullRefPtr<SignalHandlers>> signal_handlers;
    int next_signal_id { 0 };
};

static Singleton<SignalHandlersInfo> s_signals;
static SignalHandlersInfo* signals_info()
{
    return s_signals.ptr();
}

void SignalHandlers::dispatch()
{
    TemporaryChange change(m_calling_handlers, true);
    for (auto& handler : m_handlers)
        handler.value(m_signal_number);
    if (!m_handlers_pending.is_empty()) {
        for (auto& handler : m_handlers_pending) {
            if (handler.value) {
                auto result = m_handlers.set(handler.key, move(handler.value));
                VERIFY(result == AK::HashSetResult::InsertedNewEntry);
            } else {
                m_handlers.remove(handler.key);
            }
        }
        m_handlers_pending.clear();
    }
}

int SignalHandlers::add(Function<void(int)>&& handler)
{
    int id = ++signals_info()->next_signal_id;
    if (m_calling_handlers)
        m_handlers_pending.set(id, move(handler));
    else
        m_handlers.set(id, move(handler));
    return id;
}

bool SignalHandlers::remove(int handler_id)
{
    VERIFY(handler_id != 0);
    if (m_calling_handlers) {
        auto it = m_handlers.find(handler_id);
        if (it != m_handlers.end()) {
            m_handlers_pending.set(handler_id, {});
            return true;
        }
        it = m_handlers_pending.find(handler_id);
        if (it != m_handlers_pending.end()) {
            if (!it->value)
                return false;
            it->value = nullptr;
            return true;
        }
        return false;
    }
    return m_handlers.remove(handler_id);
}

static void post_application_event()
{
    auto* event = [NSEvent otherEventWithType:NSEventTypeApplicationDefined
                                     location:NSMakePoint(0, 0)
                                modifierFlags:0
                                    timestamp:0
                                 windowNumber:0
                                      context:nil
                                      subtype:0
                                        data1:0
                                        data2:0];
    [NSApp postEvent:event atStart:NO];
}

NonnullOwnPtr<Core::EventLoopImplementation> EventLoopManagerGNUstep::make_implementation()
{
    return EventLoopImplementationGNUstep::create();
}

intptr_t EventLoopManagerGNUstep::register_timer(Core::EventReceiver& receiver, int interval_milliseconds, bool should_reload)
{
    auto& thread_data = ThreadData::the();
    auto timer_id = thread_data.timer_id_allocator.allocate();
    auto weak_receiver = receiver.make_weak_ptr();

    auto interval_seconds = static_cast<double>(interval_milliseconds) / 1000.0;

    auto* timer = [NSTimer scheduledTimerWithTimeInterval:interval_seconds
                                                  repeats:should_reload
                                                    block:^(NSTimer* t) {
                                                        auto receiver_ref = weak_receiver.strong_ref();
                                                        if (!receiver_ref) {
                                                            [t invalidate];
                                                            return;
                                                        }
                                                        Core::TimerEvent event;
                                                        receiver_ref->dispatch_event(event);
                                                    }];

    [[NSRunLoop currentRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
    thread_data.timers.set(timer_id, timer);

    return timer_id;
}

void EventLoopManagerGNUstep::unregister_timer(intptr_t timer_id)
{
    auto& thread_data = ThreadData::the();
    thread_data.timer_id_allocator.deallocate(static_cast<int>(timer_id));

    auto it = thread_data.timers.find(static_cast<int>(timer_id));
    VERIFY(it != thread_data.timers.end());
    auto* timer = it->value;
    thread_data.timers.remove(it);
    [timer invalidate];
}

void EventLoopManagerGNUstep::register_notifier(Core::Notifier& notifier)
{
    auto weak_notifier = notifier.make_weak_ptr();
    int fd = notifier.fd();
    Core::Notifier::Type notifier_type = notifier.type();

    // Create a high-frequency timer to poll for data availability
    auto* timer = [NSTimer scheduledTimerWithTimeInterval:0.001
                                                  repeats:YES
                                                    block:^(NSTimer* t) {
                                                        auto notifier_ref = weak_notifier.strong_ref();
                                                        if (!notifier_ref) {
                                                            [t invalidate];
                                                            return;
                                                        }

                                                        fd_set fds;
                                                        FD_ZERO(&fds);
                                                        FD_SET(fd, &fds);

                                                        struct timeval tv = { 0, 0 };

                                                        int result = 0;
                                                        if (notifier_type == Core::Notifier::Type::Read) {
                                                            result = select(fd + 1, &fds, nullptr, nullptr, &tv);
                                                        } else if (notifier_type == Core::Notifier::Type::Write) {
                                                            result = select(fd + 1, nullptr, &fds, nullptr, &tv);
                                                        }

                                                        if (result > 0 && FD_ISSET(fd, &fds)) {
                                                            Core::NotifierActivationEvent event;
                                                            notifier_ref->dispatch_event(event);
                                                        }
                                                    }];

    [[NSRunLoop currentRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];

    ThreadData::the().notifiers.set(&notifier, { fd, timer });
    notifier.set_owner_thread(s_thread_id);
}

void EventLoopManagerGNUstep::unregister_notifier(Core::Notifier& notifier)
{
    auto* thread_data = ThreadData::for_thread(notifier.owner_thread());
    if (!thread_data)
        return;
    auto state = thread_data->notifiers.take(&notifier);
    VERIFY(state.has_value());
    [state->timer invalidate];
}

void EventLoopManagerGNUstep::did_post_event()
{
    post_application_event();
}

int EventLoopManagerGNUstep::register_signal(int signal_number, Function<void(int)> handler)
{
    VERIFY(signal_number != 0);
    auto& info = *signals_info();
    auto handlers = info.signal_handlers.find(signal_number);
    if (handlers == info.signal_handlers.end()) {
        auto signal_handlers = adopt_ref(*new SignalHandlers(signal_number));
        auto handler_id = signal_handlers->add(move(handler));
        info.signal_handlers.set(signal_number, move(signal_handlers));
        return handler_id;
    } else {
        return handlers->value->add(move(handler));
    }
}

void EventLoopManagerGNUstep::unregister_signal(int handler_id)
{
    VERIFY(handler_id != 0);
    int remove_signal_number = 0;
    auto& info = *signals_info();
    for (auto& h : info.signal_handlers) {
        auto& handlers = *h.value;
        if (handlers.remove(handler_id)) {
            if (handlers.is_empty())
                remove_signal_number = handlers.m_signal_number;
            break;
        }
    }
    if (remove_signal_number != 0)
        info.signal_handlers.remove(remove_signal_number);
}

NonnullOwnPtr<EventLoopImplementationGNUstep> EventLoopImplementationGNUstep::create()
{
    return adopt_own(*new EventLoopImplementationGNUstep);
}

EventLoopImplementationGNUstep::EventLoopImplementationGNUstep() = default;
EventLoopImplementationGNUstep::~EventLoopImplementationGNUstep() = default;

int EventLoopImplementationGNUstep::exec()
{
    [NSApp run];
    return m_exit_code;
}

size_t EventLoopImplementationGNUstep::pump(PumpMode mode)
{
    auto* wait_until = mode == PumpMode::WaitForEvents ? [NSDate distantFuture] : [NSDate distantPast];

    auto* event = [NSApp nextEventMatchingMask:NSAnyEventMask
                                     untilDate:wait_until
                                        inMode:NSDefaultRunLoopMode
                                       dequeue:YES];

    while (event) {
        // Handle signal events
        if ([event type] == NSEventTypeApplicationDefined && [event subtype] > 0) {
            int signum = [event subtype];
            auto* handlers = s_signal_handlers_map.get(signum).value_or(nullptr);
            if (handlers) {
                handlers->dispatch();
            }
        }

        [NSApp sendEvent:event];

        event = [NSApp nextEventMatchingMask:NSAnyEventMask
                                   untilDate:nil
                                      inMode:NSDefaultRunLoopMode
                                     dequeue:YES];
    }

    return 0;
}

void EventLoopImplementationGNUstep::quit(int exit_code)
{
    m_exit_code = exit_code;
    [NSApp stop:nil];
}

void EventLoopImplementationGNUstep::wake()
{
    post_application_event();
}

bool EventLoopImplementationGNUstep::was_exit_requested() const
{
    return ![NSApp isRunning];
}

}
