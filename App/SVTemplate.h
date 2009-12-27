//
//  SVTemplate.h
//  Sandvox
//
//  Created by Mike on 26/12/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface SVTemplate : NSObject
{
  @private
    NSString    *_templateString;
}

// Inefficient for now, in that it always creates a new template, so retain the result yourself. Include the filename extension please.
+ (SVTemplate *)templateNamed:(NSString *)name;

// Returns nil if not a valid string
- (id)initWithContentsOfURL:(NSURL *)url;

@property(nonatomic, copy, readonly) NSString *templateString;

@end
