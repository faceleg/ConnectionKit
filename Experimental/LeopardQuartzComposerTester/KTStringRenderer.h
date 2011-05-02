//
//  KTStringRenderer.h
//  Marvel
//
//  Created by Dan Wood on 3/10/05.
//  Copyright 2005-2011 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <Quartz/Quartz.h>

@interface KTStringRenderer : NSObject {

	QCRenderer	*myRenderer;
	NSString	*myFileName;
}

+ (KTStringRenderer *)rendererWithFile:(NSString *)aFileName;

- (NSImage *)imageWithInputs:(NSDictionary *)inputs;


@end
