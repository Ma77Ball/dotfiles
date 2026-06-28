package tui

import "github.com/charmbracelet/lipgloss"

// Palette and Lipgloss styles for the dashboard (adaptive light/dark ANSI 256).
var (
	colSelectedBg = lipgloss.AdaptiveColor{Light: "7", Dark: "236"}   // selection bar / active tab / footer
	colPrimaryBd  = lipgloss.AdaptiveColor{Light: "8", Dark: "8"}     // tab underline / sidebar border
	colFaintBd    = lipgloss.AdaptiveColor{Light: "254", Dark: "234"} // faint rules
	colSecondBd   = lipgloss.AdaptiveColor{Light: "8", Dark: "240"}   // tab separators
	colPrimary    = lipgloss.AdaptiveColor{Light: "0", Dark: "15"}    // primary text
	colSecondary  = lipgloss.AdaptiveColor{Light: "244", Dark: "251"} // secondary text
	colFaint      = lipgloss.AdaptiveColor{Light: "7", Dark: "245"}   // faint text
	colLogo       = lipgloss.Color("#00F9FB")                         // logo cyan
	colSuccess    = lipgloss.AdaptiveColor{Light: "10", Dark: "10"}
	colWarning    = lipgloss.AdaptiveColor{Light: "11", Dark: "11"}
	colError      = lipgloss.AdaptiveColor{Light: "1", Dark: "9"}

	// --- tab row ---
	styTab = lipgloss.NewStyle().
		Faint(true).
		Padding(0, 2)

	styTabActive = styTab.
			Faint(false).
			Bold(true).
			Background(colSelectedBg).
			Foreground(colPrimary)

	styTabSep = lipgloss.NewStyle().Foreground(colSecondBd)

	styTabsRow = lipgloss.NewStyle().
			BorderStyle(lipgloss.ThickBorder()).
			BorderTop(false).
			BorderLeft(false).
			BorderRight(false).
			BorderBottom(true).
			BorderBottomForeground(colPrimaryBd)

	styLogo    = lipgloss.NewStyle().Foreground(colLogo).Bold(true)
	styLogoSub = lipgloss.NewStyle().Foreground(colFaint)

	// --- table ---
	styHeaderCell = lipgloss.NewStyle().Bold(true).Foreground(colPrimary).Padding(0, 1)

	// --- priority markers ---
	styPrioHigh = lipgloss.NewStyle().Foreground(colError).Bold(true)
	styPrioMed  = lipgloss.NewStyle().Foreground(colWarning)
	styPrioLow  = lipgloss.NewStyle().Foreground(colFaint)
	styDoneMark = lipgloss.NewStyle().Foreground(colSuccess).Bold(true)

	// --- sidebar / notes ---
	stySidebar = lipgloss.NewStyle().
			BorderStyle(lipgloss.NormalBorder()).
			BorderTop(false).
			BorderRight(false).
			BorderBottom(false).
			BorderLeft(true).
			BorderForeground(colPrimaryBd).
			Padding(0, 2)

	styTitle       = lipgloss.NewStyle().Foreground(colPrimary).Bold(true)
	stySidebarMeta = lipgloss.NewStyle().Foreground(colFaint)
	stySidebarRule = lipgloss.NewStyle().Foreground(colFaintBd)
	styPager       = lipgloss.NewStyle().Foreground(colFaint).Bold(true)

	// --- footer bar ---
	styFooterBar = lipgloss.NewStyle().Background(colSelectedBg).Foreground(colFaint)
	styHelpPill  = lipgloss.NewStyle().Background(colFaint).Foreground(colSelectedBg).Padding(0, 1)
	styFooterErr = lipgloss.NewStyle().Background(colSelectedBg).Foreground(colError).Bold(true)
	styFooterOk  = lipgloss.NewStyle().Background(colSelectedBg).Foreground(colSuccess)

	// --- placeholders ---
	styPlaceholder = lipgloss.NewStyle().Foreground(colFaint).Italic(true)
	styError       = lipgloss.NewStyle().Foreground(colError).Bold(true)

	// --- input prompt (add / edit / notes) ---
	styInputLabel = lipgloss.NewStyle().Foreground(colLogo).Bold(true)

	// --- help overlay ---
	styHelpBox = lipgloss.NewStyle().
			Border(lipgloss.RoundedBorder()).
			BorderForeground(colLogo).
			Padding(1, 3)
	styHelpHead = lipgloss.NewStyle().Foreground(colLogo).Bold(true)
	styHelpKey  = lipgloss.NewStyle().Foreground(colPrimary).Bold(true)
	styHelpDesc = lipgloss.NewStyle().Foreground(colSecondary)
)
