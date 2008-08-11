//
// Based on OAStackView, which is....
//
// Copyright 1997-2004 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import "KTStackView.h"

NSString *KTStackViewDidLayoutSubviews = @"KTStackViewDidLayoutSubviews";

@interface KTStackView (PrivateAPI)
- (void) _loadSubviews;
- (void) _layoutSubviews;
@end

/*"
KTStackView assumes that all of its subviews line up in one direction (only vertical stacks are supported currently).  When a view is removed, the space is taken up by other views (currently the last view takes all the extra space) and the gap is removed by sliding adjacent views into that space.
"*/
@implementation KTStackView

//
// API
//

- (id) dataSource;
{
    return dataSource;
}

- (void) setDataSource: (id) aDataSource;
{
    dataSource = aDataSource;
    flags.needsReload = 1;

    // This is really a bug.  If we don't do this (not sure if the layout is necessary, but the reload is), then the first window in OmniWeb will not show up (it gets an exception down in the drawing code).  While it seems permissible to ask the data source as soon as we have one, the data source might have some setup of its own left to do.  This way, we force it to be valid immediately which could be bad, but not much we can do with NSView putting the smack down on us.
    [self _loadSubviews];
    [self _layoutSubviews];
}

- (void) reloadSubviews;
{
	[_window makeFirstResponder:nil];	// attempt to fix case 6221
    [self _loadSubviews];
    [self _layoutSubviews];
    [self setNeedsDisplay: YES];
}

- (void) subviewSizeChanged;
{
    //NSLog(@"subviewSizeChanged");
    flags.needsLayout = 1;
    [self setNeedsDisplay: YES];
}

- (void)setLayoutEnabled:(BOOL)layoutEnabled display:(BOOL)display;
{
    flags.layoutDisabled = !layoutEnabled;
    if (display)
        [self setNeedsDisplay:YES];
}

//
// NSView subclass
//

- (BOOL)isFlipped;
{
    return YES;
}

- (void) drawRect: (NSRect) rect;
{
    if (flags.needsReload)
        [self _loadSubviews];
    if (flags.needsLayout)
        [self _layoutSubviews];

    // This doesn't draw the subviews, we're just hooking the reset of the subviews here since this should get done before they are drawn.
    [super drawRect: rect];
}

// This doesn't protect against having a subview removed, but some checking is better than none.
- (void) addSubview: (NSView *) view;
{
    [NSException raise: NSInternalInconsistencyException
                format: @"Do not add views directly to a KTStackView -- use the dataSource"];
}

@end

@implementation KTStackView (PrivateAPI)

static int compareBasedOnArray(id object1, id object2, void *orderedObjects)
{
    int index1, index2;

    index1 = [(NSArray *)orderedObjects indexOfObjectIdenticalTo:object1];
    index2 = [(NSArray *)orderedObjects indexOfObjectIdenticalTo:object2];
    if (index1 == index2)
        return NSOrderedSame;
    else if (index1 < index2)
        return NSOrderedAscending;
    else
        return NSOrderedDescending;
}

- (void) _loadSubviews;
{
    NSArray *subviews;
    unsigned int subviewIndex, subviewCount;
    BOOL oldAutodisplay;
    
    
    nonretained_stretchyView = nil;
    flags.needsReload = 0;
    flags.needsLayout = 1;
    
    oldAutodisplay = [_window isAutodisplay];
    [_window setAutodisplay: NO];
    [_window disableFlushWindow];
    
    @try
	{
        subviews = [dataSource subviewsForStackView: self];
        
        // Remove any current subviews that aren't in the new list.  We assume that the number of views is small so an O(N*M) loop is OK
        subviewIndex = [_subviews count];
        while (subviewIndex--) {
            NSView *oldSubview;
            
            oldSubview = [_subviews objectAtIndex: subviewIndex];
            if ([subviews indexOfObjectIdenticalTo: oldSubview] == NSNotFound)
                [oldSubview removeFromSuperviewWithoutNeedingDisplay];
// ^^^^ GETTING SOME CRASHERS HERE, CASE 6221
        }

        // Find the (currently first) view that is going to stretch vertically.
        // Set the autosizing flags such that we will layout correctly due to normal NSView resizing logic (once we have layed out once correctly).
        subviewCount = [subviews count];
        for (subviewIndex = 0; subviewIndex < subviewCount; subviewIndex++) {
            NSView *view;
            unsigned int mask;
            
            // Get the view and set the autosizing flags correctly.  This will mean that the layout will be correct when we get resized due to the normal NSView resizing logic
            view = [subviews objectAtIndex: subviewIndex];
            mask = [view autoresizingMask];
            if (mask & NSViewHeightSizable && !nonretained_stretchyView) {
                nonretained_stretchyView = view;
                [view setAutoresizingMask: NSViewWidthSizable | NSViewHeightSizable];
            } else {
                if (nonretained_stretchyView)
                    // this view comes after (below) the stretchy view
                    [view setAutoresizingMask: NSViewWidthSizable | NSViewMaxYMargin];
                else
                    // this view comes before (above) the stretchy view
                    [view setAutoresizingMask: NSViewWidthSizable | NSViewMinYMargin];
            }
            
            // Call super to work around the -addSubview: check above.  Only add the view if it isn't already one of our subviews
            if ([view superview] != self)
                [super addSubview: view];
        }
        [self sortSubviewsUsingFunction:compareBasedOnArray context:subviews];
        
		if (!nonretained_stretchyView)
		{
//            NSLog(@"KTStackView: No vertically resizable subview returned from dataSource.");
			
			NSRect spaceLeft = [self bounds];
			unsigned int viewIndex, viewCount = [_subviews count];
			NSRect subviewFrame;
			NSView *view;
				
			// Figure out how much space will be taken by the views
			float remainingHeight = spaceLeft.size.height;
			for (viewIndex = 0; viewIndex < viewCount; viewIndex++) {
				view = [_subviews objectAtIndex: viewIndex];
				subviewFrame = [view frame];
				remainingHeight -= subviewFrame.size.height;
			}
			NSSize theSize = [self frame].size;
			theSize.height -= remainingHeight;
			BOOL oldDisabled = flags.layoutDisabled;
			flags.layoutDisabled = YES;
			[self setFrameSize:theSize];			// don't layout yet
			flags.layoutDisabled = oldDisabled;
		}
    } @catch(NSException *exception) {
        NSLog(@"Exception ignored during -[KTStackView _loadSubviews]: %@", exception);
    }
    
    [_window setAutodisplay: oldAutodisplay];
    if (oldAutodisplay)
        [_window setViewsNeedDisplay: YES];
    [_window enableFlushWindow];
}

