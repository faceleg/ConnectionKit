//
//  SVTemplate.h
//  Sandvox
//
//  Created by Mike on 26/12/2009.
//  Copyright 2009-2011 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface SVTemplate : NSObject
{
  @private
    NSString    *_templateString;
    NSString    *_name;
}

// Returns nil if not a valid string
- (id)initWithContentsOfURL:(NSURL *)url;


#pragma mark Cache

// Inefficient for now, in that it always creates a new template, so retain the result yourself. Include the filename extension please.
+ (SVTemplate *)templateNamed:(NSString *)name;

@property(nonatomic, readonly, copy) NSString *name;
- (BOOL)setName:(NSString *)name;   // like NSImage

@property(nonatomic, copy, readonly) NSString *templateString;

@end
