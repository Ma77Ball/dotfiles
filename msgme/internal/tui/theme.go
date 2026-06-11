package tui

import "github.com/charmbracelet/lipgloss"

// Palette and styles ported from gh-dash's theme so msgme shares its look:
// a two-line cyan logo + pill tab row with a thick underline, two-line table
// rows with a full-width selection bar, a left-bordered markdown sidebar, and a
// full-width footer bar with a "? help" pill. Colors are adaptive light/dark
// pairs copied from gh-dash's DefaultTheme (ANSI 256).
var (
	colSelectedBg = lipgloss.AdaptiveColor{Light: "7", Dark: "236"}   // selection bar / active tab / footer
	colPrimaryBd  = lipgloss.AdaptiveColor{Light: "8", Dark: "8"}     // tab underline / sidebar border
	colFaintBd    = lipgloss.AdaptiveColor{Light: "254", Dark: "234"} // faint rules
	colSecondBd   = lipgloss.AdaptiveColor{Light: "8", Dark: "240"}   // tab separators
	colPrimary    = lipgloss.AdaptiveColor{Light: "0", Dark: "15"}    // primary text
	colSecondary  = lipgloss.AdaptiveColor{Light: "244", Dark: "251"} // secondary text
	colFaint      = lipgloss.AdaptiveColor{Light: "7", Dark: "245"}   // faint text
	colLogo       = lipgloss.Color("#00F9FB")                         // gh-dash logo cyan
	colUnread     = lipgloss.AdaptiveColor{Light: "5", Dark: "213"}   // unread dot
	colSuccess    = lipgloss.AdaptiveColor{Light: "10", Dark: "10"}
	colWarning    = lipgloss.AdaptiveColor{Light: "11", Dark: "11"}
	colError      = lipgloss.AdaptiveColor{Light: "1", Dark: "9"}

	// --- tab row (gh-dash Tabs.*) ---
	styTab = lipgloss.NewStyle().
		Faint(true).
		Padding(0, 2)

	styTabActive = styTab.
			Faint(false).
			Bold(true).
			Background(colSelectedBg).
			Foreground(colPrimary)

	styTabSetup = styTab // faint, with a hollow marker added in the view

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

	// --- sub-tab bar (within an app: e.g. DMs / Mentions) ---
	stySub       = lipgloss.NewStyle().Foreground(colFaint)
	stySubActive = lipgloss.NewStyle().Foreground(colPrimary).Bold(true).Underline(true)

	// --- table (gh-dash Table.*) ---
	styHeaderCell = lipgloss.NewStyle().Bold(true).Foreground(colPrimary).Padding(0, 1)

	styUnreadDot = lipgloss.NewStyle().Foreground(colUnread)

	// --- sidebar / preview (gh-dash Sidebar.*) ---
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

	// --- footer bar (gh-dash Common.FooterStyle + "? help" pill) ---
	styFooterBar = lipgloss.NewStyle().Background(colSelectedBg).Foreground(colFaint)
	styHelpPill  = lipgloss.NewStyle().Background(colFaint).Foreground(colSelectedBg).Padding(0, 1)
	styFooterErr = lipgloss.NewStyle().Background(colSelectedBg).Foreground(colError).Bold(true)
	styFooterOk  = lipgloss.NewStyle().Background(colSelectedBg).Foreground(colSuccess)

	// --- spinner / placeholders ---
	stySpinner     = lipgloss.NewStyle().Foreground(colLogo)
	styPlaceholder = lipgloss.NewStyle().Foreground(colFaint).Italic(true)
	styError       = lipgloss.NewStyle().Foreground(colError).Bold(true)

	// --- setup card (unconnected provider) ---
	stySetupBox = lipgloss.NewStyle().
			Border(lipgloss.RoundedBorder()).
			BorderForeground(colLogo).
			Padding(1, 3)
	stySetupHead = lipgloss.NewStyle().Foreground(colLogo).Bold(true)
	stySetupBody = lipgloss.NewStyle().Foreground(colSecondary)
)
