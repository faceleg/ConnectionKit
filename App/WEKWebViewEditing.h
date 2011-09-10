//
//  WEKWebViewEditing.h
//  Sandvox
//
//  Created by Mike on 27/05/2010.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
//

#import <WebKit/WebKit.h>


@class WEKDOMRange;


@interface WebView (WEKWebViewEditing)

#pragma mark Alignment
- (NSTextAlignment)wek_alignment;


#pragma mark Lists

- (IBAction)insertOrderedList:(id)sender;
- (IBAction)insertUnorderedList:(id)sender;
- (IBAction)removeList:(id)sender;

- (BOOL)orderedList;
- (BOOL)unorderedList;

@end


#pragma mark -


