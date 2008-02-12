//
// Based on OAStackView, which is....
//
// Copyright 1997-2004 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//

#import <Cocoa/Cocoa.h>

@interface KTStackView : NSView
{
    IBOutlet id dataSource;
    NSView *nonretained_stretchyView;
    struct {
        unsigned int needsReload:1;
        unsigned int needsLayout:1;
        unsigned int layoutDisabled:1;
    } flags;
}

- (id) dataSource;
- (void) setDataSource: (id) dataSource;

- (void) reloadSubviews;
- (void) subviewSizeChanged;

- (void)setLayoutEnabled:(BOOL)layoutEnabled display:(BOOL)display;

@end

@interface NSObject(KTStackViewDataSource)
- (NSArray *) subviewsForStackView: (KTStackView *) stackView;
@end

@interface NSView (KTStackViewHelper)
- (KTStackView *) enclosingStackView;
@end

extern NSString *KTStackViewDidLayoutSubviews;

