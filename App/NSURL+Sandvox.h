//
//  NSURL+Sandvox.h
//  Sandvox
//
//  Created by Mike on 09/09/2010.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


//  This header should be well commented as to its functionality. Further information can be found at 
//  http://docs.karelia.com/z/Sandvox_Developers_Guide.html


@interface NSURL (Sandvox)

// Interprets the query portion of the receiver as a dictionary
- (NSDictionary *)svQueryParameters;

+ (NSURL *)svURLWithScheme:(NSString *)scheme
                      host:(NSString *)host
                      path:(NSString *)path
           queryParameters:(NSDictionary *)parameters;

@end