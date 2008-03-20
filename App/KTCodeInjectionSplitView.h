//
//  KTCodeInjectionSplitView.h
//  Marvel
//
//  Created by Mike on 20/03/2008.
//  Copyright 2008 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <iMediaBrowser/RBSplitView.h>


@interface KTCodeInjectionSplitView : RBSplitView
{
	NSString *myDividerDescription;
}

- (NSString *)dividerDescription;
- (void)setDividerDescription:(NSString *)description;

@end
