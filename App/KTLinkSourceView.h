//
//  KTLinkSourceView.h
//  Marvel
//
//  Created by Greg Hulands on 20/03/06.
//  Copyright 2006 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface KTLinkSourceView : NSView 
{
	IBOutlet id					delegate; // not retained
	
	struct __ktDelegateFlags {
		unsigned begin: 1;
		unsigned end: 1;
		unsigned ui: 1;
		unsigned isConnecting: 1;
		unsigned isConnected: 1;
		unsigned unused: 27;
	} myFlags;
}

- (void)setConnected:(BOOL)isConnected;

- (void)setDelegate:(id)delegate;
- (id)delegate;

@end

@interface NSObject (KTLinkSourceViewDelegate)

- (NSPasteboard *)linkSourceDidBeginDrag:(KTLinkSourceView *)link;
- (void)linkSourceDidEndDrag:(KTLinkSourceView *)link withPasteboard:(NSPasteboard *)pboard;
- (id)userInfoForLinkSource:(KTLinkSourceView *)link;

@end
