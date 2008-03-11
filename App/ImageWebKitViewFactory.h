//
//  ImageWebKitViewFactory.h
//  Marvel
//
//  Created by Dan Wood on 3/10/08.
//  Copyright 2008 Karelia Software. All rights reserved.
//

#import <WebKit/WebKit.h>
#import <Cocoa/Cocoa.h>


@interface ImageWebKitViewFactory : NSObject <WebPlugInViewFactory>
{
}

+ (NSView *)plugInViewWithArguments:(NSDictionary *)arguments;

@end


