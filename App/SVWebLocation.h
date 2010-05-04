//
//  SVWebLocation.h
//  Sandvox
//
//  Created by Mike on 04/05/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@protocol SVWebLocation <NSObject>

#pragma mark Accessors
@property(nonatomic, copy, readonly) NSURL *URL;
@property(nonatomic, copy, readonly) NSString *title;

@end
