// Ask AppKit directly what a wxWindow's backing NSView carries, and whether a
// tooltip window actually appears when the cursor rests on it.
#import <Cocoa/Cocoa.h>
#include <wx/wx.h>
#include <string>

// A plain executable is a background process on macOS, and a background app's
// windows do not take part in normal tooltip tracking. Make it a regular app so
// the probe measures tooltips and not activation policy.
void become_foreground_app()
{
    [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
    [NSApp activateIgnoringOtherApps:YES];
}

std::string native_tooltip(wxWindow *w)
{
    NSView *view = (NSView *) w->GetHandle();
    if (view == nil)
        return "(no NSView)";
    NSString *tip = [view toolTip];
    return tip == nil ? std::string() : std::string([tip UTF8String]);
}

// Park the cursor over the widget and look for a tooltip window.
//
// Counting every window on screen was wrong twice over: a tooltip left over from
// the previous widget keeps the total from rising, and warping the cursor moves
// it without producing the mouse-moved events that start AppKit's tooltip timer.
// So count only windows this process owns, and feed the event loop a real
// mouse-moved event, which needs no accessibility grant because it never leaves
// the process.
static NSUInteger own_window_count()
{
    NSArray *all = (__bridge_transfer NSArray *) CGWindowListCopyWindowInfo(
        kCGWindowListOptionOnScreenOnly | kCGWindowListExcludeDesktopElements, kCGNullWindowID);
    const pid_t me    = [[NSProcessInfo processInfo] processIdentifier];
    NSUInteger  count = 0;
    for (NSDictionary *w in all)
        if ([[w objectForKey:(id) kCGWindowOwnerPID] intValue] == me)
            ++count;
    return count;
}

std::string hover_probe(wxWindow *w)
{
    NSView *view = (NSView *) w->GetHandle();
    if (view == nil || [view window] == nil)
        return "no view";
    NSWindow *window = [view window];

    // An NSWindow ignores mouse-moved events unless asked to take them, so
    // without this the posted events are dropped before any tracking code sees
    // them and nothing ever starts the tooltip timer.
    [window setAcceptsMouseMovedEvents:YES];
    [window makeKeyAndOrderFront:nil];

    // Start away from the widget so the move onto it is a real crossing.
    CGWarpMouseCursorPosition(CGPointMake(5, 5));
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.3]];
    const NSUInteger before = own_window_count();

    const NSPoint centre_in_window = [view convertPoint:NSMakePoint(NSMidX([view bounds]),
                                                                    NSMidY([view bounds]))
                                                 toView:nil];
    const NSRect  on_screen = [window convertRectToScreen:
                                  NSMakeRect(centre_in_window.x, centre_in_window.y, 1, 1)];
    CGWarpMouseCursorPosition(CGPointMake(NSMinX(on_screen),
                                          NSMaxY([[NSScreen screens][0] frame]) - NSMinY(on_screen)));

    for (int i = 0; i < 60; ++i) {      // up to 6 s: the system delay plus slack
        NSEvent *move = [NSEvent mouseEventWithType:NSEventTypeMouseMoved
                                           location:centre_in_window
                                      modifierFlags:0
                                          timestamp:[[NSProcessInfo processInfo] systemUptime]
                                       windowNumber:[window windowNumber]
                                            context:nil
                                        eventNumber:0
                                         clickCount:0
                                           pressure:0];
        if (move != nil)
            [NSApp postEvent:move atStart:NO];
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
        if (own_window_count() > before)
            return "tooltip shown";
    }
    return "NO TOOLTIP";
}
