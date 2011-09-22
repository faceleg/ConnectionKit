//
//  SVDesignChooserImageBrowserView.m
//  Sandvox
//
//  Created by Dan Wood on 12/8/09.
//  Copyright 2009-2011 Karelia Software. All rights reserved.
//

#import "SVDesignChooserImageBrowserView.h"
#import "SVDesignBrowserViewController.h"
#if MAC_OS_X_VERSION_MAX_ALLOWED > MAC_OS_X_VERSION_10_5
#else
#import "DumpedImageKit.h"
#endif


@interface NSObject (privateAPIOhNo)
- (NSRange) range;
- (BOOL) expanded;
@end


@implementation SVDesignChooserImageBrowserView


- (void) setSelectionIndexes:(NSIndexSet *) indexes byExtendingSelection:(BOOL) extendSelection;
{
	[super setSelectionIndexes:indexes byExtendingSelection:extendSelection];
}

- (void)_expandButtonClicked:(NSDictionary *)dict;
{
	[super _expandButtonClicked:dict];
	NSEvent *event = [dict objectForKey:@"event"];
	if ([event type] == NSLeftMouseUp)
	{
		NSDictionary *info = [dict objectForKey:@"info"];
		NSObject *IKImageBrowserGridGroup = [info objectForKey:@"group"];
		if ([IKImageBrowserGridGroup respondsToSelector:@selector(range)] && [IKImageBrowserGridGroup respondsToSelector:@selector(expanded)])
		{
			NSRange range = [IKImageBrowserGridGroup range];
			BOOL expanded = [IKImageBrowserGridGroup expanded];			
			[self.dataSource setContracted:!expanded forRange:range];
		}
	}
}

- (void) awakeFromNib
{
	[self setAllowsEmptySelection:NO];	// doesn't seem to stick when set in IB
	
	NSMutableParagraphStyle *pStyle = [[[NSMutableParagraphStyle alloc] init] autorelease];
    [pStyle setParagraphStyle:[NSParagraphStyle defaultParagraphStyle]];
	[pStyle setTighteningFactorForTruncation:0.15];
	[pStyle setLineBreakMode:NSLineBreakByTruncatingMiddle];
	[pStyle setAlignment:NSCenterTextAlignment];
	
	NSDictionary *attributes
	= [NSDictionary dictionaryWithObjectsAndKeys:
	   [NSFont systemFontOfSize:[NSFont smallSystemFontSize]], NSFontAttributeName,
	   pStyle, NSParagraphStyleAttributeName,
	   nil];
	NSDictionary *attributes2
	= [NSDictionary dictionaryWithObjectsAndKeys:
	   [NSFont systemFontOfSize:[NSFont smallSystemFontSize]], NSFontAttributeName,
	   [NSColor whiteColor], NSForegroundColorAttributeName,
	   pStyle, NSParagraphStyleAttributeName,
	   nil];
	NSDictionary *attributes3
	= [NSDictionary dictionaryWithObjectsAndKeys:
	   [NSFont systemFontOfSize:[NSFont systemFontSizeForControlSize:NSMiniControlSize]], NSFontAttributeName,
	   [NSColor grayColor], NSForegroundColorAttributeName,
	   pStyle, NSParagraphStyleAttributeName,
	   nil];
	
	[self setValue:attributes  forKey:IKImageBrowserCellsTitleAttributesKey];
	[self setValue:attributes2 forKey:IKImageBrowserCellsHighlightedTitleAttributesKey];
	[self setValue:attributes3 forKey:IKImageBrowserCellsSubtitleAttributesKey];
	
	//	[self setCellSize:NSMakeSize(44.0,22.0)];
	if ([self respondsToSelector:@selector(setIntercellSpacing:)])
	{
		[self setIntercellSpacing:NSMakeSize(0.0,10.0)];	// try to get as close as possible.  don't need a subclass for just this, right?
	}
	[self setCellsStyleMask:IKCellsStyleShadowed|IKCellsStyleTitled|IKCellsStyleSubtitled];
	[self setConstrainsToOriginalSize:YES];	// Nothing seems to happen here
	if (NSAppKitVersionNumber <= 1038 + 1)		// 1038.36=10.6.8.   10_6 is not defined in that SDK.  Note: 1138 = 10.7.1
	{
		[self setCellSize:NSMakeSize(120,100)];	// EMPIRICAL - not too small to shrink, not to big to allow > 100x65 sizes
	}
	else	// Lion behaves differently...
	{
		[self setCellSize:NSMakeSize(120, 65)];	// Unfortunately it's too crowded vertically.
	}
}


- (void)keyDown:(NSEvent *)theEvent
{
	if (53 == [theEvent keyCode])		// escape -- doesn't seeem to be a constant for this.
	{
		[NSApp sendAction:@selector(cancelSheet:) to:nil from:self];
	}
	else
	{
		[super keyDown:theEvent];
	}
}


@end
