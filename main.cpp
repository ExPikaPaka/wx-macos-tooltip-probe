// Does wxWidgets register a tooltip on the underlying NSView on macOS?
//
// OrcaSlicer's UV editor draws its tool strip with UVToolButton, a bare wxWindow
// subclass that paints itself and calls SetToolTip() in its constructor. Those
// tooltips do not appear on macOS while the same build shows them on Windows.
// This builds the same shape of widget next to controls whose tooltips are known
// to work, then asks AppKit what each view actually carries.
#include <wx/wx.h>
#include <string>

void        become_foreground_app();        // probe.mm
std::string native_tooltip(wxWindow *w);   // probe.mm
std::string hover_probe(wxWindow *w);      // probe.mm

namespace {

// The same construction UVToolButton uses: a plain wxWindow that paints itself,
// sized only by SetMinSize, with the tooltip set inside the constructor.
class PaintedButton : public wxWindow
{
public:
    PaintedButton(wxWindow *parent, const wxString &label, const wxString &tip, bool opaque_style)
        : wxWindow(parent, wxID_ANY, wxDefaultPosition, wxDefaultSize,
                   wxBORDER_NONE | wxFULL_REPAINT_ON_RESIZE)
        , m_label(label)
    {
        if (opaque_style)
            SetBackgroundStyle(wxBG_STYLE_PAINT);
        SetToolTip(tip);
        Bind(wxEVT_PAINT, [this](wxPaintEvent &) {
            wxPaintDC dc(this);
            dc.SetBrush(*wxLIGHT_GREY_BRUSH);
            dc.DrawRectangle(GetClientRect());
            dc.DrawText(m_label, 4, 4);
        });
        SetMinSize(wxSize(180, 26));
    }

private:
    wxString m_label;
};

struct Probe
{
    wxString  what;
    wxWindow *win;
    wxString  expected;
};

class App : public wxApp
{
public:
    bool OnInit() override
    {
        become_foreground_app();

        auto *frame = new wxFrame(nullptr, wxID_ANY, "tooltip probe", wxDefaultPosition, wxSize(420, 320));
        auto *panel = new wxPanel(frame);
        auto *sizer = new wxBoxSizer(wxVERTICAL);

        auto add = [&](const wxString &what, wxWindow *w, const wxString &tip) {
            sizer->Add(w, 0, wxALL, 8);
            m_probes.push_back({what, w, tip});
        };

        add("wxWindow + BG_STYLE_PAINT (UVToolButton shape)",
            new PaintedButton(panel, "painted, opaque", "tip A", true), "tip A");
        add("wxWindow, default background style",
            new PaintedButton(panel, "painted, default", "tip B", false), "tip B");

        auto *text = new wxStaticText(panel, wxID_ANY, "wxStaticText");
        text->SetToolTip("tip C");
        add("wxStaticText", text, "tip C");

        auto *btn = new wxButton(panel, wxID_ANY, "wxButton");
        btn->SetToolTip("tip D");
        add("wxButton", btn, "tip D");

        panel->SetSizer(sizer);
        frame->Show();
        frame->Raise();

        // Probe once the frame is really on screen: a window laid out but not yet
        // mapped is exactly the state this is meant to rule in or out.
        CallAfter([this, frame] { wxMilliSleep(1500); report(frame); });
        return true;
    }

private:
    void report(wxFrame *frame)
    {
        wxPrintf("wxWidgets %s\n\n", wxVERSION_STRING);
        int failures = 0;
        for (const auto &p : m_probes) {
            const std::string native = native_tooltip(p.win);
            const wxString    wxside = p.win->GetToolTipText();
            const bool        ok     = native == std::string(p.expected.utf8_str());
            if (!ok)
                ++failures;
            wxPrintf("%-48s wx=%-8s NSView=%-10s %s\n", p.what, wxside,
                     native.empty() ? "(nil)" : native.c_str(), ok ? "ok" : "MISMATCH");
        }
        wxPrintf("\n-- hover --\n");
        for (const auto &p : m_probes)
            wxPrintf("%-48s %s\n", p.what, hover_probe(p.win).c_str());

        wxPrintf("\nmismatches: %d\n", failures);
        frame->Destroy();
        ExitMainLoop();
        m_exit = failures;
    }

    std::vector<Probe> m_probes;
    int                m_exit = 0;

public:
    int OnExit() override { return m_exit; }
};

} // namespace

wxIMPLEMENT_APP_CONSOLE(App);
