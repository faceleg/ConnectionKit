//
//  KTImageLoader.h
//  Marvel
//
//  Created by Dan Wood on 1/29/08.
//  Copyright 2008 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface KTImageLoader : NSObject {

	NSURL *myURL;
	NSMutableDictionary *myDictionary;
	NSMutableData *myConnectionData;
	NSSize mySize;
	float myRadius;
}

- (id)initWithURL:(NSURL *)url size:(NSSize)aSize radius:(float)aRadius destination:(NSMutableDictionary *)aDictionary;
+ (NSImage *)finalizeImage:(NSImage *)anImage toSize:(NSSize)aSize radius:(float)aRadius;





@end
