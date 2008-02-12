// http://iratescotsman.com/products/source/
// Eric Wang's reimplementation of my PopUpImage class (see above), using a subclass of NSPopUpButton.

// TJT added NSCoding and NSToolbar support

@interface RYZImagePopUpButtonCell : NSPopUpButtonCell <NSCoding>
{
    NSButtonCell *_buttonCell;
    NSSize _iconSize;
    BOOL _showsMenuWhenIconClicked;
    NSImage *_iconImage;
    NSImage *_arrowImage;
    NSToolbar *_toolbar;		// not retained, to prevent retain cycles
}

- (void)encodeWithCoder:(NSCoder *)encoder;
- (id)initWithCoder:(NSCoder *)decoder;

- (void)setToolbar:(NSToolbar *)toolbar;

// --- Getting and setting the icon size ---
- (NSSize)iconSize;
- (void)setIconSize:(NSSize)iconSize;

- (NSSize)arrowSize;

- (float)toolbarIconWidth;
- (NSSize)minimumSize;
- (NSSize)maximumSize;

// --- Getting and setting whether the menu is shown when the icon is clicked ---
- (BOOL)showsMenuWhenIconClicked;
- (void)setShowsMenuWhenIconClicked:(BOOL)showsMenuWhenIconClicked;

// --- Getting and setting the icon image ---
- (NSImage *)iconImage;
- (void)setIconImage:(NSImage *)iconImage;

// --- Getting and setting the arrow image ---
- (NSImage *)arrowImage;
- (void)setArrowImage:(NSImage *)arrowImage;

@end