/*"
Goes through the subviews and finds the first subview that is willing to stretch vertically.  This view is then given all of the height that is not taken by the other subviews.
"*/
- (void) _layoutSubviews;
{
    unsigned int viewIndex, viewCount;
    NSView *view;
    NSRect spaceLeft;
    NSRect subviewFrame;
    BOOL oldAutodisplay;
    float stretchyHeight;

    if (flags.layoutDisabled)
        return;
        
    flags.needsLayout = 0;

    spaceLeft = [self bounds];
    //NSLog(@"total bounds = %@", NSStringFromRect(spaceLeft));
    
    oldAutodisplay = [_window isAutodisplay];
    [_window setAutodisplay: NO];
    [_window disableFlushWindow];
    
    @try {
        viewCount = [_subviews count];
        
        // Figure out how much space will be taken by the non-stretchy views
        stretchyHeight = spaceLeft.size.height;
        for (viewIndex = 0; viewIndex < viewCount; viewIndex++) {
            view = [_subviews objectAtIndex: viewIndex];
            if (view != nonretained_stretchyView) {
                subviewFrame = [view frame];
                stretchyHeight -= subviewFrame.size.height;
            }
        }
        
        //NSLog(@"stretchyHeight = %f", stretchyHeight);
		if (stretchyHeight < 0.0)
		{
			stretchyHeight = 0.0;
		}
        
        // Now set the frame of each of the rectangles
        viewIndex = viewCount;
        while (viewIndex--) {
            float viewHeight;
            
            view = [_subviews objectAtIndex: viewIndex];
            
            if (view == nonretained_stretchyView)
                viewHeight = stretchyHeight;
            else {
                subviewFrame = [view frame];
                viewHeight = NSHeight(subviewFrame);
            }

            subviewFrame = NSMakeRect(NSMinX(spaceLeft), NSMaxY(spaceLeft) - viewHeight,
                                    NSWidth(spaceLeft), viewHeight);
            [view setFrame: subviewFrame];
            //NSLog(@"  subview %@  new frame = %@", [view shortDescription], NSStringFromRect(subviewFrame));
    
            spaceLeft.size.height -= subviewFrame.size.height;
        }
        
        [[NSNotificationCenter defaultCenter] postNotificationName: KTStackViewDidLayoutSubviews
                                                            object: self];
        
    } @catch (NSException *localException) {
        NSLog(@"Exception ignored during -[KTStackView _layoutSubviews]: %@", localException);
    } ;
    
    [_window setAutodisplay: oldAutodisplay];
    if (oldAutodisplay)
        [_window setViewsNeedDisplay: YES];
    [_window enableFlushWindow];
}

- (void)resizeSubviewsWithOldSize:(NSSize)oldSize;
{
	if (nil != nonretained_stretchyView)
	{
		[self _layoutSubviews];	// only makes sense to re-layout if we have a stretchy view
	}
}

@end

@implementation NSView (KTStackViewHelper)

- (KTStackView *) enclosingStackView;
{
    NSView *view;
    Class stackViewClass;
    
    view = [self superview];
    stackViewClass = [KTStackView class];
    
    while (view && ![view isKindOfClass: stackViewClass])
        view = [view superview];
        
    return (KTStackView *)view;
}

@end

